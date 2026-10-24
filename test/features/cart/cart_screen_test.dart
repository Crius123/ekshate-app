import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:ekshate_app/core/router/route_paths.dart';
import 'package:ekshate_app/features/auth/domain/user_profile.dart';
import 'package:ekshate_app/features/auth/data/auth_repository.dart';
import 'package:ekshate_app/features/wallet/data/wallet_repository.dart';
import 'package:ekshate_app/features/orders/data/orders_repository.dart';
import 'package:ekshate_app/features/cart/domain/cart_item.dart';
import 'package:ekshate_app/features/cart/presentation/cart_controller.dart';
import 'package:ekshate_app/features/cart/presentation/cart_screen.dart';
import 'package:ekshate_app/features/daily_sale/domain/daily_listing.dart';
import 'package:ekshate_app/features/daily_sale/domain/batch_bucket.dart';

void main() {
  late MockAuthRepository mockAuthRepo;
  late MockWalletRepository mockWalletRepo;
  late MockOrdersRepository mockOrdersRepo;

  void configureViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Widget createSubject({
    List<CartItem>? initialCart,
    double initialAvailableBalance = 5000.0,
    String? deliveryAddress = 'House 12, Road 5, Dhanmondi, Dhaka',
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
      initialLocation: RoutePaths.cart,
      routes: [
        GoRoute(
          path: RoutePaths.cart,
          builder: (context, state) => const CartScreen(),
        ),
        GoRoute(
          path: RoutePaths.orders,
          builder: (context, state) => const Scaffold(body: Text('Orders Screen Destination')),
        ),
        GoRoute(
          path: RoutePaths.checkout,
          builder: (context, state) => const Scaffold(body: Text('Checkout Screen Destination')),
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

  group('Batch Cart Screen Widget Tests', () {
    testWidgets('renders empty cart view when no items reserved', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      expect(find.text('Batch Order Cart'), findsOneWidget);
      expect(find.text('Your batch cart is empty'), findsOneWidget);
      expect(find.text('Explore Wholesale Drops'), findsOneWidget);

      // Tapping "Explore Wholesale Drops" navigates to daily sale
      await tester.tap(find.text('Explore Wholesale Drops'));
      await tester.pumpAndSettle();

      expect(find.text('Daily Sale Screen Destination'), findsOneWidget);
    });

    testWidgets('renders reserved items, unit prices, volume steppers, and subtotal', (tester) async {
      configureViewport(tester);
      final widget = createSubject();
      await tester.pumpWidget(widget);
      await tester.pumpAndSettle();

      // Seed cart item using riverpod container
      final element = tester.element(find.byType(CartScreen));
      final container = ProviderScope.containerOf(element);

      container.read(cartProvider.notifier).addItem(
            const DailyListing(
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
              activeBucket: BatchBucket(
                bucketNumber: 1,
                listingId: 'listing_orange_01',
                date: '2026-10-22',
                moqThreshold: 100.0,
                currentQuantity: 65.0,
                remainingCapacity: 35.0,
                status: 'open',
                orderCount: 4,
              ),
            ),
            5.0, // 5 kg @ 180 = 900 BDT
          );

      await tester.pumpAndSettle();

      // Verify item details
      expect(find.text('Nagpur Oranges (1 kg)'), findsOneWidget);
      expect(find.text('৳180 / kg'), findsOneWidget);
      expect(find.text('5 kg'), findsOneWidget);
      expect(find.text('৳900'), findsWidgets); // item total and subtotal

      // Verify delivery address review card
      expect(find.text('Delivery Address Review'), findsOneWidget);
      expect(find.textContaining('House 12, Road 5, Dhanmondi, Dhaka'), findsOneWidget);

      // Verify summary contrast
      expect(find.text('Customer Available Balance:'), findsOneWidget);
      expect(find.text('৳5000'), findsOneWidget);
      expect(find.text('Total Order Amount:'), findsOneWidget);

      // Verify proceed to checkout button enabled
      final checkoutBtn = find.byKey(const Key('proceed_to_checkout_btn'));
      expect(checkoutBtn, findsOneWidget);
      expect(find.textContaining('Proceed to Checkout'), findsOneWidget);
    });

    testWidgets('volume stepper increments and decrements quantity and recalculates totals', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(CartScreen));
      final container = ProviderScope.containerOf(element);

      container.read(cartProvider.notifier).addItem(
            const DailyListing(
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
              activeBucket: BatchBucket(
                bucketNumber: 1,
                listingId: 'listing_orange_01',
                date: '2026-10-22',
                moqThreshold: 100.0,
                currentQuantity: 65.0,
                remainingCapacity: 35.0,
                status: 'open',
                orderCount: 4,
              ),
            ),
            3.0, // 3 * 180 = 540 BDT
          );
      await tester.pumpAndSettle();

      expect(find.text('3 kg'), findsOneWidget);
      expect(find.text('৳540'), findsWidgets);

      // Tap Plus button
      await tester.tap(find.byKey(const Key('cart_item_plus_listing_orange_01')));
      await tester.pumpAndSettle();

      expect(find.text('4 kg'), findsOneWidget);
      expect(find.text('৳720'), findsWidgets);

      // Tap Minus button
      await tester.tap(find.byKey(const Key('cart_item_minus_listing_orange_01')));
      await tester.pumpAndSettle();

      expect(find.text('3 kg'), findsOneWidget);
      expect(find.text('৳540'), findsWidgets);
    });

    testWidgets('insufficient available balance disables checkout and shows deficit banner with 1-tap bKash topup', (tester) async {
      configureViewport(tester);
      // User has only 500 BDT available
      await tester.pumpWidget(createSubject(initialAvailableBalance: 500.0));
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(CartScreen));
      final container = ProviderScope.containerOf(element);

      container.read(cartProvider.notifier).addItem(
            const DailyListing(
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
              activeBucket: BatchBucket(
                bucketNumber: 1,
                listingId: 'listing_orange_01',
                date: '2026-10-22',
                moqThreshold: 100.0,
                currentQuantity: 65.0,
                remainingCapacity: 35.0,
                status: 'open',
                orderCount: 4,
              ),
            ),
            10.0, // 10 * 180 = 1800 BDT. Deficit: 1800 - 500 = 1300 BDT
          );
      await tester.pumpAndSettle();

      // Check alert banner
      expect(find.byKey(const Key('insufficient_balance_alert')), findsOneWidget);
      expect(find.text('Insufficient Available Balance'), findsOneWidget);
      expect(find.textContaining('You need ৳1300 more'), findsOneWidget);

      // Check 1-tap bKash shortcut button
      final bkashBtn = find.byKey(const Key('cart_topup_bkash_btn'));
      expect(bkashBtn, findsOneWidget);
      expect(find.text('Top-up ৳1300 via bKash'), findsOneWidget);

      // Verify Proceed to Checkout button is enabled
      final proceedBtn = tester.widget<ShadButton>(find.byKey(const Key('proceed_to_checkout_btn')));
      expect(proceedBtn.enabled, isTrue);

      // Tap 1-tap bKash button opens DepositModal
      await tester.tap(bkashBtn);
      await tester.pumpAndSettle();

      expect(find.text('Deposit Funds'), findsOneWidget);
      expect(find.text('1300'), findsOneWidget); // Pre-filled with deficit amount!
    });

    testWidgets('tapping "Proceed to Checkout" navigates to /checkout screen', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createSubject(initialAvailableBalance: 10000.0));
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(CartScreen));
      final container = ProviderScope.containerOf(element);

      container.read(cartProvider.notifier).addItem(
            const DailyListing(
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
              activeBucket: BatchBucket(
                bucketNumber: 1,
                listingId: 'listing_orange_01',
                date: '2026-10-22',
                moqThreshold: 100.0,
                currentQuantity: 65.0,
                remainingCapacity: 35.0,
                status: 'open',
                orderCount: 4,
              ),
            ),
            5.0, // 900 BDT
          );
      await tester.pumpAndSettle();

      final proceedBtn = find.byKey(const Key('proceed_to_checkout_btn'));
      expect(proceedBtn, findsOneWidget);

      // Tap Proceed to Checkout
      await tester.tap(proceedBtn);
      await tester.pumpAndSettle();

      // Redirected to checkout screen
      expect(find.text('Checkout Screen Destination'), findsOneWidget);
    });

    testWidgets('tapping delete button removes item from cart', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(CartScreen));
      final container = ProviderScope.containerOf(element);

      container.read(cartProvider.notifier).addItem(
            const DailyListing(
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
              activeBucket: BatchBucket(
                bucketNumber: 1,
                listingId: 'listing_orange_01',
                date: '2026-10-22',
                moqThreshold: 100.0,
                currentQuantity: 65.0,
                remainingCapacity: 35.0,
                status: 'open',
                orderCount: 4,
              ),
            ),
            2.0,
          );
      await tester.pumpAndSettle();

      expect(find.text('Nagpur Oranges (1 kg)'), findsOneWidget);

      // Tap remove button
      await tester.tap(find.byKey(const Key('cart_item_remove_listing_orange_01')));
      await tester.pumpAndSettle();

      // Cart is empty again
      expect(find.text('Your batch cart is empty'), findsOneWidget);
    });
  });
}
