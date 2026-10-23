import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../domain/notification_item.dart';
import '../../../../core/router/route_paths.dart';

class NotificationCard extends StatelessWidget {
  final NotificationItem notification;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const NotificationCard({
    super.key,
    required this.notification,
    this.onTap,
    this.onDismiss,
  });

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return DateFormat('d MMM').format(dateTime);
    }
  }

  void _handleDeepLink(BuildContext context) {
    onTap?.call();
    final link = notification.deepLink;
    if (link != null && link.isNotEmpty) {
      if (link == RoutePaths.orders || link.startsWith('/orders')) {
        context.push(RoutePaths.orders);
      } else if (link == RoutePaths.wallet || link.startsWith('/wallet')) {
        context.push(RoutePaths.wallet);
      } else if (link == RoutePaths.dailySale || link == '/') {
        context.push(RoutePaths.dailySale);
      } else {
        context.push(link);
      }
    }
  }

  void _copyTracking(BuildContext context, String trackingCode) {
    Clipboard.setData(ClipboardData(text: trackingCode));
    ShadToaster.of(context).show(
      ShadToast(
        title: const Text('Tracking Code Copied'),
        description: Text(trackingCode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final isUnread = !notification.isRead;

    // Category Color & Icon Configuration
    Color categoryBg;
    Color categoryFg;
    IconData categoryIcon;

    switch (notification.category) {
      case NotificationCategory.orders:
        categoryBg = const Color(0xFF3B82F6).withValues(alpha: 0.12);
        categoryFg = const Color(0xFF2563EB);
        categoryIcon = notification.metadata.containsKey('courier_partner')
            ? LucideIcons.truck
            : LucideIcons.packageCheck;
        break;
      case NotificationCategory.wallet:
        categoryBg = const Color(0xFF10B981).withValues(alpha: 0.12);
        categoryFg = const Color(0xFF059669);
        categoryIcon = LucideIcons.walletCards;
        break;
      case NotificationCategory.communityDrops:
        categoryBg = const Color(0xFFF97316).withValues(alpha: 0.12);
        categoryFg = const Color(0xFFEA580C);
        categoryIcon = LucideIcons.flame;
        break;
      case NotificationCategory.all:
        categoryBg = theme.colorScheme.muted.withValues(alpha: 0.3);
        categoryFg = theme.colorScheme.foreground;
        categoryIcon = LucideIcons.bell;
        break;
    }

    final courierPartner = notification.metadata['courier_partner'] as String?;
    final trackingCode = notification.metadata['tracking_code'] as String?;
    final refundAmount = notification.metadata['refund_amount'];
    final remainingCapacity = notification.metadata['remaining_capacity'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _handleDeepLink(context),
        child: Container(
          decoration: BoxDecoration(
            color: isUnread
                ? theme.colorScheme.primary.withValues(alpha: 0.04)
                : theme.colorScheme.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isUnread
                  ? theme.colorScheme.primary.withValues(alpha: 0.35)
                  : theme.colorScheme.border,
              width: isUnread ? 1.5 : 1.0,
            ),
          ),
          padding: const EdgeInsets.all(14.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row: Category Icon + Title + Unread Indicator + Relative Time
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: categoryBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(categoryIcon, size: 18, color: categoryFg),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                notification.title,
                                style: theme.textTheme.small.copyWith(
                                  fontWeight:
                                      isUnread ? FontWeight.bold : FontWeight.w600,
                                ),
                              ),
                            ),
                            if (isUnread) ...[
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(left: 6, right: 6),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                            Text(
                              _formatRelativeTime(notification.createdAt),
                              style: theme.textTheme.muted.copyWith(fontSize: 11),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          notification.body,
                          style: theme.textTheme.muted.copyWith(
                            color: isUnread
                                ? theme.colorScheme.foreground
                                : theme.colorScheme.mutedForeground,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Metadata Pills Row
              if (courierPartner != null ||
                  trackingCode != null ||
                  refundAmount != null ||
                  remainingCapacity != null) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    // Courier Partner Pill
                    if (courierPartner != null)
                      ShadBadge.secondary(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.truck, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              courierPartner.toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Tracking Code Pill with Copy Action
                    if (trackingCode != null)
                      InkWell(
                        onTap: () => _copyTracking(context, trackingCode),
                        child: ShadBadge.outline(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Tracking: $trackingCode',
                                style: const TextStyle(fontSize: 11),
                              ),
                              const SizedBox(width: 4),
                              const Icon(LucideIcons.copy, size: 10),
                            ],
                          ),
                        ),
                      ),

                    // 100% Escrow Refund Pill
                    if (refundAmount != null)
                      ShadBadge(
                        backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                        foregroundColor: const Color(0xFF047857),
                        child: Text(
                          'Refunded: ৳$refundAmount',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),

                    // Urgency Drop Remaining Pill
                    if (remainingCapacity != null)
                      ShadBadge(
                        backgroundColor: const Color(0xFFF97316).withValues(alpha: 0.15),
                        foregroundColor: const Color(0xFFC2410C),
                        child: Text(
                          '🔥 Only $remainingCapacity left',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
