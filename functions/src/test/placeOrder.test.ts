import { describe, it } from 'node:test';
import * as assert from 'node:assert/strict';
import { executePlaceOrder, processBucketTargetMet, PlaceOrderPayload } from '../placeOrder';

// Comprehensive In-Memory Hierarchical Firestore Mock replicating real transactions & subcollections
class HierarchicalMockFirestore {
  private docs: Map<string, any> = new Map();
  private autoIdCounter = 1000;

  generateId(prefix = 'doc_'): string {
    this.autoIdCounter++;
    return `${prefix}${this.autoIdCounter}`;
  }

  setDoc(path: string, data: any) {
    this.docs.set(path, { ...data });
  }

  getDoc(path: string) {
    const d = this.docs.get(path);
    return d ? { ...d } : undefined;
  }

  getAllDocsInCollection(collectionPrefix: string) {
    const results: Array<{ path: string; id: string; data: any }> = [];
    for (const [path, data] of this.docs.entries()) {
      // Must match directly under collectionPrefix (not nested subcollections)
      if (path.startsWith(collectionPrefix + '/')) {
        const subPath = path.substring(collectionPrefix.length + 1);
        if (!subPath.includes('/')) {
          results.push({ path, id: subPath, data: { ...data } });
        }
      }
    }
    return results;
  }

  collection(collectionPath: string) {
    return this.createCollectionRef(collectionPath);
  }

  private createCollectionRef(path: string): any {
    return {
      path,
      doc: (docId?: string) => {
        const id = docId || this.generateId('gen_');
        const docPath = `${path}/${id}`;
        return this.createDocRef(docPath, id);
      },
      where: (field: string, op: string, value: any) => {
        const queryFilters: Array<{ field: string; op: string; value: any }> = [
          { field, op, value },
        ];
        const queryObj = {
          where: (f2: string, op2: string, v2: any) => {
            queryFilters.push({ field: f2, op: op2, value: v2 });
            return queryObj;
          },
          get: async () => {
            const allDocs = this.getAllDocsInCollection(path);
            const filtered = allDocs.filter((d) => {
              return queryFilters.every((q) => {
                const val = d.data[q.field];
                if (q.op === '==') return val === q.value;
                return false;
              });
            });

            return {
              empty: filtered.length === 0,
              size: filtered.length,
              docs: filtered.map((f) => ({
                id: f.id,
                ref: this.createDocRef(f.path, f.id),
                data: () => ({ ...f.data }),
              })),
            };
          },
        };
        return queryObj;
      },
    };
  }

  private createDocRef(docPath: string, docId: string): any {
    return {
      path: docPath,
      id: docId,
      get: async () => {
        const d = this.docs.get(docPath);
        return {
          id: docId,
          exists: d !== undefined,
          data: () => (d ? { ...d } : undefined),
        };
      },
      set: async (data: any) => {
        this.docs.set(docPath, { ...data });
      },
      update: async (data: any) => {
        const current = this.docs.get(docPath) || {};
        this.docs.set(docPath, { ...current, ...data });
      },
      collection: (subColName: string) => {
        return this.createCollectionRef(`${docPath}/${subColName}`);
      },
    };
  }

  batch() {
    const stagedUpdates: Array<() => void> = [];
    return {
      update: (docRef: any, data: any) => {
        stagedUpdates.push(() => {
          const current = this.docs.get(docRef.path) || {};
          this.docs.set(docRef.path, { ...current, ...data });
        });
      },
      commit: async () => {
        for (const u of stagedUpdates) {
          u();
        }
      },
    };
  }

  async runTransaction<T>(updateFunction: (transaction: any) => Promise<T>): Promise<T> {
    const stagedWrites: Array<() => void> = [];

    const transaction = {
      get: async (docRef: any) => {
        const docData = this.docs.get(docRef.path);
        return {
          exists: docData !== undefined,
          id: docRef.id,
          data: () => (docData ? { ...docData } : undefined),
        };
      },
      set: (docRef: any, data: any) => {
        stagedWrites.push(() => {
          this.docs.set(docRef.path, { ...data });
        });
      },
      update: (docRef: any, data: any) => {
        stagedWrites.push(() => {
          const current = this.docs.get(docRef.path) || {};
          const updated = { ...current };

          for (const key of Object.keys(data)) {
            const val = data[key];
            if (val && typeof val === 'object' && ('operand' in val || (val as any).isIncrement)) {
              const operand = (val as any).operand ?? (val as any).value ?? 0;
              updated[key] = (Number(updated[key]) || 0) + Number(operand);
            } else {
              updated[key] = val;
            }
          }

          this.docs.set(docRef.path, updated);
        });
      },
    };

    const result = await updateFunction(transaction);

    // Apply writes
    for (const write of stagedWrites) {
      write();
    }

    return result;
  }
}

describe('placeOrder Atomic Cloud Function & Rollover Integration Tests', () => {
  const TEST_DATE = '2026-10-22';
  const LISTING_ID = 'oranges_01';
  const BUYER_UID = 'user_buyer_42';

  function setupTestEnvironment() {
    const mockDb = new HierarchicalMockFirestore();

    // 1. Seed Customer Profile
    mockDb.setDoc(`users/${BUYER_UID}`, {
      uid: BUYER_UID,
      phone_number: '+8801711000042',
      available_balance: 5000,
      escrow_balance: 0,
      role: 'customer',
    });

    // 2. Seed Daily Campaign
    mockDb.setDoc(`daily_campaigns/${TEST_DATE}`, {
      date: TEST_DATE,
      status: 'active',
    });

    // 3. Seed Daily Listing
    mockDb.setDoc(`daily_campaigns/${TEST_DATE}/listings/${LISTING_ID}`, {
      id: LISTING_ID,
      product_id: 'prod_orange_01',
      product_title: 'Nagpur Oranges (1 kg)',
      unit: 'kg',
      unit_price: 180,
      active_bucket_number: 1,
      total_buckets_count: 1,
      total_volume_ordered: 65,
      status: 'active',
    });

    // 4. Seed Active Bucket #1 (MOQ: 100, Current: 65, Remaining: 35)
    mockDb.setDoc(`daily_campaigns/${TEST_DATE}/listings/${LISTING_ID}/buckets/1`, {
      bucket_number: 1,
      listing_id: LISTING_ID,
      date: TEST_DATE,
      moq_threshold: 100,
      current_quantity: 65,
      remaining_capacity: 35,
      status: 'open',
      order_count: 4,
    });

    return mockDb;
  }

  it('successfully debits available balance, credits escrow, creates order & writes audit ledger entry', async () => {
    const mockDb = setupTestEnvironment();

    const payload: PlaceOrderPayload = {
      date: TEST_DATE,
      listingId: LISTING_ID,
      quantity: 10, // 10 kg @ 180 = 1800 BDT
      deliveryAddress: 'House 12, Road 5, Dhanmondi, Dhaka',
      phone: '+8801711000042',
    };

    const result = await executePlaceOrder(BUYER_UID, payload, mockDb as any);

    assert.equal(result.success, true);
    assert.equal(result.bucketNumber, 1);
    assert.equal(result.isMoqReached, false);
    assert.equal(result.nextBucketNumber, null);
    assert.equal(result.totalAmount, 1800);
    assert.ok(result.orderId);

    // 1. Verify User Balances
    const user = mockDb.getDoc(`users/${BUYER_UID}`);
    assert.equal(user.available_balance, 3200); // 5000 - 1800
    assert.equal(user.escrow_balance, 1800);    // 0 + 1800

    // 2. Verify Order Document
    const order = mockDb.getDoc(`orders/${result.orderId}`);
    assert.ok(order, 'Order document must exist');
    assert.equal(order.user_id, BUYER_UID);
    assert.equal(order.listing_id, LISTING_ID);
    assert.equal(order.bucket_number, 1);
    assert.equal(order.quantity, 10);
    assert.equal(order.unit_price, 180);
    assert.equal(order.total_amount, 1800);
    assert.equal(order.status, 'pending_bucket');
    assert.equal(order.delivery_address, 'House 12, Road 5, Dhanmondi, Dhaka');

    // 3. Verify Bucket Volume Updated
    const bucket = mockDb.getDoc(`daily_campaigns/${TEST_DATE}/listings/${LISTING_ID}/buckets/1`);
    assert.equal(bucket.current_quantity, 75);
    assert.equal(bucket.remaining_capacity, 25);
    assert.equal(bucket.status, 'open');
    assert.equal(bucket.order_count, 5);

    // 4. Verify Listing Total Volume Updated
    const listing = mockDb.getDoc(`daily_campaigns/${TEST_DATE}/listings/${LISTING_ID}`);
    assert.equal(listing.total_volume_ordered, 75);

    // 5. Verify Write-Once Audit Ledger Entry
    const allLedger = mockDb.getAllDocsInCollection('wallet_transactions');
    assert.equal(allLedger.length, 1);
    assert.equal(allLedger[0].data.user_id, BUYER_UID);
    assert.equal(allLedger[0].data.type, 'order_hold');
    assert.equal(allLedger[0].data.amount, -1800);
    assert.equal(allLedger[0].data.order_id, result.orderId);
  });

  it('rejects order with failed-precondition when user has insufficient available balance', async () => {
    const mockDb = setupTestEnvironment();

    // User only has 1000 BDT
    mockDb.setDoc(`users/${BUYER_UID}`, {
      uid: BUYER_UID,
      available_balance: 1000,
      escrow_balance: 0,
      role: 'customer',
    });

    const payload: PlaceOrderPayload = {
      date: TEST_DATE,
      listingId: LISTING_ID,
      quantity: 10, // 10 * 180 = 1800 > 1000
      deliveryAddress: 'House 12, Road 5, Dhanmondi, Dhaka',
    };

    await assert.rejects(
      async () => {
        await executePlaceOrder(BUYER_UID, payload, mockDb as any);
      },
      (err: any) => {
        assert.match(err.message, /Insufficient wallet balance/);
        return true;
      }
    );

    // Verify balances untouched
    const user = mockDb.getDoc(`users/${BUYER_UID}`);
    assert.equal(user.available_balance, 1000);
    assert.equal(user.escrow_balance, 0);

    // Verify no orders created
    const orders = mockDb.getAllDocsInCollection('orders');
    assert.equal(orders.length, 0);
  });

  it('enforces hard capacity clamp: rejects order exceeding remaining bucket capacity', async () => {
    const mockDb = setupTestEnvironment();

    // Give buyer plenty of funds (10,000 BDT) so capacity clamp is tested isolatedly
    mockDb.setDoc(`users/${BUYER_UID}`, {
      uid: BUYER_UID,
      available_balance: 10000,
      escrow_balance: 0,
      role: 'customer',
    });

    // Remaining capacity in bucket 1 is 35 kg. Customer attempts to order 40 kg
    const payload: PlaceOrderPayload = {
      date: TEST_DATE,
      listingId: LISTING_ID,
      quantity: 40, // 40 > remainingCapacity (35)
      deliveryAddress: 'House 12, Road 5, Dhanmondi, Dhaka',
    };

    await assert.rejects(
      async () => {
        await executePlaceOrder(BUYER_UID, payload, mockDb as any);
      },
      (err: any) => {
        assert.match(err.message, /exceeds remaining bucket capacity/);
        return true;
      }
    );

    // Verify bucket untouched
    const bucket = mockDb.getDoc(`daily_campaigns/${TEST_DATE}/listings/${LISTING_ID}/buckets/1`);
    assert.equal(bucket.current_quantity, 65);
    assert.equal(bucket.remaining_capacity, 35);
  });

  it('automatically rolls over to Bucket #(N+1) when MOQ threshold is met exactly', async () => {
    const mockDb = setupTestEnvironment();

    // Remaining capacity is 35 kg. Customer orders exactly 35 kg to achieve MOQ 100
    const payload: PlaceOrderPayload = {
      date: TEST_DATE,
      listingId: LISTING_ID,
      quantity: 35, // 35 * 180 = 6300 BDT
      deliveryAddress: 'House 12, Road 5, Dhanmondi, Dhaka',
    };

    // Give buyer sufficient funds
    mockDb.setDoc(`users/${BUYER_UID}`, {
      uid: BUYER_UID,
      available_balance: 10000,
      escrow_balance: 0,
      role: 'customer',
    });

    const result = await executePlaceOrder(BUYER_UID, payload, mockDb as any);

    assert.equal(result.success, true);
    assert.equal(result.bucketNumber, 1);
    assert.equal(result.isMoqReached, true);
    assert.equal(result.nextBucketNumber, 2);

    // 1. Bucket #1 must now be 'target_met'
    const bucket1 = mockDb.getDoc(`daily_campaigns/${TEST_DATE}/listings/${LISTING_ID}/buckets/1`);
    assert.equal(bucket1.current_quantity, 100);
    assert.equal(bucket1.remaining_capacity, 0);
    assert.equal(bucket1.status, 'target_met');

    // 2. Listing must have active_bucket_number = 2 and total_buckets_count = 2
    const listing = mockDb.getDoc(`daily_campaigns/${TEST_DATE}/listings/${LISTING_ID}`);
    assert.equal(listing.active_bucket_number, 2);
    assert.equal(listing.total_buckets_count, 2);
    assert.equal(listing.total_volume_ordered, 100);

    // 3. Bucket #2 must be automatically initialized and 'open'
    const bucket2 = mockDb.getDoc(`daily_campaigns/${TEST_DATE}/listings/${LISTING_ID}/buckets/2`);
    assert.ok(bucket2, 'Bucket #2 must be created');
    assert.equal(bucket2.bucket_number, 2);
    assert.equal(bucket2.status, 'open');
    assert.equal(bucket2.current_quantity, 0);
    assert.equal(bucket2.remaining_capacity, 100);
    assert.equal(bucket2.moq_threshold, 100);

    // 4. Now a subsequent order lands into Bucket #2 automatically!
    const subsequentPayload: PlaceOrderPayload = {
      date: TEST_DATE,
      listingId: LISTING_ID,
      quantity: 5,
      deliveryAddress: 'House 12, Road 5, Dhanmondi, Dhaka',
    };
    const subsequentResult = await executePlaceOrder(BUYER_UID, subsequentPayload, mockDb as any);
    assert.equal(subsequentResult.bucketNumber, 2);
    assert.equal(subsequentResult.isMoqReached, false);

    const bucket2Updated = mockDb.getDoc(`daily_campaigns/${TEST_DATE}/listings/${LISTING_ID}/buckets/2`);
    assert.equal(bucket2Updated.current_quantity, 5);
    assert.equal(bucket2Updated.remaining_capacity, 95);
  });

  it('rejects order placement if campaign is inactive or listing is closed', async () => {
    const mockDb = setupTestEnvironment();

    // Mark campaign as preview
    mockDb.setDoc(`daily_campaigns/${TEST_DATE}`, {
      date: TEST_DATE,
      status: 'preview',
    });

    const payload: PlaceOrderPayload = {
      date: TEST_DATE,
      listingId: LISTING_ID,
      quantity: 5,
      deliveryAddress: 'House 12, Road 5, Dhanmondi, Dhaka',
    };

    await assert.rejects(
      async () => {
        await executePlaceOrder(BUYER_UID, payload, mockDb as any);
      },
      (err: any) => {
        assert.match(err.message, /Campaign is not active/);
        return true;
      }
    );
  });

  it('processBucketTargetMet confirms all pending orders for target_met bucket', async () => {
    const mockDb = setupTestEnvironment();

    // Seed 2 pending orders in Bucket #1
    mockDb.setDoc('orders/ord_test_01', {
      order_id: 'ord_test_01',
      date: TEST_DATE,
      listing_id: LISTING_ID,
      bucket_number: 1,
      status: 'pending_bucket',
    });
    mockDb.setDoc('orders/ord_test_02', {
      order_id: 'ord_test_02',
      date: TEST_DATE,
      listing_id: LISTING_ID,
      bucket_number: 1,
      status: 'pending_bucket',
    });
    // And 1 order in Bucket #2 (should remain unaffected)
    mockDb.setDoc('orders/ord_test_03', {
      order_id: 'ord_test_03',
      date: TEST_DATE,
      listing_id: LISTING_ID,
      bucket_number: 2,
      status: 'pending_bucket',
    });

    const confirmedCount = await processBucketTargetMet(TEST_DATE, LISTING_ID, 1, mockDb as any);
    assert.equal(confirmedCount, 2);

    const ord1 = mockDb.getDoc('orders/ord_test_01');
    const ord2 = mockDb.getDoc('orders/ord_test_02');
    const ord3 = mockDb.getDoc('orders/ord_test_03');

    assert.equal(ord1.status, 'confirmed');
    assert.equal(ord2.status, 'confirmed');
    assert.equal(ord3.status, 'pending_bucket'); // Bucket 2 remains pending
  });
});
