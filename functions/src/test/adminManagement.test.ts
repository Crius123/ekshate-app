import { describe, it } from 'node:test';
import * as assert from 'node:assert/strict';
import {
  verifyAdminCaller,
  executeCreateOrUpdateDailyCampaign,
  executeReviewWithdrawalRequest,
  executeGetAdminOperationalMetrics,
  executeSubmitWithdrawalRequest,
} from '../adminManagement';

class MockFirestore {
  public docs: Map<string, any> = new Map();
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

  async runTransaction<T>(updateFunction: (transaction: any) => Promise<T>): Promise<T> {
    const stagedWrites: Array<() => void> = [];

    const transaction = {
      get: async (docRef: any) => {
        const doc = this.docs.get(docRef.path);
        return {
          exists: doc !== undefined,
          id: docRef.id,
          data: () => (doc ? { ...doc } : undefined),
        };
      },
      set: (docRef: any, data: any) => {
        stagedWrites.push(() => {
          this.docs.set(docRef.path, { ...data });
        });
      },
      update: (docRef: any, data: any) => {
        stagedWrites.push(() => {
          const existing = this.docs.get(docRef.path) || {};
          this.docs.set(docRef.path, { ...existing, ...data });
        });
      },
    };

    const result = await updateFunction(transaction);
    for (const write of stagedWrites) {
      write();
    }
    return result;
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

  private createDocRef(path: string, id: string): any {
    return {
      id,
      path,
      get: async () => {
        const doc = this.docs.get(path);
        return {
          exists: doc !== undefined,
          id,
          data: () => (doc ? { ...doc } : undefined),
        };
      },
      set: async (data: any, options?: { merge?: boolean }) => {
        if (options?.merge) {
          const existing = this.docs.get(path) || {};
          this.docs.set(path, { ...existing, ...data });
        } else {
          this.docs.set(path, { ...data });
        }
      },
      update: async (data: any) => {
        const existing = this.docs.get(path);
        if (!existing) {
          throw new Error(`Doc ${path} does not exist`);
        }
        this.docs.set(path, { ...existing, ...data });
      },
      collection: (subCollectionName: string) => {
        return this.createCollectionRef(`${path}/${subCollectionName}`);
      },
    };
  }
}

describe('Admin Dashboard Operations & Financial Review Engine Tests', () => {
  it('verifyAdminCaller: authorizes admins via token custom claims or users profile', async () => {
    const mockDb = new MockFirestore();
    mockDb.setDoc('users/admin_usr_01', { uid: 'admin_usr_01', role: 'admin' });
    mockDb.setDoc('users/customer_usr_02', { uid: 'customer_usr_02', role: 'customer' });

    // 1. Success via token custom claim
    const adminFromToken = await verifyAdminCaller(
      { uid: 'any_uid', token: { role: 'admin' } },
      mockDb as any
    );
    assert.equal(adminFromToken, 'any_uid');

    // 2. Success via firestore user profile
    const adminFromDoc = await verifyAdminCaller(
      { uid: 'admin_usr_01', token: {} },
      mockDb as any
    );
    assert.equal(adminFromDoc, 'admin_usr_01');

    // 3. Rejects unauthenticated caller
    await assert.rejects(
      async () => verifyAdminCaller(undefined, mockDb as any),
      (err: any) => err.code === 'unauthenticated'
    );

    // 4. Rejects customer role
    await assert.rejects(
      async () => verifyAdminCaller({ uid: 'customer_usr_02', token: {} }, mockDb as any),
      (err: any) => err.code === 'permission-denied'
    );
  });

  it('executeCreateOrUpdateDailyCampaign: provisions campaign window and initializes Bucket #1 with computed discount', async () => {
    const mockDb = new MockFirestore();
    const campaignDate = '2026-10-25';

    const result = await executeCreateOrUpdateDailyCampaign(
      {
        date: campaignDate,
        status: 'preview',
        listings: [
          {
            productTitle: 'Sonali Chicken',
            unit: 'kg',
            marketPrice: 320,
            unitPrice: 240, // 25% discount
            moqThreshold: 50,
            category: 'Fresh Meat & Poultry',
            imageUrl: 'https://cdn.ekshate.com/sonali.jpg',
            description: 'Naturally reared antibiotic-free poultry',
          },
        ],
      },
      mockDb as any
    );

    assert.equal(result.success, true);
    assert.equal(result.date, campaignDate);
    assert.equal(result.status, 'preview');
    assert.equal(result.listingsCreated, 1);
    assert.equal(result.listings[0].discountPercent, 25);
    assert.equal(result.listings[0].moqThreshold, 50);

    // Verify campaign document
    const campaignDoc = mockDb.getDoc(`daily_campaigns/${campaignDate}`);
    assert.ok(campaignDoc);
    assert.equal(campaignDoc.date, campaignDate);
    assert.equal(campaignDoc.status, 'preview');
    assert.equal(campaignDoc.total_listings_count, 1);

    // Verify listing document
    const listingId = result.listings[0].listingId;
    const listingDoc = mockDb.getDoc(`daily_campaigns/${campaignDate}/listings/${listingId}`);
    assert.ok(listingDoc);
    assert.equal(listingDoc.product_title, 'Sonali Chicken');
    assert.equal(listingDoc.market_price, 320);
    assert.equal(listingDoc.unit_price, 240);
    assert.equal(listingDoc.discount_percent, 25);
    assert.equal(listingDoc.active_bucket_number, 1);
    assert.equal(listingDoc.total_buckets_count, 1);

    // Verify Auto-initialized Bucket #1
    const bucket1Doc = mockDb.getDoc(`daily_campaigns/${campaignDate}/listings/${listingId}/buckets/1`);
    assert.ok(bucket1Doc);
    assert.equal(bucket1Doc.bucket_number, 1);
    assert.equal(bucket1Doc.moq_threshold, 50);
    assert.equal(bucket1Doc.current_quantity, 0);
    assert.equal(bucket1Doc.remaining_capacity, 50);
    assert.equal(bucket1Doc.status, 'open');
    assert.equal(bucket1Doc.order_count, 0);

    // Verify master product upsert
    const productDoc = mockDb.getDoc(`products/${listingDoc.product_id}`);
    assert.ok(productDoc);
    assert.equal(productDoc.title, 'Sonali Chicken');
    assert.equal(productDoc.unit, 'kg');
  });

  it('executeReviewWithdrawalRequest: approves withdrawal, debits balance, and writes immutable ledger entry', async () => {
    const mockDb = new MockFirestore();
    const customerUid = 'cust_withdraw_01';
    const adminUid = 'admin_op_99';
    const requestId = 'wreq_1001';

    // Seed customer with 5,000 BDT available balance
    mockDb.setDoc(`users/${customerUid}`, {
      uid: customerUid,
      role: 'customer',
      available_balance: 5000.0,
      escrow_balance: 500.0,
    });

    // Seed pending withdrawal request of 2,000 BDT
    mockDb.setDoc(`withdrawal_requests/${requestId}`, {
      id: requestId,
      user_id: customerUid,
      amount: 2000.0,
      payout_method: 'bkash',
      account_number: '01711223344',
      status: 'pending',
    });

    const approvalResult = await executeReviewWithdrawalRequest(
      {
        requestId,
        action: 'approve',
        payoutTrxId: 'trx_payout_custom_1001',
      },
      adminUid,
      mockDb as any
    );

    assert.equal(approvalResult.success, true);
    assert.equal(approvalResult.status, 'approved');
    assert.equal(approvalResult.amount, 2000.0);
    assert.equal(approvalResult.trxId, 'trx_payout_custom_1001');

    // Customer balance must be debited by 2,000: 5,000 -> 3,000
    const userDoc = mockDb.getDoc(`users/${customerUid}`);
    assert.equal(userDoc.available_balance, 3000.0);
    assert.equal(userDoc.escrow_balance, 500.0); // Escrow untouched

    // Immutable ledger record in wallet_transactions
    const ledgerDoc = mockDb.getDoc('wallet_transactions/trx_payout_custom_1001');
    assert.ok(ledgerDoc);
    assert.equal(ledgerDoc.trx_id, 'trx_payout_custom_1001');
    assert.equal(ledgerDoc.user_id, customerUid);
    assert.equal(ledgerDoc.type, 'withdrawal_payout');
    assert.equal(ledgerDoc.amount, -2000.0);
    assert.equal(ledgerDoc.status, 'completed');
    assert.equal(ledgerDoc.gateway, 'bkash');
    assert.equal(ledgerDoc.reference_id, requestId);

    // Withdrawal request record updated to approved
    const reqDoc = mockDb.getDoc(`withdrawal_requests/${requestId}`);
    assert.equal(reqDoc.status, 'approved');
    assert.equal(reqDoc.reviewed_by, adminUid);
    assert.equal(reqDoc.trx_id, 'trx_payout_custom_1001');
  });

  it('executeReviewWithdrawalRequest: rejects approval when customer has insufficient balance', async () => {
    const mockDb = new MockFirestore();
    const customerUid = 'cust_low_balance';
    const requestId = 'wreq_insufficient';

    mockDb.setDoc(`users/${customerUid}`, {
      uid: customerUid,
      available_balance: 500.0, // Only 500 available
    });

    mockDb.setDoc(`withdrawal_requests/${requestId}`, {
      id: requestId,
      user_id: customerUid,
      amount: 1500.0, // Requesting 1500
      status: 'pending',
    });

    await assert.rejects(
      async () =>
        executeReviewWithdrawalRequest(
          { requestId, action: 'approve' },
          'admin_uid',
          mockDb as any
        ),
      (err: any) => err.code === 'failed-precondition'
    );

    // Balance should remain unchanged
    const userDoc = mockDb.getDoc(`users/${customerUid}`);
    assert.equal(userDoc.available_balance, 500.0);
  });

  it('executeReviewWithdrawalRequest: rejects request with reason and preserves user balance', async () => {
    const mockDb = new MockFirestore();
    const customerUid = 'cust_reject_test';
    const adminUid = 'admin_op_99';
    const requestId = 'wreq_reject_01';

    mockDb.setDoc(`users/${customerUid}`, {
      uid: customerUid,
      available_balance: 4000.0,
    });

    mockDb.setDoc(`withdrawal_requests/${requestId}`, {
      id: requestId,
      user_id: customerUid,
      amount: 1000.0,
      status: 'pending',
    });

    const rejectResult = await executeReviewWithdrawalRequest(
      {
        requestId,
        action: 'reject',
        rejectionReason: 'Invalid bKash personal wallet number provided.',
      },
      adminUid,
      mockDb as any
    );

    assert.equal(rejectResult.success, true);
    assert.equal(rejectResult.status, 'rejected');
    assert.equal(rejectResult.rejectionReason, 'Invalid bKash personal wallet number provided.');

    // Balance must be preserved
    const userDoc = mockDb.getDoc(`users/${customerUid}`);
    assert.equal(userDoc.available_balance, 4000.0);

    // Request marked rejected
    const reqDoc = mockDb.getDoc(`withdrawal_requests/${requestId}`);
    assert.equal(reqDoc.status, 'rejected');
    assert.equal(reqDoc.rejection_reason, 'Invalid bKash personal wallet number provided.');
  });

  it('executeReviewWithdrawalRequest: prevents double-review of already processed requests', async () => {
    const mockDb = new MockFirestore();
    mockDb.setDoc('users/user_x', { uid: 'user_x', available_balance: 5000 });
    mockDb.setDoc('withdrawal_requests/wreq_already_approved', {
      id: 'wreq_already_approved',
      user_id: 'user_x',
      amount: 1000,
      status: 'approved',
    });

    await assert.rejects(
      async () =>
        executeReviewWithdrawalRequest(
          { requestId: 'wreq_already_approved', action: 'approve' },
          'admin_uid',
          mockDb as any
        ),
      (err: any) => err.code === 'failed-precondition'
    );
  });

  it('executeGetAdminOperationalMetrics: aggregates GMV, escrow volume, momentum, and pending dispatch counts', async () => {
    const mockDb = new MockFirestore();
    const date = '2026-10-24';

    // 1. Seed Campaign
    mockDb.setDoc(`daily_campaigns/${date}`, {
      date,
      status: 'active',
    });

    // 2. Seed Listing & Active Bucket
    mockDb.setDoc(`daily_campaigns/${date}/listings/list_potato`, {
      product_id: 'prod_potato',
      product_title: 'Holland Potato',
      category: 'Vegetables',
      unit: 'kg',
      market_price: 60,
      unit_price: 45,
      discount_percent: 25,
      active_bucket_number: 1,
      moq_threshold: 100,
    });
    mockDb.setDoc(`daily_campaigns/${date}/listings/list_potato/buckets/1`, {
      bucket_number: 1,
      moq_threshold: 100,
      current_quantity: 80,
      remaining_capacity: 20,
      order_count: 8,
      status: 'open',
    });

    // 3. Seed Orders
    mockDb.setDoc('orders/ord_01', {
      order_id: 'ord_01',
      date,
      total_amount: 1800,
      status: 'pending_escrow',
    });
    mockDb.setDoc('orders/ord_02', {
      order_id: 'ord_02',
      date,
      total_amount: 2200,
      status: 'confirmed', // not dispatched yet -> pending courier dispatch
    });
    mockDb.setDoc('orders/ord_03', {
      order_id: 'ord_03',
      date,
      total_amount: 1500,
      status: 'dispatched',
    });
    mockDb.setDoc('orders/ord_04', {
      order_id: 'ord_04',
      date,
      total_amount: 500,
      status: 'refunded',
    });

    // 4. Seed Pending Withdrawal Requests
    mockDb.setDoc('withdrawal_requests/wreq_01', {
      id: 'wreq_01',
      amount: 1500,
      status: 'pending',
    });
    mockDb.setDoc('withdrawal_requests/wreq_02', {
      id: 'wreq_02',
      amount: 2500,
      status: 'pending',
    });
    mockDb.setDoc('withdrawal_requests/wreq_03', {
      id: 'wreq_03',
      amount: 3000,
      status: 'approved',
    });

    const metrics = await executeGetAdminOperationalMetrics(date, mockDb as any);

    assert.equal(metrics.date, date);
    assert.equal(metrics.campaignStatus, 'active');
    // GMV excludes refunded: 1800 + 2200 + 1500 = 5500
    assert.equal(metrics.gmv, 5500);
    // Escrow volume: pending_escrow = 1800
    assert.equal(metrics.escrowVolume, 1800);
    assert.equal(metrics.totalOrdersCount, 4);
    assert.equal(metrics.pendingEscrowOrdersCount, 1);
    assert.equal(metrics.confirmedOrdersCount, 1);
    assert.equal(metrics.dispatchedOrdersCount, 1);
    assert.equal(metrics.refundedOrdersCount, 1);
    assert.equal(metrics.pendingDispatchCount, 1);

    // Momentum
    assert.equal(metrics.listingsCount, 1);
    assert.equal(metrics.averageFillPercentage, 80);
    assert.equal(metrics.bucketMomentum[0].productTitle, 'Holland Potato');
    assert.equal(metrics.bucketMomentum[0].fillPercentage, 80);
    assert.equal(metrics.bucketMomentum[0].remainingCapacity, 20);

    // Withdrawals
    assert.equal(metrics.pendingWithdrawalsCount, 2);
    assert.equal(metrics.pendingWithdrawalsAmount, 4000);
  });

  it('executeSubmitWithdrawalRequest: creates pending withdrawal request for customer', async () => {
    const mockDb = new MockFirestore();
    const userId = 'usr_buyer_submit';
    mockDb.setDoc(`users/${userId}`, {
      uid: userId,
      available_balance: 3500.0,
    });

    const result = await executeSubmitWithdrawalRequest(
      userId,
      {
        amount: 2000,
        payoutMethod: 'bkash',
        accountNumber: '01819998877',
      },
      mockDb as any
    );

    assert.equal(result.success, true);
    assert.equal(result.status, 'pending');
    assert.equal(result.amount, 2000);

    const doc = mockDb.getDoc(`withdrawal_requests/${result.requestId}`);
    assert.ok(doc);
    assert.equal(doc.user_id, userId);
    assert.equal(doc.amount, 2000);
    assert.equal(doc.payout_method, 'bkash');
    assert.equal(doc.account_number, '01819998877');
    assert.equal(doc.status, 'pending');

    // Rejects request when amount exceeds balance
    await assert.rejects(
      async () =>
        executeSubmitWithdrawalRequest(
          userId,
          {
            amount: 5000,
            payoutMethod: 'bkash',
            accountNumber: '01819998877',
          },
          mockDb as any
        ),
      (err: any) => err.code === 'failed-precondition'
    );
  });
});
