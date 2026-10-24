import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ekshate_app/features/auth/domain/user_profile.dart';
import 'package:ekshate_app/features/auth/data/auth_repository.dart';
import 'package:ekshate_app/features/wallet/data/wallet_repository.dart';
import 'package:ekshate_app/features/orders/domain/order_entity.dart';
import 'package:ekshate_app/features/orders/data/orders_repository.dart';
import 'package:ekshate_app/features/orders/presentation/orders_screen.dart';
import 'package:ekshate_app/features/orders/presentation/orders_controller.dart';

void main() {
  late MockAuthRepository mockAuthRepo;
  late MockWalletRepository mockWalletRepo;
  late MockOrdersRepository mockOrdersRepo;

  void configureViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Widget createTestWidget({List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuthRepo),
        walletRepositoryProvider.overrideWithValue(mockWalletRepo),
        ordersRepositoryProvider.overrideWithValue(mockOrdersRepo),
        ...overrides,
      ],
      child: const ShadApp(
        home: OrdersScreen(),
      ),
    );
  }

  setUp(() {
    mockAuthRepo = MockAuthRepository(
      initialUser: const UserProfile(
        uid: 'user_dev_01',
        phoneNumber: '+8801711000001',
        displayName: 'Sheikh Buyer',
        availableBalance: 5000.0,
        escrowBalance: 1800.0,
        deliveryAddress: 'House 12, Road 5, Dhanmondi, Dhaka',
      ),
      simulatedDelay: Duration.zero,
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
  });

  group('OrdersScreen Dashboard & Order Tracking Widget Tests', () {
    testWidgets('renders app bar, midnight settlement banner, and segmented filter tabs', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // App bar title
      expect(find.text('My Bulk Orders'), findsOneWidget);

      // Midnight settlement banner
      expect(find.textContaining('Midnight Settlement (11:59 PM BDT)'), findsOneWidget);

      // Filter tabs
      expect(find.text('Pending Orders'), findsOneWidget);
      expect(find.text('Confirmed Deals'), findsOneWidget);
      expect(find.text('Dispatched (In Transit)'), findsOneWidget);
      expect(find.text('Refunded Deals'), findsOneWidget);

      // Badge counts for initial seed
      expect(find.text('1'), findsNWidgets(3)); // 1 pending, 1 confirmed, 1 refunded in seed
      expect(find.text('0'), findsOneWidget); // 0 dispatched initially
    });

    testWidgets('default tab displays active pending escrow order with badge, bucket, and explanation', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Product Title
      expect(find.text('Nagpur Oranges (1 kg)'), findsOneWidget);

      // Status Badge
      expect(find.text('PENDING'), findsOneWidget);

      // Allocated Bucket & Info
      expect(find.text('Allocated Bucket #1'), findsOneWidget);

      // Quantity & Total Escrow
      expect(find.text('Quantity Ordered'), findsOneWidget);
      expect(find.text('10 kg'), findsOneWidget);
      expect(find.text('Amount on Hold'), findsOneWidget);
      expect(find.text('৳1800'), findsOneWidget);

      // Delivery Destination
      expect(find.text('Delivery: House 12, Road 5, Dhanmondi, Dhaka'), findsOneWidget);

      // Explanatory Banner
      expect(find.text('Payment is held safely until the group reaches its wholesale target.'), findsOneWidget);
    });

    testWidgets('tapping Confirmed Deals tab filters and displays confirmed order with emerald badge', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap on Confirmed Deals tab
      await tester.tap(find.text('Confirmed Deals'));
      await tester.pumpAndSettle();

      // Should show Miniket Premium Rice
      expect(find.text('Miniket Premium Rice (25 kg bag)'), findsOneWidget);
      expect(find.text('CONFIRMED'), findsOneWidget);
      expect(find.text('1 bag'), findsOneWidget);
      expect(find.text('৳1750'), findsOneWidget);
      expect(find.text('Bucket met MOQ and order is queued for morning procurement.'), findsOneWidget);

      // Should NOT show pending or refunded orders in this tab
      expect(find.text('Nagpur Oranges (1 kg)'), findsNothing);
      expect(find.text('Pure Mustard Oil (5 L jar)'), findsNothing);
    });

    testWidgets('tapping Dispatched tab filters and renders courier partner pill, tracking code, copy button, and parcel weight', (tester) async {
      configureViewport(tester);

      final dispatchedOrder = OrderEntity(
        orderId: 'ord_disp_001',
        userId: 'user_dev_01',
        listingId: 'listing_rice_02',
        bucketNumber: 1,
        productTitle: 'Miniket Premium Rice (25 kg bag)',
        quantity: 2.0,
        unit: 'bag',
        unitPrice: 1750.0,
        totalAmount: 3500.0,
        status: 'dispatched',
        deliveryAddress: 'House 12, Road 5, Dhanmondi, Dhaka',
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
        date: '2026-10-23',
        courierPartner: 'pathao',
        consignmentId: 'PTH-CON-disp001',
        trackingCode: 'PTH-TRK-disp001',
        trackingUrl: 'https://pathao.com/courier/tracking/?consignment_id=PTH-CON-disp001',
        dispatchedAt: DateTime.now().subtract(const Duration(hours: 1)),
        parcelWeightKg: 50.0,
      );

      final repoWithDispatched = MockOrdersRepository(
        authRepository: mockAuthRepo,
        walletRepository: mockWalletRepo,
        initialOrders: [dispatchedOrder],
        simulatedDelay: Duration.zero,
      );

      await tester.pumpWidget(createTestWidget(overrides: [
        ordersRepositoryProvider.overrideWithValue(repoWithDispatched),
      ]));
      await tester.pumpAndSettle();

      // Switch to Dispatched tab
      await tester.tap(find.text('Dispatched (In Transit)'));
      await tester.pumpAndSettle();

      // Product Title
      expect(find.text('Miniket Premium Rice (25 kg bag)'), findsOneWidget);

      // Status Badge
      expect(find.text('DISPATCHED'), findsOneWidget);

      // Courier Partner Pill
      expect(find.text('Pathao Courier'), findsOneWidget);

      // Parcel Weight Tag
      expect(find.text('Weight: 50.0 kg'), findsOneWidget);

      // Tracking code
      expect(find.text('Tracking: PTH-TRK-disp001'), findsOneWidget);

      // Copy action button
      expect(find.text('Copy'), findsOneWidget);

      // Explanatory Banner
      expect(find.textContaining('Consignment booked via PATHAO'), findsOneWidget);
    });

    testWidgets('tapping copy on tracking code copies to clipboard and displays toast feedback', (tester) async {
      configureViewport(tester);

      final dispatchedOrder = OrderEntity(
        orderId: 'ord_disp_002',
        userId: 'user_dev_01',
        listingId: 'listing_orange_01',
        bucketNumber: 1,
        productTitle: 'Nagpur Oranges (1 kg)',
        quantity: 10.0,
        unit: 'kg',
        unitPrice: 180.0,
        totalAmount: 1800.0,
        status: 'dispatched',
        deliveryAddress: 'House 12, Road 5, Dhanmondi, Dhaka',
        createdAt: DateTime.now(),
        courierPartner: 'steadfast',
        consignmentId: 'SF-CON-disp002',
        trackingCode: 'SF-TRK-disp002',
        parcelWeightKg: 10.0,
      );

      final repoWithDispatched = MockOrdersRepository(
        authRepository: mockAuthRepo,
        walletRepository: mockWalletRepo,
        initialOrders: [dispatchedOrder],
        simulatedDelay: Duration.zero,
      );

      await tester.pumpWidget(createTestWidget(overrides: [
        ordersRepositoryProvider.overrideWithValue(repoWithDispatched),
      ]));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dispatched (In Transit)'));
      await tester.pumpAndSettle();

      expect(find.text('Steadfast Courier'), findsOneWidget);

      // Tap Copy button
      await tester.tap(find.text('Copy'));
      await tester.pumpAndSettle();

      // Verify Toast appeared
      expect(find.text('Tracking Code Copied'), findsOneWidget);
    });

    testWidgets('tapping Refunded Deals tab filters and displays refunded order with red badge', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap on Refunded Deals tab
      await tester.tap(find.text('Refunded Deals'));
      await tester.pumpAndSettle();

      // Should show Pure Mustard Oil
      expect(find.text('Pure Mustard Oil (5 L jar)'), findsOneWidget);
      expect(find.text('REFUNDED'), findsOneWidget);
      expect(find.text('2 jar'), findsOneWidget);
      expect(find.text('৳1560'), findsOneWidget);
      expect(find.text('Group did not meet target MOQ and payment was refunded to your available balance.'), findsOneWidget);

      // Should NOT show pending or confirmed orders in this tab
      expect(find.text('Nagpur Oranges (1 kg)'), findsNothing);
      expect(find.text('Miniket Premium Rice (25 kg bag)'), findsNothing);
    });

    testWidgets('displays tailored empty state when a tab has zero orders', (tester) async {
      configureViewport(tester);

      final emptyOrdersRepo = MockOrdersRepository(
        authRepository: mockAuthRepo,
        walletRepository: mockWalletRepo,
        initialOrders: const [],
        simulatedDelay: Duration.zero,
      );

      await tester.pumpWidget(createTestWidget(overrides: [
        ordersRepositoryProvider.overrideWithValue(emptyOrdersRepo),
      ]));
      await tester.pumpAndSettle();

      // Empty state for Active Escrow
      expect(find.text('No Pending Orders'), findsOneWidget);
      expect(find.text('You have no orders currently waiting in open groups.'), findsOneWidget);

      // Tap Confirmed Deals
      await tester.tap(find.text('Confirmed Deals'));
      await tester.pumpAndSettle();
      expect(find.text('No Confirmed Deals Yet'), findsOneWidget);

      // Tap Dispatched
      await tester.tap(find.text('Dispatched (In Transit)'));
      await tester.pumpAndSettle();
      expect(find.text('No Dispatched Orders'), findsOneWidget);

      // Tap Refunded Deals
      await tester.tap(find.text('Refunded Deals'));
      await tester.pumpAndSettle();
      expect(find.text('No Refunded Deals'), findsOneWidget);
    });

    testWidgets('dynamic courier dispatch simulation transitions confirmed order to dispatched', (tester) async {
      configureViewport(tester);
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepo),
          walletRepositoryProvider.overrideWithValue(mockWalletRepo),
          ordersRepositoryProvider.overrideWithValue(mockOrdersRepo),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const ShadApp(
            home: OrdersScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check Confirmed Deals initially has 1 order
      await tester.tap(find.text('Confirmed Deals'));
      await tester.pumpAndSettle();
      expect(find.text('Miniket Premium Rice (25 kg bag)'), findsOneWidget);

      // Dispatch morning confirmed orders via courier API simulation
      await container.read(ordersListProvider.notifier).simulateDispatch(
        campaignDate: '2026-10-21',
        courierPartner: 'redx',
      );
      await tester.pumpAndSettle();

      // Confirmed Deals tab is now empty
      expect(find.text('No Confirmed Deals Yet'), findsOneWidget);

      // Switch to Dispatched tab
      await tester.tap(find.text('Dispatched (In Transit)'));
      await tester.pumpAndSettle();

      // Miniket Premium Rice is now in Dispatched tab!
      expect(find.text('Miniket Premium Rice (25 kg bag)'), findsOneWidget);
      expect(find.text('DISPATCHED'), findsOneWidget);
      expect(find.text('RedX Delivery'), findsOneWidget);
      expect(find.text('Tracking: REDX-TRK-rice_000'), findsOneWidget);
    });
  });
}
