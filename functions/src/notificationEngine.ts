import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onDocumentUpdated } from 'firebase-functions/v2/firestore';

export type NotificationCategory = 'orders' | 'wallet' | 'community';

export interface NotificationPreferences {
  orderUpdates: boolean;
  walletAlerts: boolean;
  communityDrops: boolean;
}

export const DEFAULT_NOTIFICATION_PREFERENCES: NotificationPreferences = {
  orderUpdates: true,
  walletAlerts: true,
  communityDrops: true,
};

export interface FcmNotificationPayload {
  title: string;
  body: string;
  category: NotificationCategory;
  deepLink?: string;
  metadata?: Record<string, any>;
}

export interface InAppNotificationRecord {
  id?: string;
  user_id: string; // Firebase Auth UID or 'broadcast'
  title: string;
  body: string;
  category: NotificationCategory;
  is_read: boolean;
  deep_link?: string;
  metadata?: Record<string, any>;
  created_at: admin.firestore.FieldValue | admin.firestore.Timestamp | Date;
}

export interface SendResult {
  success: boolean;
  messageId?: string;
  inAppNotificationId?: string;
  recipientCount?: number;
  failureCount?: number;
  error?: string;
  skippedReason?: string;
}

export interface MessagingAdapter {
  send(message: any): Promise<string>;
  sendEachForMulticast(message: any): Promise<{
    responses: Array<{ success: boolean; error?: any; messageId?: string }>;
    successCount: number;
    failureCount: number;
  }>;
}

/**
 * Default FCM messaging adapter wrapping admin.messaging().
 */
export class AdminMessagingAdapter implements MessagingAdapter {
  async send(message: any): Promise<string> {
    return admin.messaging().send(message);
  }

  async sendEachForMulticast(message: any): Promise<{
    responses: Array<{ success: boolean; error?: any; messageId?: string }>;
    successCount: number;
    failureCount: number;
  }> {
    return admin.messaging().sendEachForMulticast(message);
  }
}

/**
 * Checks if a user has opted in to notifications for a specific category.
 */
export function isCategoryEnabledForUser(
  category: NotificationCategory,
  preferences?: Partial<NotificationPreferences>
): boolean {
  const prefs = { ...DEFAULT_NOTIFICATION_PREFERENCES, ...(preferences || {}) };
  switch (category) {
    case 'orders':
      return prefs.orderUpdates;
    case 'wallet':
      return prefs.walletAlerts;
    case 'community':
      return prefs.communityDrops;
    default:
      return true;
  }
}

/**
 * Broadcasts a push notification to an FCM topic and records an in-app notification.
 * Supported topics include listing topics (topic: listing_{listingId}) and campaign topics (topic: campaign_{date}).
 */
export async function sendTopicNotification(
  topic: string,
  payload: FcmNotificationPayload,
  firestoreInstance?: admin.firestore.Firestore,
  messagingAdapter?: MessagingAdapter
): Promise<SendResult> {
  const db = firestoreInstance || admin.firestore();
  const messaging = messagingAdapter || new AdminMessagingAdapter();

  // Sanitize topic name: FCM topics must match [a-zA-Z0-9-_.~%]+
  const cleanTopic = topic.replace(/[^a-zA-Z0-9-_.~%]/g, '_');

  // Convert metadata values to strings for FCM data payload
  const stringifiedData: Record<string, string> = {
    category: payload.category,
    deep_link: payload.deepLink || '/',
  };
  if (payload.metadata) {
    for (const [key, val] of Object.entries(payload.metadata)) {
      stringifiedData[key] = typeof val === 'object' ? JSON.stringify(val) : String(val);
    }
  }

  const fcmMessage = {
    topic: cleanTopic,
    notification: {
      title: payload.title,
      body: payload.body,
    },
    data: stringifiedData,
  };

  let messageId: string | undefined;
  try {
    messageId = await messaging.send(fcmMessage);
  } catch (err: any) {
    console.error(`Error sending FCM topic message to ${cleanTopic}:`, err);
  }

  // Record broadcast in notifications collection
  let inAppNotificationId: string | undefined;
  try {
    const notifRef = db.collection('notifications').doc();
    inAppNotificationId = notifRef.id;
    await notifRef.set({
      id: notifRef.id,
      user_id: `topic:${cleanTopic}`,
      title: payload.title,
      body: payload.body,
      category: payload.category,
      is_read: false,
      deep_link: payload.deepLink || '/',
      metadata: payload.metadata || {},
      created_at: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (dbErr: any) {
    console.error(`Error saving topic notification to Firestore:`, dbErr);
  }

  return {
    success: true,
    messageId,
    inAppNotificationId,
    recipientCount: 1,
  };
}

/**
 * Sends a direct push notification to a user using their registered FCM device tokens in fcm_tokens/{userId}.
 * Validates user preferences to respect user quiet preferences, and writes an in-app notification.
 */
export async function sendDirectUserNotification(
  userId: string,
  payload: FcmNotificationPayload,
  firestoreInstance?: admin.firestore.Firestore,
  messagingAdapter?: MessagingAdapter
): Promise<SendResult> {
  const db = firestoreInstance || admin.firestore();
  const messaging = messagingAdapter || new AdminMessagingAdapter();

  // 1. Fetch user FCM tokens and preferences
  let tokens: string[] = [];
  let preferences: NotificationPreferences = { ...DEFAULT_NOTIFICATION_PREFERENCES };

  const tokenDocRef = db.collection('fcm_tokens').doc(userId);
  const tokenDoc = await tokenDocRef.get();

  if (tokenDoc.exists) {
    const tokenData = tokenDoc.data() || {};
    if (Array.isArray(tokenData.tokens)) {
      tokens = tokenData.tokens.filter((t: any) => typeof t === 'string' && t.trim().length > 0);
    }
    if (tokenData.preferences) {
      preferences = { ...DEFAULT_NOTIFICATION_PREFERENCES, ...tokenData.preferences };
    }
  }

  // 2. Check if user enabled notifications for this category
  const isEnabled = isCategoryEnabledForUser(payload.category, preferences);

  // 3. Persist in-app notification for the user
  const notifRef = db.collection('notifications').doc();
  const inAppNotificationId = notifRef.id;
  await notifRef.set({
    id: notifRef.id,
    user_id: userId,
    title: payload.title,
    body: payload.body,
    category: payload.category,
    is_read: false,
    deep_link: payload.deepLink || (payload.category === 'wallet' ? '/wallet' : '/orders'),
    metadata: payload.metadata || {},
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  });

  // If user disabled push notifications for this category, skip FCM broadcast
  if (!isEnabled) {
    return {
      success: true,
      inAppNotificationId,
      skippedReason: `User opted out of ${payload.category} notifications`,
      recipientCount: 0,
    };
  }

  if (tokens.length === 0) {
    return {
      success: true,
      inAppNotificationId,
      skippedReason: 'No registered device tokens found for user',
      recipientCount: 0,
    };
  }

  // 4. Construct and send FCM Multicast message
  const stringifiedData: Record<string, string> = {
    category: payload.category,
    deep_link: payload.deepLink || (payload.category === 'wallet' ? '/wallet' : '/orders'),
  };
  if (payload.metadata) {
    for (const [key, val] of Object.entries(payload.metadata)) {
      stringifiedData[key] = typeof val === 'object' ? JSON.stringify(val) : String(val);
    }
  }

  const multicastMessage = {
    tokens,
    notification: {
      title: payload.title,
      body: payload.body,
    },
    data: stringifiedData,
  };

  try {
    const response = await messaging.sendEachForMulticast(multicastMessage);
    
    // Prune stale / invalid tokens if reported by FCM
    const tokensToRemove: string[] = [];
    response.responses.forEach((resp, idx) => {
      if (!resp.success && resp.error) {
        const errCode = resp.error.code || '';
        if (
          errCode === 'messaging/invalid-registration-token' ||
          errCode === 'messaging/registration-token-not-registered'
        ) {
          tokensToRemove.push(tokens[idx]);
        }
      }
    });

    if (tokensToRemove.length > 0) {
      await tokenDocRef.update({
        tokens: admin.firestore.FieldValue.arrayRemove(...tokensToRemove),
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    return {
      success: response.successCount > 0,
      inAppNotificationId,
      recipientCount: response.successCount,
      failureCount: response.failureCount,
    };
  } catch (fcmErr: any) {
    console.error(`FCM multicast dispatch failed for user ${userId}:`, fcmErr);
    return {
      success: false,
      inAppNotificationId,
      error: fcmErr.message,
    };
  }
}

/**
 * Urgency Milestone Alert: Evaluates bucket fill and broadcasts "Almost Unlocked!" alert
 * when an open bucket achieves >= 80% of its MOQ target.
 * Uses atomic flag urgency_alert_sent to guarantee strict idempotency and prevent spamming.
 */
export async function checkAndTriggerUrgencyMilestone(
  date: string,
  listingId: string,
  bucketNumber: number,
  firestoreInstance?: admin.firestore.Firestore,
  messagingAdapter?: MessagingAdapter
): Promise<{ triggered: boolean; remainingCapacity?: number; topic?: string }> {
  const db = firestoreInstance || admin.firestore();
  const bucketRef = db
    .collection('daily_campaigns')
    .doc(date)
    .collection('listings')
    .doc(listingId)
    .collection('buckets')
    .doc(String(bucketNumber));

  const listingRef = db.collection('daily_campaigns').doc(date).collection('listings').doc(listingId);

  const bucketSnap = await bucketRef.get();
  if (!bucketSnap.exists) {
    return { triggered: false };
  }

  const bucketData = bucketSnap.data()!;
  
  // Idempotency: only open buckets that have not sent urgency alert
  if (bucketData.urgency_alert_sent || bucketData.status !== 'open') {
    return { triggered: false };
  }

  const moqThreshold = Number(bucketData.moq_threshold) || 1;
  const currentQuantity = Number(bucketData.current_quantity) || 0;
  const fillRatio = currentQuantity / moqThreshold;

  // Threshold: >= 80% and < 100%
  if (fillRatio >= 0.8 && fillRatio < 1.0) {
    const listingSnap = await listingRef.get();
    const listingData = listingSnap.exists ? listingSnap.data()! : {};
    const productTitle = listingData.product_title || 'Produce';
    const unit = listingData.unit || 'kg';
    const unitPrice = Number(listingData.unit_price) || 0;

    const remaining = Math.max(0, moqThreshold - currentQuantity);
    const remainingFormatted = Number.isInteger(remaining) ? remaining.toString() : remaining.toFixed(1);

    // Atomically set urgency_alert_sent = true
    await bucketRef.update({
      urgency_alert_sent: true,
      urgency_alert_sent_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    const topic = `listing_${listingId}`;
    const payload: FcmNotificationPayload = {
      title: '🔥 Almost Unlocked!',
      body: `Only ${remainingFormatted} ${unit} left to unlock ${productTitle} at ৳${unitPrice}/${unit}!`,
      category: 'community',
      deepLink: '/',
      metadata: {
        listing_id: listingId,
        bucket_number: bucketNumber,
        date,
        remaining_capacity: remaining,
        unit_price: unitPrice,
      },
    };

    await sendTopicNotification(topic, payload, db, messagingAdapter);

    return {
      triggered: true,
      remainingCapacity: remaining,
      topic,
    };
  }

  return { triggered: false };
}

/**
 * Bucket Target Met Notification: Notifies all participant buyers when a bucket achieves MOQ.
 * Called when a bucket achieves MOQ in placeOrder / onBucketTargetMet.
 */
export async function notifyBucketTargetMet(
  date: string,
  listingId: string,
  bucketNumber: number,
  firestoreInstance?: admin.firestore.Firestore,
  messagingAdapter?: MessagingAdapter
): Promise<{ notifiedBuyersCount: number }> {
  const db = firestoreInstance || admin.firestore();

  // 1. Fetch listing details for context if available
  let productTitle = 'Produce';
  let unit = 'kg';
  try {
    const listingRef = db
      .collection('daily_campaigns')
      .doc(date)
      .collection('listings')
      .doc(listingId);
    if (listingRef && typeof listingRef.get === 'function') {
      const listingSnap = await listingRef.get();
      if (listingSnap && listingSnap.exists && typeof listingSnap.data === 'function') {
        const listingData = listingSnap.data() || {};
        productTitle = listingData.product_title || productTitle;
        unit = listingData.unit || unit;
      }
    }
  } catch (_) {
    // Non-fatal if listing document read fails
  }

  // 2. Query all participant orders in this bucket
  const ordersSnap = await db
    .collection('orders')
    .where('date', '==', date)
    .where('listing_id', '==', listingId)
    .where('bucket_number', '==', bucketNumber)
    .get();

  let count = 0;
  for (const orderDoc of ordersSnap.docs) {
    const order = orderDoc.data();
    
    // Idempotency: skip if already notified
    if (order.target_met_notified) {
      continue;
    }

    const userId = order.user_id;
    const qty = order.quantity || 1;

    const payload: FcmNotificationPayload = {
      title: '🎉 MOQ Target Met!',
      body: `Bucket #${bucketNumber} unlocked! Your order of ${qty} ${unit} for ${productTitle} is confirmed for fulfillment.`,
      category: 'orders',
      deepLink: '/orders',
      metadata: {
        order_id: orderDoc.id,
        listing_id: listingId,
        bucket_number: bucketNumber,
        date,
      },
    };

    await sendDirectUserNotification(userId, payload, db, messagingAdapter);

    // Mark order as target_met_notified
    await orderDoc.ref.update({
      target_met_notified: true,
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    });

    count++;
  }

  return { notifiedBuyersCount: count };
}

/**
 * Settlement Confirmed Notification: Notifies buyer at midnight settlement with confirmed order confirmation.
 */
export async function notifySettlementConfirmed(
  order: any,
  firestoreInstance?: admin.firestore.Firestore,
  messagingAdapter?: MessagingAdapter
): Promise<SendResult> {
  const db = firestoreInstance || admin.firestore();

  const userId = order.user_id;
  const orderId = order.order_id || order.id;
  const productTitle = order.product_title || 'Produce';
  const qty = order.quantity || 1;
  const unit = order.unit || 'kg';

  const payload: FcmNotificationPayload = {
    title: '✅ Order Confirmed!',
    body: `Your order for ${qty} ${unit} ${productTitle} has been locked in for morning depot procurement.`,
    category: 'orders',
    deepLink: '/orders',
    metadata: {
      order_id: orderId,
      listing_id: order.listing_id,
      bucket_number: order.bucket_number,
      date: order.date,
    },
  };

  return sendDirectUserNotification(userId, payload, db, messagingAdapter);
}

/**
 * Settlement Escrow Refund Notification: Notifies buyer at midnight settlement with instant 100% wallet refund receipt.
 */
export async function notifySettlementRefund(
  order: any,
  refundAmount: number,
  firestoreInstance?: admin.firestore.Firestore,
  messagingAdapter?: MessagingAdapter
): Promise<SendResult> {
  const db = firestoreInstance || admin.firestore();

  const userId = order.user_id;
  const orderId = order.order_id || order.id;
  const productTitle = order.product_title || 'produce';

  const payload: FcmNotificationPayload = {
    title: '💸 100% Escrow Refunded!',
    body: `৳${refundAmount} has been refunded to your available wallet balance as the MOQ target for ${productTitle} was not met.`,
    category: 'wallet',
    deepLink: '/wallet',
    metadata: {
      order_id: orderId,
      listing_id: order.listing_id,
      bucket_number: order.bucket_number,
      date: order.date,
      refund_amount: refundAmount,
    },
  };

  return sendDirectUserNotification(userId, payload, db, messagingAdapter);
}

/**
 * Courier Dispatched Notification: Notifies buyer upon last-mile dispatch with courier partner pill,
 * tracking code, and delivery estimates.
 */
export async function notifyCourierDispatched(
  order: any,
  dispatchInfo: {
    courierPartner: string;
    trackingCode: string;
    trackingUrl: string;
    deliveryEstimate?: string;
  },
  firestoreInstance?: admin.firestore.Firestore,
  messagingAdapter?: MessagingAdapter
): Promise<SendResult> {
  const db = firestoreInstance || admin.firestore();

  const userId = order.user_id;
  const orderId = order.order_id || order.id;
  const productTitle = order.product_title || 'Produce';
  const partnerName = dispatchInfo.courierPartner.toUpperCase();
  const trackingCode = dispatchInfo.trackingCode;
  const deliveryEstimate = dispatchInfo.deliveryEstimate || 'Today afternoon';

  const payload: FcmNotificationPayload = {
    title: `🚚 Dispatched via ${partnerName}!`,
    body: `Your order for ${productTitle} is on the way! Tracking: ${trackingCode}. Expected delivery: ${deliveryEstimate}.`,
    category: 'orders',
    deepLink: '/orders',
    metadata: {
      order_id: orderId,
      courier_partner: dispatchInfo.courierPartner,
      tracking_code: trackingCode,
      tracking_url: dispatchInfo.trackingUrl,
      delivery_estimate: deliveryEstimate,
    },
  };

  return sendDirectUserNotification(userId, payload, db, messagingAdapter);
}

// =========================================================================
// Cloud Functions: Triggers & Callables
// =========================================================================

/**
 * onBucketUpdated: Firestore trigger monitoring bucket volume progression.
 * Automatically broadcasts "Almost Unlocked!" urgency alerts when fill reaches >= 80%.
 */
export const onBucketUpdated = onDocumentUpdated(
  {
    document: 'daily_campaigns/{date}/listings/{listingId}/buckets/{bucketNumber}',
    region: 'asia-south1',
  },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    // Check if quantity increased and bucket is still open
    if (after.status === 'open' && after.current_quantity > (before.current_quantity || 0)) {
      const date = event.params.date;
      const listingId = event.params.listingId;
      const bucketNumber = Number(event.params.bucketNumber);

      await checkAndTriggerUrgencyMilestone(date, listingId, bucketNumber);
    }
  }
);

/**
 * registerFcmToken: HTTPS Callable function enabling client devices to register their FCM tokens
 * and initial push preferences.
 */
export const registerFcmToken = onCall<{
  token: string;
  preferences?: Partial<NotificationPreferences>;
}>(
  {
    region: 'asia-south1',
    enforceAppCheck: false,
  },
  async (request) => {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError('unauthenticated', 'User must be authenticated to register an FCM device token.');
    }
    const uid = request.auth.uid;
    const { token, preferences } = request.data || {};

    if (!token || typeof token !== 'string' || token.trim().length === 0) {
      throw new HttpsError('invalid-argument', 'Valid FCM device token string is required.');
    }

    const db = admin.firestore();
    const tokenDocRef = db.collection('fcm_tokens').doc(uid);

    const updatePayload: any = {
      user_id: uid,
      tokens: admin.firestore.FieldValue.arrayUnion(token.trim()),
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (preferences && typeof preferences === 'object') {
      updatePayload.preferences = {
        orderUpdates: preferences.orderUpdates !== false,
        walletAlerts: preferences.walletAlerts !== false,
        communityDrops: preferences.communityDrops !== false,
      };
    }

    await tokenDocRef.set(updatePayload, { merge: true });

    return { success: true, message: 'FCM token registered successfully.' };
  }
);

/**
 * updateNotificationPreferences: HTTPS Callable function enabling user to update their notification categories.
 */
export const updateNotificationPreferences = onCall<{
  preferences: NotificationPreferences;
}>(
  {
    region: 'asia-south1',
    enforceAppCheck: false,
  },
  async (request) => {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError('unauthenticated', 'User must be authenticated.');
    }
    const uid = request.auth.uid;
    const { preferences } = request.data || {};

    if (!preferences || typeof preferences !== 'object') {
      throw new HttpsError('invalid-argument', 'Preferences object is required.');
    }

    const db = admin.firestore();
    await db.collection('fcm_tokens').doc(uid).set(
      {
        preferences: {
          orderUpdates: Boolean(preferences.orderUpdates),
          walletAlerts: Boolean(preferences.walletAlerts),
          communityDrops: Boolean(preferences.communityDrops),
        },
        updated_at: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    return { success: true };
  }
);
