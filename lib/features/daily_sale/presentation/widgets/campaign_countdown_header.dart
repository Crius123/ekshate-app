import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ekshate_app/features/daily_sale/presentation/daily_sale_controller.dart';

/// Campaign header displaying dynamic countdown timers synchronized to campaign windows:
/// - Preview Mode: Countdown to 10:00 AM BDT
/// - Active Ordering: Countdown to 11:59 PM BDT
class CampaignCountdownHeader extends ConsumerStatefulWidget {
  final bool autoTick;

  const CampaignCountdownHeader({
    super.key,
    this.autoTick = true,
  });

  @override
  ConsumerState<CampaignCountdownHeader> createState() =>
      _CampaignCountdownHeaderState();
}

class _CampaignCountdownHeaderState
    extends ConsumerState<CampaignCountdownHeader> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.autoTick) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final timerInfo = ref.watch(campaignTimerInfoProvider);
    final isPreview = timerInfo.isPreview;

    final primaryAccent =
        isPreview ? const Color(0xFFF59E0B) : const Color(0xFF10B981);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF18181B), // Zinc 900
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: primaryAccent.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryAccent.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Campaign Badge & Status Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isPreview ? LucideIcons.clock : LucideIcons.flame,
                    color: primaryAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Daily Bulk Campaign',
                    style: theme.textTheme.small.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              // Status Badge
              ShadBadge(
                key: const Key('campaign_status_badge'),
                backgroundColor: primaryAccent.withValues(alpha: 0.15),
                foregroundColor: primaryAccent,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: primaryAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      timerInfo.phaseLabel, // 'Preview Mode' or 'Active Ordering'
                      style: TextStyle(
                        color: primaryAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Middle: Dynamic Target Header & Segmented Countdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Target Title & Status Explanation
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      timerInfo.targetLabel, // 'Countdown to 10:00 AM BDT' or 'Countdown to 11:59 PM BDT'
                      key: const Key('campaign_target_label'),
                      style: theme.textTheme.large.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isPreview
                          ? 'Wholesale drops unlock at 10:00 AM BDT'
                          : 'Deals close at midnight (11:59 PM BDT)',
                      style: theme.textTheme.muted.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // Segmented Digital Timer Digits
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTimeSegment(timerInfo.hours, 'HRS', primaryAccent),
                  _buildTimeSeparator(primaryAccent),
                  _buildTimeSegment(timerInfo.minutes, 'MIN', primaryAccent),
                  _buildTimeSeparator(primaryAccent),
                  _buildTimeSegment(timerInfo.seconds, 'SEC', primaryAccent),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Window Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              key: const Key('campaign_window_progress_bar'),
              value: timerInfo.progressPercent,
              minHeight: 4,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(primaryAccent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSegment(String value, String label, Color accentColor) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF27272A), // Zinc 800
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white12),
          ),
          child: Text(
            value,
            key: Key('timer_segment_$label'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: Color(0xFF71717A), // Zinc 500
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSeparator(Color accentColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
      child: Text(
        ':',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: accentColor,
        ),
      ),
    );
  }
}
