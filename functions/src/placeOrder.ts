import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onDocumentUpdated } from 'firebase-functions/v2/firestore';

export interface PlaceOrderPayload {
  date: string;          // Format: "YYYY-MM-DD"
  listingId: string;     // e.g. "oranges_01"
  quantity: number;      // Volume requested (e.g. 5 kg)
  deliveryAddress: string;
  phone?: string;
}

export interface PlaceOrderResult {
  success: boolean;
  orderId: string;
  bucketNumber: number;
  isMoqReached: boolean;
  nextBucketNumber: number | null;
  totalAmount: number;
}

/**
 * executePlaceOrder: Core transaction logic for placeOrder.
 * Separated to allow direct integration testing against Firebase Emulators & Mock Firestore.
 */
export async function executePlaceOrder(
  uid: string,
  payload: PlaceOrderPayload,
  firestoreInstance?: admin.firestore.Firestore
): Promise<PlaceOrderResult> {
  const { date, listingId, quantity, deliveryAddress, phone } = payload;

  // 1. Input Validation
  if (!date || !/^\d{4}-\d{2}-\d{2}$/.test(date)) {
    throw new HttpsError('invalid-argument', 'Invalid campaign date format. Expected YYYY-MM-DD.');
  }
  if (!listingId || typeof listingId !== 'string') {
    throw new HttpsError('invalid-argument', 'Valid listingId is required.');
  }
  if (typeof quantity !== 'number' || quantity <= 0 || !Number.isFinite(quantity)) {
    throw new HttpsError('invalid-argument', 'Quantity must be a positive number.');
  }
  if (!deliveryAddress || typeof deliveryAddress !== 'string' || deliveryAddress.trim().length === 0) {
    throw new HttpsError('invalid-argument', 'Delivery address is required.');
  }

  const db = firestoreInstance || admin.firestore();

  // Document References
  const userRef = db.collection('users').doc(uid);
  const campaignRef = db.collection('daily_campaigns').doc(date);
  const listingRef = campaignRef.collection('listings').doc(listingId);

  // 2. Atomic Transaction
  const result = await db.runTransaction(async (transaction) => {
    // -----------------------------------------------------------------
    // PHASE A: ALL READS (Must execute before any writes)
    // -----------------------------------------------------------------

    // Read User
    const userSnap = await transaction.get(userRef);
    if (!userSnap.exists) {
      throw new HttpsError('not-found', 'User profile not found.');
    }
    const userData = userSnap.data()!;
    const availableBalance = Number(userData.available_balance || 0);

    // Read Campaign
    const campaignSnap = await transaction.get(campaignRef);
    if (!campaignSnap.exists) {
      throw new HttpsError('not-found', `Campaign for ${date} does not exist.`);
    }
    const campaignData = campaignSnap.data()!;
    if (campaignData.status !== 'active') {
      throw new HttpsError(
        'failed-precondition',
        `Campaign is not active (current status: ${campaignData.status}). Orders accepted only 10:00 AM - 11:59 PM BDT.`
      );
    }

    // Read Listing
    const listingSnap = await transaction.get(listingRef);
    if (!listingSnap.exists) {
      throw new HttpsError('not-found', `Listing '${listingId}' does not exist.`);
    }
    const listingData = listingSnap.data()!;
    if (listingData.status !== 'active') {
      throw new HttpsError('failed-precondition', `Listing is currently closed.`);
    }

    const unitPrice = Number(listingData.unit_price);
    const totalAmount = quantity * unitPrice;

    // Verify User Wallet Balance
    if (availableBalance < totalAmount) {
      throw new HttpsError(
        'failed-precondition',
        `Insufficient wallet balance. Total: ${totalAmount} BDT, Available: ${availableBalance} BDT. Please top up.`
      );
    }

    const activeBucketNum = Number(listingData.active_bucket_number || 1);
    const bucketRef = listingRef.collection('buckets').doc(String(activeBucketNum));

    // Read Active Bucket
    const bucketSnap = await transaction.get(bucketRef);
    if (!bucketSnap.exists) {
      throw new HttpsError('not-found', `Active Bucket #${activeBucketNum} not initialized.`);
    }
    const bucketData = bucketSnap.data()!;
    if (bucketData.status !== 'open') {
      throw new HttpsError(
        'failed-precondition',
        `Bucket #${activeBucketNum} is locked (${bucketData.status}).`
      );
    }

    const moqThreshold = Number(bucketData.moq_threshold);
    const currentQuantity = Number(bucketData.current_quantity || 0);
    const remainingCapacity = moqThreshold - currentQuantity;

    // HARD CAPACITY CLAMP: Single-bucket integrity rule
    if (quantity > remainingCapacity) {
      throw new HttpsError(
        'failed-precondition',
        `Requested quantity (${quantity} kg) exceeds remaining bucket capacity (${remainingCapacity} kg). Hard capacity clamp enforced.`
      );
    }

    // -----------------------------------------------------------------
    // PHASE B: ALL WRITES
    // -----------------------------------------------------------------
    const newQuantity = currentQuantity + quantity;
    const newRemainingCapacity = moqThreshold - newQuantity;
    const isMoqReached = newQuantity === moqThreshold;

    // 1. Deduct Available Balance, Credit Escrow Balance
    transaction.update(userRef, {
      available_balance: admin.firestore.FieldValue.increment(-totalAmount),
      escrow_balance: admin.firestore.FieldValue.increment(totalAmount),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 2. Create Order Document
    const orderRef = db.collection('orders').doc();
    const orderPayload = {
      order_id: orderRef.id,
      user_id: uid,
      user_phone: phone || userData.phone_number || '',
      date,
      listing_id: listingId,
      bucket_number: activeBucketNum,
      product_id: listingData.product_id,
      product_title: listingData.product_title,
      unit: listingData.unit,
      unit_price: unitPrice,
      quantity,
      total_amount: totalAmount,
      status: 'pending_bucket',
      delivery_address: deliveryAddress.trim(),
      created_at: admin.firestore.FieldValue.serverTimestamp(),
      confirmed_at: null,
      refunded_at: null,
    };
    transaction.set(orderRef, orderPayload);

    // 3. Write Ledger Entry (write-once audit trail)
    const trxRef = db.collection('wallet_transactions').doc();
    transaction.set(trxRef, {
      trx_id: trxRef.id,
      user_id: uid,
      type: 'order_hold',
      amount: -totalAmount,
      status: 'completed',
      gateway: 'internal',
      order_id: orderRef.id,
      listing_id: listingId,
      bucket_number: activeBucketNum,
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 4. Update Current Bucket Volume
    transaction.update(bucketRef, {
      current_quantity: newQuantity,
      remaining_capacity: newRemainingCapacity,
      order_count: admin.firestore.FieldValue.increment(1),
      status: isMoqReached ? 'target_met' : 'open',
      target_met_at: isMoqReached ? admin.firestore.FieldValue.serverTimestamp() : null,
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 5. Update Listing Totals
    transaction.update(listingRef, {
      total_volume_ordered: admin.firestore.FieldValue.increment(quantity),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    // 6. Rollover to Bucket #(N+1) if MOQ Target Met
    let nextBucketNumber: number | null = null;
    if (isMoqReached) {
      nextBucketNumber = activeBucketNum + 1;
      const nextBucketRef = listingRef.collection('buckets').doc(String(nextBucketNumber));

      transaction.set(nextBucketRef, {
        bucket_number: nextBucketNumber,
        listing_id: listingId,
        date,
        moq_threshold: moqThreshold,
        current_quantity: 0,
        remaining_capacity: moqThreshold,
        status: 'open',
        order_count: 0,
        target_met_at: null,
        settled_at: null,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      transaction.update(listingRef, {
        active_bucket_number: nextBucketNumber,
        total_buckets_count: admin.firestore.FieldValue.increment(1),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    return {
      orderId: orderRef.id,
      bucketNumber: activeBucketNum,
      isMoqReached,
      nextBucketNumber,
      totalAmount,
    };
  });

  return {
    success: true,
    ...result,
  };
}

/**
 * placeOrder: Atomic Firestore transaction for community bulk purchasing.
 * Enforces single-bucket integrity, hard capacity limits, wallet balance validation,
 * escrow reserve deduction, and automatic rollover to Bucket #(N+1) upon MOQ threshold.
 */
export const placeOrder = onCall<PlaceOrderPayload>(
  {
    region: 'asia-south1',
    enforceAppCheck: false, // Set to true in production with App Check tokens
  },
  async (request) => {
    // 1. Authentication Check
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError('unauthenticated', 'User must be signed in to place an order.');
    }
    const uid = request.auth.uid;
    return await executePlaceOrder(uid, request.data);
  }
);

/**
 * processBucketTargetMet: Asynchronously updates all pending orders in this bucket to 'confirmed'.
 */
export async function processBucketTargetMet(
  date: string,
  listingId: string,
  bucketNumber: number,
  firestoreInstance?: admin.firestore.Firestore
): Promise<number> {
  const db = firestoreInstance || admin.firestore();
  const ordersQuery = await db
    .collection('orders')
    .where('date', '==', date)
    .where('listing_id', '==', listingId)
    .where('bucket_number', '==', bucketNumber)
    .where('status', '==', 'pending_bucket')
    .get();

  if (ordersQuery.empty) return 0;

  const batch = db.batch();
  ordersQuery.docs.forEach((doc: any) => {
    batch.update(doc.ref, {
      status: 'confirmed',
      confirmed_at: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  await batch.commit();

  // Send transactional FCM push and in-app notifications to all participant buyers
  try {
    const { notifyBucketTargetMet } = await import('./notificationEngine');
    await notifyBucketTargetMet(date, listingId, bucketNumber, db);
  } catch (notifErr) {
    console.error(`Error notifying buyers for Bucket #${bucketNumber} (${listingId}):`, notifErr);
  }

  return ordersQuery.size;
}

/**
 * onBucketTargetMet: Background trigger firing when a bucket achieves MOQ ('target_met').
 * Asynchronously updates all pending orders in this bucket to 'confirmed'.
 * Decouples order status fan-out from the placeOrder transaction.
 */
export const onBucketTargetMet = onDocumentUpdated(
  {
    document: 'daily_campaigns/{date}/listings/{listingId}/buckets/{bucketNumber}',
    region: 'asia-south1',
  },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    // Transition from 'open' to 'target_met'
    if (before.status === 'open' && after.status === 'target_met') {
      const date = event.params.date;
      const listingId = event.params.listingId;
      const bucketNumber = Number(event.params.bucketNumber);
      const count = await processBucketTargetMet(date, listingId, bucketNumber);
      console.log(`Confirmed ${count} orders for Bucket #${bucketNumber} (${listingId})`);
    }
  }
);
