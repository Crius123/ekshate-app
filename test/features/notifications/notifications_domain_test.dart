import 'package:flutter_test/flutter_test.dart';
import 'package:ekshate_app/features/notifications/domain/notification_item.dart';
import 'package:ekshate_app/features/notifications/domain/notification_preferences.dart';

void main() {
  group('NotificationItem & NotificationCategory Domain Tests', () {
    test('NotificationCategory correctly parses from string representations', () {
      expect(NotificationCategory.fromString('orders'), NotificationCategory.orders);
      expect(NotificationCategory.fromString('order'), NotificationCategory.orders);
      expect(NotificationCategory.fromString('wallet'), NotificationCategory.wallet);
      expect(NotificationCategory.fromString('community'), NotificationCategory.communityDrops);
      expect(NotificationCategory.fromString('community_drops'), NotificationCategory.communityDrops);
      expect(NotificationCategory.fromString('unknown'), NotificationCategory.orders);
    });

    test('NotificationItem serializes to and deserializes from Firestore map format', () {
      final now = DateTime(2026, 10, 23, 10, 0, 0);
      final item = NotificationItem(
        id: 'notif_001',
        userId: 'user_123',
        title: '🔥 Almost Unlocked!',
        body: 'Only 10 kg left to unlock Nagpur Oranges!',
        category: NotificationCategory.communityDrops,
        isRead: false,
        deepLink: '/',
        metadata: {'listing_id': 'oranges_01', 'remaining': 10},
        createdAt: now,
      );

      final map = item.toFirestoreMap();
      expect(map['id'], 'notif_001');
      expect(map['user_id'], 'user_123');
      expect(map['title'], '🔥 Almost Unlocked!');
      expect(map['category'], 'community');
      expect(map['is_read'], false);
      expect(map['deep_link'], '/');
      expect(map['metadata']['remaining'], 10);

      final restored = NotificationItem.fromFirestore(map, 'notif_001');
      expect(restored.id, 'notif_001');
      expect(restored.userId, 'user_123');
      expect(restored.category, NotificationCategory.communityDrops);
      expect(restored.isRead, false);
      expect(restored.deepLink, '/');
      expect(restored.metadata['remaining'], 10);
    });

    test('NotificationItem copyWith modifies fields immutably', () {
      final item = NotificationItem(
        id: 'notif_002',
        userId: 'user_123',
        title: 'Order Confirmed',
        body: 'Your batch is confirmed.',
        category: NotificationCategory.orders,
        isRead: false,
        createdAt: DateTime.now(),
      );

      final readItem = item.copyWith(isRead: true);
      expect(readItem.isRead, true);
      expect(item.isRead, false); // Original preserved
    });
  });

  group('NotificationPreferences Domain Tests', () {
    test('NotificationPreferences defaults all categories to true (opted-in)', () {
      const prefs = NotificationPreferences();
      expect(prefs.orderUpdates, true);
      expect(prefs.walletAlerts, true);
      expect(prefs.communityDrops, true);
    });

    test('NotificationPreferences serializes and deserializes accurately', () {
      const prefs = NotificationPreferences(
        orderUpdates: true,
        walletAlerts: false,
        communityDrops: true,
      );

      final map = prefs.toMap();
      expect(map['orderUpdates'], true);
      expect(map['walletAlerts'], false);
      expect(map['communityDrops'], true);

      final parsed = NotificationPreferences.fromMap(map);
      expect(parsed.orderUpdates, true);
      expect(parsed.walletAlerts, false);
      expect(parsed.communityDrops, true);
    });
  });
}
