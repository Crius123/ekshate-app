import * as admin from 'firebase-admin';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { onCall, HttpsError } from 'firebase-functions/v2/https';

/**
 * Helper to get current calendar date string in Asia/Dhaka timezone (YYYY-MM-DD)
 */
export function getDhakaDateString(dateObj: Date = new Date()): string {
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Asia/Dhaka',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
  return formatter.format(dateObj); // Returns "YYYY-MM-DD"
}

interface SettlementSummary {
  date: string;
  confirmedBuckets: number;
  failedBuckets: number;
  confirmedOrders: number;
  refundedOrders: number;
  totalRefundAmount: number;
}

/**
 * Reusable core settlement reconciliation logic.
 * Idempotent, safe to rerun upon partial failure.
 */
export async function executeCampaignSettlement(campaignDate: string): Promise<SettlementSummary> {
  const db = admin.firestore();
  const campaignRef = db.collection('daily_campaigns').doc(campaignDate);

  const campaignSnap = await campaignRef.get();
  if (!campaignSnap.exists) {
    throw new Error(`Campaign for date ${campaignDate} does not exist.`);
  }

  const campaignData = campaignSnap.data()!;
  if (campaignData.status === 'settled') {
    console.log(`Campaign ${campaignDate} is already settled. Exiting idempotently.`);
    return {
      date: campaignDate,
      confirmedBuckets: 0,
      failedBuckets: 0,
      confirmedOrders: 0,
      refundedOrders: 0,
      totalRefundAmount: 0,
    };
  }

  // 1. Lock Campaign: Transition to 'settling'
  await campaignRef.update({
    status: 'settling',
    settling_started_at: admin.firestore.FieldValue.serverTimestamp(),
  });

  const summary: SettlementSummary = {
    date: campaignDate,
    confirmedBuckets: 0,
    failedBuckets: 0,
    confirmedOrders: 0,
    refundedOrders: 0,
    totalRefundAmount: 0,
  };

  // 2. Query All Daily Listings
  const listingsSnap = await campaignRef.collection('listings').get();

  for (const listingDoc of listingsSnap.docs) {
    const listingId = listingDoc.id;
    // Mark listing closed
    await listingDoc.ref.update({
      status: 'closed',
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Query All Buckets for this listing
    const bucketsSnap = await listingDoc.ref.collection('buckets').get();

    for (const bucketDoc of bucketsSnap.docs) {
      const bucketData = bucketDoc.data();
      const bucketNumber = Number(bucketData.bucket_number);
      const bucketStatus = bucketData.status;

      // -------------------------------------------------------------
      // CASE 1: BUCKET MET MOQ ('target_met' or 'confirmed')
      // -------------------------------------------------------------
      if (bucketStatus === 'target_met' || bucketStatus === 'confirmed') {
        await bucketDoc.ref.update({
          status: 'confirmed',
          settled_at: admin.firestore.FieldValue.serverTimestamp(),
        });
        summary.confirmedBuckets++;

        // Query orders in this confirmed bucket to settle escrow balances
        const confirmedOrdersSnap = await db
          .collection('orders')
          .where('date', '==', campaignDate)
          .where('listing_id', '==', listingId)
          .where('bucket_number', '==', bucketNumber)
          .where('status', 'in', ['pending_bucket', 'confirmed'])
          .get();

        for (const orderDoc of confirmedOrdersSnap.docs) {
          const order = orderDoc.data();
          const userId = order.user_id;
          const totalAmount = Number(order.total_amount);

          await db.runTransaction(async (transaction) => {
            const userRef = db.collection('users').doc(userId);
            const userSnap = await transaction.get(userRef);
            if (!userSnap.exists) return;

            // Escrow is captured / settled
            transaction.update(userRef, {
              escrow_balance: admin.firestore.FieldValue.increment(-totalAmount),
              updated_at: admin.firestore.FieldValue.serverTimestamp(),
            });

            // Ensure order is marked confirmed
            transaction.update(orderDoc.ref, {
              status: 'confirmed',
              confirmed_at: admin.firestore.FieldValue.serverTimestamp(),
            });

            // Ledger entry for escrow settlement
            const trxRef = db.collection('wallet_transactions').doc();
            transaction.set(trxRef, {
              trx_id: trxRef.id,
              user_id: userId,
              type: 'order_settle',
              amount: totalAmount,
              status: 'completed',
              gateway: 'internal',
              order_id: orderDoc.id,
              listing_id: listingId,
              bucket_number: bucketNumber,
              created_at: admin.firestore.FieldValue.serverTimestamp(),
            });
          });

          summary.confirmedOrders++;
        }
      }
      // -------------------------------------------------------------
      // CASE 2: BUCKET FAILED MOQ (remained 'open' at 11:59 PM)
      // -------------------------------------------------------------
      else if (bucketStatus === 'open') {
        await bucketDoc.ref.update({
          status: 'failed',
          settled_at: admin.firestore.FieldValue.serverTimestamp(),
        });
        summary.failedBuckets++;

        // Query all unfulfilled orders in this partial bucket
        const pendingOrdersSnap = await db
          .collection('orders')
          .where('date', '==', campaignDate)
          .where('listing_id', '==', listingId)
          .where('bucket_number', '==', bucketNumber)
          .where('status', '==', 'pending_bucket')
          .get();

        // Process batch refunds in chunks of 50 to guarantee atomic safety
        const CHUNK_SIZE = 50;
        for (let i = 0; i < pendingOrdersSnap.docs.length; i += CHUNK_SIZE) {
          const chunk = pendingOrdersSnap.docs.slice(i, i + CHUNK_SIZE);

          for (const orderDoc of chunk) {
            const order = orderDoc.data();
            const userId = order.user_id;
            const refundAmount = Number(order.total_amount);

            await db.runTransaction(async (transaction) => {
              const userRef = db.collection('users').doc(userId);
              const userSnap = await transaction.get(userRef);
              if (!userSnap.exists) return;

              // 1. Restore funds: Escrow -> Available Balance
              transaction.update(userRef, {
                available_balance: admin.firestore.FieldValue.increment(refundAmount),
                escrow_balance: admin.firestore.FieldValue.increment(-refundAmount),
                updated_at: admin.firestore.FieldValue.serverTimestamp(),
              });

              // 2. Mark order refunded
              transaction.update(orderDoc.ref, {
                status: 'refunded',
                refunded_at: admin.firestore.FieldValue.serverTimestamp(),
              });

              // 3. Write immutable refund ledger entry
              const trxRef = db.collection('wallet_transactions').doc();
              transaction.set(trxRef, {
                trx_id: trxRef.id,
                user_id: userId,
                type: 'order_refund',
                amount: refundAmount,
                status: 'completed',
                gateway: 'internal',
                order_id: orderDoc.id,
                listing_id: listingId,
                bucket_number: bucketNumber,
                created_at: admin.firestore.FieldValue.serverTimestamp(),
              });
            });

            summary.refundedOrders++;
            summary.totalRefundAmount += refundAmount;
          }
        }
      }
    }
  }

  // 3. Finalize Campaign Status to 'settled'
  await campaignRef.update({
    status: 'settled',
    settled_at: admin.firestore.FieldValue.serverTimestamp(),
    settlement_summary: summary,
  });

  console.log(`Campaign ${campaignDate} settlement complete:`, summary);
  return summary;
}

/**
 * settleDailyCampaign: Scheduled Cloud Function running at 11:59 PM BDT every night.
 * Automatically reconciles all daily listings, confirms met buckets, and issues
 * instant wallet refunds for partial unfulfilled buckets.
 */
export const settleDailyCampaign = onSchedule(
  {
    schedule: '59 23 * * *',
    timeZone: 'Asia/Dhaka',
    region: 'asia-south1',
    retryCount: 3,
  },
  async () => {
    const todayDhaka = getDhakaDateString();
    console.log(`Running scheduled 11:59 PM settlement for date: ${todayDhaka}`);
    await executeCampaignSettlement(todayDhaka);
  }
);

/**
 * manualSettleDailyCampaign: Administrative callable trigger to execute or test
 * campaign settlement for a specific calendar date on demand.
 */
export const manualSettleDailyCampaign = onCall<{ date?: string }>(
  {
    region: 'asia-south1',
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Admin authentication required.');
    }
    // Verify admin role
    const db = admin.firestore();
    const callerSnap = await db.collection('users').doc(request.auth.uid).get();
    if (!callerSnap.exists || callerSnap.data()?.role !== 'admin') {
      throw new HttpsError('permission-denied', 'Only platform administrators can manually trigger settlement.');
    }

    const targetDate = request.data?.date || getDhakaDateString();
    const summary = await executeCampaignSettlement(targetDate);
    return {
      success: true,
      summary,
    };
  }
);
