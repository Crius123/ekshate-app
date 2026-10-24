import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// CapacityQuantitySelector enforces single-bucket integrity directly in the UI.
/// Hard-clamps quantity strictly between 1.0 and [remainingCapacity].
/// Disables the increment button and renders a prominent warning pill when bucket capacity is reached.
class CapacityQuantitySelector extends StatelessWidget {
  final double currentQuantity;
  final double remainingCapacity;
  final String unit;
  final ValueChanged<double> onQuantityChanged;
  final double minQuantity;
  final double step;

  const CapacityQuantitySelector({
    super.key,
    required this.currentQuantity,
    required this.remainingCapacity,
    required this.unit,
    required this.onQuantityChanged,
    this.minQuantity = 1.0,
    this.step = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final hasNoCapacity = remainingCapacity <= 0;
    final isAtMaxCapacity = currentQuantity >= remainingCapacity || hasNoCapacity;
    final isAtMinCapacity = currentQuantity <= minQuantity || hasNoCapacity;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 4,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Minus Button
                ShadButton.outline(
                  key: const Key('capacity_qty_minus'),
                  size: ShadButtonSize.sm,
                  enabled: !isAtMinCapacity,
                  onPressed: () {
                    if (currentQuantity > minQuantity) {
                      final nextQty = (currentQuantity - step).clamp(minQuantity, remainingCapacity);
                      onQuantityChanged(nextQty);
                    }
                  },
                  child: const Icon(LucideIcons.minus, size: 14),
                ),

                // Micro-animated Quantity Display
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    transitionBuilder: (child, animation) {
                      return ScaleTransition(
                        scale: animation,
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
                    child: Text(
                      '${currentQuantity.toStringAsFixed(0)} $unit',
                      key: ValueKey('qty_${currentQuantity}_$unit'),
                      style: theme.textTheme.large.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                ),

                // Plus Button
                ShadButton.outline(
                  key: const Key('capacity_qty_plus'),
                  size: ShadButtonSize.sm,
                  enabled: !isAtMaxCapacity,
                  onPressed: () {
                    if (currentQuantity < remainingCapacity) {
                      final nextQty = (currentQuantity + step).clamp(minQuantity, remainingCapacity);
                      onQuantityChanged(nextQty);
                    }
                  },
                  child: const Icon(LucideIcons.plus, size: 14),
                ),
              ],
            ),

            // Quick Preset / Max Chip
            if (!hasNoCapacity && remainingCapacity > 1) ...[
              ActionChip(
                key: const Key('capacity_qty_max_chip'),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                label: Text(
                  'Max (${remainingCapacity.toStringAsFixed(0)})',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                backgroundColor: isAtMaxCapacity
                    ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                    : const Color(0xFF10B981).withValues(alpha: 0.15),
                side: BorderSide(
                  color: isAtMaxCapacity
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.4)
                      : const Color(0xFF10B981).withValues(alpha: 0.4),
                ),
                onPressed: () {
                  onQuantityChanged(remainingCapacity);
                },
              ),
            ],
          ],
        ),

        const SizedBox(height: 8),

        // Capacity Feedback Pill / Indicator
        if (hasNoCapacity)
          _buildWarningPill(
            message: 'Bucket target reached (0 $unit available)',
            isSoldOut: true,
          )
        else if (isAtMaxCapacity)
          _buildWarningPill(
            message:
                'Bucket limit reached (${remainingCapacity.toStringAsFixed(0)} $unit available)',
          )
        else
          Text(
            '${(remainingCapacity - currentQuantity).toStringAsFixed(0)} $unit left to unlock bucket target',
            style: theme.textTheme.muted.copyWith(fontSize: 12),
          ),
      ],
    );
  }

  Widget _buildWarningPill({required String message, bool isSoldOut = false}) {
    final color = isSoldOut ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);

    return Container(
      key: const Key('capacity_warning_pill'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSoldOut ? LucideIcons.ban : LucideIcons.alertTriangle,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 150.ms).slideY(begin: 0.1, end: 0);
  }
}
