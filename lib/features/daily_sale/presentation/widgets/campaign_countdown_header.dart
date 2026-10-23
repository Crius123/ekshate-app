import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ekshate_app/core/config/theme/app_decorations.dart';
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
        isPreview ? AppColors.amberEscrow : AppColors.emerald;
    final glowAccent =
        isPreview ? AppColors.amberGlow : AppColors.emeraldGlow;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF131D2D),
            const Color(0xFF0F172A),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: primaryAccent.withValues(alpha: 0.35),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: glowAccent,
            blurRadius: 24,
            spreadRadius: -4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Campaign Badge & Status Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: primaryAccent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isPreview ? LucideIcons.clock : LucideIcons.flame,
                      color: primaryAccent,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 10),
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
                        boxShadow: [
                          BoxShadow(
                            color: primaryAccent.withValues(alpha: 0.6),
                            blurRadius: 6,
                          ),
                        ],
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

          const SizedBox(height: 14),

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
                        letterSpacing: -0.3,
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

          const SizedBox(height: 14),

          // Window Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              key: const Key('campaign_window_progress_bar'),
              value: timerInfo.progressPercent,
              minHeight: 5,
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B), // Slate 800
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            value,
            key: Key('timer_segment_$label'),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              letterSpacing: 0.5,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: Color(0xFF94A3B8), // Slate 400
          ),
        ),
      ],
    );
  }

  Widget _buildTimeSeparator(Color accentColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
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
