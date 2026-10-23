import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/notification_item.dart';
import '../domain/notification_preferences.dart';
import '../data/notifications_repository.dart';
import '../../auth/presentation/auth_controller.dart';

/// Currently selected category tab in the Notification Hub
final notificationFilterProvider = StateProvider<NotificationCategory>((ref) {
  return NotificationCategory.all;
});

/// Reactive stream of all notifications for the current authenticated user
final notificationsStreamProvider = StreamProvider<List<NotificationItem>>((ref) {
  final repo = ref.watch(notificationsRepositoryProvider);
  final auth = ref.watch(authStateProvider);
  final userId = auth.asData?.value?.uid ?? 'user_dev_01';
  return repo.watchNotifications(userId);
});

/// Unread notification count for scaffold badge and app bar bell
final unreadNotificationCountProvider = Provider<int>((ref) {
  final notifsAsync = ref.watch(notificationsStreamProvider);
  return notifsAsync.maybeWhen(
    data: (items) => items.where((item) => !item.isRead).length,
    orElse: () => 0,
  );
});

/// Category counts map for tab badges
final categoryCountsProvider = Provider<Map<NotificationCategory, int>>((ref) {
  final notifsAsync = ref.watch(notificationsStreamProvider);
  final items = notifsAsync.maybeWhen(data: (d) => d, orElse: () => <NotificationItem>[]);

  return {
    NotificationCategory.all: items.length,
    NotificationCategory.orders: items.where((i) => i.category == NotificationCategory.orders).length,
    NotificationCategory.wallet: items.where((i) => i.category == NotificationCategory.wallet).length,
    NotificationCategory.communityDrops: items.where((i) => i.category == NotificationCategory.communityDrops).length,
  };
});

/// Filtered list of notifications according to selected tab
final filteredNotificationsProvider = Provider<List<NotificationItem>>((ref) {
  final filter = ref.watch(notificationFilterProvider);
  final notifsAsync = ref.watch(notificationsStreamProvider);
  final items = notifsAsync.maybeWhen(data: (d) => d, orElse: () => <NotificationItem>[]);

  if (filter == NotificationCategory.all) {
    return items;
  }
  return items.where((item) => item.category == filter).toList();
});

/// Notification Actions Controller (mark as read, mark all read, delete)
class NotificationsController extends StateNotifier<AsyncValue<void>> {
  final NotificationsRepository _repository;
  final Ref _ref;

  NotificationsController(this._repository, this._ref) : super(const AsyncValue.data(null));

  String get _currentUserId {
    return _ref.read(authStateProvider).asData?.value?.uid ?? 'user_dev_01';
  }

  Future<void> markAsRead(String id) async {
    try {
      await _repository.markAsRead(id);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> markAllAsRead() async {
    try {
      state = const AsyncValue.loading();
      await _repository.markAllAsRead(_currentUserId);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteNotification(String id) async {
    try {
      await _repository.deleteNotification(id);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final notificationsControllerProvider =
    StateNotifierProvider<NotificationsController, AsyncValue<void>>((ref) {
  final repo = ref.watch(notificationsRepositoryProvider);
  return NotificationsController(repo, ref);
});

/// User Notification Preferences Controller
class NotificationPreferencesNotifier extends StateNotifier<AsyncValue<NotificationPreferences>> {
  final NotificationsRepository _repository;
  final Ref _ref;

  NotificationPreferencesNotifier(this._repository, this._ref)
      : super(const AsyncValue.data(NotificationPreferences())) {
    loadPreferences();
  }

  String get _currentUserId {
    return _ref.read(authStateProvider).asData?.value?.uid ?? 'user_dev_01';
  }

  Future<void> loadPreferences() async {
    try {
      final prefs = await _repository.getPreferences(_currentUserId);
      state = AsyncValue.data(prefs);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updatePreferences(NotificationPreferences prefs) async {
    try {
      state = AsyncValue.data(prefs);
      await _repository.updatePreferences(_currentUserId, prefs);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> toggleOrderUpdates(bool enabled) async {
    final current = state.value ?? const NotificationPreferences();
    await updatePreferences(current.copyWith(orderUpdates: enabled));
  }

  Future<void> toggleWalletAlerts(bool enabled) async {
    final current = state.value ?? const NotificationPreferences();
    await updatePreferences(current.copyWith(walletAlerts: enabled));
  }

  Future<void> toggleCommunityDrops(bool enabled) async {
    final current = state.value ?? const NotificationPreferences();
    await updatePreferences(current.copyWith(communityDrops: enabled));
  }
}

final notificationPreferencesProvider =
    StateNotifierProvider<NotificationPreferencesNotifier, AsyncValue<NotificationPreferences>>((ref) {
  final repo = ref.watch(notificationsRepositoryProvider);
  return NotificationPreferencesNotifier(repo, ref);
});
