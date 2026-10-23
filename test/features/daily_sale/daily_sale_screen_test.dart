import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ekshate_app/features/daily_sale/presentation/daily_sale_screen.dart';
import 'package:ekshate_app/features/daily_sale/presentation/daily_sale_controller.dart';
import 'package:ekshate_app/features/daily_sale/domain/daily_listing.dart';
import 'package:ekshate_app/features/daily_sale/domain/batch_bucket.dart';
import 'package:ekshate_app/features/cart/presentation/cart_controller.dart';

void main() {
  void configureViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Widget createDailySaleScreenWidget({
    List<Override> overrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        campaignClockProvider.overrideWithValue(() => DateTime(2026, 10, 22, 14, 0, 0)),
        ...overrides,
      ],
      child: const ShadApp(
        home: DailySaleScreen(),
      ),
    );
  }

  group('DailySaleScreen & BulkDealCard Integration Tests', () {
    testWidgets('renders campaign header with dynamic countdown and active wholesale drops', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createDailySaleScreenWidget());
      await tester.pumpAndSettle();

      // App bar & Campaign Header
      expect(find.text('Ekshate'), findsOneWidget);
      expect(find.text('Daily Bulk Campaign'), findsOneWidget);
      expect(find.text('Active Ordering'), findsWidgets);
      expect(find.text('Countdown to 11:59 PM BDT'), findsOneWidget);

      // Section title
      expect(find.text('Active Wholesale Deals'), findsOneWidget);
      expect(find.text('3 Deals Live'), findsOneWidget);

      // Deals rendered
      expect(find.text('Nagpur Oranges (1 kg)'), findsOneWidget);
      expect(find.text('Miniket Premium Rice (25 kg bag)'), findsOneWidget);
      expect(find.text('Pure Mustard Oil (5 L jar)'), findsOneWidget);
    });

    testWidgets('bulk deal cards render photography, wholesale price, retail strike-through, and discount badge', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createDailySaleScreenWidget());
      await tester.pumpAndSettle();

      // Wholesale unit price: ৳180/kg
      expect(find.text('৳180/kg'), findsOneWidget);

      // Retail benchmark strike-through: ৳240
      expect(find.text('৳240'), findsOneWidget);
      final retailText = tester.widget<Text>(find.text('৳240'));
      expect(retailText.style?.decoration, TextDecoration.lineThrough);

      // Percentage discount badge: 25% OFF
      expect(find.text('25% OFF'), findsOneWidget);
      expect(find.byKey(const Key('discount_badge_listing_orange_01')), findsOneWidget);

      // Savings info
      expect(find.text('Save ৳60/kg'), findsOneWidget);
    });

    testWidgets('real-time batch quota indicator renders volume vs MOQ, emerald progress bar, and active bucket badge', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createDailySaleScreenWidget());
      await tester.pumpAndSettle();

      // 65/100 kg ordered
      expect(find.text('65/100 kg ordered'), findsOneWidget);

      // Active bucket badge: Bucket #1
      expect(find.text('Bucket #1'), findsWidgets);

      // Linear progress bar calculation: 65 / 100 = 0.65
      final progressBars = tester.widgetList<LinearProgressIndicator>(
        find.byKey(const Key('batch_quota_progress_bar')),
      );
      expect(progressBars.isNotEmpty, isTrue);
      final orangeProgressBar = progressBars.first;
      expect(orangeProgressBar.value, 0.65);
      expect(
        (orangeProgressBar.valueColor as AlwaysStoppedAnimation<Color>).value,
        const Color(0xFF10B981), // Emerald progress color
      );

      // Quota percent info
      expect(find.text('65% MOQ reached'), findsOneWidget);
      expect(find.text('35 kg remaining'), findsOneWidget);
    });

    testWidgets('updates subtotal dynamically when quantity selector increments', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createDailySaleScreenWidget());
      await tester.pumpAndSettle();

      // Initial subtotal for 1 kg of oranges: ৳180
      expect(find.text('৳180'), findsWidgets);

      // Find first deal card's plus button
      final plusBtn = find.byKey(const Key('capacity_qty_plus')).first;
      await tester.tap(plusBtn);
      await tester.pumpAndSettle();

      // Quantity is now 2 kg
      expect(find.text('2 kg'), findsOneWidget);

      // Subtotal updated: 2 * 180 = ৳360
      expect(find.text('৳360'), findsOneWidget);
    });

    testWidgets('"Reserve Volume" adds volume to batch cart with haptic & toast confirmation', (tester) async {
      configureViewport(tester);

      final container = ProviderContainer(
        overrides: [
          campaignClockProvider.overrideWithValue(() => DateTime(2026, 10, 22, 14, 0, 0)),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ShadApp(
            home: DailySaleScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Cart starts empty
      expect(container.read(cartProvider), isEmpty);

      // Increment quantity of first deal (Nagpur Oranges) to 3 kg
      final plusBtn = find.byKey(const Key('capacity_qty_plus')).first;
      await tester.tap(plusBtn);
      await tester.pumpAndSettle();
      await tester.tap(plusBtn);
      await tester.pumpAndSettle();

      expect(find.text('3 kg'), findsOneWidget);
      expect(find.text('৳540'), findsOneWidget);

      // Tap "Reserve Volume" button
      final reserveBtn = find.byKey(const Key('reserve_volume_btn_listing_orange_01'));
      expect(reserveBtn, findsOneWidget);
      await tester.tap(reserveBtn);
      await tester.pumpAndSettle();

      // 1. Toast confirmation displayed
      expect(find.text('Added to Batch Cart'), findsOneWidget);
      expect(find.text('Added 3 kg of Nagpur Oranges (1 kg) to your order.'), findsOneWidget);

      // 2. Cart updated in state
      final cart = container.read(cartProvider);
      expect(cart.length, 1);
      final item = cart.first;
      expect(item.listingId, 'listing_orange_01');
      expect(item.productTitle, 'Nagpur Oranges (1 kg)');
      expect(item.quantity, 3.0);
      expect(item.unitPrice, 180.0);
      expect(item.totalAmount, 540.0);
    });

    testWidgets('enforces hard capacity limit and displays warning pill on feed card', (tester) async {
      configureViewport(tester);

      const constrainedListing = DailyListing(
        id: 'listing_test_small',
        productId: 'prod_test_01',
        productTitle: 'Limited Test Produce (1 kg)',
        unit: 'kg',
        marketPrice: 200.0,
        unitPrice: 150.0,
        discountPercent: 25.0,
        moqThreshold: 10.0,
        activeBucketNumber: 1,
        totalBucketsCount: 1,
        totalVolumeOrdered: 8.0,
        status: 'active',
        activeBucket: BatchBucket(
          bucketNumber: 1,
          listingId: 'listing_test_small',
          date: '2026-10-22',
          moqThreshold: 10.0,
          currentQuantity: 8.0,
          remainingCapacity: 2.0, // Only 2 kg remaining!
          status: 'open',
          orderCount: 2,
        ),
      );

      await tester.pumpWidget(
        createDailySaleScreenWidget(
          overrides: [
            dailyListingsProvider.overrideWith(() => _SingleListingController(constrainedListing)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Limited Test Produce (1 kg)'), findsOneWidget);
      expect(find.text('8/10 kg ordered'), findsOneWidget);

      // Tap plus once -> 2 kg (reaches limit)
      final plusBtn = find.byKey(const Key('capacity_qty_plus'));
      await tester.tap(plusBtn);
      await tester.pumpAndSettle();

      expect(find.text('2 kg'), findsOneWidget);

      // Warning pill displayed
      expect(find.byKey(const Key('capacity_warning_pill')), findsOneWidget);
      expect(find.text('Bucket limit reached (2 kg available)'), findsOneWidget);

      // Plus button disabled
      final plusWidget = tester.widget<ShadButton>(plusBtn);
      expect(plusWidget.enabled, isFalse);
    });
  });
}

class _SingleListingController extends DailySaleController {
  final DailyListing singleListing;
  _SingleListingController(this.singleListing);

  @override
  List<DailyListing> build() => [singleListing];
}
