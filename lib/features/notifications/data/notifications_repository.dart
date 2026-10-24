import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/notification_item.dart';
import '../domain/notification_preferences.dart';
import '../../auth/data/auth_repository.dart';

abstract class NotificationsRepository {
  Stream<List<NotificationItem>> watchNotifications(String userId);
  Future<List<NotificationItem>> getNotifications(String userId);
  Future<void> markAsRead(String notificationId);
  Future<void> markAllAsRead(String userId);
  Future<void> deleteNotification(String notificationId);
  Future<NotificationPreferences> getPreferences(String userId);
  Future<void> updatePreferences(String userId, NotificationPreferences preferences);
  Future<void> registerFcmToken(String userId, String token);
}

class MockNotificationsRepository implements NotificationsRepository {
  final AuthRepository? authRepository;
  final Duration simulatedDelay;

  final List<NotificationItem> _items = [];
  final Map<String, NotificationPreferences> _userPreferences = {};
  final Map<String, List<String>> _userTokens = {};
  final StreamController<List<NotificationItem>> _controller =
      StreamController<List<NotificationItem>>.broadcast();

  MockNotificationsRepository({
    this.authRepository,
    this.simulatedDelay = Duration.zero,
    List<NotificationItem>? initialItems,
  }) {
    if (initialItems != null) {
      _items.addAll(initialItems);
    } else {
      _seedDefaultNotifications();
    }
  }

  void _seedDefaultNotifications() {
    final now = DateTime.now();
    _items.addAll([
      NotificationItem(
        id: 'notif_seed_01',
        userId: 'user_dev_01',
        title: '🔥 Almost Unlocked!',
        body: 'Only 10 kg left to unlock Nagpur Oranges at ৳180/kg!',
        category: NotificationCategory.communityDrops,
        isRead: false,
        deepLink: '/',
        metadata: {
          'listing_id': 'oranges_01',
          'remaining_capacity': 10,
          'unit_price': 180,
          'progress': 0.85,
        },
        createdAt: now.subtract(const Duration(minutes: 15)),
      ),
      NotificationItem(
        id: 'notif_seed_02',
        userId: 'user_dev_01',
        title: '🎉 MOQ Target Met!',
        body: 'Bucket #1 for Nazirshail Premium Rice reached 100 kg! Your order is confirmed.',
        category: NotificationCategory.orders,
        isRead: false,
        deepLink: '/orders',
        metadata: {
          'order_id': 'ord_seed_101',
          'listing_id': 'rice_01',
          'bucket_number': 1,
        },
        createdAt: now.subtract(const Duration(hours: 1)),
      ),
      NotificationItem(
        id: 'notif_seed_03',
        userId: 'user_dev_01',
        title: '🚚 Dispatched via PATHAO!',
        body: 'Your order for Organic Honey is on the way! Tracking: PATH-889123. Estimated delivery: Today afternoon.',
        category: NotificationCategory.orders,
        isRead: true,
        deepLink: '/orders',
        metadata: {
          'order_id': 'ord_seed_102',
          'courier_partner': 'pathao',
          'tracking_code': 'PATH-889123',
          'delivery_estimate': 'Today afternoon',
        },
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
      NotificationItem(
        id: 'notif_seed_04',
        userId: 'user_dev_01',
        title: '💸 100% Refund Returned!',
        body: '৳1,800 returned to your available balance as the MOQ target was not met.',
        category: NotificationCategory.wallet,
        isRead: true,
        deepLink: '/wallet',
        metadata: {
          'order_id': 'ord_seed_103',
          'refund_amount': 1800,
        },
        createdAt: now.subtract(const Duration(days: 1)),
      ),
    ]);
  }

  void _notifyListeners() {
    _controller.add(List.unmodifiable(_items));
  }

  @override
  Stream<List<NotificationItem>> watchNotifications(String userId) {
    // Emit initial cached list immediately upon subscribing
    Future.microtask(() => _notifyListeners());
    return _controller.stream.map((list) {
      return list.where((item) => item.userId == userId || item.userId == 'broadcast' || item.userId.startsWith('topic:')).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  @override
  Future<List<NotificationItem>> getNotifications(String userId) async {
    if (simulatedDelay > Duration.zero) await Future.delayed(simulatedDelay);
    final results = _items.where((item) => item.userId == userId || item.userId == 'broadcast' || item.userId.startsWith('topic:')).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return results;
  }

  @override
  Future<void> markAsRead(String notificationId) async {
    if (simulatedDelay > Duration.zero) await Future.delayed(simulatedDelay);
    final idx = _items.indexWhere((i) => i.id == notificationId);
    if (idx != -1) {
      _items[idx] = _items[idx].copyWith(isRead: true);
      _notifyListeners();
    }
  }

  @override
  Future<void> markAllAsRead(String userId) async {
    if (simulatedDelay > Duration.zero) await Future.delayed(simulatedDelay);
    for (int i = 0; i < _items.length; i++) {
      if (_items[i].userId == userId || _items[i].userId == 'broadcast' || _items[i].userId.startsWith('topic:')) {
        _items[i] = _items[i].copyWith(isRead: true);
      }
    }
    _notifyListeners();
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    if (simulatedDelay > Duration.zero) await Future.delayed(simulatedDelay);
    _items.removeWhere((i) => i.id == notificationId);
    _notifyListeners();
  }

  @override
  Future<NotificationPreferences> getPreferences(String userId) async {
    if (simulatedDelay > Duration.zero) await Future.delayed(simulatedDelay);
    return _userPreferences[userId] ?? const NotificationPreferences();
  }

  @override
  Future<void> updatePreferences(String userId, NotificationPreferences preferences) async {
    if (simulatedDelay > Duration.zero) await Future.delayed(simulatedDelay);
    _userPreferences[userId] = preferences;
  }

  @override
  Future<void> registerFcmToken(String userId, String token) async {
    if (simulatedDelay > Duration.zero) await Future.delayed(simulatedDelay);
    final tokens = _userTokens.putIfAbsent(userId, () => []);
    if (!tokens.contains(token)) {
      tokens.add(token);
    }
  }

  /// Helper for integration tests to inject notifications dynamically
  void addNotification(NotificationItem item) {
    _items.insert(0, item);
    _notifyListeners();
  }

  void dispose() {
    _controller.close();
  }
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return MockNotificationsRepository(authRepository: authRepo);
});
