import { describe, it } from 'node:test';
import * as assert from 'node:assert/strict';
import {
  sendTopicNotification,
  sendDirectUserNotification,
  checkAndTriggerUrgencyMilestone,
  notifyBucketTargetMet,
  notifySettlementConfirmed,
  notifySettlementRefund,
  notifyCourierDispatched,
  MessagingAdapter,
  isCategoryEnabledForUser,
} from '../notificationEngine';

/**
 * Mock FCM Messaging Adapter to capture and verify outbound push payloads
 */
class MockMessagingService implements MessagingAdapter {
  public sentTopicMessages: Array<any> = [];
  public sentMulticastMessages: Array<any> = [];
  public simulatedMulticastResponses: Array<{ success: boolean; error?: any; messageId?: string }> = [];

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

    if (this.simulatedMulticastResponses.length > 0) {
      const responses = this.simulatedMulticastResponses;
      const successCount = responses.filter((r) => r.success).length;
      const failureCount = responses.filter((r) => !r.success).length;
      return { responses, successCount, failureCount };
    }

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
 * In-memory Mock Firestore
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
        return this.createFilteredQuery(path, [{ field, op, value }]);
      },
    };
  }

  private createFilteredQuery(collectionPath: string, filters: Array<{ field: string; op: string; value: any }>): any {
    return {
      where: (field: string, op: string, value: any) => {
        return this.createFilteredQuery(collectionPath, [...filters, { field, op, value }]);
      },
      get: async () => {
        const allDocs = this.getAllDocsInCollection(collectionPath);
        const filtered = allDocs.filter((doc) => {
          return filters.every((filter) => {
            const val = doc.data[filter.field];
            if (filter.op === '==') return val === filter.value;
            if (filter.op === 'in') return Array.isArray(filter.value) && filter.value.includes(val);
            if (filter.op === '>=') return val >= filter.value;
            if (filter.op === '<=') return val <= filter.value;
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
  }

  private createDocRef(docPath: string, id: string): any {
    return {
      id,
      path: docPath,
      get: async () => {
        const data = this.docs.get(docPath);
        return {
          id,
          exists: data !== undefined,
          data: () => (data ? { ...data } : undefined),
        };
      },
      set: async (data: any, options?: { merge?: boolean }) => {
        if (options?.merge && this.docs.has(docPath)) {
          const current = this.docs.get(docPath);
          this.docs.set(docPath, { ...current, ...data });
        } else {
          this.docs.set(docPath, { ...data });
        }
      },
      update: async (data: any) => {
        const current = this.docs.get(docPath) || {};
        this.docs.set(docPath, { ...current, ...data });
      },
      collection: (subCol: string) => {
        return this.createCollectionRef(`${docPath}/${subCol}`);
      },
    };
  }
}

describe('FCM Push Notification Matrix & Urgency Alerts Tests', () => {
  it('sendTopicNotification: broadcasts to FCM topic and records in-app notification', async () => {
    const mockDb = new HierarchicalMockFirestore();
    const mockMessaging = new MockMessagingService();

    const result = await sendTopicNotification(
      'listing_oranges_01',
      {
        title: '🔥 Almost Unlocked!',
        body: 'Only 15 kg left to unlock Nagpur Oranges!',
        category: 'community',
        deepLink: '/',
        metadata: { listing_id: 'oranges_01', remaining: 15 },
      },
      mockDb as any,
      mockMessaging
    );

    assert.equal(result.success, true);
    assert.equal(mockMessaging.sentTopicMessages.length, 1);
    const sent = mockMessaging.sentTopicMessages[0];
    assert.equal(sent.topic, 'listing_oranges_01');
    assert.equal(sent.notification.title, '🔥 Almost Unlocked!');
    assert.equal(sent.data.category, 'community');
    assert.equal(sent.data.deep_link, '/');
    assert.equal(sent.data.remaining, '15');

    // Verify in-app notification written to Firestore
    const notifs = mockDb.getAllDocsInCollection('notifications');
    assert.equal(notifs.length, 1);
    assert.equal(notifs[0].data.user_id, 'topic:listing_oranges_01');
    assert.equal(notifs[0].data.title, '🔥 Almost Unlocked!');
    assert.equal(notifs[0].data.category, 'community');
    assert.equal(notifs[0].data.is_read, false);
  });

  it('sendDirectUserNotification: dispatches to registered device tokens and creates in-app notification', async () => {
    const mockDb = new HierarchicalMockFirestore();
    const mockMessaging = new MockMessagingService();

    // Setup registered tokens for user
    mockDb.setDoc('fcm_tokens/user_101', {
      user_id: 'user_101',
      tokens: ['token_abc_1', 'token_xyz_2'],
      preferences: { orderUpdates: true, walletAlerts: true, communityDrops: true },
    });

    const result = await sendDirectUserNotification(
      'user_101',
      {
        title: '🎉 MOQ Target Met!',
        body: 'Your Nagpur Oranges order is confirmed!',
        category: 'orders',
        deepLink: '/orders',
        metadata: { order_id: 'ord_999' },
      },
      mockDb as any,
      mockMessaging
    );

    assert.equal(result.success, true);
    assert.equal(result.recipientCount, 2);
    assert.equal(mockMessaging.sentMulticastMessages.length, 1);
    const multi = mockMessaging.sentMulticastMessages[0];
    assert.deepEqual(multi.tokens, ['token_abc_1', 'token_xyz_2']);
    assert.equal(multi.notification.title, '🎉 MOQ Target Met!');

    // Verify in-app notification written for user
    const notifs = mockDb.getAllDocsInCollection('notifications');
    assert.equal(notifs.length, 1);
    assert.equal(notifs[0].data.user_id, 'user_101');
    assert.equal(notifs[0].data.category, 'orders');
    assert.equal(notifs[0].data.deep_link, '/orders');
    assert.equal(notifs[0].data.is_read, false);
  });

  it('sendDirectUserNotification: respects user quiet preferences and skips FCM if category disabled', async () => {
    const mockDb = new HierarchicalMockFirestore();
    const mockMessaging = new MockMessagingService();

    // User disabled walletAlerts
    mockDb.setDoc('fcm_tokens/user_quiet', {
      user_id: 'user_quiet',
      tokens: ['token_quiet_1'],
      preferences: { orderUpdates: true, walletAlerts: false, communityDrops: true },
    });

    const result = await sendDirectUserNotification(
      'user_quiet',
      {
        title: '💸 Escrow Refunded',
        body: '৳500 returned to your wallet.',
        category: 'wallet',
        deepLink: '/wallet',
      },
      mockDb as any,
      mockMessaging
    );

    assert.equal(result.success, true);
    assert.equal(result.recipientCount, 0);
    assert.match(result.skippedReason!, /opted out/);
    assert.equal(mockMessaging.sentMulticastMessages.length, 0);

    // In-app notification is still saved
    const notifs = mockDb.getAllDocsInCollection('notifications');
    assert.equal(notifs.length, 1);
    assert.equal(notifs[0].data.user_id, 'user_quiet');
  });

  it('checkAndTriggerUrgencyMilestone: triggers when fill reaches >= 80% and enforces strict idempotency', async () => {
    const mockDb = new HierarchicalMockFirestore();
    const mockMessaging = new MockMessagingService();
    const date = '2026-10-23';
    const listingId = 'oranges_01';
    const bucketNumber = 1;

    mockDb.setDoc(`daily_campaigns/${date}/listings/${listingId}`, {
      product_title: 'Nagpur Oranges',
      unit: 'kg',
      unit_price: 180,
    });

    // Bucket at 85% fill (85 / 100 kg)
    mockDb.setDoc(`daily_campaigns/${date}/listings/${listingId}/buckets/${bucketNumber}`, {
      bucket_number: 1,
      moq_threshold: 100,
      current_quantity: 85,
      status: 'open',
    });

    // 1. First trigger: should fire urgency alert
    const firstRun = await checkAndTriggerUrgencyMilestone(date, listingId, bucketNumber, mockDb as any, mockMessaging);
    assert.equal(firstRun.triggered, true);
    assert.equal(firstRun.remainingCapacity, 15);
    assert.equal(firstRun.topic, 'listing_oranges_01');

    assert.equal(mockMessaging.sentTopicMessages.length, 1);
    assert.equal(mockMessaging.sentTopicMessages[0].notification.title, '🔥 Almost Unlocked!');
    assert.match(mockMessaging.sentTopicMessages[0].notification.body, /Only 15 kg left to unlock Nagpur Oranges at ৳180\/kg!/);

    // Verify bucket was marked urgency_alert_sent = true
    const updatedBucket = mockDb.getDoc(`daily_campaigns/${date}/listings/${listingId}/buckets/${bucketNumber}`);
    assert.equal(updatedBucket.urgency_alert_sent, true);

    // 2. Second trigger on the same bucket: should NOT fire again (idempotency guard)
    const secondRun = await checkAndTriggerUrgencyMilestone(date, listingId, bucketNumber, mockDb as any, mockMessaging);
    assert.equal(secondRun.triggered, false);
    assert.equal(mockMessaging.sentTopicMessages.length, 1); // No additional message sent!
  });

  it('checkAndTriggerUrgencyMilestone: does NOT trigger when fill is under 80%', async () => {
    const mockDb = new HierarchicalMockFirestore();
    const mockMessaging = new MockMessagingService();
    const date = '2026-10-23';
    const listingId = 'oranges_01';
    const bucketNumber = 1;

    // Bucket at 70% fill (70 / 100 kg)
    mockDb.setDoc(`daily_campaigns/${date}/listings/${listingId}/buckets/${bucketNumber}`, {
      bucket_number: 1,
      moq_threshold: 100,
      current_quantity: 70,
      status: 'open',
    });

    const result = await checkAndTriggerUrgencyMilestone(date, listingId, bucketNumber, mockDb as any, mockMessaging);
    assert.equal(result.triggered, false);
    assert.equal(mockMessaging.sentTopicMessages.length, 0);
  });

  it('notifyBucketTargetMet: notifies all participant buyers when MOQ is unlocked', async () => {
    const mockDb = new HierarchicalMockFirestore();
    const mockMessaging = new MockMessagingService();
    const date = '2026-10-23';
    const listingId = 'rice_01';
    const bucketNumber = 1;

    mockDb.setDoc(`daily_campaigns/${date}/listings/${listingId}`, {
      product_title: 'Nazirshail Premium Rice',
      unit: 'kg',
      unit_price: 85,
    });

    // Registered tokens for buyers
    mockDb.setDoc('fcm_tokens/buyer_1', { tokens: ['token_b1'] });
    mockDb.setDoc('fcm_tokens/buyer_2', { tokens: ['token_b2'] });

    // Orders in this bucket
    mockDb.setDoc('orders/ord_1', {
      user_id: 'buyer_1',
      date,
      listing_id: listingId,
      bucket_number: bucketNumber,
      quantity: 25,
      unit: 'kg',
      status: 'pending_bucket',
    });
    mockDb.setDoc('orders/ord_2', {
      user_id: 'buyer_2',
      date,
      listing_id: listingId,
      bucket_number: bucketNumber,
      quantity: 50,
      unit: 'kg',
      status: 'pending_bucket',
    });

    const result = await notifyBucketTargetMet(date, listingId, bucketNumber, mockDb as any, mockMessaging);
    assert.equal(result.notifiedBuyersCount, 2);
    assert.equal(mockMessaging.sentMulticastMessages.length, 2);

    // Verify orders were flagged target_met_notified
    const ord1 = mockDb.getDoc('orders/ord_1');
    const ord2 = mockDb.getDoc('orders/ord_2');
    assert.equal(ord1.target_met_notified, true);
    assert.equal(ord2.target_met_notified, true);

    // Verify in-app notifications created
    const notifs = mockDb.getAllDocsInCollection('notifications');
    assert.equal(notifs.length, 2);
    assert.equal(notifs[0].data.title, '🎉 MOQ Target Met!');
  });

  it('notifySettlementConfirmed & notifySettlementRefund: notifies buyers at midnight settlement', async () => {
    const mockDb = new HierarchicalMockFirestore();
    const mockMessaging = new MockMessagingService();

    mockDb.setDoc('fcm_tokens/buyer_win', { tokens: ['tok_win'] });
    mockDb.setDoc('fcm_tokens/buyer_fail', { tokens: ['tok_fail'] });

    // 1. Confirmed Order
    const confirmedOrder = {
      id: 'ord_win_1',
      user_id: 'buyer_win',
      product_title: 'Alphonso Mango',
      quantity: 10,
      unit: 'kg',
      date: '2026-10-23',
    };
    await notifySettlementConfirmed(confirmedOrder, mockDb as any, mockMessaging);

    // 2. Refunded Order
    const refundedOrder = {
      id: 'ord_fail_1',
      user_id: 'buyer_fail',
      product_title: 'Saffron Box',
      date: '2026-10-23',
    };
    await notifySettlementRefund(refundedOrder, 1500, mockDb as any, mockMessaging);

    assert.equal(mockMessaging.sentMulticastMessages.length, 2);
    assert.equal(mockMessaging.sentMulticastMessages[0].notification.title, '✅ Order Confirmed!');
    assert.equal(mockMessaging.sentMulticastMessages[1].notification.title, '💸 100% Escrow Refunded!');

    const notifs = mockDb.getAllDocsInCollection('notifications');
    assert.equal(notifs.length, 2);
    assert.equal(notifs[1].data.category, 'wallet');
    assert.match(notifs[1].data.body, /1500/);
  });

  it('notifyCourierDispatched: notifies buyers upon last-mile dispatch with tracking info and partner pill', async () => {
    const mockDb = new HierarchicalMockFirestore();
    const mockMessaging = new MockMessagingService();

    mockDb.setDoc('fcm_tokens/buyer_dispatch', { tokens: ['tok_disp'] });

    const dispatchedOrder = {
      id: 'ord_disp_1',
      user_id: 'buyer_dispatch',
      product_title: 'Organic Honey',
      quantity: 2,
      unit: 'jar',
    };

    const dispatchInfo = {
      courierPartner: 'pathao',
      trackingCode: 'PATH-889900',
      trackingUrl: 'https://pathao.com/track/PATH-889900',
      deliveryEstimate: 'Today 3:00 PM',
    };

    const res = await notifyCourierDispatched(dispatchedOrder, dispatchInfo, mockDb as any, mockMessaging);
    assert.equal(res.success, true);
    assert.equal(mockMessaging.sentMulticastMessages.length, 1);

    const sentMsg = mockMessaging.sentMulticastMessages[0];
    assert.equal(sentMsg.notification.title, '🚚 Dispatched via PATHAO!');
    assert.match(sentMsg.notification.body, /PATH-889900/);
    assert.match(sentMsg.notification.body, /Today 3:00 PM/);

    const notifs = mockDb.getAllDocsInCollection('notifications');
    assert.equal(notifs.length, 1);
    assert.equal(notifs[0].data.category, 'orders');
    assert.equal(notifs[0].data.metadata.tracking_code, 'PATH-889900');
    assert.equal(notifs[0].data.metadata.courier_partner, 'pathao');
  });

  it('isCategoryEnabledForUser: accurately evaluates preferences fallback and overrides', () => {
    assert.equal(isCategoryEnabledForUser('orders'), true);
    assert.equal(isCategoryEnabledForUser('wallet'), true);
    assert.equal(isCategoryEnabledForUser('community'), true);

    assert.equal(isCategoryEnabledForUser('orders', { orderUpdates: false }), false);
    assert.equal(isCategoryEnabledForUser('wallet', { walletAlerts: false }), false);
    assert.equal(isCategoryEnabledForUser('community', { communityDrops: false }), false);
  });
});
