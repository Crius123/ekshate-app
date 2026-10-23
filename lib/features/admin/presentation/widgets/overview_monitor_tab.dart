import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../domain/admin_metrics.dart';
import '../admin_controller.dart';

class OverviewMonitorTab extends ConsumerWidget {
  final AdminMetrics metrics;

  const OverviewMonitorTab({super.key, required this.metrics});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final actionState = ref.watch(adminActionControllerProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Operational Status Banner
          _buildOperationalStatusBanner(context, theme),
          const SizedBox(height: 16),

          // Primary Financial KPI Metric Cards
          _buildKpiMetricsGrid(context, theme),
          const SizedBox(height: 16),

          // Real-time Campaign Fill Momentum Gauge
          _buildCampaignMomentumGauge(context, theme),
          const SizedBox(height: 20),

          // Emergency Operational Manual Overrides Card
          _buildManualOverridesSection(context, theme, ref, actionState),
          const SizedBox(height: 24),

          // Live Wholesale Bucket Momentum List
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Live Bucket Momentum', style: theme.textTheme.h4),
              Text(
                '${metrics.listingsCount} Active Listings',
                style: theme.textTheme.muted.copyWith(fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (metrics.bucketMomentum.isEmpty)
            _buildEmptyMomentumCard(theme)
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: metrics.bucketMomentum.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = metrics.bucketMomentum[index];
                return _buildBucketMomentumCard(context, theme, item);
              },
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildOperationalStatusBanner(BuildContext context, ShadThemeData theme) {
    Color statusColor;
    String statusTitle;
    String statusSubtitle;
    IconData statusIcon;

    switch (metrics.campaignStatus.toLowerCase()) {
      case 'active':
        statusColor = const Color(0xFF10B981); // Emerald
        statusTitle = 'Active Purchasing Window (10:00 AM – 11:59 PM BDT)';
        statusSubtitle = 'Live community orders accumulating into discrete MOQ batch buckets.';
        statusIcon = LucideIcons.flame;
        break;
      case 'preview':
        statusColor = const Color(0xFF38BDF8); // Sky
        statusTitle = 'Catalog Preview Window (12:00 AM – 10:00 AM BDT)';
        statusSubtitle = 'Read-only discovery mode. Purchasing opens at 10:00 AM BDT.';
        statusIcon = LucideIcons.eye;
        break;
      case 'settling':
        statusColor = const Color(0xFFF59E0B); // Amber
        statusTitle = 'Settlement In Progress';
        statusSubtitle = 'Reconciling bucket tallies, capturing escrow, and queuing refunds.';
        statusIcon = LucideIcons.loader2;
        break;
      case 'settled':
        statusColor = const Color(0xFF8B5CF6); // Purple
        statusTitle = 'Campaign Settled & Closed';
        statusSubtitle = 'Escrow permanently captured. Morning procurement manifest ready.';
        statusIcon = LucideIcons.checkCircle2;
        break;
      default:
        statusColor = const Color(0xFF64748B);
        statusTitle = 'Campaign Window: ${metrics.campaignStatus.toUpperCase()}';
        statusSubtitle = 'Operator control panel active for date ${metrics.date}.';
        statusIcon = LucideIcons.info;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(statusIcon, color: statusColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusTitle,
                  style: theme.textTheme.small.copyWith(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusSubtitle,
                  style: theme.textTheme.muted.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              metrics.campaignStatus.toUpperCase(),
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiMetricsGrid(BuildContext context, ShadThemeData theme) {
    return Column(
      children: [
        Row(
          children: [
            // GMV Card
            Expanded(
              child: _buildMetricTile(
                theme: theme,
                title: "Today's GMV",
                value: '৳${metrics.gmv.toStringAsFixed(0)}',
                subtitle: '${metrics.totalOrdersCount} Total Orders',
                icon: LucideIcons.trendingUp,
                accentColor: const Color(0xFF10B981), // Emerald
              ),
            ),
            const SizedBox(width: 12),
            // Escrow Holds Card
            Expanded(
              child: _buildMetricTile(
                theme: theme,
                title: 'Escrow Volume',
                value: '৳${metrics.escrowVolume.toStringAsFixed(0)}',
                subtitle: '${metrics.pendingEscrowOrdersCount} In Pending Escrow',
                icon: LucideIcons.shieldCheck,
                accentColor: const Color(0xFFF59E0B), // Amber
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Confirmed Orders Card
            Expanded(
              child: _buildMetricTile(
                theme: theme,
                title: 'Confirmed Orders',
                value: '${metrics.confirmedOrdersCount}',
                subtitle: '${metrics.dispatchedOrdersCount} Dispatched',
                icon: LucideIcons.packageCheck,
                accentColor: const Color(0xFF0EA5E9), // Sky
              ),
            ),
            const SizedBox(width: 12),
            // Pending Dispatch Card
            Expanded(
              child: _buildMetricTile(
                theme: theme,
                title: 'Pending Dispatch',
                value: '${metrics.pendingDispatchCount}',
                subtitle: 'Courier Queue Ready',
                icon: LucideIcons.truck,
                accentColor: const Color(0xFFF97316), // Orange
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required ShadThemeData theme,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A), // Slate 900
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: theme.textTheme.muted.copyWith(fontSize: 12, fontWeight: FontWeight.w500),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 16, color: accentColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.h3.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: theme.textTheme.muted.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildCampaignMomentumGauge(BuildContext context, ShadThemeData theme) {
    final fillPct = metrics.averageFillPercentage;
    final progressVal = (fillPct / 100.0).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.gauge, size: 18, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Text('Campaign Quota Completion Gauge', style: theme.textTheme.small.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${fillPct.toStringAsFixed(1)}% Completed',
                  style: const TextStyle(
                    color: Color(0xFF10B981),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progressVal,
              minHeight: 12,
              backgroundColor: const Color(0xFF334155),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Calculated across ${metrics.listingsCount} wholesale listings',
                style: theme.textTheme.muted.copyWith(fontSize: 11),
              ),
              Text(
                'Threshold: 100% to Lock All',
                style: theme.textTheme.muted.copyWith(fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildManualOverridesSection(
    BuildContext context,
    ShadThemeData theme,
    WidgetRef ref,
    AdminActionState actionState,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.alertTriangle, size: 18, color: Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              Text('Emergency Operations Overrides', style: theme.textTheme.small.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Manual trigger actions for platform operators during unscheduled maintenance or dispatch cutovers.',
            style: theme.textTheme.muted.copyWith(fontSize: 11),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              // Manual Settlement Shortcut Button
              Expanded(
                child: ShadButton.outline(
                  key: const Key('emergency_settlement_button'),
                  enabled: !actionState.isLoading,
                  onPressed: () => _confirmAndTriggerSettlement(context, ref),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.zap, size: 16, color: Color(0xFFF59E0B)),
                      SizedBox(width: 6),
                      Text('Emergency Settlement', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Manual Dispatch Shortcut Button
              Expanded(
                child: ShadButton.outline(
                  key: const Key('manual_dispatch_button'),
                  enabled: !actionState.isLoading,
                  onPressed: () => _confirmAndTriggerDispatch(context, ref),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.truck, size: 16, color: Color(0xFF0EA5E9)),
                      SizedBox(width: 6),
                      Text('Trigger Dispatch', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBucketMomentumCard(BuildContext context, ShadThemeData theme, BucketMomentum item) {
    final progress = (item.fillPercentage / 100.0).clamp(0.0, 1.0);
    final isLocked = item.fillPercentage >= 100.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productTitle,
                      style: theme.textTheme.small.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.category} • ৳${item.unitPrice.toStringAsFixed(0)}/${item.unit} (${item.discountPercent.toStringAsFixed(0)}% OFF)',
                      style: theme.textTheme.muted.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isLocked ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFF0EA5E9).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Bucket #${item.activeBucketNumber}',
                  style: TextStyle(
                    color: isLocked ? const Color(0xFF10B981) : const Color(0xFF0EA5E9),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFF334155),
              valueColor: AlwaysStoppedAnimation<Color>(
                isLocked ? const Color(0xFF10B981) : const Color(0xFF38BDF8),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${item.currentQuantity.toStringAsFixed(1)} / ${item.moqThreshold.toStringAsFixed(0)} ${item.unit} ordered',
                style: theme.textTheme.muted.copyWith(fontSize: 11),
              ),
              Text(
                isLocked ? 'TARGET MET (Won)' : '${item.remainingCapacity.toStringAsFixed(1)} ${item.unit} remaining',
                style: TextStyle(
                  color: isLocked ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMomentumCard(ShadThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(LucideIcons.packageOpen, size: 36, color: Color(0xFF64748B)),
            const SizedBox(height: 8),
            Text('No Active Listings Today', style: theme.textTheme.small.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              'Use the Daily Deal Scheduler tab to provision wholesale listings for this campaign.',
              textAlign: TextAlign.center,
              style: theme.textTheme.muted.copyWith(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmAndTriggerSettlement(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Emergency Campaign Settlement'),
        content: const Text(
          'Are you sure you want to trigger manual midnight settlement right now?\n\n'
          'This will lock the campaign, confirm all target-met buckets, capture escrow balances permanently, and execute batch refunds for unmet buckets.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            key: const Key('confirm_settlement_action_button'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B)),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final summary = await ref
                  .read(adminActionControllerProvider.notifier)
                  .triggerEmergencySettlement(metrics.date);
              if (context.mounted && summary != null) {
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  SnackBar(content: Text(summary), backgroundColor: const Color(0xFF10B981)),
                );
              }
            },
            child: const Text('Confirm Settlement'),
          ),
        ],
      ),
    );
  }

  void _confirmAndTriggerDispatch(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Manual Courier Dispatch'),
        content: Text(
          'Trigger courier booking and consignment generation for ${metrics.pendingDispatchCount} confirmed orders?\n\n'
          'This will assign Pathao tracking codes and mark orders as DISPATCHED.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            key: const Key('confirm_dispatch_action_button'),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0EA5E9)),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final summary = await ref
                  .read(adminActionControllerProvider.notifier)
                  .triggerManualDispatch(metrics.date, 'Pathao Courier');
              if (context.mounted && summary != null) {
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  SnackBar(content: Text(summary), backgroundColor: const Color(0xFF10B981)),
                );
              }
            },
            child: const Text('Confirm Dispatch'),
          ),
        ],
      ),
    );
  }
}
