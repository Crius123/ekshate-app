import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../notifications_controller.dart';
import '../../domain/notification_preferences.dart';

class NotificationPreferencesModal extends ConsumerWidget {
  const NotificationPreferencesModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const NotificationPreferencesModal(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final prefsAsync = ref.watch(notificationPreferencesProvider);
    final prefs = prefsAsync.value ?? const NotificationPreferences();
    final notifier = ref.read(notificationPreferencesProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border.all(color: theme.colorScheme.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.mutedForeground.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.bellRing, size: 20, color: Color(0xFF10B981)),
                    const SizedBox(width: 8),
                    Text(
                      'Push Preferences',
                      style: theme.textTheme.h4.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 18),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Customize your time-sensitive community alerts and transactional buyer updates.',
              style: theme.textTheme.muted.copyWith(fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Toggle 1: Order Updates
            _buildPreferenceTile(
              context,
              theme: theme,
              icon: LucideIcons.packageCheck,
              iconColor: const Color(0xFF2563EB),
              title: 'Order & Courier Tracking',
              description:
                  'Target met confirmations, courier dispatch tracking, and delivery updates.',
              value: prefs.orderUpdates,
              onChanged: (val) => notifier.toggleOrderUpdates(val),
            ),
            const SizedBox(height: 12),

            // Toggle 2: Wallet & Payment Alerts
            _buildPreferenceTile(
              context,
              theme: theme,
              icon: LucideIcons.walletCards,
              iconColor: const Color(0xFF059669),
              title: 'Wallet & Payment Receipts',
              description:
                  'Instant 100% refunds at midnight and balance top-up receipts.',
              value: prefs.walletAlerts,
              onChanged: (val) => notifier.toggleWalletAlerts(val),
            ),
            const SizedBox(height: 12),

            // Toggle 3: Community Urgency Drops
            _buildPreferenceTile(
              context,
              theme: theme,
              icon: LucideIcons.flame,
              iconColor: const Color(0xFFEA580C),
              title: 'Community Urgency Drops',
              description:
                  'Momentum alerts when wholesale bulk buckets reach >= 80% capacity.',
              value: prefs.communityDrops,
              onChanged: (val) => notifier.toggleCommunityDrops(val),
            ),
            const SizedBox(height: 24),

            // Close Button
            SizedBox(
              width: double.infinity,
              child: ShadButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Save & Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferenceTile(
    BuildContext context, {
    required ShadThemeData theme,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.small.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: theme.textTheme.muted.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ShadSwitch(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
