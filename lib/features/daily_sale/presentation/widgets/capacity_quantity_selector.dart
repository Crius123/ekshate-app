import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// CapacityQuantitySelector enforces single-bucket integrity directly in the UI.
/// Clamps quantity strictly between 1.0 and [remainingCapacity].
class CapacityQuantitySelector extends StatelessWidget {
  final double currentQuantity;
  final double remainingCapacity;
  final String unit;
  final ValueChanged<double> onQuantityChanged;

  const CapacityQuantitySelector({
    super.key,
    required this.currentQuantity,
    required this.remainingCapacity,
    required this.unit,
    required this.onQuantityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final isAtMaxCapacity = currentQuantity >= remainingCapacity;
    final isAtMinCapacity = currentQuantity <= 1.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ShadButton.outline(
              size: ShadButtonSize.sm,
              enabled: !isAtMinCapacity,
              onPressed: () {
                if (currentQuantity > 1.0) {
                  onQuantityChanged(currentQuantity - 1.0);
                }
              },
              child: const Icon(LucideIcons.minus, size: 14),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                '${currentQuantity.toStringAsFixed(0)} $unit',
                style: theme.textTheme.large.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            ShadButton.outline(
              size: ShadButtonSize.sm,
              enabled: !isAtMaxCapacity,
              onPressed: () {
                if (currentQuantity < remainingCapacity) {
                  onQuantityChanged(currentQuantity + 1.0);
                }
              },
              child: const Icon(LucideIcons.plus, size: 14),
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (isAtMaxCapacity)
          Text(
            '⚠️ Reached bucket limit (${remainingCapacity.toStringAsFixed(0)} $unit available)',
            style: theme.textTheme.small.copyWith(
              color: const Color(0xFFF59E0B),
              fontWeight: FontWeight.w600,
            ),
          )
        else
          Text(
            '${remainingCapacity.toStringAsFixed(0)} $unit left to unlock bucket target',
            style: theme.textTheme.muted,
          ),
      ],
    );
  }
}
