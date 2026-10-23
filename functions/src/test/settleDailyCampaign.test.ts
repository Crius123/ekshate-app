import { describe, it } from 'node:test';
import * as assert from 'node:assert/strict';
import { executeCampaignSettlement, settleDailyCampaign } from '../settleDailyCampaign';

class HierarchicalMockFirestore {
  public docs: Map<string, any> = new Map();
  private autoIdCounter = 5000;

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
      get: async () => {
        const allDocs = this.getAllDocsInCollection(path);
        return {
          empty: allDocs.length === 0,
          size: allDocs.length,
          docs: allDocs.map((f) => ({
            id: f.id,
            ref: this.createDocRef(f.path, f.id),
            data: () => ({ ...f.data }),
          })),
        };
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
                if (q.op === 'in') return Array.isArray(q.value) && q.value.includes(val);
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
      collection: (subColName: string) => {
        return this.createCollectionRef(`${docPath}/${subColName}`);
      },
      get: async () => {
        const docData = this.docs.get(docPath);
        return {
          exists: docData !== undefined,
          id: docId,
          ref: this.createDocRef(docPath, docId),
          data: () => (docData ? { ...docData } : undefined),
        };
      },
      set: async (data: any, options?: any) => {
        if (options && options.merge) {
          const current = this.docs.get(docPath) || {};
          this.docs.set(docPath, { ...current, ...data });
        } else {
          this.docs.set(docPath, { ...data });
        }
      },
      update: async (updates: any) => {
        const current = this.docs.get(docPath) || {};
        const updated = { ...current };
        for (const k of Object.keys(updates)) {
          const val = updates[k];
          if (val && typeof val === 'object' && ('operand' in val || (val as any).isIncrement)) {
            const operand = (val as any).operand ?? (val as any).value ?? 0;
            updated[k] = (Number(updated[k]) || 0) + Number(operand);
          } else {
            updated[k] = val;
          }
        }
        this.docs.set(docPath, updated);
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

    for (const write of stagedWrites) {
      write();
    }

    return result;
  }
}

describe('Midnight Settlement & Escrow Refund Reconciliation Tests', () => {
  const TEST_DATE = '2026-10-22';

  it('verifies settleDailyCampaign scheduled cron trigger configuration', () => {
    // settleDailyCampaign should be configured for 11:59 PM Asia/Dhaka
    assert.ok(settleDailyCampaign);
    // Examine scheduled cloud function properties
    const funcAny = settleDailyCampaign as any;
    assert.strictEqual(funcAny.__endpoint?.scheduleTrigger?.schedule, '59 23 * * *');
    assert.strictEqual(funcAny.__endpoint?.scheduleTrigger?.timeZone, 'Asia/Dhaka');
  });

  it('locks campaign to settling, confirms won buckets (target_met), captures escrow, and writes order_settle ledger', async () => {
    const mockDb = new HierarchicalMockFirestore();
    const userId = 'user_buyer_01';

    // 1. Seed User with escrow funds
    mockDb.setDoc(`users/${userId}`, {
      uid: userId,
      available_balance: 1000,
      escrow_balance: 1800,
      role: 'customer',
    });

    // 2. Seed Campaign
    mockDb.setDoc(`daily_campaigns/${TEST_DATE}`, {
      date: TEST_DATE,
      status: 'active',
    });

    // 3. Seed Listing
    mockDb.setDoc(`daily_campaigns/${TEST_DATE}/listings/listing_orange_01`, {
      id: 'listing_orange_01',
      product_title: 'Nagpur Oranges (1 kg)',
      status: 'active',
    });

    // 4. Seed Bucket (target_met)
    mockDb.setDoc(`daily_campaigns/${TEST_DATE}/listings/listing_orange_01/buckets/1`, {
      bucket_number: 1,
      status: 'target_met',
      current_quantity: 100,
      moq_threshold: 100,
    });

    // 5. Seed Order in bucket
    const orderId = 'ord_orange_won_101';
    mockDb.setDoc(`orders/${orderId}`, {
      order_id: orderId,
      user_id: userId,
      date: TEST_DATE,
      listing_id: 'listing_orange_01',
      bucket_number: 1,
      total_amount: 1800,
      status: 'pending_bucket',
    });

    // Execute Settlement
    const summary = await executeCampaignSettlement(TEST_DATE, mockDb as any);

    // Verify Summary
    assert.strictEqual(summary.confirmedBuckets, 1);
    assert.strictEqual(summary.failedBuckets, 0);
    assert.strictEqual(summary.confirmedOrders, 1);
    assert.strictEqual(summary.refundedOrders, 0);
    assert.strictEqual(summary.totalRefundAmount, 0);

    // Verify Campaign status
    const campaignDoc = mockDb.getDoc(`daily_campaigns/${TEST_DATE}`);
    assert.strictEqual(campaignDoc.status, 'settled');

    // Verify Listing status
    const listingDoc = mockDb.getDoc(`daily_campaigns/${TEST_DATE}/listings/listing_orange_01`);
    assert.strictEqual(listingDoc.status, 'closed');

    // Verify Bucket status
    const bucketDoc = mockDb.getDoc(`daily_campaigns/${TEST_DATE}/listings/listing_orange_01/buckets/1`);
    assert.strictEqual(bucketDoc.status, 'confirmed');

    // Verify Order status & escrow capture flag
    const orderDoc = mockDb.getDoc(`orders/${orderId}`);
    assert.strictEqual(orderDoc.status, 'confirmed');
    assert.strictEqual(orderDoc.escrow_captured, true);

    // Verify User Balances: escrow captured (decremented by 1800), available unchanged
    const userDoc = mockDb.getDoc(`users/${userId}`);
    assert.strictEqual(userDoc.available_balance, 1000);
    assert.strictEqual(userDoc.escrow_balance, 0);

    // Verify Ledger Transaction
    const allTxs = mockDb.getAllDocsInCollection('wallet_transactions');
    assert.strictEqual(allTxs.length, 1);
    assert.strictEqual(allTxs[0].data.type, 'order_settle');
    assert.strictEqual(allTxs[0].data.amount, 1800);
    assert.strictEqual(allTxs[0].data.user_id, userId);
    assert.strictEqual(allTxs[0].data.order_id, orderId);
  });

  it('marks partial open buckets as failed and executes batch refunds: restores available balance, decrements escrow, flags refunded', async () => {
    const mockDb = new HierarchicalMockFirestore();
    const userId = 'user_buyer_partial';

    // 1. Seed User
    mockDb.setDoc(`users/${userId}`, {
      uid: userId,
      available_balance: 500,
      escrow_balance: 1750,
      role: 'customer',
    });

    // 2. Seed Campaign
    mockDb.setDoc(`daily_campaigns/${TEST_DATE}`, {
      date: TEST_DATE,
      status: 'active',
    });

    // 3. Seed Listing
    mockDb.setDoc(`daily_campaigns/${TEST_DATE}/listings/listing_rice_02`, {
      id: 'listing_rice_02',
      product_title: 'Miniket Rice (25 kg bag)',
      status: 'active',
    });

    // 4. Seed Bucket (open, did not hit MOQ)
    mockDb.setDoc(`daily_campaigns/${TEST_DATE}/listings/listing_rice_02/buckets/1`, {
      bucket_number: 1,
      status: 'open',
      current_quantity: 15,
      moq_threshold: 50,
    });

    // 5. Seed Order in open bucket
    const orderId = 'ord_rice_failed_202';
    mockDb.setDoc(`orders/${orderId}`, {
      order_id: orderId,
      user_id: userId,
      date: TEST_DATE,
      listing_id: 'listing_rice_02',
      bucket_number: 1,
      total_amount: 1750,
      status: 'pending_bucket',
    });

    // Execute Settlement
    const summary = await executeCampaignSettlement(TEST_DATE, mockDb as any);

    // Verify Summary
    assert.strictEqual(summary.confirmedBuckets, 0);
    assert.strictEqual(summary.failedBuckets, 1);
    assert.strictEqual(summary.confirmedOrders, 0);
    assert.strictEqual(summary.refundedOrders, 1);
    assert.strictEqual(summary.totalRefundAmount, 1750);

    // Verify Bucket marked failed
    const bucketDoc = mockDb.getDoc(`daily_campaigns/${TEST_DATE}/listings/listing_rice_02/buckets/1`);
    assert.strictEqual(bucketDoc.status, 'failed');

    // Verify Order marked refunded
    const orderDoc = mockDb.getDoc(`orders/${orderId}`);
    assert.strictEqual(orderDoc.status, 'refunded');

    // Verify User Balances: available restored (+1750), escrow decremented (-1750)
    const userDoc = mockDb.getDoc(`users/${userId}`);
    assert.strictEqual(userDoc.available_balance, 2250); // 500 + 1750
    assert.strictEqual(userDoc.escrow_balance, 0);       // 1750 - 1750

    // Verify Ledger Transaction
    const allTxs = mockDb.getAllDocsInCollection('wallet_transactions');
    assert.strictEqual(allTxs.length, 1);
    assert.strictEqual(allTxs[0].data.type, 'order_refund');
    assert.strictEqual(allTxs[0].data.amount, 1750);
    assert.strictEqual(allTxs[0].data.user_id, userId);
    assert.strictEqual(allTxs[0].data.order_id, orderId);
  });

  it('processes batch refunds across multiple orders correctly in chunks of 50', async () => {
    const mockDb = new HierarchicalMockFirestore();

    // Seed Campaign
    mockDb.setDoc(`daily_campaigns/${TEST_DATE}`, {
      date: TEST_DATE,
      status: 'active',
    });

    // Seed Listing
    mockDb.setDoc(`daily_campaigns/${TEST_DATE}/listings/listing_bulk_fail`, {
      id: 'listing_bulk_fail',
      product_title: 'Bulk Test Product',
      status: 'active',
    });

    // Seed Bucket (open)
    mockDb.setDoc(`daily_campaigns/${TEST_DATE}/listings/listing_bulk_fail/buckets/1`, {
      bucket_number: 1,
      status: 'open',
      current_quantity: 60,
      moq_threshold: 200,
    });

    // Create 60 orders across 60 distinct users (exceeding chunk size of 50)
    const TOTAL_ORDERS = 60;
    const ORDER_AMOUNT = 100;
    for (let i = 1; i <= TOTAL_ORDERS; i++) {
      const uId = `user_chunk_${i}`;
      mockDb.setDoc(`users/${uId}`, {
        uid: uId,
        available_balance: 0,
        escrow_balance: ORDER_AMOUNT,
      });

      const ordId = `ord_chunk_${i}`;
      mockDb.setDoc(`orders/${ordId}`, {
        order_id: ordId,
        user_id: uId,
        date: TEST_DATE,
        listing_id: 'listing_bulk_fail',
        bucket_number: 1,
        total_amount: ORDER_AMOUNT,
        status: 'pending_bucket',
      });
    }

    const summary = await executeCampaignSettlement(TEST_DATE, mockDb as any);
    assert.strictEqual(summary.failedBuckets, 1);
    assert.strictEqual(summary.refundedOrders, TOTAL_ORDERS);
    assert.strictEqual(summary.totalRefundAmount, TOTAL_ORDERS * ORDER_AMOUNT);

    // Verify all 60 users received refunds
    for (let i = 1; i <= TOTAL_ORDERS; i++) {
      const u = mockDb.getDoc(`users/user_chunk_${i}`);
      assert.strictEqual(u.available_balance, ORDER_AMOUNT);
      assert.strictEqual(u.escrow_balance, 0);

      const o = mockDb.getDoc(`orders/ord_chunk_${i}`);
      assert.strictEqual(o.status, 'refunded');
    }

    // Verify 60 ledger transactions written
    const txs = mockDb.getAllDocsInCollection('wallet_transactions');
    assert.strictEqual(txs.length, TOTAL_ORDERS);
  });

  it('guarantees strict idempotency: rerun on already settled campaign exits with zero changes', async () => {
    const mockDb = new HierarchicalMockFirestore();
    const userId = 'user_idempotent_test';

    mockDb.setDoc(`users/${userId}`, {
      uid: userId,
      available_balance: 500,
      escrow_balance: 500,
    });

    mockDb.setDoc(`daily_campaigns/${TEST_DATE}`, {
      date: TEST_DATE,
      status: 'active',
    });

    mockDb.setDoc(`daily_campaigns/${TEST_DATE}/listings/listing_1`, {
      id: 'listing_1',
      status: 'active',
    });

    mockDb.setDoc(`daily_campaigns/${TEST_DATE}/listings/listing_1/buckets/1`, {
      bucket_number: 1,
      status: 'open',
      current_quantity: 5,
      moq_threshold: 50,
    });

    mockDb.setDoc(`orders/ord_test_idem`, {
      order_id: 'ord_test_idem',
      user_id: userId,
      date: TEST_DATE,
      listing_id: 'listing_1',
      bucket_number: 1,
      total_amount: 500,
      status: 'pending_bucket',
    });

    // First Run: Executes settlement and refunds
    const firstSummary = await executeCampaignSettlement(TEST_DATE, mockDb as any);
    assert.strictEqual(firstSummary.refundedOrders, 1);
    assert.strictEqual(firstSummary.totalRefundAmount, 500);

    const userAfterFirst = mockDb.getDoc(`users/${userId}`);
    assert.strictEqual(userAfterFirst.available_balance, 1000);
    assert.strictEqual(userAfterFirst.escrow_balance, 0);
    assert.strictEqual(mockDb.getAllDocsInCollection('wallet_transactions').length, 1);

    // Second Run: Strictly Idempotent!
    const secondSummary = await executeCampaignSettlement(TEST_DATE, mockDb as any);
    assert.strictEqual(secondSummary.confirmedBuckets, 0);
    assert.strictEqual(secondSummary.failedBuckets, 0);
    assert.strictEqual(secondSummary.confirmedOrders, 0);
    assert.strictEqual(secondSummary.refundedOrders, 0);
    assert.strictEqual(secondSummary.totalRefundAmount, 0);

    // Balances and ledger count remain untouched
    const userAfterSecond = mockDb.getDoc(`users/${userId}`);
    assert.strictEqual(userAfterSecond.available_balance, 1000);
    assert.strictEqual(userAfterSecond.escrow_balance, 0);
    assert.strictEqual(mockDb.getAllDocsInCollection('wallet_transactions').length, 1);
  });

  it('throws error when settling a non-existent campaign', async () => {
    const mockDb = new HierarchicalMockFirestore();
    await assert.rejects(
      async () => {
        await executeCampaignSettlement('1999-01-01', mockDb as any);
      },
      {
        message: 'Campaign for date 1999-01-01 does not exist.',
      }
    );
  });
});
