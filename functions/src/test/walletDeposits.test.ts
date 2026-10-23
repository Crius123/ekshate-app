import { describe, it } from 'node:test';
import * as assert from 'node:assert/strict';
import { recordDepositTransaction } from '../walletDeposits';

// In-Memory Firestore mock that replicates real Firestore atomic transactions and FieldValue.increment
class MockFirestore {
  private data: Map<string, Map<string, any>> = new Map();

  constructor() {
    this.data.set('users', new Map());
    this.data.set('wallet_transactions', new Map());
  }

  seedUser(uid: string, initialData: any) {
    this.data.get('users')!.set(uid, { ...initialData });
  }

  getUser(uid: string) {
    return this.data.get('users')!.get(uid);
  }

  getTransactionDoc(trxId: string) {
    return this.data.get('wallet_transactions')!.get(trxId);
  }

  collection(collectionName: string) {
    const table = this.data.get(collectionName) || new Map();
    this.data.set(collectionName, table);

    return {
      doc: (docId: string) => {
        return {
          id: docId,
          collectionName,
          path: `${collectionName}/${docId}`,
        };
      },
    };
  }

  async runTransaction<T>(updateFunction: (transaction: any) => Promise<T>): Promise<T> {
    const stagedWrites: Array<() => void> = [];

    const transaction = {
      get: async (docRef: any) => {
        const table = this.data.get(docRef.collectionName);
        const doc = table?.get(docRef.id);
        return {
          exists: doc !== undefined,
          id: docRef.id,
          data: () => (doc ? { ...doc } : undefined),
        };
      },
      set: (docRef: any, data: any) => {
        stagedWrites.push(() => {
          const table = this.data.get(docRef.collectionName)!;
          table.set(docRef.id, { ...data });
        });
      },
      update: (docRef: any, data: any) => {
        stagedWrites.push(() => {
          const table = this.data.get(docRef.collectionName)!;
          const current = table.get(docRef.id) || {};
          const updated = { ...current };

          for (const key of Object.keys(data)) {
            const val = data[key];
            if (val && typeof val === 'object' && ('operand' in val || val.isIncrement)) {
              const inc = ('operand' in val) ? (val as any).operand : (val as any).value;
              updated[key] = (Number(updated[key]) || 0) + Number(inc);
            } else {
              updated[key] = val;
            }
          }
          table.set(docRef.id, updated);
        });
      },
    };

    const result = await updateFunction(transaction);
    // Apply all atomic writes
    for (const write of stagedWrites) {
      write();
    }
    return result;
  }
}

// Override FieldValue.increment in mock context
(global as any).mockIncrement = (value: number) => ({ isIncrement: true, value });

describe('Wallet Deposit Engine & Ledger Idempotency Integration Tests', () => {
  it('successfully credits available_balance on first valid top-up', async () => {
    const mockDb = new MockFirestore();
    mockDb.seedUser('usr_buyer_01', {
      uid: 'usr_buyer_01',
      available_balance: 500,
      escrow_balance: 0,
      role: 'customer',
    });

    const result = await recordDepositTransaction(
      {
        gatewayTrxId: 'trx_bkash_90001',
        userId: 'usr_buyer_01',
        amount: 1500,
        gateway: 'bkash',
        referenceId: 'pay_ref_01',
      },
      mockDb as any
    );

    assert.equal(result.success, true);
    assert.equal(result.duplicate, false);
    assert.equal(result.trxId, 'trx_bkash_90001');
    assert.equal(result.newAvailableBalance, 2000);

    // Verify User Balance updated
    const user = mockDb.getUser('usr_buyer_01');
    assert.equal(user.available_balance, 2000);

    // Verify Ledger record written
    const trx = mockDb.getTransactionDoc('trx_bkash_90001');
    assert.ok(trx);
    assert.equal(trx.trx_id, 'trx_bkash_90001');
    assert.equal(trx.user_id, 'usr_buyer_01');
    assert.equal(trx.type, 'top_up');
    assert.equal(trx.amount, 1500);
    assert.equal(trx.status, 'completed');
    assert.equal(trx.gateway, 'bkash');
  });

  it('guarantees zero duplicate credits when repeated webhook/retry fires with same gatewayTrxId', async () => {
    const mockDb = new MockFirestore();
    mockDb.seedUser('usr_buyer_02', {
      uid: 'usr_buyer_02',
      available_balance: 1000,
      escrow_balance: 0,
      role: 'customer',
    });

    // 1st Webhook: Successfully processed
    const firstCall = await recordDepositTransaction(
      {
        gatewayTrxId: 'val_ssl_unique_999',
        userId: 'usr_buyer_02',
        amount: 2500,
        gateway: 'sslcommerz',
        referenceId: 'tran_ssl_999',
      },
      mockDb as any
    );

    assert.equal(firstCall.success, true);
    assert.equal(firstCall.duplicate, false);
    assert.equal(mockDb.getUser('usr_buyer_02').available_balance, 3500);

    // 2nd Webhook (Network retry or duplicate IPN callback with same val_id)
    const secondCall = await recordDepositTransaction(
      {
        gatewayTrxId: 'val_ssl_unique_999',
        userId: 'usr_buyer_02',
        amount: 2500,
        gateway: 'sslcommerz',
        referenceId: 'tran_ssl_999',
      },
      mockDb as any
    );

    // Assert duplicate detected and zero balance increment
    assert.equal(secondCall.success, true);
    assert.equal(secondCall.duplicate, true);
    assert.match(secondCall.message, /Duplicate credit prevented/i);
    assert.equal(
      mockDb.getUser('usr_buyer_02').available_balance,
      3500,
      'Available balance must NOT increment on duplicate transaction'
    );

    // 3rd Webhook (Another retry)
    const thirdCall = await recordDepositTransaction(
      {
        gatewayTrxId: 'val_ssl_unique_999',
        userId: 'usr_buyer_02',
        amount: 2500,
        gateway: 'sslcommerz',
      },
      mockDb as any
    );

    assert.equal(thirdCall.duplicate, true);
    assert.equal(mockDb.getUser('usr_buyer_02').available_balance, 3500);
  });

  it('throws error when user document does not exist and prevents ledger corruption', async () => {
    const mockDb = new MockFirestore();

    await assert.rejects(
      async () => {
        await recordDepositTransaction(
          {
            gatewayTrxId: 'trx_ghost_01',
            userId: 'non_existent_uid',
            amount: 500,
            gateway: 'bkash',
          },
          mockDb as any
        );
      },
      {
        message: /User profile not found for uid: non_existent_uid/,
      }
    );

    // Assert no orphaned ledger entry was created
    assert.equal(mockDb.getTransactionDoc('trx_ghost_01'), undefined);
  });

  it('rejects invalid or non-positive deposit amounts', async () => {
    const mockDb = new MockFirestore();
    mockDb.seedUser('usr_buyer_03', { uid: 'usr_buyer_03', available_balance: 100 });

    await assert.rejects(
      async () => {
        await recordDepositTransaction(
          {
            gatewayTrxId: 'trx_neg_01',
            userId: 'usr_buyer_03',
            amount: -100,
            gateway: 'bkash',
          },
          mockDb as any
        );
      },
      {
        message: /Deposit amount must be a positive number/,
      }
    );

    await assert.rejects(
      async () => {
        await recordDepositTransaction(
          {
            gatewayTrxId: 'trx_zero_01',
            userId: 'usr_buyer_03',
            amount: 0,
            gateway: 'bkash',
          },
          mockDb as any
        );
      },
      {
        message: /Deposit amount must be a positive number/,
      }
    );
  });
});
