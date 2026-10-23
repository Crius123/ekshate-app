import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getDhakaDateString } from './settleDailyCampaign';

export interface ScheduleListingItem {
  productId?: string;
  productTitle: string;
  unit: string;
  marketPrice: number;
  unitPrice: number;
  moqThreshold: number;
  category?: string;
  imageUrl?: string;
  description?: string;
}

export interface CreateOrUpdateCampaignPayload {
  date?: string;
  status?: 'preview' | 'active' | 'closed' | 'settled';
  listings?: ScheduleListingItem[];
  listing?: ScheduleListingItem;
}

export interface ReviewWithdrawalPayload {
  requestId: string;
  action: 'approve' | 'reject';
  rejectionReason?: string;
  payoutMethod?: string;
  payoutTrxId?: string;
  adminNotes?: string;
}

export interface SubmitWithdrawalPayload {
  amount: number;
  payoutMethod: 'bkash' | 'nagad' | 'bank' | 'rocket' | string;
  accountNumber: string;
  bankName?: string;
  accountHolderName?: string;
}

export interface BucketMomentumItem {
  listingId: string;
  productId: string;
  productTitle: string;
  category: string;
  unit: string;
  marketPrice: number;
  unitPrice: number;
  discountPercent: number;
  activeBucketNumber: number;
  moqThreshold: number;
  currentQuantity: number;
  remainingCapacity: number;
  fillPercentage: number;
  orderCount: number;
  status: string;
}

export interface AdminOperationalMetrics {
  date: string;
  campaignStatus: string;
  gmv: number;
  escrowVolume: number;
  totalOrdersCount: number;
  pendingEscrowOrdersCount: number;
  confirmedOrdersCount: number;
  dispatchedOrdersCount: number;
  refundedOrdersCount: number;
  pendingDispatchCount: number;
  listingsCount: number;
  averageFillPercentage: number;
  bucketMomentum: BucketMomentumItem[];
  pendingWithdrawalsCount: number;
  pendingWithdrawalsAmount: number;
}

/**
 * Verify caller has admin privileges (via token claims or Firestore users profile)
 */
export async function verifyAdminCaller(
  auth: { uid: string; token?: any } | undefined,
  dbInstance?: admin.firestore.Firestore
): Promise<string> {
  if (!auth || !auth.uid) {
    throw new HttpsError('unauthenticated', 'Admin authentication required.');
  }

  // Token custom claims check
  if (auth.token?.role === 'admin' || auth.token?.admin === true) {
    return auth.uid;
  }

  // Firestore user profile role check
  const db = dbInstance || admin.firestore();
  const userSnap = await db.collection('users').doc(auth.uid).get();
  if (!userSnap.exists || userSnap.data()?.role !== 'admin') {
    throw new HttpsError(
      'permission-denied',
      'Access restricted to platform administrators only.'
    );
  }

  return auth.uid;
}

/**
 * Core business logic for provisioning calendar date campaigns & wholesale listings
 */
export async function executeCreateOrUpdateDailyCampaign(
  payload: CreateOrUpdateCampaignPayload,
  firestoreInstance?: admin.firestore.Firestore
): Promise<{
  success: boolean;
  date: string;
  status: string;
  activeFrom: string;
  activeTo: string;
  listingsCreated: number;
  listings: Array<{ listingId: string; productTitle: string; discountPercent: number; moqThreshold: number }>;
}> {
  const db = firestoreInstance || admin.firestore();
  const targetDate = payload.date || getDhakaDateString();

  if (!/^\d{4}-\d{2}-\d{2}$/.test(targetDate)) {
    throw new HttpsError('invalid-argument', `Invalid date format: ${targetDate}. Expected YYYY-MM-DD.`);
  }

  // Active purchasing window: 10:00 AM – 11:59 PM BDT (+06:00)
  const activeFromDate = new Date(`${targetDate}T10:00:00+06:00`);
  const activeToDate = new Date(`${targetDate}T23:59:59+06:00`);

  let campaignStatus = payload.status;
  if (!campaignStatus) {
    const todayDhaka = getDhakaDateString();
    if (targetDate > todayDhaka) {
      campaignStatus = 'preview';
    } else if (targetDate === todayDhaka) {
      const now = new Date();
      if (now >= activeFromDate && now <= activeToDate) {
        campaignStatus = 'active';
      } else if (now < activeFromDate) {
        campaignStatus = 'preview';
      } else {
        campaignStatus = 'closed';
      }
    } else {
      campaignStatus = 'closed';
    }
  }

  const campaignRef = db.collection('daily_campaigns').doc(targetDate);
  const campaignSnap = await campaignRef.get();

  const campaignRecord: Record<string, any> = {
    date: targetDate,
    status: campaignStatus,
    active_from: admin.firestore.Timestamp.fromDate(activeFromDate),
    active_to: admin.firestore.Timestamp.fromDate(activeToDate),
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  };

  if (!campaignSnap.exists) {
    campaignRecord.created_at = admin.firestore.FieldValue.serverTimestamp();
    campaignRecord.total_listings_count = 0;
  }

  await campaignRef.set(campaignRecord, { merge: true });

  // Consolidate listings from payload
  const rawListings: ScheduleListingItem[] = [];
  if (Array.isArray(payload.listings)) {
    rawListings.push(...payload.listings);
  }
  if (payload.listing) {
    rawListings.push(payload.listing);
  }

  const createdListingsSummary: Array<{
    listingId: string;
    productTitle: string;
    discountPercent: number;
    moqThreshold: number;
  }> = [];

  for (const item of rawListings) {
    if (!item.productTitle || !item.unit || item.marketPrice <= 0 || item.unitPrice <= 0 || item.moqThreshold <= 0) {
      throw new HttpsError(
        'invalid-argument',
        `Invalid listing fields for "${item.productTitle || 'Unknown'}". Ensure positive prices and MOQ.`
      );
    }

    const discountPercent = Math.max(
      0,
      Math.round(((item.marketPrice - item.unitPrice) / item.marketPrice) * 100 * 10) / 10
    );

    const slug = item.productTitle
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, '_')
      .replace(/^_+|_+$/g, '');
    const cleanDate = targetDate.replace(/-/g, '');
    const listingId = `list_${cleanDate}_${slug || 'item'}`;
    const productId = item.productId || `prod_${slug || 'item'}`;

    const listingRef = campaignRef.collection('listings').doc(listingId);
    await listingRef.set(
      {
        product_id: productId,
        product_title: item.productTitle,
        unit: item.unit,
        market_price: item.marketPrice,
        unit_price: item.unitPrice,
        discount_percent: discountPercent,
        moq_threshold: item.moqThreshold,
        active_bucket_number: 1,
        total_buckets_count: 1,
        total_volume_ordered: 0,
        status: campaignStatus === 'preview' ? 'preview' : 'active',
        category: item.category || 'General',
        image_url: item.imageUrl || '',
        thumbnail_url: item.imageUrl || '',
        description: item.description || '',
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    // Auto-initialize Bucket #1
    const bucket1Ref = listingRef.collection('buckets').doc('1');
    const bucket1Snap = await bucket1Ref.get();
    if (!bucket1Snap.exists) {
      await bucket1Ref.set({
        bucket_number: 1,
        listing_id: listingId,
        date: targetDate,
        moq_threshold: item.moqThreshold,
        current_quantity: 0,
        remaining_capacity: item.moqThreshold,
        status: 'open',
        order_count: 0,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    // Upsert into master products collection if not present
    const productRef = db.collection('products').doc(productId);
    const productSnap = await productRef.get();
    if (!productSnap.exists) {
      await productRef.set({
        title: item.productTitle,
        description: item.description || `${item.productTitle} bulk wholesale listing.`,
        category: item.category || 'General',
        unit: item.unit,
        media_urls: item.imageUrl ? [item.imageUrl] : [],
        thumbnail_url: item.imageUrl || '',
        is_active: true,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    createdListingsSummary.push({
      listingId,
      productTitle: item.productTitle,
      discountPercent,
      moqThreshold: item.moqThreshold,
    });
  }

  // Update total listings count
  const allListingsSnap = await campaignRef.collection('listings').get();
  await campaignRef.update({
    total_listings_count: allListingsSnap.size,
  });

  return {
    success: true,
    date: targetDate,
    status: campaignStatus,
    activeFrom: activeFromDate.toISOString(),
    activeTo: activeToDate.toISOString(),
    listingsCreated: rawListings.length,
    listings: createdListingsSummary,
  };
}

/**
 * Core business logic for reviewing/approving/rejecting customer withdrawal requests
 */
export async function executeReviewWithdrawalRequest(
  payload: ReviewWithdrawalPayload,
  adminUid: string,
  firestoreInstance?: admin.firestore.Firestore
): Promise<{
  success: boolean;
  requestId: string;
  status: 'approved' | 'rejected';
  amount: number;
  trxId?: string;
  rejectionReason?: string;
}> {
  const db = firestoreInstance || admin.firestore();

  if (!payload.requestId || !payload.action) {
    throw new HttpsError('invalid-argument', 'requestId and action ("approve" | "reject") are required.');
  }

  if (payload.action !== 'approve' && payload.action !== 'reject') {
    throw new HttpsError('invalid-argument', `Invalid action: ${payload.action}. Must be "approve" or "reject".`);
  }

  const requestRef = db.collection('withdrawal_requests').doc(payload.requestId);

  // If mock firestore does not support runTransaction, provide direct fallback
  const runTransaction = db.runTransaction
    ? (fn: (trx: any) => Promise<any>) => db.runTransaction(fn)
    : async (fn: (trx: any) => Promise<any>) => {
        const dummyTrx = {
          get: (ref: any) => ref.get(),
          set: (ref: any, data: any) => ref.set(data),
          update: (ref: any, data: any) => ref.update(data),
        };
        return fn(dummyTrx);
      };

  return await runTransaction(async (trx) => {
    const requestSnap = await trx.get(requestRef);
    if (!requestSnap.exists) {
      throw new HttpsError('not-found', `Withdrawal request ${payload.requestId} does not exist.`);
    }

    const reqData = requestSnap.data()!;
    if (reqData.status !== 'pending') {
      throw new HttpsError('failed-precondition', `Withdrawal request has already been ${reqData.status}.`);
    }

    const userId = reqData.user_id;
    const amount = Number(reqData.amount);

    if (isNaN(amount) || amount <= 0) {
      throw new HttpsError('invalid-argument', 'Withdrawal request contains an invalid amount.');
    }

    const userRef = db.collection('users').doc(userId);
    const userSnap = await trx.get(userRef);
    if (!userSnap.exists) {
      throw new HttpsError('not-found', `Customer profile ${userId} not found.`);
    }

    const userData = userSnap.data()!;

    if (payload.action === 'approve') {
      const currentAvailable = Number(userData.available_balance ?? 0);
      if (currentAvailable < amount) {
        throw new HttpsError(
          'failed-precondition',
          `Insufficient customer available balance. Required: ৳${amount}, Available: ৳${currentAvailable}.`
        );
      }

      // Debit customer balance atomically
      const updatedBalance = +(currentAvailable - amount).toFixed(2);
      trx.update(userRef, {
        available_balance: updatedBalance,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Write-once ledger audit record
      const trxId = payload.payoutTrxId || `trx_payout_${payload.requestId}`;
      const ledgerRef = db.collection('wallet_transactions').doc(trxId);
      trx.set(ledgerRef, {
        trx_id: trxId,
        user_id: userId,
        type: 'withdrawal_payout',
        amount: -amount,
        status: 'completed',
        gateway: reqData.payout_method || payload.payoutMethod || 'bkash',
        reference_id: payload.requestId,
        created_at: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Update withdrawal request record
      trx.update(requestRef, {
        status: 'approved',
        reviewed_by: adminUid,
        reviewed_at: admin.firestore.FieldValue.serverTimestamp(),
        trx_id: trxId,
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
        ...(payload.adminNotes ? { admin_notes: payload.adminNotes } : {}),
      });

      return {
        success: true,
        requestId: payload.requestId,
        status: 'approved' as const,
        amount,
        trxId,
      };
    } else {
      // Action is 'reject'
      const reason = payload.rejectionReason || 'Rejected by platform administrator.';
      trx.update(requestRef, {
        status: 'rejected',
        rejection_reason: reason,
        reviewed_by: adminUid,
        reviewed_at: admin.firestore.FieldValue.serverTimestamp(),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
        ...(payload.adminNotes ? { admin_notes: payload.adminNotes } : {}),
      });

      return {
        success: true,
        requestId: payload.requestId,
        status: 'rejected' as const,
        amount,
        rejectionReason: reason,
      };
    }
  });
}

/**
 * Core business logic for real-time operational metrics & monitoring
 */
export async function executeGetAdminOperationalMetrics(
  targetDate?: string,
  firestoreInstance?: admin.firestore.Firestore
): Promise<AdminOperationalMetrics> {
  const db = firestoreInstance || admin.firestore();
  const date = targetDate || getDhakaDateString();

  const campaignRef = db.collection('daily_campaigns').doc(date);
  const campaignSnap = await campaignRef.get();
  const campaignStatus = campaignSnap.exists ? campaignSnap.data()?.status || 'preview' : 'not_created';

  // 1. Fetch Orders for this date
  let ordersList: any[] = [];
  if (typeof (db as any).getAllDocsInCollection === 'function') {
    ordersList = (db as any).getAllDocsInCollection('orders').filter((d: any) => d.data.date === date);
  } else {
    const ordersSnap = await db.collection('orders').where('date', '==', date).get();
    ordersList = ordersSnap.docs.map((d) => ({ path: d.ref.path, id: d.id, data: d.data() }));
  }

  let gmv = 0;
  let escrowVolume = 0;
  let pendingEscrowOrdersCount = 0;
  let confirmedOrdersCount = 0;
  let dispatchedOrdersCount = 0;
  let refundedOrdersCount = 0;
  let pendingDispatchCount = 0;

  for (const o of ordersList) {
    const d = o.data;
    const amount = Number(d.total_amount || 0);
    const status = d.status;

    if (status !== 'refunded') {
      gmv += amount;
    }

    if (status === 'pending_escrow') {
      escrowVolume += amount;
      pendingEscrowOrdersCount++;
    } else if (status === 'confirmed') {
      confirmedOrdersCount++;
      if (!d.dispatched_at && status !== 'dispatched') {
        pendingDispatchCount++;
      }
    } else if (status === 'dispatched') {
      dispatchedOrdersCount++;
    } else if (status === 'refunded') {
      refundedOrdersCount++;
    }
  }

  // 2. Fetch Listings & Active Buckets
  const bucketMomentum: BucketMomentumItem[] = [];
  let totalFillPercent = 0;

  let listingsList: any[] = [];
  if (typeof (db as any).getAllDocsInCollection === 'function') {
    listingsList = (db as any).getAllDocsInCollection(`daily_campaigns/${date}/listings`);
  } else {
    const snap = await campaignRef.collection('listings').get();
    listingsList = snap.docs.map((d) => ({ path: d.ref.path, id: d.id, data: d.data() }));
  }

  for (const l of listingsList) {
    const lData = l.data;
    const listingId = l.id;
    const activeBucketNum = Number(lData.active_bucket_number || 1);

    // Fetch active bucket
    let bucketData: any;
    if (typeof (db as any).getDoc === 'function') {
      bucketData = (db as any).getDoc(`daily_campaigns/${date}/listings/${listingId}/buckets/${activeBucketNum}`);
    } else {
      const bSnap = await campaignRef
        .collection('listings')
        .doc(listingId)
        .collection('buckets')
        .doc(String(activeBucketNum))
        .get();
      bucketData = bSnap.exists ? bSnap.data() : undefined;
    }

    const moq = Number(bucketData?.moq_threshold || lData.moq_threshold || 100);
    const currentQty = Number(bucketData?.current_quantity || 0);
    const remaining = Number(bucketData?.remaining_capacity ?? Math.max(0, moq - currentQty));
    const fillPercent = moq > 0 ? Math.min(100, Math.round((currentQty / moq) * 100 * 10) / 10) : 0;

    totalFillPercent += fillPercent;

    bucketMomentum.push({
      listingId,
      productId: lData.product_id || '',
      productTitle: lData.product_title || 'Unknown Product',
      category: lData.category || 'General',
      unit: lData.unit || 'unit',
      marketPrice: Number(lData.market_price || 0),
      unitPrice: Number(lData.unit_price || 0),
      discountPercent: Number(lData.discount_percent || 0),
      activeBucketNumber: activeBucketNum,
      moqThreshold: moq,
      currentQuantity: currentQty,
      remainingCapacity: remaining,
      fillPercentage: fillPercent,
      orderCount: Number(bucketData?.order_count || 0),
      status: bucketData?.status || lData.status || 'open',
    });
  }

  const averageFillPercentage =
    bucketMomentum.length > 0 ? Math.round((totalFillPercent / bucketMomentum.length) * 10) / 10 : 0;

  // 3. Fetch Pending Withdrawal Requests
  let pendingWithdrawals: any[] = [];
  if (typeof (db as any).getAllDocsInCollection === 'function') {
    pendingWithdrawals = (db as any)
      .getAllDocsInCollection('withdrawal_requests')
      .filter((d: any) => d.data.status === 'pending');
  } else {
    const wSnap = await db.collection('withdrawal_requests').where('status', '==', 'pending').get();
    pendingWithdrawals = wSnap.docs.map((d) => ({ path: d.ref.path, id: d.id, data: d.data() }));
  }

  let pendingWithdrawalsAmount = 0;
  for (const w of pendingWithdrawals) {
    pendingWithdrawalsAmount += Number(w.data.amount || 0);
  }

  return {
    date,
    campaignStatus,
    gmv: +gmv.toFixed(2),
    escrowVolume: +escrowVolume.toFixed(2),
    totalOrdersCount: ordersList.length,
    pendingEscrowOrdersCount,
    confirmedOrdersCount,
    dispatchedOrdersCount,
    refundedOrdersCount,
    pendingDispatchCount,
    listingsCount: bucketMomentum.length,
    averageFillPercentage,
    bucketMomentum,
    pendingWithdrawalsCount: pendingWithdrawals.length,
    pendingWithdrawalsAmount: +pendingWithdrawalsAmount.toFixed(2),
  };
}

/**
 * Customer helper logic for submitting wallet withdrawal request
 */
export async function executeSubmitWithdrawalRequest(
  userId: string,
  payload: SubmitWithdrawalPayload,
  firestoreInstance?: admin.firestore.Firestore
): Promise<{
  success: boolean;
  requestId: string;
  amount: number;
  status: 'pending';
}> {
  const db = firestoreInstance || admin.firestore();

  if (!userId) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }

  const amount = Number(payload.amount);
  if (isNaN(amount) || amount <= 0) {
    throw new HttpsError('invalid-argument', 'Withdrawal amount must be greater than zero.');
  }

  if (!payload.accountNumber || !payload.accountNumber.trim()) {
    throw new HttpsError('invalid-argument', 'Account number is required.');
  }

  const userRef = db.collection('users').doc(userId);
  const userSnap = await userRef.get();
  if (!userSnap.exists) {
    throw new HttpsError('not-found', 'User profile not found.');
  }

  const available = Number(userSnap.data()?.available_balance || 0);
  if (available < amount) {
    throw new HttpsError(
      'failed-precondition',
      `Insufficient available balance. Available: ৳${available}, Requested: ৳${amount}.`
    );
  }

  const requestId = `wreq_${Date.now()}_${Math.floor(Math.random() * 10000)}`;
  const requestRef = db.collection('withdrawal_requests').doc(requestId);

  await requestRef.set({
    id: requestId,
    user_id: userId,
    amount,
    payout_method: payload.payoutMethod || 'bkash',
    account_number: payload.accountNumber.trim(),
    bank_name: payload.bankName?.trim() || null,
    account_holder_name: payload.accountHolderName?.trim() || null,
    status: 'pending',
    created_at: admin.firestore.FieldValue.serverTimestamp(),
    updated_at: admin.firestore.FieldValue.serverTimestamp(),
  });

  return {
    success: true,
    requestId,
    amount,
    status: 'pending',
  };
}

// ---------------------------------------------------------------------------
// Cloud Functions Exports
// ---------------------------------------------------------------------------

/**
 * Callable Cloud Function: createOrUpdateDailyCampaign
 * Allows administrators to schedule daily campaigns and wholesale listings with Bucket #1.
 */
export const createOrUpdateDailyCampaign = onCall<CreateOrUpdateCampaignPayload>(
  {
    region: 'asia-south1',
    enforceAppCheck: false,
  },
  async (request) => {
    const db = admin.firestore();
    await verifyAdminCaller(request.auth, db);
    return await executeCreateOrUpdateDailyCampaign(request.data || {}, db);
  }
);

/**
 * Callable Cloud Function: reviewWithdrawalRequest
 * Allows administrators to approve or reject customer wallet withdrawal requests.
 */
export const reviewWithdrawalRequest = onCall<ReviewWithdrawalPayload>(
  {
    region: 'asia-south1',
    enforceAppCheck: false,
  },
  async (request) => {
    const db = admin.firestore();
    const adminUid = await verifyAdminCaller(request.auth, db);
    return await executeReviewWithdrawalRequest(request.data || ({} as any), adminUid, db);
  }
);

/**
 * Callable Cloud Function: getAdminOperationalMetrics
 * Returns real-time campaign momentum, GMV, escrow volume, and pending dispatches.
 */
export const getAdminOperationalMetrics = onCall<{ date?: string }>(
  {
    region: 'asia-south1',
    enforceAppCheck: false,
  },
  async (request) => {
    const db = admin.firestore();
    await verifyAdminCaller(request.auth, db);
    return await executeGetAdminOperationalMetrics(request.data?.date, db);
  }
);

/**
 * Callable Cloud Function: submitWithdrawalRequest
 * Customer endpoint to request funds withdrawal to bKash/Bank.
 */
export const submitWithdrawalRequest = onCall<SubmitWithdrawalPayload>(
  {
    region: 'asia-south1',
    enforceAppCheck: false,
  },
  async (request) => {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError('unauthenticated', 'User must be authenticated.');
    }
    const db = admin.firestore();
    return await executeSubmitWithdrawalRequest(request.auth.uid, request.data || ({} as any), db);
  }
);
