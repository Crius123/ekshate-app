import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../domain/notification_item.dart';
import '../notifications_controller.dart';
import '../../../../core/config/theme/app_decorations.dart';

/// Notification trigger widget rendered in top headers and mobile app bars.
///
/// Triggers a sleek ShadSelect dropdown popup in-place without leaving the current page,
/// allowing immediate viewing, category identification, and marking of notifications as read.
class NotificationBellButton extends ConsumerWidget {
  final Color? color;

  const NotificationBellButton({super.key, this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    final notifsAsync = ref.watch(notificationsStreamProvider);
    final notifications = notifsAsync.maybeWhen(
      data: (items) => items,
      orElse: () => const <NotificationItem>[],
    );
    final controller = ref.read(notificationsControllerProvider.notifier);

    final triggerContent = Badge(
      isLabelVisible: unreadCount > 0,
      label: Text(
        unreadCount > 99 ? '99+' : '$unreadCount',
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),
      backgroundColor: const Color(0xFF10B981),
      textColor: Colors.white,
      child: Icon(
        LucideIcons.bell,
        size: 20,
        color: color ?? AppColors.textPrimary,
      ),
    );

    return ShadSelect<String>(
      minWidth: 44,
      maxWidth: 420,
      maxHeight: 400,
      placeholder: triggerContent,
      selectedOptionBuilder: (context, _) => triggerContent,
      trailing: const SizedBox.shrink(),
      decoration: const ShadDecoration(
        border: ShadBorder.none,
        focusedBorder: ShadBorder.none,
        secondaryBorder: ShadBorder.none,
        secondaryFocusedBorder: ShadBorder.none,
        color: Colors.transparent,
      ),
      header: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                if (unreadCount > 0)
                  InkWell(
                    borderRadius: BorderRadius.circular(4),
                    onTap: () => controller.markAllAsRead(),
                    child: const Text(
                      'Mark all as read',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF10B981),
                      ),
                    ),
                  ),
              ],
            ),
            if (unreadCount > 0) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$unreadCount new',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF047857),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      options: notifications.isEmpty
          ? [
              const ShadOption<String>(
                value: 'empty',
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.0, horizontal: 12.0),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.bellOff, size: 26, color: Color(0xFF94A3B8)),
                        SizedBox(height: 8),
                        Text(
                          'All caught up!',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'No new notifications right now.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ]
          : notifications.map((item) {
              IconData icon;
              Color iconColor;
              Color iconBg;

              switch (item.category) {
                case NotificationCategory.orders:
                  icon = LucideIcons.package;
                  iconColor = const Color(0xFF0284C7);
                  iconBg = const Color(0xFFE0F2FE);
                  break;
                case NotificationCategory.wallet:
                  icon = LucideIcons.wallet;
                  iconColor = const Color(0xFFD97706);
                  iconBg = const Color(0xFFFEF3C7);
                  break;
                case NotificationCategory.communityDrops:
                  icon = LucideIcons.flame;
                  iconColor = const Color(0xFF10B981);
                  iconBg = const Color(0xFFD1FAE5);
                  break;
                case NotificationCategory.all:
                  icon = LucideIcons.bell;
                  iconColor = const Color(0xFF64748B);
                  iconBg = const Color(0xFFF1F5F9);
                  break;
              }

              return ShadOption<String>(
                value: item.id,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                backgroundColor: item.isRead ? Colors.transparent : const Color(0xFFF8FAFC),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(icon, size: 13, color: iconColor),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  item.title,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: item.isRead ? FontWeight.w500 : FontWeight.w700,
                                    color: const Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (!item.isRead) ...[
                                const SizedBox(width: 4),
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.body,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF475569),
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
      onChanged: (id) {
        if (id != null && id != 'empty') {
          controller.markAsRead(id);
        }
      },
    );
  }
}
