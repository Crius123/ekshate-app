import { describe, it } from 'node:test';
import * as assert from 'node:assert/strict';
import {
  buildAlgoliaListingRecord,
  syncListingRecordToAlgolia,
  syncBucketRecordToAlgolia,
  batchSyncCampaignToAlgolia,
} from '../algoliaSync';
import { LISTINGS_INDEX_SETTINGS } from '../algoliaConfig';

// Mock Algolia Client for testing without network calls
class MockAlgoliaClient {
  public savedObjects: Array<{ indexName: string; body: any }> = [];
  public batchSavedObjects: Array<{ indexName: string; objects: any[] }> = [];
  public deletedObjects: Array<{ indexName: string; objectID: string }> = [];

  async saveObject(params: { indexName: string; body: any }) {
    this.savedObjects.push(params);
    return { taskID: 'task_mock_1' };
  }

  async saveObjects(params: { indexName: string; objects: any[] }) {
    this.batchSavedObjects.push(params);
    return { taskIDs: ['task_mock_batch'] };
  }

  async deleteObject(params: { indexName: string; objectID: string }) {
    this.deletedObjects.push(params);
    return { taskID: 'task_mock_del' };
  }
}

// In-Memory Firestore mock
class MockFirestoreForAlgolia {
  public docs: Map<string, any> = new Map();

  setDoc(path: string, data: any) {
    this.docs.set(path, data);
  }

  doc(path: string) {
    const data = this.docs.get(path);
    return {
      id: path.split('/').pop() || '',
      path,
      get: async () => ({
        exists: data !== undefined,
        data: () => data,
      }),
      collection: (colName: string) => {
        return {
          doc: (subId: string) => {
            const subPath = `${path}/${colName}/${subId}`;
            const subData = this.docs.get(subPath);
            return {
              id: subId,
              path: subPath,
              get: async () => ({
                exists: subData !== undefined,
                data: () => subData,
              }),
            };
          },
        };
      },
    };
  }

  collection(path: string) {
    return {
      doc: (docId: string) => this.doc(`${path}/${docId}`),
      get: async () => {
        const matches: any[] = [];
        for (const [key, val] of this.docs.entries()) {
          if (key.startsWith(path + '/') && key.split('/').length === path.split('/').length + 1) {
            matches.push({
              id: key.split('/').pop() || '',
              ref: this.doc(key),
              data: () => val,
            });
          }
        }
        return {
          empty: matches.length === 0,
          docs: matches,
        };
      },
    };
  }
}

describe('Algolia Real-Time Search Sync & Engine Tests', () => {
  it('buildAlgoliaListingRecord correctly denormalizes bucket progress, capacity, and product fields', () => {
    const listingData = {
      product_id: 'prod_orange_01',
      product_title: 'Nagpur Oranges (1 kg)',
      unit: 'kg',
      market_price: 240,
      unit_price: 180,
      discount_percent: 25,
      moq_threshold: 100,
      active_bucket_number: 1,
      total_buckets_count: 1,
      total_volume_ordered: 65,
      status: 'active',
    };

    const bucketData = {
      bucket_number: 1,
      moq_threshold: 100,
      current_quantity: 65,
      remaining_capacity: 35,
      status: 'open',
    };

    const productData = {
      category: 'Fresh Fruits',
      thumbnail_url: 'https://cdn.example.com/orange.png',
    };

    const record = buildAlgoliaListingRecord(
      '2026-10-22',
      'listing_orange_01',
      listingData,
      bucketData,
      productData
    );

    assert.equal(record.objectID, 'listing_orange_01');
    assert.equal(record.product_title, 'Nagpur Oranges (1 kg)');
    assert.equal(record.category, 'Fresh Fruits');
    assert.equal(record.unit, 'kg');
    assert.equal(record.unit_price, 180);
    assert.equal(record.market_price, 240);
    assert.equal(record.discount_percent, 25);
    assert.equal(record.active_bucket_number, 1);
    assert.equal(record.active_bucket_current_qty, 65);
    assert.equal(record.active_bucket_remaining_capacity, 35);
    assert.equal(record.active_bucket_progress_percent, 0.65);
    assert.equal(record.active_bucket_status, 'open');
    assert.equal(record.thumbnail_url, 'https://cdn.example.com/orange.png');
    assert.ok(record.updated_at_timestamp > 0);
  });

  it('syncListingRecordToAlgolia saves denormalized listing record into Algolia index', async () => {
    const mockClient = new MockAlgoliaClient();
    const mockDb = new MockFirestoreForAlgolia();

    mockDb.setDoc('products/prod_rice_01', {
      category: 'Grains & Staples',
      thumbnail_url: 'https://cdn.example.com/rice.png',
    });

    mockDb.setDoc('daily_campaigns/2026-10-22/listings/listing_rice_01/buckets/1', {
      current_quantity: 20,
      remaining_capacity: 80,
      moq_threshold: 100,
      status: 'open',
    });

    const listingData = {
      product_id: 'prod_rice_01',
      product_title: 'Miniket Rice 25kg',
      unit: 'bag',
      market_price: 2100,
      unit_price: 1750,
      discount_percent: 16.6,
      moq_threshold: 100,
      active_bucket_number: 1,
      total_volume_ordered: 20,
      status: 'active',
    };

    const record = await syncListingRecordToAlgolia(
      mockClient,
      'ekshate_daily_listings',
      mockDb as any,
      '2026-10-22',
      'listing_rice_01',
      listingData
    );

    assert.equal(record.product_title, 'Miniket Rice 25kg');
    assert.equal(record.active_bucket_remaining_capacity, 80);
    assert.equal(mockClient.savedObjects.length, 1);
    assert.equal(mockClient.savedObjects[0].indexName, 'ekshate_daily_listings');
    assert.equal(mockClient.savedObjects[0].body.product_title, 'Miniket Rice 25kg');
    assert.equal(mockClient.savedObjects[0].body.category, 'Grains & Staples');
    assert.equal(mockClient.savedObjects[0].body.active_bucket_remaining_capacity, 80);
    assert.equal(mockClient.savedObjects[0].body.active_bucket_progress_percent, 0.2);
  });

  it('syncBucketRecordToAlgolia updates Algolia when active bucket mutates', async () => {
    const mockClient = new MockAlgoliaClient();
    const mockDb = new MockFirestoreForAlgolia();

    mockDb.setDoc('daily_campaigns/2026-10-22/listings/listing_oil_01', {
      product_id: 'prod_oil_01',
      product_title: 'Mustard Oil 5L',
      unit: 'jar',
      market_price: 950,
      unit_price: 780,
      discount_percent: 18,
      moq_threshold: 50,
      active_bucket_number: 2,
      total_volume_ordered: 70,
      status: 'active',
    });

    mockDb.setDoc('products/prod_oil_01', {
      category: 'Edible Oils',
      thumbnail_url: 'https://cdn.example.com/oil.png',
    });

    // Mutate Active Bucket (#2)
    const activeBucketMutation = {
      bucket_number: 2,
      current_quantity: 20,
      remaining_capacity: 30,
      moq_threshold: 50,
      status: 'open',
    };

    const record = await syncBucketRecordToAlgolia(
      mockClient,
      'ekshate_daily_listings',
      mockDb as any,
      '2026-10-22',
      'listing_oil_01',
      '2',
      activeBucketMutation
    );

    assert.ok(record !== null);
    assert.equal(mockClient.savedObjects.length, 1);
    assert.equal(mockClient.savedObjects[0].body.active_bucket_number, 2);
    assert.equal(mockClient.savedObjects[0].body.active_bucket_current_qty, 20);
    assert.equal(mockClient.savedObjects[0].body.active_bucket_remaining_capacity, 30);
    assert.equal(mockClient.savedObjects[0].body.active_bucket_progress_percent, 0.4);
  });

  it('syncBucketRecordToAlgolia ignores mutations on non-active historical buckets', async () => {
    const mockClient = new MockAlgoliaClient();
    const mockDb = new MockFirestoreForAlgolia();

    mockDb.setDoc('daily_campaigns/2026-10-22/listings/listing_oil_01', {
      product_id: 'prod_oil_01',
      product_title: 'Mustard Oil 5L',
      unit: 'jar',
      active_bucket_number: 2, // Active is #2
      status: 'active',
    });

    // Mutate Completed Bucket (#1)
    const historicalBucketData = {
      bucket_number: 1,
      current_quantity: 50,
      remaining_capacity: 0,
      status: 'target_met',
    };

    const record = await syncBucketRecordToAlgolia(
      mockClient,
      'ekshate_daily_listings',
      mockDb as any,
      '2026-10-22',
      'listing_oil_01',
      '1', // Mutating #1 while active is #2
      historicalBucketData
    );

    assert.equal(record, null);
    assert.equal(mockClient.savedObjects.length, 0); // No Algolia update sent
  });

  it('batchSyncCampaignToAlgolia performs atomic batch upsert for all campaign listings on activation', async () => {
    const mockClient = new MockAlgoliaClient();
    const mockDb = new MockFirestoreForAlgolia();

    mockDb.setDoc('daily_campaigns/2026-10-22/listings/deal_1', {
      product_id: 'prod_1',
      product_title: 'Deal 1',
      active_bucket_number: 1,
      status: 'active',
      unit: 'kg',
      moq_threshold: 100,
    });
    mockDb.setDoc('daily_campaigns/2026-10-22/listings/deal_1/buckets/1', {
      current_quantity: 10,
      remaining_capacity: 90,
      moq_threshold: 100,
      status: 'open',
    });

    mockDb.setDoc('daily_campaigns/2026-10-22/listings/deal_2', {
      product_id: 'prod_2',
      product_title: 'Deal 2',
      active_bucket_number: 1,
      status: 'active',
      unit: 'liter',
      moq_threshold: 50,
    });
    mockDb.setDoc('daily_campaigns/2026-10-22/listings/deal_2/buckets/1', {
      current_quantity: 25,
      remaining_capacity: 25,
      moq_threshold: 50,
      status: 'open',
    });

    const records = await batchSyncCampaignToAlgolia(
      mockClient,
      'ekshate_daily_listings',
      mockDb as any,
      '2026-10-22'
    );

    assert.equal(records.length, 2);
    assert.equal(mockClient.batchSavedObjects.length, 1);
    assert.equal(mockClient.batchSavedObjects[0].objects.length, 2);
    assert.equal(mockClient.batchSavedObjects[0].indexName, 'ekshate_daily_listings');
  });

  it('verifies Algolia index settings configuration structure', () => {
    assert.ok(LISTINGS_INDEX_SETTINGS.searchableAttributes.includes('unordered(product_title)'));
    assert.ok(LISTINGS_INDEX_SETTINGS.searchableAttributes.includes('unordered(category)'));
    assert.ok(LISTINGS_INDEX_SETTINGS.attributesForFaceting.includes('filterOnly(status)'));
    assert.ok(LISTINGS_INDEX_SETTINGS.attributesForFaceting.includes('filterOnly(date)'));
    assert.ok(LISTINGS_INDEX_SETTINGS.attributesForFaceting.includes('category'));
    assert.ok(LISTINGS_INDEX_SETTINGS.customRanking.includes('desc(total_volume_ordered)'));
  });
});
