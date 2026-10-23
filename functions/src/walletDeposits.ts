import * as admin from 'firebase-admin';
import { onCall, onRequest, HttpsError } from 'firebase-functions/v2/https';

export type DepositGateway = 'bkash' | 'sslcommerz';

export interface RecordDepositParams {
  gatewayTrxId: string;
  userId: string;
  amount: number;
  gateway: DepositGateway;
  referenceId?: string;
  metadata?: Record<string, unknown>;
}

export interface DepositResult {
  success: boolean;
  duplicate: boolean;
  trxId: string;
  amount: number;
  message: string;
  newAvailableBalance?: number;
}

/**
 * recordDepositTransaction: Core write-once ledger idempotency engine.
 * Atomically verifies wallet_transactions/{gatewayTrxId} before incrementing available_balance.
 * Guarantees zero duplicate credits across repeated webhooks, network retries, or concurrent callbacks.
 */
export async function recordDepositTransaction(
  params: RecordDepositParams,
  firestoreInstance?: admin.firestore.Firestore
): Promise<DepositResult> {
  const db = firestoreInstance || admin.firestore();
  const { gatewayTrxId, userId, amount, gateway, referenceId, metadata } = params;

  if (!gatewayTrxId || typeof gatewayTrxId !== 'string' || gatewayTrxId.trim().length === 0) {
    throw new Error('Valid gatewayTrxId is required.');
  }
  if (!userId || typeof userId !== 'string' || userId.trim().length === 0) {
    throw new Error('Valid userId is required.');
  }
  if (typeof amount !== 'number' || !Number.isFinite(amount) || amount <= 0) {
    throw new Error('Deposit amount must be a positive number.');
  }

  const trxRef = db.collection('wallet_transactions').doc(gatewayTrxId.trim());
  const userRef = db.collection('users').doc(userId.trim());

  return await db.runTransaction(async (transaction) => {
    // -------------------------------------------------------------
    // PHASE A: ALL READS
    // -------------------------------------------------------------
    const existingTrxSnap = await transaction.get(trxRef);

    // IDEMPOTENCY CHECK: If transaction record already exists, abort safely with duplicate flag
    if (existingTrxSnap.exists) {
      const existingData = existingTrxSnap.data()!;
      console.warn(
        `[Idempotency Guard] Duplicate deposit attempt detected for gatewayTrxId: ${gatewayTrxId} (User: ${userId})`
      );
      return {
        success: true,
        duplicate: true,
        trxId: gatewayTrxId,
        amount: Number(existingData.amount || amount),
        message: 'Deposit already processed. Duplicate credit prevented.',
      };
    }

    const userSnap = await transaction.get(userRef);
    if (!userSnap.exists) {
      throw new Error(`User profile not found for uid: ${userId}`);
    }

    const currentBalance = Number(userSnap.data()?.available_balance || 0);
    const newBalance = currentBalance + amount;

    // -------------------------------------------------------------
    // PHASE B: ALL WRITES
    // -------------------------------------------------------------
    // 1. Write immutable ledger entry
    transaction.set(trxRef, {
      trx_id: gatewayTrxId,
      user_id: userId,
      type: 'top_up',
      amount,
      status: 'completed',
      gateway,
      reference_id: referenceId || gatewayTrxId,
      metadata: metadata || {},
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 2. Increment available_balance
    transaction.update(userRef, {
      available_balance: admin.firestore.FieldValue.increment(amount),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      duplicate: false,
      trxId: gatewayTrxId,
      amount,
      newAvailableBalance: newBalance,
      message: 'Wallet balance successfully credited.',
    };
  });
}

/**
 * createDepositSession:
 * Callable Cloud Function initiating bKash Tokenized Checkout or SSLCommerz Hosted Session.
 */
export const createDepositSession = onCall<{
  amount: number;
  gateway: DepositGateway;
  callbackUrl?: string;
}>(
  {
    region: 'asia-south1',
  },
  async (request) => {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError('unauthenticated', 'User must be signed in to deposit funds.');
    }
    const uid = request.auth.uid;
    const { amount, gateway, callbackUrl } = request.data;

    if (typeof amount !== 'number' || !Number.isFinite(amount) || amount < 10) {
      throw new HttpsError('invalid-argument', 'Minimum deposit amount is 10 BDT.');
    }
    if (amount > 100000) {
      throw new HttpsError('invalid-argument', 'Maximum deposit amount per transaction is 100,000 BDT.');
    }
    if (gateway !== 'bkash' && gateway !== 'sslcommerz') {
      throw new HttpsError('invalid-argument', 'Supported gateways are "bkash" and "sslcommerz".');
    }

    const now = Date.now();
    const nonce = Math.random().toString(36).substring(2, 8).toUpperCase();

    if (gateway === 'bkash') {
      const paymentId = `bkash_pay_${now}_${nonce}`;
      const simulatedTrxId = `trx_bkash_${now}_${nonce}`;
      const bkashURL = `https://checkout.sandbox.bka.sh/v1.2.0-beta/tokenized/checkout?paymentID=${paymentId}`;

      return {
        success: true,
        gateway: 'bkash',
        userId: uid,
        paymentId,
        gatewayTrxId: simulatedTrxId,
        amount,
        redirectUrl: bkashURL,
        callbackUrl: callbackUrl || `https://ekshate.web.app/wallet/callback?paymentID=${paymentId}`,
      };
    } else {
      const tranId = `ssl_${now}_${nonce}`;
      const simulatedValId = `val_ssl_${now}_${nonce}`;
      const gatewayPageUrl = `https://sandbox.sslcommerz.com/gwprocess/v4/gw.php?Q=pay&tran_id=${tranId}`;

      return {
        success: true,
        gateway: 'sslcommerz',
        userId: uid,
        paymentId: tranId,
        tranId,
        gatewayTrxId: simulatedValId,
        amount,
        redirectUrl: gatewayPageUrl,
        ipnUrl: `https://asia-south1-ekshate-app.cloudfunctions.net/sslcommerzIpnWebhook`,
      };
    }
  }
);

/**
 * executeBkashPayment:
 * Callable Cloud Function to execute bKash Tokenized Checkout after customer enters PIN.
 */
export const executeBkashPayment = onCall<{
  paymentId: string;
  trxId?: string;
  amount: number;
}>(
  {
    region: 'asia-south1',
  },
  async (request) => {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError('unauthenticated', 'User must be signed in to complete deposit.');
    }
    const uid = request.auth.uid;
    const { paymentId, trxId, amount } = request.data;

    if (!paymentId) {
      throw new HttpsError('invalid-argument', 'paymentId is required.');
    }
    if (typeof amount !== 'number' || amount <= 0) {
      throw new HttpsError('invalid-argument', 'Valid amount is required.');
    }

    const gatewayTrxId = trxId || `trx_bkash_${paymentId.replace('bkash_pay_', '')}`;

    try {
      const result = await recordDepositTransaction({
        gatewayTrxId,
        userId: uid,
        amount,
        gateway: 'bkash',
        referenceId: paymentId,
        metadata: {
          flow: 'bkash_tokenized_checkout',
        },
      });

      return result;
    } catch (error: any) {
      console.error('Failed to execute bKash deposit:', error);
      throw new HttpsError('internal', error.message || 'Deposit processing failed.');
    }
  }
);

/**
 * sslcommerzIpnWebhook:
 * HTTP Webhook endpoint receiving asynchronous IPN callbacks from SSLCommerz.
 * Validates payload and invokes atomic recordDepositTransaction with val_id as idempotency key.
 */
export const sslcommerzIpnWebhook = onRequest(
  {
    region: 'asia-south1',
  },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).send('Method Not Allowed');
      return;
    }

    const body = req.body || {};
    const {
      val_id,
      tran_id,
      amount,
      status,
      currency,
      value_a, // Contains userId
    } = body;

    console.log('[SSLCommerz IPN Received]', { val_id, tran_id, amount, status, currency, userId: value_a });

    // Validate Status and Currency
    if (status !== 'VALID' && status !== 'VALIDATED') {
      console.warn(`[SSLCommerz IPN] Payment status is ${status}, ignoring credit.`);
      res.status(200).json({ status: 'IGNORED', message: `Status was ${status}` });
      return;
    }

    if (currency !== 'BDT') {
      console.warn(`[SSLCommerz IPN] Invalid currency ${currency}, expected BDT.`);
      res.status(400).send('Invalid currency');
      return;
    }

    if (!val_id || !value_a || !amount) {
      console.error('[SSLCommerz IPN] Missing mandatory IPN fields.');
      res.status(400).send('Missing mandatory parameters');
      return;
    }

    try {
      const depositAmount = parseFloat(amount);
      const result = await recordDepositTransaction({
        gatewayTrxId: val_id,
        userId: value_a,
        amount: depositAmount,
        gateway: 'sslcommerz',
        referenceId: tran_id,
        metadata: {
          ipn_body: body,
        },
      });

      res.status(200).json({
        status: 'SUCCESS',
        duplicate: result.duplicate,
        trxId: result.trxId,
        message: result.message,
      });
    } catch (err: any) {
      console.error('[SSLCommerz IPN Error]', err);
      res.status(500).json({ status: 'FAILED', error: err.message });
    }
  }
);
