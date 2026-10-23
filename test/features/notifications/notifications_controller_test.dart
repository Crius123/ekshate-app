import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ekshate_app/features/notifications/domain/notification_item.dart';
import 'package:ekshate_app/features/notifications/data/notifications_repository.dart';
import 'package:ekshate_app/features/notifications/presentation/notifications_controller.dart';
import 'package:ekshate_app/features/auth/domain/user_profile.dart';
import 'package:ekshate_app/features/auth/data/auth_repository.dart';

void main() {
  late MockAuthRepository mockAuthRepo;
  late MockNotificationsRepository mockNotifsRepo;

  setUp(() {
    mockAuthRepo = MockAuthRepository(
      initialUser: const UserProfile(
        uid: 'user_dev_01',
        phoneNumber: '+8801711000001',
        displayName: 'Test Buyer',
      ),
      simulatedDelay: Duration.zero,
    );

    mockNotifsRepo = MockNotificationsRepository(
      authRepository: mockAuthRepo,
      simulatedDelay: Duration.zero,
    );
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuthRepo),
        notificationsRepositoryProvider.overrideWithValue(mockNotifsRepo),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('NotificationsController & Providers Unit Tests', () {
    test('notificationsStreamProvider emits seeded notification records', () async {
      final container = createContainer();
      final stream = container.read(notificationsStreamProvider.future);
      final items = await stream;

      expect(items.isNotEmpty, true);
      expect(items.length, 4);
    });

    test('unreadNotificationCountProvider counts unread items accurately', () async {
      final container = createContainer();
      await container.read(notificationsStreamProvider.future);

      final unreadCount = container.read(unreadNotificationCountProvider);
      // In seed data: notif_seed_01 (unread) and notif_seed_02 (unread) => 2
      expect(unreadCount, 2);
    });

    test('filteredNotificationsProvider respects tab filter selection', () async {
      final container = createContainer();
      await container.read(notificationsStreamProvider.future);

      // 1. All tab
      container.read(notificationFilterProvider.notifier).state = NotificationCategory.all;
      expect(container.read(filteredNotificationsProvider).length, 4);

      // 2. Orders tab (seed has 2 order items: target met and courier dispatched)
      container.read(notificationFilterProvider.notifier).state = NotificationCategory.orders;
      final orderItems = container.read(filteredNotificationsProvider);
      expect(orderItems.length, 2);
      expect(orderItems.every((i) => i.category == NotificationCategory.orders), true);

      // 3. Wallet tab (seed has 1 refund item)
      container.read(notificationFilterProvider.notifier).state = NotificationCategory.wallet;
      final walletItems = container.read(filteredNotificationsProvider);
      expect(walletItems.length, 1);
      expect(walletItems.first.category, NotificationCategory.wallet);

      // 4. Community Drops tab (seed has 1 urgency drop)
      container.read(notificationFilterProvider.notifier).state = NotificationCategory.communityDrops;
      final dropItems = container.read(filteredNotificationsProvider);
      expect(dropItems.length, 1);
      expect(dropItems.first.title, '🔥 Almost Unlocked!');
    });

    test('markAsRead marks item as read and decrements unread counter', () async {
      final container = createContainer();
      await container.read(notificationsStreamProvider.future);
      expect(container.read(unreadNotificationCountProvider), 2);

      await container.read(notificationsControllerProvider.notifier).markAsRead('notif_seed_01');
      await Future.delayed(const Duration(milliseconds: 10));

      final items = await container.read(notificationsStreamProvider.future);
      final marked = items.firstWhere((i) => i.id == 'notif_seed_01');
      expect(marked.isRead, true);
      expect(container.read(unreadNotificationCountProvider), 1);
    });

    test('markAllAsRead marks all notifications as read', () async {
      final container = createContainer();
      await container.read(notificationsStreamProvider.future);
      expect(container.read(unreadNotificationCountProvider), 2);

      await container.read(notificationsControllerProvider.notifier).markAllAsRead();
      await Future.delayed(const Duration(milliseconds: 10));

      final items = await container.read(notificationsStreamProvider.future);
      expect(items.every((i) => i.isRead), true);
      expect(container.read(unreadNotificationCountProvider), 0);
    });

    test('NotificationPreferencesNotifier toggles user push preferences', () async {
      final container = createContainer();
      final notifier = container.read(notificationPreferencesProvider.notifier);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(container.read(notificationPreferencesProvider).value?.walletAlerts, true);

      await notifier.toggleWalletAlerts(false);
      expect(container.read(notificationPreferencesProvider).value?.walletAlerts, false);

      await notifier.toggleOrderUpdates(false);
      expect(container.read(notificationPreferencesProvider).value?.orderUpdates, false);

      await notifier.toggleCommunityDrops(false);
      expect(container.read(notificationPreferencesProvider).value?.communityDrops, false);
    });
  });
}
