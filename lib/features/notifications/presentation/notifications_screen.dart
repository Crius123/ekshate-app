import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:go_router/go_router.dart';
import '../domain/notification_item.dart';
import 'notifications_controller.dart';
import 'widgets/notification_card.dart';
import 'widgets/notification_preferences_modal.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final activeFilter = ref.watch(notificationFilterProvider);
    final notifications = ref.watch(filteredNotificationsProvider);
    final counts = ref.watch(categoryCountsProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    final controller = ref.read(notificationsControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        title: Row(
          children: [
            Text('Notifications', style: theme.textTheme.h4),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              ShadBadge(
                backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                foregroundColor: const Color(0xFF047857),
                child: Text(
                  '$unreadCount new',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (unreadCount > 0)
            IconButton(
              tooltip: 'Mark all as read',
              icon: const Icon(LucideIcons.checkCheck, size: 20),
              onPressed: () => controller.markAllAsRead(),
            ),
          IconButton(
            tooltip: 'Push Preferences',
            icon: const Icon(LucideIcons.slidersHorizontal, size: 20),
            onPressed: () => NotificationPreferencesModal.show(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Categorized Filter Tabs (Horizontal Scrollable Pills)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.colorScheme.border),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: NotificationCategory.values.map((cat) {
                  final isSelected = activeFilter == cat;
                  final count = counts[cat] ?? 0;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        ref.read(notificationFilterProvider.notifier).state = cat;
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.muted.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              cat.label,
                              style: TextStyle(
                                color: isSelected
                                    ? theme.colorScheme.primaryForeground
                                    : theme.colorScheme.foreground,
                                fontWeight:
                                    isSelected ? FontWeight.bold : FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                            if (count > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white.withValues(alpha: 0.25)
                                      : theme.colorScheme.mutedForeground
                                          .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$count',
                                  style: TextStyle(
                                    color: isSelected
                                        ? theme.colorScheme.primaryForeground
                                        : theme.colorScheme.mutedForeground,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Notifications Feed or Empty State
          Expanded(
            child: notifications.isEmpty
                ? _buildEmptyState(context, activeFilter, theme)
                : ListView.builder(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      final item = notifications[index];
                      return NotificationCard(
                        notification: item,
                        onTap: () {
                          if (!item.isRead) {
                            controller.markAsRead(item.id);
                          }
                        },
                        onDismiss: () => controller.deleteNotification(item.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    NotificationCategory filter,
    ShadThemeData theme,
  ) {
    IconData emptyIcon;
    String emptyTitle;
    String emptySubtitle;

    switch (filter) {
      case NotificationCategory.orders:
        emptyIcon = LucideIcons.package;
        emptyTitle = 'No Order Updates';
        emptySubtitle = 'Target met confirmations and courier tracking will show here.';
        break;
      case NotificationCategory.wallet:
        emptyIcon = LucideIcons.wallet;
        emptyTitle = 'No Wallet Receipts';
        emptySubtitle = 'Refunds and deposit receipts will appear here.';
        break;
      case NotificationCategory.communityDrops:
        emptyIcon = LucideIcons.flame;
        emptyTitle = 'No Urgency Drops';
        emptySubtitle = 'Milestone alerts when wholesale buckets hit 80% will pop up here.';
        break;
      case NotificationCategory.all:
        emptyIcon = LucideIcons.bellOff;
        emptyTitle = 'All Caught Up!';
        emptySubtitle = 'You have no notifications right now.';
        break;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.muted.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(emptyIcon, size: 40, color: theme.colorScheme.mutedForeground),
            ),
            const SizedBox(height: 16),
            Text(
              emptyTitle,
              style: theme.textTheme.h4.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              emptySubtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.muted.copyWith(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
