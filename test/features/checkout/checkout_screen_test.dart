import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:ekshate_app/core/router/route_paths.dart';
import 'package:ekshate_app/features/cart/domain/cart_item.dart';
import 'package:ekshate_app/features/cart/presentation/cart_controller.dart';
import 'package:ekshate_app/features/checkout/presentation/checkout_screen.dart';
import 'package:ekshate_app/features/daily_sale/domain/daily_listing.dart';
import 'package:ekshate_app/features/daily_sale/domain/batch_bucket.dart';
import 'package:ekshate_app/features/daily_sale/presentation/daily_sale_controller.dart';
import 'package:ekshate_app/features/auth/domain/user_profile.dart';
import 'package:ekshate_app/features/auth/data/auth_repository.dart';
import 'package:ekshate_app/features/wallet/data/wallet_repository.dart';
import 'package:ekshate_app/features/orders/data/orders_repository.dart';

void main() {
  late MockAuthRepository mockAuthRepo;
  late MockWalletRepository mockWalletRepo;
  late MockOrdersRepository mockOrdersRepo;

  void configureViewport(WidgetTester tester, {bool isDesktop = false}) {
    if (isDesktop) {
      tester.view.physicalSize = const Size(1200, 1000);
    } else {
      tester.view.physicalSize = const Size(400, 900);
    }
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  final sampleListing = const DailyListing(
    id: 'listing_orange_01',
    productId: 'prod_orange_01',
    productTitle: 'Nagpur Oranges (1 kg)',
    unit: 'kg',
    marketPrice: 240.0,
    unitPrice: 180.0,
    discountPercent: 25.0,
    moqThreshold: 100.0,
    activeBucketNumber: 1,
    totalBucketsCount: 1,
    totalVolumeOrdered: 65.0,
    status: 'active',
    imageUrl: 'https://example.com/orange.png',
    activeBucket: BatchBucket(
      bucketNumber: 1,
      listingId: 'listing_orange_01',
      date: '2026-10-24',
      moqThreshold: 100.0,
      currentQuantity: 65.0,
      remainingCapacity: 35.0,
      status: 'open',
      orderCount: 4,
    ),
  );

  Widget createSubject({
    String? deliveryAddress = 'House 12, Road 5, Dhanmondi, Dhaka',
    double initialAvailableBalance = 5000.0,
    List<CartItem>? initialCart,
  }) {
    mockAuthRepo = MockAuthRepository(
      simulatedDelay: Duration.zero,
      initialUser: UserProfile(
        uid: 'user_dev_01',
        phoneNumber: '+8801711000001',
        displayName: 'Sheikh Buyer',
        availableBalance: initialAvailableBalance,
        escrowBalance: 0.0,
        deliveryAddress: deliveryAddress,
      ),
    );

    mockWalletRepo = MockWalletRepository(
      authRepository: mockAuthRepo,
      simulatedDelay: Duration.zero,
    );

    mockOrdersRepo = MockOrdersRepository(
      authRepository: mockAuthRepo,
      walletRepository: mockWalletRepo,
      simulatedDelay: Duration.zero,
    );

    final router = GoRouter(
      initialLocation: RoutePaths.checkout,
      routes: [
        GoRoute(
          path: RoutePaths.checkout,
          builder: (context, state) => const CheckoutScreen(),
        ),
        GoRoute(
          path: RoutePaths.orders,
          builder: (context, state) => const Scaffold(body: Text('Orders Screen Destination')),
        ),
        GoRoute(
          path: RoutePaths.dailySale,
          builder: (context, state) => const Scaffold(body: Text('Daily Sale Screen Destination')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuthRepo),
        walletRepositoryProvider.overrideWithValue(mockWalletRepo),
        ordersRepositoryProvider.overrideWithValue(mockOrdersRepo),
      ],
      child: ShadApp.router(
        routerConfig: router,
      ),
    );
  }

  group('CheckoutScreen Widget Tests', () {
    testWidgets('renders empty state when cart has no items', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      expect(find.text('Your cart is empty'), findsOneWidget);
      expect(find.text('Explore Deals'), findsOneWidget);

      await tester.tap(find.text('Explore Deals'));
      await tester.pumpAndSettle();
      expect(find.text('Daily Sale Screen Destination'), findsOneWidget);
    });

    testWidgets('renders items, confirmed address, and total breakdown', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      // Add item to cart
      final element = tester.element(find.byType(CheckoutScreen));
      final container = ProviderScope.containerOf(element);
      container.read(cartProvider.notifier).addItem(sampleListing, 2.0); // 2 kg @ 180 = 360
      await tester.pumpAndSettle();

      expect(find.text('Checkout'), findsOneWidget);
      expect(find.text('Escrow Safe'), findsOneWidget);

      // Address Section
      expect(find.text('Delivery Destination'), findsOneWidget);
      expect(find.textContaining('House 12, Road 5, Dhanmondi, Dhaka'), findsOneWidget);
      expect(find.text('Confirmed'), findsOneWidget);

      // Item Section
      expect(find.text('Nagpur Oranges (1 kg)'), findsOneWidget);
      expect(find.text('2 kg'), findsOneWidget);
      expect(find.text('৳360'), findsWidgets);

      // Order Summary
      expect(find.text('Order Summary'), findsOneWidget);
      expect(find.text('Items Subtotal'), findsOneWidget);
      expect(find.text('Delivery Fee'), findsOneWidget);

      // Confirm button enabled
      final confirmBtn = find.byKey(const Key('confirm_escrow_funds_btn'));
      expect(confirmBtn, findsOneWidget);
      final btnWidget = tester.widget<ShadButton>(confirmBtn);
      expect(btnWidget.enabled, isTrue);
    });

    testWidgets('prompts user to add address when none exists and blocks order until added', (tester) async {
      configureViewport(tester);
      // Start with null/empty address
      await tester.pumpWidget(createSubject(deliveryAddress: ''));
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(CheckoutScreen));
      final container = ProviderScope.containerOf(element);
      container.read(cartProvider.notifier).addItem(sampleListing, 1.0);
      await tester.pumpAndSettle();

      // Verify no address banner is shown
      expect(find.byKey(const Key('checkout_no_address_banner')), findsOneWidget);
      expect(find.text('Delivery Address Required'), findsOneWidget);
      expect(find.byKey(const Key('checkout_add_address_btn')), findsOneWidget);

      // Verify Confirm & Place Order button is disabled
      final confirmBtn = tester.widget<ShadButton>(find.byKey(const Key('confirm_escrow_funds_btn')).first);
      expect(confirmBtn.enabled, isFalse);

      // Tap Add Delivery Address
      await tester.tap(find.byKey(const Key('checkout_add_address_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Delivery Address'), findsWidgets);
      expect(find.byKey(const Key('checkout_address_input')), findsOneWidget);

      // Enter address and save
      await tester.enterText(
        find.byKey(const Key('checkout_address_input')),
        'Apartment 4B, Road 27, Gulshan 1, Dhaka',
      );
      await tester.tap(find.byKey(const Key('save_delivery_address_btn')));
      await tester.pumpAndSettle();

      // Verified address is now shown
      expect(find.textContaining('Gulshan 1, Dhaka'), findsOneWidget);

      // Button is now enabled
      final updatedConfirmBtn = tester.widget<ShadButton>(find.byKey(const Key('confirm_escrow_funds_btn')).first);
      expect(updatedConfirmBtn.enabled, isTrue);
    });

    testWidgets('applies coupon code and deducts discount from total', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(CheckoutScreen));
      final container = ProviderScope.containerOf(element);
      container.read(cartProvider.notifier).addItem(sampleListing, 2.0); // 360 BDT
      await tester.pumpAndSettle();

      // Enter EKSHATE50 coupon code
      await tester.ensureVisible(find.byKey(const Key('checkout_coupon_input')));
      await tester.enterText(find.byKey(const Key('checkout_coupon_input')), 'EKSHATE50');
      await tester.ensureVisible(find.byKey(const Key('checkout_apply_coupon_btn')));
      await tester.tap(find.byKey(const Key('checkout_apply_coupon_btn')));
      await tester.pumpAndSettle();

      // Coupon applied chip shown
      expect(find.textContaining('EKSHATE50 applied (-৳50)'), findsOneWidget);
      expect(find.byKey(const Key('checkout_remove_coupon_btn')), findsOneWidget);

      // Remove coupon
      await tester.ensureVisible(find.byKey(const Key('checkout_remove_coupon_btn')));
      await tester.tap(find.byKey(const Key('checkout_remove_coupon_btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('checkout_coupon_input')), findsOneWidget);
    });

    testWidgets('adjusting quantity stepper in checkout updates item and total amount', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(CheckoutScreen));
      final container = ProviderScope.containerOf(element);
      container.read(cartProvider.notifier).addItem(sampleListing, 1.0); // 180 BDT
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('checkout_item_qty_listing_orange_01')), findsOneWidget);
      expect(find.text('1 kg'), findsOneWidget);

      // Increment
      await tester.tap(find.byKey(const Key('checkout_item_plus_listing_orange_01')));
      await tester.pumpAndSettle();

      expect(find.text('2 kg'), findsOneWidget);
      expect(find.text('৳360'), findsWidgets);

      // Decrement
      await tester.tap(find.byKey(const Key('checkout_item_minus_listing_orange_01')));
      await tester.pumpAndSettle();

      expect(find.text('1 kg'), findsOneWidget);
      expect(find.text('৳180'), findsWidgets);
    });

    testWidgets('tapping confirm order places order and redirects to /orders', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(CheckoutScreen));
      final container = ProviderScope.containerOf(element);
      container.read(cartProvider.notifier).addItem(sampleListing, 2.0); // 360 BDT
      await tester.pumpAndSettle();

      final confirmBtn = find.byKey(const Key('confirm_escrow_funds_btn'));
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Redirected to orders destination
      expect(find.text('Orders Screen Destination'), findsOneWidget);

      // Cart cleared
      expect(container.read(cartProvider), isEmpty);
    });
  });
}
