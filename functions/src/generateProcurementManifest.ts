import * as admin from 'firebase-admin';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getDhakaDateString } from './settleDailyCampaign';

export interface ProcurementItem {
  sku: string;
  listing_id: string;
  product_id: string;
  product_title: string;
  category: string;
  total_volume: number;
  unit: string;
  confirmed_buckets_count: number;
  estimated_unit_cost: number;
  total_budget: number;
  target_market: string;
  packaging_notes: string;
  status: 'pending' | 'procured';
}

export interface ProcurementManifest {
  date: string;
  total_confirmed_volume: number;
  total_procurement_cost: number;
  total_items_count: number;
  total_buckets_count: number;
  items: ProcurementItem[];
  csv_payload: string;
  status: 'pending_procurement' | 'in_procurement' | 'procured';
  created_at: admin.firestore.FieldValue | FirebaseFirestore.Timestamp;
  updated_at: admin.firestore.FieldValue | FirebaseFirestore.Timestamp;
}

/**
 * Standard RFC 4180 CSV value escaping
 */
export function escapeCsvField(value: any): string {
  if (value === null || value === undefined) return '';
  const str = String(value);
  if (str.includes(',') || str.includes('"') || str.includes('\n') || str.includes('\r')) {
    return `"${str.replace(/"/g, '""')}"`;
  }
  return str;
}

/**
 * Generates standardized CSV string payload for morning physical procurement market agents.
 * Columns: SKU, Product Title, Category, Total Volume, Unit, Estimated Unit Cost,
 *          Total Budget, Target Wholesale Market / Supplier, and Packaging Notes.
 */
export function generateProcurementCsv(items: ProcurementItem[]): string {
  const headers = [
    'SKU',
    'Product Title',
    'Category',
    'Total Volume',
    'Unit',
    'Estimated Unit Cost',
    'Total Budget',
    'Target Wholesale Market / Supplier',
    'Packaging Notes',
  ];

  const headerLine = headers.join(',');
  if (items.length === 0) {
    return headerLine + '\n';
  }

  const rows = items.map((item) =>
    [
      escapeCsvField(item.sku),
      escapeCsvField(item.product_title),
      escapeCsvField(item.category),
      escapeCsvField(item.total_volume),
      escapeCsvField(item.unit),
      escapeCsvField(item.estimated_unit_cost),
      escapeCsvField(item.total_budget),
      escapeCsvField(item.target_market),
      escapeCsvField(item.packaging_notes),
    ].join(',')
  );

  return [headerLine, ...rows].join('\n') + '\n';
}

/**
 * Calculates packaging requirements based on product metadata, category, unit, and total volume.
 * Handles specifications such as 50 kg burlap bags, 10 kg crates, 5 L tins, etc.
 */
export function calculatePackagingNotes(
  totalVolume: number,
  unit: string,
  category: string,
  customPackagingSpec?: string
): string {
  if (totalVolume <= 0) {
    return 'N/A (0 volume)';
  }

  // If a custom specification was passed on the listing or product (e.g. "50 kg burlap bags")
  if (customPackagingSpec && customPackagingSpec.trim().length > 0) {
    const sizeMatch = customPackagingSpec.match(/^(\d+(?:\.\d+)?)\s*(kg|liter|l|piece|bundle)?\s*(.*)$/i);
    if (sizeMatch) {
      const packSize = parseFloat(sizeMatch[1]);
      const packName = sizeMatch[3]?.trim() || 'packs';
      if (packSize > 0) {
        const fullPacks = Math.floor(totalVolume / packSize);
        const remainder = +(totalVolume % packSize).toFixed(2);
        if (fullPacks > 0 && remainder > 0) {
          return `${fullPacks} x ${packSize} ${unit} ${packName} + 1 x ${remainder} ${unit} loose`;
        } else if (fullPacks > 0) {
          return `${fullPacks} x ${packSize} ${unit} ${packName}`;
        } else {
          return `1 x ${remainder} ${unit} loose ${packName}`;
        }
      }
    }
    return `${customPackagingSpec} (${totalVolume} ${unit})`;
  }

  const normalizedCategory = (category || '').toLowerCase();
  const normalizedUnit = (unit || '').toLowerCase();

  // 1. Bulk Grains, Staples & Root Vegetables -> 50 kg burlap bags
  if (
    normalizedCategory.includes('grain') ||
    normalizedCategory.includes('staple') ||
    normalizedCategory.includes('rice') ||
    normalizedCategory.includes('potato') ||
    normalizedCategory.includes('onion') ||
    normalizedCategory.includes('pulse') ||
    normalizedCategory.includes('lentil') ||
    normalizedCategory.includes('flour')
  ) {
    const fullBags = Math.floor(totalVolume / 50);
    const remainder = +(totalVolume % 50).toFixed(2);
    if (fullBags > 0 && remainder > 0) {
      return `${fullBags} x 50 kg burlap bags + 1 x ${remainder} kg loose sack`;
    } else if (fullBags > 0) {
      return `${fullBags} x 50 kg burlap bags`;
    } else {
      return `1 x ${remainder} kg burlap bag`;
    }
  }

  // 2. Fresh Fruits & Vegetables -> 10 kg plastic crates
  if (
    normalizedCategory.includes('fruit') ||
    normalizedCategory.includes('produce') ||
    normalizedCategory.includes('vegetable')
  ) {
    const fullCrates = Math.floor(totalVolume / 10);
    const remainder = +(totalVolume % 10).toFixed(2);
    if (fullCrates > 0 && remainder > 0) {
      return `${fullCrates} x 10 kg crates + 1 x ${remainder} kg loose crate`;
    } else if (fullCrates > 0) {
      return `${fullCrates} x 10 kg crates`;
    } else {
      return `1 x ${remainder} kg crate`;
    }
  }

  // 3. Edible Oils & Liquids -> 5 L food-grade containers
  if (normalizedUnit.includes('liter') || normalizedCategory.includes('oil') || normalizedCategory.includes('liquid')) {
    const fullContainers = Math.floor(totalVolume / 5);
    const remainder = +(totalVolume % 5).toFixed(2);
    if (fullContainers > 0 && remainder > 0) {
      return `${fullContainers} x 5 L containers + 1 x ${remainder} L container`;
    } else if (fullContainers > 0) {
      return `${fullContainers} x 5 L containers`;
    } else {
      return `1 x ${remainder} L container`;
    }
  }

  // Default fallback packaging: Wholesale cartons
  const packCount = Math.ceil(totalVolume / 10);
  return `${packCount} x Wholesale cartons (${totalVolume} ${unit})`;
}

/**
 * Extracts estimated unit wholesale procurement cost.
 * Falls back to 75% of customer retail/bulk unit_price.
 */
function determineEstimatedUnitCost(listingData: any, productData: any): number {
  if (typeof listingData.estimated_unit_cost === 'number' && listingData.estimated_unit_cost > 0) {
    return listingData.estimated_unit_cost;
  }
  if (typeof listingData.wholesale_price === 'number' && listingData.wholesale_price > 0) {
    return listingData.wholesale_price;
  }
  if (typeof listingData.wholesale_cost === 'number' && listingData.wholesale_cost > 0) {
    return listingData.wholesale_cost;
  }
  if (productData && typeof productData.wholesale_cost === 'number' && productData.wholesale_cost > 0) {
    return productData.wholesale_cost;
  }
  const unitPrice = Number(listingData.unit_price) || 0;
  return Math.round(unitPrice * 0.75);
}

/**
 * Extracts target wholesale depot/market name.
 */
function determineTargetMarket(listingData: any, productData: any): string {
  return (
    listingData.target_market ||
    listingData.supplier_market ||
    listingData.target_supplier ||
    (productData && productData.target_market) ||
    'Karwan Bazar Wholesale Hub, Dhaka'
  );
}

/**
 * Core reconciliation engine that aggregates confirmed won buckets across listings
 * for a campaign date and writes an immutable record to `procurement_manifests/{date}`.
 */
export async function buildProcurementManifest(
  campaignDate: string,
  firestoreInstance?: admin.firestore.Firestore
): Promise<ProcurementManifest> {
  const db = firestoreInstance || admin.firestore();
  const manifestRef = db.collection('procurement_manifests').doc(campaignDate);

  const existingSnap = await manifestRef.get();
  const existingData = existingSnap.exists ? existingSnap.data() : null;
  const initialStatus: 'pending_procurement' | 'in_procurement' | 'procured' =
    existingData?.status || 'pending_procurement';

  const campaignRef = db.collection('daily_campaigns').doc(campaignDate);
  const listingsSnap = await campaignRef.collection('listings').get();

  const items: ProcurementItem[] = [];
  let totalConfirmedVolume = 0;
  let totalProcurementCost = 0;
  let totalBucketsCount = 0;

  for (const listingDoc of listingsSnap.docs) {
    const listingId = listingDoc.id;
    const listingData = listingDoc.data();

    // Query buckets belonging to this listing
    const bucketsSnap = await listingDoc.ref.collection('buckets').get();
    const confirmedBuckets = bucketsSnap.docs.filter((b) => {
      const bData = b.data();
      return bData.status === 'confirmed';
    });

    if (confirmedBuckets.length === 0) {
      continue;
    }

    let listingVolume = 0;
    for (const bucketDoc of confirmedBuckets) {
      const bData = bucketDoc.data();
      const qty = Number(bData.current_quantity) || Number(bData.moq_threshold) || 0;
      listingVolume += qty;
    }

    if (listingVolume <= 0) {
      continue;
    }

    totalBucketsCount += confirmedBuckets.length;
    totalConfirmedVolume += listingVolume;

    // Optional Master product lookup
    let productData: any = null;
    if (listingData.product_id) {
      try {
        const prodSnap = await db.collection('products').doc(listingData.product_id).get();
        if (prodSnap.exists) {
          productData = prodSnap.data();
        }
      } catch (err) {
        // Continue if products collection does not contain doc
      }
    }

    const sku =
      listingData.sku ||
      (productData && productData.sku) ||
      listingData.product_id ||
      listingId;
    const productTitle = listingData.product_title || productData?.title || 'Wholesale Produce';
    const category = listingData.category || productData?.category || 'General Wholesale';
    const unit = listingData.unit || productData?.unit || 'kg';
    const estimatedUnitCost = determineEstimatedUnitCost(listingData, productData);
    const totalBudget = Math.round(listingVolume * estimatedUnitCost);
    totalProcurementCost += totalBudget;

    const targetMarket = determineTargetMarket(listingData, productData);
    const customPackagingSpec = listingData.packaging_spec || productData?.packaging_spec;
    const packagingNotes = calculatePackagingNotes(listingVolume, unit, category, customPackagingSpec);

    // Preserve item checklist status if it was already marked as procured by a market agent
    const previousItem = existingData?.items?.find((i: any) => i.sku === sku || i.listing_id === listingId);
    const itemStatus: 'pending' | 'procured' = previousItem?.status === 'procured' ? 'procured' : 'pending';

    items.push({
      sku,
      listing_id: listingId,
      product_id: listingData.product_id || '',
      product_title: productTitle,
      category,
      total_volume: listingVolume,
      unit,
      confirmed_buckets_count: confirmedBuckets.length,
      estimated_unit_cost: estimatedUnitCost,
      total_budget: totalBudget,
      target_market: targetMarket,
      packaging_notes: packagingNotes,
      status: itemStatus,
    });
  }

  // Generate downloadable/shareable CSV payload
  const csvPayload = generateProcurementCsv(items);

  const manifestRecord: ProcurementManifest = {
    date: campaignDate,
    total_confirmed_volume: totalConfirmedVolume,
    total_procurement_cost: totalProcurementCost,
    total_items_count: items.length,
    total_buckets_count: totalBucketsCount,
    items,
    csv_payload: csvPayload,
    status: initialStatus,
    created_at: existingData?.created_at || admin.firestore.FieldValue.serverTimestamp(),
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  };

  await manifestRef.set(manifestRecord, { merge: true });

  console.log(`Procurement manifest for ${campaignDate} saved:`, {
    totalConfirmedVolume,
    totalProcurementCost,
    itemsCount: items.length,
  });

  return manifestRecord;
}

/**
 * Cloud Function generateProcurementManifest: Callable endpoint for admins and procurement market agents.
 */
export const generateProcurementManifest = onCall<{ date?: string }>(
  {
    region: 'asia-south1',
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Authentication required.');
    }

    const targetDate = request.data?.date || getDhakaDateString();
    const manifest = await buildProcurementManifest(targetDate);
    return {
      success: true,
      manifest,
    };
  }
);

/**
 * Scheduled Cloud Function running at 4:00 AM BDT every morning.
 * Prepares the physical market procurement manifest for on-ground Karwan Bazar and farm depot agents.
 */
export const scheduledProcurementManifest = onSchedule(
  {
    schedule: '0 4 * * *',
    timeZone: 'Asia/Dhaka',
    region: 'asia-south1',
    retryCount: 3,
  },
  async () => {
    const todayDhaka = getDhakaDateString();
    console.log(`Running scheduled 4:00 AM procurement manifest generation for date: ${todayDhaka}`);
    await buildProcurementManifest(todayDhaka);
  }
);
