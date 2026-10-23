import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ekshate_app/features/daily_sale/presentation/widgets/capacity_quantity_selector.dart';

void main() {
  group('CapacityQuantitySelector Widget Tests', () {
    testWidgets('renders initial quantity and disables minus button at 1 unit', (tester) async {
      double selectedQty = 1.0;

      await tester.pumpWidget(
        ShadApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return CapacityQuantitySelector(
                  currentQuantity: selectedQty,
                  remainingCapacity: 35.0,
                  unit: 'kg',
                  onQuantityChanged: (qty) => setState(() => selectedQty = qty),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Quantity text
      expect(find.text('1 kg'), findsOneWidget);

      // Minus button is disabled
      final minusFinder = find.byKey(const Key('capacity_qty_minus'));
      expect(minusFinder, findsOneWidget);
      final minusButton = tester.widget<ShadButton>(minusFinder);
      expect(minusButton.enabled, isFalse);

      // Plus button is enabled
      final plusFinder = find.byKey(const Key('capacity_qty_plus'));
      expect(plusFinder, findsOneWidget);
      final plusButton = tester.widget<ShadButton>(plusFinder);
      expect(plusButton.enabled, isTrue);

      // Helper text shown when under limit
      expect(find.text('34 kg left to unlock bucket target'), findsOneWidget);

      // Warning pill is NOT present
      expect(find.byKey(const Key('capacity_warning_pill')), findsNothing);
    });

    testWidgets('increments quantity and enables minus button', (tester) async {
      double selectedQty = 1.0;

      await tester.pumpWidget(
        ShadApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return CapacityQuantitySelector(
                  currentQuantity: selectedQty,
                  remainingCapacity: 35.0,
                  unit: 'kg',
                  onQuantityChanged: (qty) => setState(() => selectedQty = qty),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Plus button
      await tester.tap(find.byKey(const Key('capacity_qty_plus')));
      await tester.pumpAndSettle();

      // Quantity increased to 2 kg
      expect(find.text('2 kg'), findsOneWidget);
      expect(selectedQty, 2.0);

      // Minus button is now enabled
      final minusButton = tester.widget<ShadButton>(find.byKey(const Key('capacity_qty_minus')));
      expect(minusButton.enabled, isTrue);

      // Tap Minus button
      await tester.tap(find.byKey(const Key('capacity_qty_minus')));
      await tester.pumpAndSettle();

      // Quantity decreased back to 1 kg
      expect(find.text('1 kg'), findsOneWidget);
      expect(selectedQty, 1.0);
    });

    testWidgets('hard-clamps quantity to remainingCapacity, disables plus button and renders warning pill', (tester) async {
      double selectedQty = 34.0;
      const double remainingCap = 35.0;

      await tester.pumpWidget(
        ShadApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return CapacityQuantitySelector(
                  currentQuantity: selectedQty,
                  remainingCapacity: remainingCap,
                  unit: 'kg',
                  onQuantityChanged: (qty) => setState(() => selectedQty = qty),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Under limit: warning pill not present
      expect(find.byKey(const Key('capacity_warning_pill')), findsNothing);
      expect(find.text('1 kg left to unlock bucket target'), findsOneWidget);

      // Tap plus to reach 35.0 kg
      await tester.tap(find.byKey(const Key('capacity_qty_plus')));
      await tester.pumpAndSettle();

      expect(find.text('35 kg'), findsOneWidget);
      expect(selectedQty, 35.0);

      // Plus button must be disabled
      final plusButton = tester.widget<ShadButton>(find.byKey(const Key('capacity_qty_plus')));
      expect(plusButton.enabled, isFalse);

      // Warning pill MUST be rendered
      expect(find.byKey(const Key('capacity_warning_pill')), findsOneWidget);
      expect(find.text('Bucket limit reached (35 kg available)'), findsOneWidget);
      expect(find.byIcon(LucideIcons.alertTriangle), findsOneWidget);

      // Tapping disabled plus button must not increment
      await tester.tap(find.byKey(const Key('capacity_qty_plus')));
      await tester.pumpAndSettle();
      expect(selectedQty, 35.0);
    });

    testWidgets('tapping Max preset chip hard-clamps quantity to remainingCapacity', (tester) async {
      double selectedQty = 1.0;
      const double remainingCap = 25.0;

      await tester.pumpWidget(
        ShadApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return CapacityQuantitySelector(
                  currentQuantity: selectedQty,
                  remainingCapacity: remainingCap,
                  unit: 'bag',
                  onQuantityChanged: (qty) => setState(() => selectedQty = qty),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Max chip
      final maxChip = find.byKey(const Key('capacity_qty_max_chip'));
      expect(maxChip, findsOneWidget);
      expect(find.text('Max (25)'), findsOneWidget);

      await tester.tap(maxChip);
      await tester.pumpAndSettle();

      expect(selectedQty, 25.0);
      expect(find.text('25 bag'), findsOneWidget);

      // Plus button disabled
      final plusButton = tester.widget<ShadButton>(find.byKey(const Key('capacity_qty_plus')));
      expect(plusButton.enabled, isFalse);

      // Warning pill shown
      expect(find.byKey(const Key('capacity_warning_pill')), findsOneWidget);
      expect(find.text('Bucket limit reached (25 bag available)'), findsOneWidget);
    });

    testWidgets('disables both buttons and shows sold-out warning pill when remainingCapacity is 0', (tester) async {
      double selectedQty = 1.0;

      await tester.pumpWidget(
        ShadApp(
          home: Scaffold(
            body: CapacityQuantitySelector(
              currentQuantity: selectedQty,
              remainingCapacity: 0.0,
              unit: 'kg',
              onQuantityChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Both buttons disabled
      final minusButton = tester.widget<ShadButton>(find.byKey(const Key('capacity_qty_minus')));
      expect(minusButton.enabled, isFalse);

      final plusButton = tester.widget<ShadButton>(find.byKey(const Key('capacity_qty_plus')));
      expect(plusButton.enabled, isFalse);

      // Sold out warning pill shown
      expect(find.byKey(const Key('capacity_warning_pill')), findsOneWidget);
      expect(find.text('Bucket target reached (0 kg available)'), findsOneWidget);
    });
  });
}
