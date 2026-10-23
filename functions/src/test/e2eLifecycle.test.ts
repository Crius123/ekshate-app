import { describe, it } from 'node:test';
import * as assert from 'node:assert/strict';
import {
  executeCreateOrUpdateDailyCampaign,
  executeSubmitWithdrawalRequest,
  executeReviewWithdrawalRequest,
  executeGetAdminOperationalMetrics,
} from '../adminManagement';
import { recordDepositTransaction } from '../walletDeposits';
import { executePlaceOrder, processBucketTargetMet } from '../placeOrder';
import { executeCampaignSettlement } from '../settleDailyCampaign';
import {
  buildProcurementManifest,
  generateProcurementCsv,
  calculatePackagingNotes,
} from '../generateProcurementManifest';
import {
  executeCampaignDispatch,
  calculateParcelWeight,
  CourierGateway,
} from '../courierDispatch';
import {
  checkAndTriggerUrgencyMilestone,
  MessagingAdapter,
} from '../notificationEngine';

/**
 * Mock FCM Messaging Service for capturing push payloads in E2E tests
 */
class MockMessagingService implements MessagingAdapter {
  public sentTopicMessages: Array<any> = [];
  public sentMulticastMessages: Array<any> = [];

  async send(message: any): Promise<string> {
    this.sentTopicMessages.push(message);
    return `msg_topic_${this.sentTopicMessages.length}`;
  }

  async sendEachForMulticast(message: any): Promise<{
    responses: Array<{ success: boolean; error?: any; messageId?: string }>;
    successCount: number;
    failureCount: number;
  }> {
    this.sentMulticastMessages.push(message);
    const responses = (message.tokens || []).map((_: string, idx: number) => ({
      success: true,
      messageId: `msg_multi_${idx + 1}`,
    }));
    return {
      responses,
      successCount: responses.length,
      failureCount: 0,
    };
  }
}

/**
 * Robust Hierarchical Mock Firestore supporting real transactions,
 * subcollections, batch commits, FieldValue.increment, and filter operators.
 */
class HierarchicalMockFirestore {
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

  batch() {
    const stagedUpdates: Array<() => void> = [];
    return {
      set: (docRef: any, data: any) => {
        stagedUpdates.push(() => {
          this.docs.set(docRef.path, { ...data });
        });
      },
      update: (docRef: any, data: any) => {
        stagedUpdates.push(() => {
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
      delete: (docRef: any) => {
        stagedUpdates.push(() => {
          this.docs.delete(docRef.path);
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
      set: (docRef: any, data: any, options?: { merge?: boolean }) => {
        stagedWrites.push(() => {
          if (options?.merge) {
            const current = this.docs.get(docRef.path) || {};
            this.docs.set(docRef.path, { ...current, ...data });
          } else {
            this.docs.set(docRef.path, { ...data });
          }
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
          orderBy: () => queryObj,
          limit: () => queryObj,
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
      get: async () => {
        const d = this.docs.get(docPath);
        return {
          id: docId,
          exists: d !== undefined,
          data: () => (d ? { ...d } : undefined),
        };
      },
      set: async (data: any, options?: { merge?: boolean }) => {
        if (options?.merge) {
          const current = this.docs.get(docPath) || {};
          this.docs.set(docPath, { ...current, ...data });
        } else {
          this.docs.set(docPath, { ...data });
        }
      },
      update: async (data: any) => {
        const current = this.docs.get(docPath) || {};
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
        this.docs.set(docPath, updated);
      },
      collection: (subColName: string) => {
        return this.createCollectionRef(`${docPath}/${subColName}`);
      },
    };
  }
}

describe('Full End-to-End Bulk Buying Lifecycle Acceptance Suite', () => {
  const CAMPAIGN_DATE = '2026-10-23';
  const ADMIN_UID = 'admin_super_01';

  // Customer IDs
  const USER_A = 'usr_buyer_a';
  const USER_B = 'usr_buyer_b';
  const USER_C = 'usr_buyer_c';
  const USER_D = 'usr_buyer_d';

  let mockDb: HierarchicalMockFirestore;
  let mockMessaging: MockMessagingService;
  let listingId: string;

  it('executes the complete customer and operator journey across all 7 discrete lifecycle phases', async () => {
    mockDb = new HierarchicalMockFirestore();
    mockMessaging = new MockMessagingService();

    // Seed Admin User
    mockDb.setDoc(`users/${ADMIN_UID}`, {
      uid: ADMIN_UID,
      role: 'admin',
      displayName: 'Super Admin',
      phone_number: '+8801711999999',
      available_balance: 0,
      escrow_balance: 0,
    });

    // -------------------------------------------------------------------------
    // Phase 1: Deal Scheduling
    // Admin provisions daily wholesale listing (100 kg MOQ at ৳120/kg, benchmark ৳180/kg)
    // with auto-initialized Bucket #1.
    // -------------------------------------------------------------------------
    const scheduleResult = await executeCreateOrUpdateDailyCampaign(
      {
        date: CAMPAIGN_DATE,
        status: 'active',
        listing: {
          productId: 'prod_potato_dinajpur',
          productTitle: 'Fresh Dinajpur Potatoes (1 kg)',
          unit: 'kg',
          marketPrice: 180,
          unitPrice: 120,
          moqThreshold: 100,
          category: 'vegetables',
          description: 'Premium grade table potatoes sourced directly from Dinajpur growers',
        },
      },
      mockDb as any
    );

    assert.equal(scheduleResult.success, true);
    assert.equal(scheduleResult.listingsCreated, 1);
    listingId = scheduleResult.listings[0].listingId;
    assert.ok(listingId, 'Listing ID must be generated');

    // Verify Campaign Document
    const campaignDoc = mockDb.getDoc(`daily_campaigns/${CAMPAIGN_DATE}`);
    assert.ok(campaignDoc, 'Campaign document must exist');
    assert.equal(campaignDoc.status, 'active');

    // Verify Listing Document
    const listingDoc = mockDb.getDoc(`daily_campaigns/${CAMPAIGN_DATE}/listings/${listingId}`);
    assert.ok(listingDoc, 'Listing document must exist');
    assert.equal(listingDoc.unit_price, 120);
    assert.equal(listingDoc.market_price, 180);
    assert.equal(listingDoc.active_bucket_number, 1);
    assert.equal(listingDoc.status, 'active');
    // Computed savings: (180 - 120) / 180 = 33.33%
    assert.ok(listingDoc.discount_percent >= 33.3, 'Discount percent should be ~33.33%');

    // Verify Bucket #1 Initialization
    const bucket1Doc = mockDb.getDoc(`daily_campaigns/${CAMPAIGN_DATE}/listings/${listingId}/buckets/1`);
    assert.ok(bucket1Doc, 'Bucket #1 must be initialized');
    assert.equal(bucket1Doc.bucket_number, 1);
    assert.equal(bucket1Doc.moq_threshold, 100);
    assert.equal(bucket1Doc.current_quantity, 0);
    assert.equal(bucket1Doc.remaining_capacity, 100);
    assert.equal(bucket1Doc.status, 'open');

    // -------------------------------------------------------------------------
    // Phase 2: Customer Onboarding & Wallet Top-up
    // Multiple customers (User A, User B, User C, User D) onboard and deposit
    // funds via bKash & SSLCommerz with idempotent write-once ledger verification.
    // -------------------------------------------------------------------------
    const customers = [
      { uid: USER_A, phone: '+8801711000001', name: 'User A', deposit: 8000, gateway: 'bkash' as const, trx: 'BKASH_TRX_A_001' },
      { uid: USER_B, phone: '+8801711000002', name: 'User B', deposit: 4000, gateway: 'sslcommerz' as const, trx: 'SSL_TRX_B_001' },
      { uid: USER_C, phone: '+8801711000003', name: 'User C', deposit: 3000, gateway: 'bkash' as const, trx: 'BKASH_TRX_C_001' },
      { uid: USER_D, phone: '+8801711000004', name: 'User D', deposit: 2500, gateway: 'bkash' as const, trx: 'BKASH_TRX_D_001' },
    ];

    for (const c of customers) {
      // 1. Initial user profile creation (0 balance)
      mockDb.setDoc(`users/${c.uid}`, {
        uid: c.uid,
        phone_number: c.phone,
        displayName: c.name,
        available_balance: 0,
        escrow_balance: 0,
        role: 'customer',
        deliveryAddress: `House ${c.name}, Road 12, Dhanmondi, Dhaka`,
      });

      // 2. Deposit Funds
      const depositResult = await recordDepositTransaction(
        {
          gatewayTrxId: c.trx,
          userId: c.uid,
          amount: c.deposit,
          gateway: c.gateway,
        },
        mockDb as any
      );

      assert.equal(depositResult.success, true);
      assert.equal(depositResult.duplicate, false);
      assert.equal(depositResult.amount, c.deposit);

      // Verify user balance updated
      const updatedUser = mockDb.getDoc(`users/${c.uid}`);
      assert.equal(updatedUser.available_balance, c.deposit);
      assert.equal(updatedUser.escrow_balance, 0);

      // Verify immutable wallet transaction ledger entry
      const ledgerEntry = mockDb.getDoc(`wallet_transactions/${c.trx}`);
      assert.ok(ledgerEntry, `Ledger entry for ${c.trx} must exist`);
      assert.equal(ledgerEntry.status, 'completed');
      assert.equal(ledgerEntry.amount, c.deposit);

      // 3. Idempotent Retry Guard: Repeated deposit with same gatewayTrxId
      const duplicateResult = await recordDepositTransaction(
        {
          gatewayTrxId: c.trx,
          userId: c.uid,
          amount: c.deposit,
          gateway: c.gateway,
        },
        mockDb as any
      );

      assert.equal(duplicateResult.success, true);
      assert.equal(duplicateResult.duplicate, true, 'Duplicate deposit must be detected');

      // User balance must NOT be credited twice
      const userAfterRetry = mockDb.getDoc(`users/${c.uid}`);
      assert.equal(userAfterRetry.available_balance, c.deposit, 'Balance must remain unchanged after duplicate retry');
    }

    // -------------------------------------------------------------------------
    // Phase 3: Community Bulk Ordering & Hard Clamping
    // - User A orders 60 kg (Bucket #1 at 60%).
    // - User B orders 25 kg (Bucket #1 at 85% -> triggers 80% urgency alert milestone).
    // - Hard capacity clamping prevents User C from exceeding remaining 15 kg capacity in a single order.
    // - User C orders remaining 15 kg -> Bucket #1 hits MOQ exactly (`target_met`),
    //   sends notifications, and auto-spawns Bucket #2.
    // - User D orders 20 kg into Bucket #2 (partial fill).
    // -------------------------------------------------------------------------

    // 1. User A orders 60 kg (Total: 60 * 120 = 7,200 BDT)
    const orderAResult = await executePlaceOrder(
      USER_A,
      {
        date: CAMPAIGN_DATE,
        listingId,
        quantity: 60,
        deliveryAddress: 'House A, Road 12, Dhanmondi, Dhaka',
      },
      mockDb as any
    );

    assert.equal(orderAResult.success, true);
    assert.equal(orderAResult.bucketNumber, 1);
    assert.equal(orderAResult.isMoqReached, false);
    assert.equal(orderAResult.totalAmount, 7200);

    const userADoc = mockDb.getDoc(`users/${USER_A}`);
    assert.equal(userADoc.available_balance, 8000 - 7200); // 800 BDT remaining
    assert.equal(userADoc.escrow_balance, 7200);

    const bucket1AfterA = mockDb.getDoc(`daily_campaigns/${CAMPAIGN_DATE}/listings/${listingId}/buckets/1`);
    assert.equal(bucket1AfterA.current_quantity, 60);
    assert.equal(bucket1AfterA.remaining_capacity, 40);
    assert.equal(bucket1AfterA.status, 'open');

    // 2. User B orders 25 kg (Total: 25 * 120 = 3,000 BDT)
    const orderBResult = await executePlaceOrder(
      USER_B,
      {
        date: CAMPAIGN_DATE,
        listingId,
        quantity: 25,
        deliveryAddress: 'House B, Road 12, Dhanmondi, Dhaka',
      },
      mockDb as any
    );

    assert.equal(orderBResult.success, true);
    assert.equal(orderBResult.bucketNumber, 1);
    assert.equal(orderBResult.isMoqReached, false);
    assert.equal(orderBResult.totalAmount, 3000);

    const userBDoc = mockDb.getDoc(`users/${USER_B}`);
    assert.equal(userBDoc.available_balance, 4000 - 3000); // 1,000 BDT remaining
    assert.equal(userBDoc.escrow_balance, 3000);

    const bucket1AfterB = mockDb.getDoc(`daily_campaigns/${CAMPAIGN_DATE}/listings/${listingId}/buckets/1`);
    assert.equal(bucket1AfterB.current_quantity, 85); // 85% fill
    assert.equal(bucket1AfterB.remaining_capacity, 15);

    // Trigger & Verify 80% Urgency Alert Milestone
    const milestoneResult = await checkAndTriggerUrgencyMilestone(
      CAMPAIGN_DATE,
      listingId,
      1,
      mockDb as any,
      mockMessaging as any
    );
    assert.equal(milestoneResult.triggered, true, 'Urgency milestone should trigger at 85% fill');
    assert.equal(milestoneResult.remainingCapacity, 15);
    assert.equal(mockMessaging.sentTopicMessages.length, 1);
    assert.ok(mockMessaging.sentTopicMessages[0].notification.title.includes('Almost Unlocked'));

    // Check urgency alert idempotency: duplicate check does not fire again
    const milestoneDuplicate = await checkAndTriggerUrgencyMilestone(
      CAMPAIGN_DATE,
      listingId,
      1,
      mockDb as any,
      mockMessaging as any
    );
    assert.equal(milestoneDuplicate.triggered, false, 'Urgency milestone should not fire repeatedly');

    // 3. Hard Capacity Clamping: User C attempts to order 20 kg (only 15 kg remaining in Bucket #1)
    await assert.rejects(
      async () => {
        await executePlaceOrder(
          USER_C,
          {
            date: CAMPAIGN_DATE,
            listingId,
            quantity: 20, // Exceeds 15 kg
            deliveryAddress: 'House C, Road 12, Dhanmondi, Dhaka',
          },
          mockDb as any
        );
      },
      (err: any) => {
        assert.match(err.message, /exceeds remaining bucket capacity/i);
        return true;
      },
      'Expected hard capacity clamp rejection when quantity exceeds remaining bucket volume'
    );

    // Verify User C balance was not touched
    const userCAfterFailedOrder = mockDb.getDoc(`users/${USER_C}`);
    assert.equal(userCAfterFailedOrder.available_balance, 3000);
    assert.equal(userCAfterFailedOrder.escrow_balance, 0);

    // 4. User C orders remaining 15 kg -> Bucket #1 hits MOQ exactly (100 kg), unlocks, and spawns Bucket #2
    const orderCResult = await executePlaceOrder(
      USER_C,
      {
        date: CAMPAIGN_DATE,
        listingId,
        quantity: 15,
        deliveryAddress: 'House C, Road 12, Dhanmondi, Dhaka',
      },
      mockDb as any
    );

    assert.equal(orderCResult.success, true);
    assert.equal(orderCResult.bucketNumber, 1);
    assert.equal(orderCResult.isMoqReached, true, 'MOQ must be met exactly');
    assert.equal(orderCResult.nextBucketNumber, 2, 'Bucket #2 must be next');
    assert.equal(orderCResult.totalAmount, 1800);

    const userCDoc = mockDb.getDoc(`users/${USER_C}`);
    assert.equal(userCDoc.available_balance, 3000 - 1800); // 1,200 BDT remaining
    assert.equal(userCDoc.escrow_balance, 1800);

    // Verify Bucket #1 achieved MOQ ('target_met')
    const bucket1TargetMet = mockDb.getDoc(`daily_campaigns/${CAMPAIGN_DATE}/listings/${listingId}/buckets/1`);
    assert.equal(bucket1TargetMet.status, 'target_met');
    assert.equal(bucket1TargetMet.current_quantity, 100);
    assert.equal(bucket1TargetMet.remaining_capacity, 0);

    // Verify Bucket #2 automatically spawned and active
    const bucket2Spawned = mockDb.getDoc(`daily_campaigns/${CAMPAIGN_DATE}/listings/${listingId}/buckets/2`);
    assert.ok(bucket2Spawned, 'Bucket #2 must be created');
    assert.equal(bucket2Spawned.bucket_number, 2);
    assert.equal(bucket2Spawned.status, 'open');
    assert.equal(bucket2Spawned.current_quantity, 0);
    assert.equal(bucket2Spawned.remaining_capacity, 100);

    // Listing active bucket updated to #2
    const listingAfterTargetMet = mockDb.getDoc(`daily_campaigns/${CAMPAIGN_DATE}/listings/${listingId}`);
    assert.equal(listingAfterTargetMet.active_bucket_number, 2);

    // Asynchronously process onBucketTargetMet: transitions pending orders in Bucket #1 to 'confirmed'
    const confirmedCount = await processBucketTargetMet(CAMPAIGN_DATE, listingId, 1, mockDb as any);
    assert.equal(confirmedCount, 3, 'All 3 orders in Bucket #1 must transition to confirmed');

    const orderADoc = mockDb.getDoc(`orders/${orderAResult.orderId}`);
    const orderBDoc = mockDb.getDoc(`orders/${orderBResult.orderId}`);
    const orderCDoc = mockDb.getDoc(`orders/${orderCResult.orderId}`);
    assert.equal(orderADoc.status, 'confirmed');
    assert.equal(orderBDoc.status, 'confirmed');
    assert.equal(orderCDoc.status, 'confirmed');

    // 5. User D orders 20 kg into Bucket #2 (partial fill: 20 / 100 kg)
    const orderDResult = await executePlaceOrder(
      USER_D,
      {
        date: CAMPAIGN_DATE,
        listingId,
        quantity: 20,
        deliveryAddress: 'House D, Road 12, Dhanmondi, Dhaka',
      },
      mockDb as any
    );

    assert.equal(orderDResult.success, true);
    assert.equal(orderDResult.bucketNumber, 2, 'Must be routed into Bucket #2');
    assert.equal(orderDResult.isMoqReached, false);
    assert.equal(orderDResult.totalAmount, 2400);

    const userDDoc = mockDb.getDoc(`users/${USER_D}`);
    assert.equal(userDDoc.available_balance, 2500 - 2400); // 100 BDT
    assert.equal(userDDoc.escrow_balance, 2400);

    const bucket2AfterD = mockDb.getDoc(`daily_campaigns/${CAMPAIGN_DATE}/listings/${listingId}/buckets/2`);
    assert.equal(bucket2AfterD.current_quantity, 20);
    assert.equal(bucket2AfterD.remaining_capacity, 80);
    assert.equal(bucket2AfterD.status, 'open');

    const orderDDoc = mockDb.getDoc(`orders/${orderDResult.orderId}`);
    assert.equal(orderDDoc.status, 'pending_bucket');

    // Verify operational metrics before midnight settlement
    const metricsBeforeSettlement = await executeGetAdminOperationalMetrics(CAMPAIGN_DATE, mockDb as any);
    assert.equal(metricsBeforeSettlement.gmv, 7200 + 3000 + 1800 + 2400); // 14,400 BDT
    assert.equal(metricsBeforeSettlement.escrowVolume, 2400); // Pending escrow order (User D)
    assert.equal(metricsBeforeSettlement.totalOrdersCount, 4);
    assert.equal(metricsBeforeSettlement.confirmedOrdersCount, 3);
    assert.equal(metricsBeforeSettlement.pendingEscrowOrdersCount, 1);

    // -------------------------------------------------------------------------
    // Phase 4: Midnight Settlement Reconciliation
    // - settleDailyCampaign transitions campaign to 'settling'.
    // - Bucket #1 confirmed -> escrow captured, orders confirmed.
    // - Bucket #2 failed -> escrow released, User D 100% refunded to available_balance.
    // -------------------------------------------------------------------------
    const settlementSummary = await executeCampaignSettlement(CAMPAIGN_DATE, mockDb as any);

    assert.equal(settlementSummary.confirmedBuckets, 1, 'Bucket #1 confirmed');
    assert.equal(settlementSummary.failedBuckets, 1, 'Bucket #2 failed');
    assert.equal(settlementSummary.confirmedOrders, 3, '3 orders confirmed in Bucket #1');
    assert.equal(settlementSummary.refundedOrders, 1, '1 order refunded from Bucket #2');
    assert.equal(settlementSummary.totalRefundAmount, 2400);

    // Verify Campaign is Settled
    const campaignAfterSettlement = mockDb.getDoc(`daily_campaigns/${CAMPAIGN_DATE}`);
    assert.equal(campaignAfterSettlement.status, 'settled');

    // Verify Bucket #1 Confirmed and Escrow Captured
    const bucket1Settled = mockDb.getDoc(`daily_campaigns/${CAMPAIGN_DATE}/listings/${listingId}/buckets/1`);
    assert.equal(bucket1Settled.status, 'confirmed');

    const userASettled = mockDb.getDoc(`users/${USER_A}`);
    assert.equal(userASettled.escrow_balance, 0, 'User A escrow captured');
    assert.equal(userASettled.available_balance, 800);

    const userBSettled = mockDb.getDoc(`users/${USER_B}`);
    assert.equal(userBSettled.escrow_balance, 0, 'User B escrow captured');
    assert.equal(userBSettled.available_balance, 1000);

    const userCSettled = mockDb.getDoc(`users/${USER_C}`);
    assert.equal(userCSettled.escrow_balance, 0, 'User C escrow captured');
    assert.equal(userCSettled.available_balance, 1200);

    // Verify Bucket #2 Failed and User D 100% Refunded
    const bucket2Settled = mockDb.getDoc(`daily_campaigns/${CAMPAIGN_DATE}/listings/${listingId}/buckets/2`);
    assert.equal(bucket2Settled.status, 'failed');

    const userDSettled = mockDb.getDoc(`users/${USER_D}`);
    assert.equal(userDSettled.available_balance, 2500, 'User D available balance must be 100% restored (2,500 BDT)');
    assert.equal(userDSettled.escrow_balance, 0, 'User D escrow balance reset to 0');

    const orderDRefunded = mockDb.getDoc(`orders/${orderDResult.orderId}`);
    assert.equal(orderDRefunded.status, 'refunded');

    // -------------------------------------------------------------------------
    // Phase 5: Morning Procurement & Manifest Export
    // - generateProcurementManifest aggregates confirmed Bucket #1 items,
    //   validates packaging specs, and outputs RFC 4180 CSV.
    // -------------------------------------------------------------------------
    const procurementManifest = await buildProcurementManifest(CAMPAIGN_DATE, mockDb as any);

    assert.equal(procurementManifest.total_confirmed_volume, 100, 'Total volume: 100 kg');
    assert.equal(procurementManifest.total_items_count, 1);
    assert.equal(procurementManifest.total_buckets_count, 1);
    assert.equal(procurementManifest.status, 'pending_procurement');

    const item = procurementManifest.items[0];
    assert.equal(item.product_title, 'Fresh Dinajpur Potatoes (1 kg)');
    assert.equal(item.total_volume, 100);
    assert.equal(item.unit, 'kg');

    // Packaging Specs validation
    const packagingNotes = calculatePackagingNotes(item.total_volume, item.unit, item.category);
    assert.ok(packagingNotes.includes('crates'), 'Vegetables/Produce packaging should specify crates');

    // RFC 4180 CSV Export validation
    const csvContent = generateProcurementCsv(procurementManifest.items);
    assert.ok(csvContent.startsWith('SKU,Product Title,Category,Total Volume,Unit'), 'CSV must have standardized headers');
    assert.ok(csvContent.includes('Fresh Dinajpur Potatoes (1 kg)'));
    assert.ok(csvContent.includes('100'));

    // -------------------------------------------------------------------------
    // Phase 6: Multi-Courier Last-Mile Dispatch
    // - dispatchCampaignOrders calculates parcel weight and assigns Pathao/Steadfast/RedX
    //   tracking codes to confirmed orders.
    // -------------------------------------------------------------------------
    const gateway = new CourierGateway({ mockMode: true, primaryCourier: 'pathao' });
    const dispatchReport = await executeCampaignDispatch({
      date: CAMPAIGN_DATE,
      db: mockDb as any,
      gateway,
      preferredCourier: 'pathao',
    });

    assert.equal(dispatchReport.totalOrders, 3, '3 confirmed orders to dispatch');
    assert.equal(dispatchReport.dispatchedCount, 3);
    assert.equal(dispatchReport.failedCount, 0);

    // Verify parcel weight calculations:
    // User A: 60 kg -> 60 kg parcel weight
    // User B: 25 kg -> 25 kg parcel weight
    // User C: 15 kg -> 15 kg parcel weight
    assert.equal(calculateParcelWeight(60, 'kg'), 60);
    assert.equal(calculateParcelWeight(25, 'kg'), 25);
    assert.equal(calculateParcelWeight(15, 'kg'), 15);

    // Verify order updates in Firestore
    const orderADispatched = mockDb.getDoc(`orders/${orderAResult.orderId}`);
    assert.equal(orderADispatched.status, 'dispatched');
    assert.equal(orderADispatched.courier_partner, 'pathao');
    assert.ok(orderADispatched.tracking_code.startsWith('PTH-TRK-'));
    assert.equal(orderADispatched.parcel_weight_kg, 60);

    const orderBDispatched = mockDb.getDoc(`orders/${orderBResult.orderId}`);
    assert.equal(orderBDispatched.status, 'dispatched');
    assert.equal(orderBDispatched.courier_partner, 'pathao');
    assert.ok(orderBDispatched.tracking_code.startsWith('PTH-TRK-'));
    assert.equal(orderBDispatched.parcel_weight_kg, 25);

    const orderCDispatched = mockDb.getDoc(`orders/${orderCResult.orderId}`);
    assert.equal(orderCDispatched.status, 'dispatched');
    assert.equal(orderCDispatched.courier_partner, 'pathao');
    assert.ok(orderCDispatched.tracking_code.startsWith('PTH-TRK-'));
    assert.equal(orderCDispatched.parcel_weight_kg, 15);

    // -------------------------------------------------------------------------
    // Phase 7: Operator Financial Review & Payout
    // - User D submits withdrawal request for ৳2,400 to bKash.
    // - Admin reviews, approves, debits wallet balance, and writes withdrawal_payout ledger entry.
    // -------------------------------------------------------------------------
    // User D has 2,500 BDT available balance after 100% refund in Phase 4
    const submitWithdrawalResult = await executeSubmitWithdrawalRequest(
      USER_D,
      {
        amount: 2400,
        payoutMethod: 'bkash',
        accountNumber: '+8801711000004',
      },
      mockDb as any
    );

    assert.equal(submitWithdrawalResult.success, true);
    assert.equal(submitWithdrawalResult.amount, 2400);
    const requestId = submitWithdrawalResult.requestId;

    const requestDoc = mockDb.getDoc(`withdrawal_requests/${requestId}`);
    assert.ok(requestDoc, 'Withdrawal request must be saved');
    assert.equal(requestDoc.status, 'pending');
    assert.equal(requestDoc.user_id, USER_D);

    // Admin reviews and approves withdrawal
    const reviewResult = await executeReviewWithdrawalRequest(
      {
        requestId,
        action: 'approve',
        payoutTrxId: 'BKASH_PAYOUT_BATCH_991',
        adminNotes: 'Verified refund balance payout for failed Bucket #2',
      },
      ADMIN_UID,
      mockDb as any
    );

    assert.equal(reviewResult.success, true);
    assert.equal(reviewResult.status, 'approved');
    assert.equal(reviewResult.amount, 2400);

    // Verify User D available balance debited: 2500 - 2400 = 100 BDT
    const userDFinal = mockDb.getDoc(`users/${USER_D}`);
    assert.equal(userDFinal.available_balance, 100);

    // Verify withdrawal request marked approved
    const requestDocApproved = mockDb.getDoc(`withdrawal_requests/${requestId}`);
    assert.equal(requestDocApproved.status, 'approved');
    assert.equal(requestDocApproved.reviewed_by, ADMIN_UID);

    // Verify immutable withdrawal payout ledger entry written
    const allTransactions = mockDb.getAllDocsInCollection('wallet_transactions');
    const payoutTrx = allTransactions.find((t) => t.data.type === 'withdrawal_payout');
    assert.ok(payoutTrx, 'withdrawal_payout ledger record must be written');
    assert.equal(payoutTrx.data.user_id, USER_D);
    assert.equal(payoutTrx.data.amount, -2400);
    assert.equal(payoutTrx.data.gateway, 'bkash');
  });
});
