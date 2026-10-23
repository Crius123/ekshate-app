import * as admin from 'firebase-admin';
import { onDocumentWritten, onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { algoliasearch } from 'algoliasearch';
import { getDhakaDateString } from './settleDailyCampaign';

export const ALGOLIA_INDEX_NAME = process.env.ALGOLIA_INDEX_NAME || 'ekshate_daily_listings';

export const getAlgoliaClient = () => {
  return algoliasearch(
    process.env.ALGOLIA_APP_ID || '',
    process.env.ALGOLIA_ADMIN_API_KEY || ''
  );
};

export interface AlgoliaListingRecord {
  objectID: string;            // listingId
  listing_id: string;
  date: string;                // "YYYY-MM-DD"
  product_id: string;
  product_title: string;
  category: string;
  unit: string;
  market_price: number;
  unit_price: number;
  discount_percent: number;
  moq_threshold: number;
  active_bucket_number: number;
  total_buckets_count: number;
  total_volume_ordered: number;
  status: string;              // 'preview' | 'active' | 'closed' | 'settled'
  active_bucket_moq: number;
  active_bucket_current_qty: number;
  active_bucket_remaining_capacity: number;
  active_bucket_progress_percent: number;
  active_bucket_status: string;
  thumbnail_url: string;
  updated_at_timestamp: number;
}

/**
 * Builds an AlgoliaListingRecord with denormalized bucket and product details.
 */
export function buildAlgoliaListingRecord(
  date: string,
  listingId: string,
  listingData: Record<string, any>,
  bucketData?: Record<string, any>,
  productData?: Record<string, any>
): AlgoliaListingRecord {
  const activeBucketNum = Number(listingData.active_bucket_number || 1);
  const moqThreshold = Number(listingData.moq_threshold || 0);
  const bucketMoq = Number(bucketData?.moq_threshold ?? moqThreshold);
  const bucketCurrentQty = Number(bucketData?.current_quantity ?? 0);
  const bucketRemainingCap = Number(
    bucketData?.remaining_capacity ?? (bucketMoq > 0 ? bucketMoq - bucketCurrentQty : 0)
  );
  const progressPercent = bucketMoq > 0 ? Math.min(1.0, bucketCurrentQty / bucketMoq) : 0.0;

  return {
    objectID: listingId,
    listing_id: listingId,
    date,
    product_id: listingData.product_id || '',
    product_title: listingData.product_title || '',
    category: productData?.category || listingData.category || 'General',
    unit: listingData.unit || 'kg',
    market_price: Number(listingData.market_price || 0),
    unit_price: Number(listingData.unit_price || 0),
    discount_percent: Number(listingData.discount_percent || 0),
    moq_threshold: moqThreshold,
    active_bucket_number: activeBucketNum,
    total_buckets_count: Number(listingData.total_buckets_count || 1),
    total_volume_ordered: Number(listingData.total_volume_ordered || 0),
    status: listingData.status || 'active',
    active_bucket_moq: bucketMoq,
    active_bucket_current_qty: bucketCurrentQty,
    active_bucket_remaining_capacity: bucketRemainingCap,
    active_bucket_progress_percent: progressPercent,
    active_bucket_status: bucketData?.status || 'open',
    thumbnail_url: productData?.thumbnail_url || listingData.thumbnail_url || '',
    updated_at_timestamp: Date.now(),
  };
}

/**
 * Core function to query related product/bucket documents and sync a listing to Algolia.
 */
export async function syncListingRecordToAlgolia(
  client: { saveObject: (params: any) => Promise<any> },
  indexName: string,
  db: admin.firestore.Firestore,
  date: string,
  listingId: string,
  listingData: Record<string, any>,
  listingDocRef?: admin.firestore.DocumentReference
): Promise<AlgoliaListingRecord> {
  let category = listingData.category || 'General';
  let thumbnailUrl = listingData.thumbnail_url || '';

  if (listingData.product_id) {
    try {
      const prodSnap = await db.collection('products').doc(listingData.product_id).get();
      if (prodSnap.exists) {
        const prodData = prodSnap.data()!;
        category = prodData.category || category;
        thumbnailUrl = prodData.thumbnail_url || thumbnailUrl;
      }
    } catch (e) {
      console.warn(`Failed to fetch master product for listing ${listingId}:`, e);
    }
  }

  const activeBucketNum = Number(listingData.active_bucket_number || 1);
  let bucketData: Record<string, any> | undefined;

  try {
    const bucketRef = listingDocRef
      ? listingDocRef.collection('buckets').doc(String(activeBucketNum))
      : db.doc(`daily_campaigns/${date}/listings/${listingId}/buckets/${activeBucketNum}`);
    const bucketSnap = await bucketRef.get();
    if (bucketSnap.exists) {
      bucketData = bucketSnap.data()!;
    }
  } catch (e) {
    console.warn(`Failed to fetch active bucket for listing ${listingId}:`, e);
  }

  const record = buildAlgoliaListingRecord(
    date,
    listingId,
    listingData,
    bucketData,
    { category, thumbnail_url: thumbnailUrl }
  );

  await client.saveObject({
    indexName,
    body: record as unknown as Record<string, unknown>,
  });

  return record;
}

/**
 * Core function to sync active bucket mutations to Algolia.
 */
export async function syncBucketRecordToAlgolia(
  client: { saveObject: (params: any) => Promise<any> },
  indexName: string,
  db: admin.firestore.Firestore,
  date: string,
  listingId: string,
  bucketNum: string,
  bucketData: Record<string, any>
): Promise<AlgoliaListingRecord | null> {
  const listingRef = db.doc(`daily_campaigns/${date}/listings/${listingId}`);
  const listingSnap = await listingRef.get();
  if (!listingSnap.exists) return null;

  const listingData = listingSnap.data()!;
  const activeBucketNum = Number(listingData.active_bucket_number || 1);

  // Only update Algolia if this mutated bucket is the ACTIVE bucket
  if (Number(bucketNum) !== activeBucketNum) {
    return null;
  }

  let category = listingData.category || 'General';
  let thumbnailUrl = listingData.thumbnail_url || '';
  if (listingData.product_id) {
    try {
      const prodSnap = await db.collection('products').doc(listingData.product_id).get();
      if (prodSnap.exists) {
        const prodData = prodSnap.data()!;
        category = prodData.category || category;
        thumbnailUrl = prodData.thumbnail_url || thumbnailUrl;
      }
    } catch (e) {
      console.warn(`Failed to fetch master product for listing ${listingId}:`, e);
    }
  }

  const record = buildAlgoliaListingRecord(
    date,
    listingId,
    listingData,
    bucketData,
    { category, thumbnail_url: thumbnailUrl }
  );

  await client.saveObject({
    indexName,
    body: record as unknown as Record<string, unknown>,
  });

  return record;
}

/**
 * Core function to batch sync all listings of an activated campaign to Algolia.
 */
export async function batchSyncCampaignToAlgolia(
  client: { saveObjects: (params: any) => Promise<any> },
  indexName: string,
  db: admin.firestore.Firestore,
  date: string
): Promise<AlgoliaListingRecord[]> {
  const listingsSnap = await db.collection(`daily_campaigns/${date}/listings`).get();
  if (listingsSnap.empty) return [];

  const records: AlgoliaListingRecord[] = [];

  for (const doc of listingsSnap.docs) {
    const data = doc.data();
    const activeBucketNum = Number(data.active_bucket_number || 1);

    let bucketData: Record<string, any> | undefined;
    try {
      const bucketSnap = await doc.ref.collection('buckets').doc(String(activeBucketNum)).get();
      if (bucketSnap.exists) {
        bucketData = bucketSnap.data()!;
      }
    } catch (e) {
      console.warn(`Failed to fetch active bucket for listing ${doc.id}:`, e);
    }

    let category = data.category || 'General';
    let thumbnailUrl = data.thumbnail_url || '';
    if (data.product_id) {
      try {
        const prodSnap = await db.collection('products').doc(data.product_id).get();
        if (prodSnap.exists) {
          const prodData = prodSnap.data()!;
          category = prodData.category || category;
          thumbnailUrl = prodData.thumbnail_url || thumbnailUrl;
        }
      } catch (e) {
        console.warn(`Failed to fetch master product for listing ${doc.id}:`, e);
      }
    }

    records.push(buildAlgoliaListingRecord(
      date,
      doc.id,
      data,
      bucketData,
      { category, thumbnail_url: thumbnailUrl }
    ));
  }

  await client.saveObjects({
    indexName,
    objects: records as unknown as Record<string, unknown>[],
  });

  return records;
}

/**
 * Real-time Firestore sync trigger for daily listings.
 * Listens to: daily_campaigns/{date}/listings/{listingId}
 */
export const syncListingToAlgolia = onDocumentWritten(
  {
    document: 'daily_campaigns/{date}/listings/{listingId}',
    region: 'asia-south1',
    secrets: ['ALGOLIA_APP_ID', 'ALGOLIA_ADMIN_API_KEY'],
    retry: true,
  },
  async (event) => {
    const { date, listingId } = event.params;
    const beforeSnap = event.data?.before;
    const afterSnap = event.data?.after;

    const client = getAlgoliaClient();

    // 1. DELETE Case: Document was deleted from Firestore
    if (!afterSnap?.exists && beforeSnap?.exists) {
      console.log(`[Algolia Sync] Deleting record: ${listingId}`);
      await client.deleteObject({
        indexName: ALGOLIA_INDEX_NAME,
        objectID: listingId,
      });
      return;
    }

    if (!afterSnap?.exists) return;

    const listingData = afterSnap.data()!;
    const db = admin.firestore();

    const record = await syncListingRecordToAlgolia(
      client,
      ALGOLIA_INDEX_NAME,
      db,
      date,
      listingId,
      listingData,
      afterSnap.ref
    );

    console.log(`[Algolia Sync] Upserted listing ${listingId} (${record.product_title})`);
  }
);

/**
 * Real-time Firestore sync trigger for batch buckets.
 * Listens to: daily_campaigns/{date}/listings/{listingId}/buckets/{bucketNum}
 */
export const syncBucketToAlgolia = onDocumentWritten(
  {
    document: 'daily_campaigns/{date}/listings/{listingId}/buckets/{bucketNum}',
    region: 'asia-south1',
    secrets: ['ALGOLIA_APP_ID', 'ALGOLIA_ADMIN_API_KEY'],
    retry: true,
  },
  async (event) => {
    const { date, listingId, bucketNum } = event.params;
    const afterSnap = event.data?.after;
    if (!afterSnap?.exists) return;

    const bucketData = afterSnap.data()!;
    const db = admin.firestore();
    const client = getAlgoliaClient();

    const record = await syncBucketRecordToAlgolia(
      client,
      ALGOLIA_INDEX_NAME,
      db,
      date,
      listingId,
      bucketNum,
      bucketData
    );

    if (record) {
      console.log(`[Algolia Sync] Synced bucket #${bucketNum} mutation for listing ${listingId}`);
    }
  }
);

/**
 * Campaign Activation Batch Sync:
 * When campaign document flips to status: 'active' (e.g. at 10:00 AM BDT),
 * perform an atomic batch upsert to ensure all listings are live with zero query lag.
 */
export const onCampaignActivated = onDocumentUpdated(
  {
    document: 'daily_campaigns/{date}',
    region: 'asia-south1',
    secrets: ['ALGOLIA_APP_ID', 'ALGOLIA_ADMIN_API_KEY'],
  },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    if (before.status !== 'active' && after.status === 'active') {
      const date = event.params.date;
      console.log(`[Algolia Sync] Campaign ${date} activated! Running batch sync.`);

      const db = admin.firestore();
      const client = getAlgoliaClient();

      const records = await batchSyncCampaignToAlgolia(
        client,
        ALGOLIA_INDEX_NAME,
        db,
        date
      );

      console.log(`[Algolia Sync] Batch synced ${records.length} listings for active campaign.`);
    }
  }
);

/**
 * Generates an Algolia secured search key restricted to the current active campaign date
 */
export const getSearchToken = onCall(
  {
    region: 'asia-south1',
    secrets: ['ALGOLIA_APP_ID', 'ALGOLIA_SEARCH_KEY'],
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'User must be authenticated.');
    }
    const today = getDhakaDateString();
    const [year, month, day] = today.split('-').map(Number);
    const midnightUtcTimestamp = Math.floor(Date.UTC(year, month - 1, day, 17, 59, 59) / 1000);

    const client = getAlgoliaClient();
    const securedApiKey = client.generateSecuredApiKey({
      parentApiKey: process.env.ALGOLIA_SEARCH_KEY || '',
      restrictions: {
        restrictIndices: [ALGOLIA_INDEX_NAME],
        filters: `status:active AND date:${today}`,
        validUntil: midnightUtcTimestamp,
      },
    });

    return {
      appId: process.env.ALGOLIA_APP_ID,
      indexName: ALGOLIA_INDEX_NAME,
      securedApiKey,
      validUntil: midnightUtcTimestamp,
    };
  }
);
