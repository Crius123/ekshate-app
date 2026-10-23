import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../domain/batch_bucket.dart';

/// Renders the real-time quota indicator showing accumulated volume versus MOQ threshold,
/// active bucket badge (e.g., Bucket #1), and animated emerald progress bar.
class BatchQuotaIndicator extends StatelessWidget {
  final BatchBucket bucket;
  final String unit;
  final bool showBucketBadge;

  const BatchQuotaIndicator({
    super.key,
    required this.bucket,
    required this.unit,
    this.showBucketBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final progress = bucket.progressPercentage;
    final percentText = (progress * 100).toStringAsFixed(0);
    final isTargetMet = bucket.isTargetMet;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status Row: Volume vs MOQ & Bucket Badge
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  const Icon(LucideIcons.users, size: 14, color: Color(0xFF10B981)),
                  const SizedBox(width: 6),
                  Text(
                    '${bucket.currentQuantity.toStringAsFixed(0)}/${bucket.moqThreshold.toStringAsFixed(0)} $unit ordered',
                    style: theme.textTheme.small.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (showBucketBadge)
              ShadBadge(
                key: Key('bucket_badge_${bucket.bucketNumber}'),
                child: Text('Bucket #${bucket.bucketNumber}'),
              ),
          ],
        ),
        const SizedBox(height: 6),

        // Live Animated Emerald Progress Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            key: const Key('batch_quota_progress_bar'),
            value: progress,
            minHeight: 8,
            backgroundColor: const Color(0xFFE2E8F0),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
          ),
        ),
        const SizedBox(height: 6),

        // Quota Target Met or Remaining Info
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '$percentText% MOQ reached',
              style: theme.textTheme.muted.copyWith(fontSize: 11),
            ),
            Text(
              isTargetMet
                  ? '🎯 Target Met! Rollover Active'
                  : '${bucket.remainingCapacity.toStringAsFixed(0)} $unit remaining',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isTargetMet ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
