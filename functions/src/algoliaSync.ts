import * as admin from 'firebase-admin';
import { onDocumentWritten, onDocumentUpdated } from 'firebase-functions/v2/firestore';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { algoliasearch } from 'algoliasearch';
import { getDhakaDateString } from './settleDailyCampaign';

const ALGOLIA_INDEX_NAME = process.env.ALGOLIA_INDEX_NAME || 'ekshate_daily_listings';

const algoliaClient = algoliasearch(
  process.env.ALGOLIA_APP_ID || '',
  process.env.ALGOLIA_ADMIN_API_KEY || ''
);

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

    // 1. DELETE Case: Document was deleted from Firestore
    if (!afterSnap?.exists && beforeSnap?.exists) {
      console.log(`[Algolia Sync] Deleting record: ${listingId}`);
      await algoliaClient.deleteObject({
        indexName: ALGOLIA_INDEX_NAME,
        objectID: listingId,
      });
      return;
    }

    if (!afterSnap?.exists) return;

    const listingData = afterSnap.data()!;
    const db = admin.firestore();

    // 2. Query Master Product details (category, thumbnail)
    let category = 'General';
    let thumbnailUrl = '';
    try {
      const prodSnap = await db.collection('products').doc(listingData.product_id).get();
      if (prodSnap.exists) {
        const prodData = prodSnap.data()!;
        category = prodData.category || 'General';
        thumbnailUrl = prodData.thumbnail_url || '';
      }
    } catch (e) {
      console.warn(`Failed to fetch master product for listing ${listingId}:`, e);
    }

    // 3. Query Active Bucket details to denormalize real-time capacity and progress
    const activeBucketNum = Number(listingData.active_bucket_number || 1);
    let bucketMoq = Number(listingData.moq_threshold || 0);
    let bucketCurrentQty = 0;
    let bucketRemainingCap = bucketMoq;
    let bucketStatus = 'open';

    try {
      const bucketSnap = await afterSnap.ref.collection('buckets').doc(String(activeBucketNum)).get();
      if (bucketSnap.exists) {
        const bData = bucketSnap.data()!;
        bucketMoq = Number(bData.moq_threshold || bucketMoq);
        bucketCurrentQty = Number(bData.current_quantity || 0);
        bucketRemainingCap = Number(bData.remaining_capacity ?? (bucketMoq - bucketCurrentQty));
        bucketStatus = bData.status || 'open';
      }
    } catch (e) {
      console.warn(`Failed to fetch active bucket for listing ${listingId}:`, e);
    }

    const progressPercent = bucketMoq > 0 ? Math.min(1.0, bucketCurrentQty / bucketMoq) : 0.0;

    // 4. Construct Algolia Record
    const record: AlgoliaListingRecord = {
      objectID: listingId,
      listing_id: listingId,
      date,
      product_id: listingData.product_id,
      product_title: listingData.product_title,
      category,
      unit: listingData.unit,
      market_price: Number(listingData.market_price),
      unit_price: Number(listingData.unit_price),
      discount_percent: Number(listingData.discount_percent),
      moq_threshold: Number(listingData.moq_threshold),
      active_bucket_number: activeBucketNum,
      total_buckets_count: Number(listingData.total_buckets_count || 1),
      total_volume_ordered: Number(listingData.total_volume_ordered || 0),
      status: listingData.status || 'active',
      active_bucket_moq: bucketMoq,
      active_bucket_current_qty: bucketCurrentQty,
      active_bucket_remaining_capacity: bucketRemainingCap,
      active_bucket_progress_percent: progressPercent,
      active_bucket_status: bucketStatus,
      thumbnail_url: thumbnailUrl,
      updated_at_timestamp: Date.now(),
    };

    // 5. Upsert to Algolia (v5 API uses client.saveObject)
    await algoliaClient.saveObject({
      indexName: ALGOLIA_INDEX_NAME,
      body: record as unknown as Record<string, unknown>,
    });

    console.log(`[Algolia Sync] Upserted listing ${listingId} (${record.product_title})`);
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
      const listingsSnap = await db.collection(`daily_campaigns/${date}/listings`).get();
      if (listingsSnap.empty) return;

      const records: Record<string, unknown>[] = [];

      for (const doc of listingsSnap.docs) {
        const data = doc.data();
        records.push({
          objectID: doc.id,
          listing_id: doc.id,
          date,
          product_id: data.product_id,
          product_title: data.product_title,
          unit: data.unit,
          market_price: Number(data.market_price),
          unit_price: Number(data.unit_price),
          discount_percent: Number(data.discount_percent),
          moq_threshold: Number(data.moq_threshold),
          active_bucket_number: Number(data.active_bucket_number || 1),
          total_volume_ordered: Number(data.total_volume_ordered || 0),
          status: 'active',
          updated_at_timestamp: Date.now(),
        });
      }

      await algoliaClient.saveObjects({
        indexName: ALGOLIA_INDEX_NAME,
        objects: records,
      });

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

    const securedApiKey = algoliaClient.generateSecuredApiKey({
      parentApiKey: process.env.ALGOLIA_SEARCH_KEY || '',
      restrictions: {
        restrictIndices: [ALGOLIA_INDEX_NAME],
        filters: `status:active AND date:${today}`,
        validUntil: midnightUtcTimestamp,
        hitsPerPage: 30,
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
