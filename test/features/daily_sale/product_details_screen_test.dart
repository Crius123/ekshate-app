import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ekshate_app/features/daily_sale/presentation/product_details_screen.dart';
import 'package:ekshate_app/features/cart/presentation/cart_controller.dart';

void main() {
  void configureViewport(WidgetTester tester, {Size size = const Size(800, 1600)}) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Widget createProductDetailsWidget(String listingId, {ProviderContainer? container}) {
    final scope = container != null
        ? UncontrolledProviderScope(
            container: container,
            child: ShadApp(
              home: ProductDetailsScreen(listingId: listingId),
            ),
          )
        : ProviderScope(
            child: ShadApp(
              home: ProductDetailsScreen(listingId: listingId),
            ),
          );
    return scope;
  }

  group('ProductDetailsScreen Widget & Feature Tests', () {
    testWidgets('renders all photo card details: image, title, pricing, quota, and discount badges', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createProductDetailsWidget('listing_orange_01'));
      await tester.pumpAndSettle();

      // 1. Title and Category
      expect(find.text('Nagpur Oranges (1 kg)'), findsWidgets);
      expect(find.text('Fresh Fruits'), findsWidgets);
      expect(find.text('Base Unit: kg'), findsOneWidget);

      // 2. Overlaid badges
      expect(find.text('25% OFF WHOLESALE'), findsOneWidget);
      expect(find.text('Bucket #1'), findsWidgets);

      // 3. Wholesale Pricing & Retail benchmark
      expect(find.text('৳180/kg'), findsOneWidget);
      expect(find.text('৳240'), findsOneWidget);
      expect(find.text('Save ৳60/kg (25% Off)'), findsOneWidget);

      // 4. Batch Quota details
      expect(find.text('Community Batch Goal'), findsOneWidget);
      expect(find.text('Target MOQ: 100 kg'), findsOneWidget);
      expect(find.text('35 kg remaining'), findsWidgets);

      // 5. Technical Specifications
      expect(find.text('Product Specifications'), findsOneWidget);
      expect(find.text('Sourcing Mandi'), findsOneWidget);
      expect(find.text('Nagpur Wholesale Citrus Mandi'), findsWidgets);
    });

    testWidgets('renders comprehensive Product Description section with description body and highlights', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createProductDetailsWidget('listing_orange_01'));
      await tester.pumpAndSettle();

      // Product Description header
      expect(find.text('Product Description'), findsOneWidget);

      // Description body text
      expect(
        find.textContaining('Farm-fresh sweet and tangy Nagpur oranges directly imported'),
        findsOneWidget,
      );

      // Sourcing & Quality highlights
      expect(find.text('Highlights & Sourcing Quality'), findsOneWidget);
      expect(find.text('Sweet & tangy citrus profile with tender juicy pulp'), findsOneWidget);
      expect(find.text('Rich in natural Vitamin C & antioxidants'), findsOneWidget);
      expect(find.text('Direct import cold-chain transit to Dhaka'), findsOneWidget);
    });

    testWidgets('updates subtotal dynamically and clamps to remaining bucket capacity', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createProductDetailsWidget('listing_orange_01'));
      await tester.pumpAndSettle();

      // Initial subtotal for 1 kg: ৳180
      expect(find.text('Total: ৳180'), findsOneWidget);

      // Tap plus button in quantity selector
      final plusBtn = find.byKey(const Key('capacity_qty_plus'));
      await tester.tap(plusBtn);
      await tester.pumpAndSettle();

      // Quantity increments to 2 kg
      expect(find.text('2 kg'), findsOneWidget);
      expect(find.text('Total: ৳360'), findsOneWidget);
      expect(find.text('Saving ৳120'), findsOneWidget);
    });

    testWidgets('reserves volume and adds item to BatchCart on sticky action bar button tap', (tester) async {
      configureViewport(tester);
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(createProductDetailsWidget('listing_orange_01', container: container));
      await tester.pumpAndSettle();

      // Cart starts empty
      expect(container.read(cartProvider), isEmpty);

      // Tap plus button twice for 3 kg
      final plusBtn = find.byKey(const Key('capacity_qty_plus'));
      await tester.tap(plusBtn);
      await tester.pumpAndSettle();
      await tester.tap(plusBtn);
      await tester.pumpAndSettle();

      expect(find.text('3 kg'), findsOneWidget);
      expect(find.text('Total: ৳540'), findsOneWidget);

      // Tap Reserve Volume button on sticky bottom action bar
      final reserveBtn = find.byKey(const Key('details_reserve_volume_btn_listing_orange_01'));
      expect(reserveBtn, findsOneWidget);
      await tester.tap(reserveBtn);
      await tester.pumpAndSettle();

      // Toast feedback displayed
      expect(find.text('Added to Batch Cart'), findsOneWidget);

      // Cart state updated
      final cart = container.read(cartProvider);
      expect(cart.length, 1);
      expect(cart.first.productTitle, 'Nagpur Oranges (1 kg)');
      expect(cart.first.quantity, 3.0);
      expect(cart.first.totalAmount, 540.0);
    });

    testWidgets('renders desktop two-column layout on wide viewports (>= 900px)', (tester) async {
      configureViewport(tester, size: const Size(1200, 900));
      await tester.pumpWidget(createProductDetailsWidget('listing_orange_01'));
      await tester.pumpAndSettle();

      expect(find.text('Product Description'), findsOneWidget);
      expect(find.text('Product Specifications'), findsOneWidget);
      expect(find.text('Escrow-Protected Wallet'), findsOneWidget);
      expect(find.text('Zero-Loss Guarantee'), findsOneWidget);
    });

    testWidgets('renders not found state when listing id does not exist', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createProductDetailsWidget('non_existent_id'));
      await tester.pumpAndSettle();

      expect(find.text('Product Not Found'), findsOneWidget);
      expect(find.text('Product listing could not be found.'), findsOneWidget);
      expect(find.text('Back to Daily Deals'), findsOneWidget);
    });
  });
}
