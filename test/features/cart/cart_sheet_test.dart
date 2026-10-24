import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ekshate_app/features/cart/domain/cart_item.dart';
import 'package:ekshate_app/features/cart/presentation/cart_controller.dart';
import 'package:ekshate_app/features/cart/presentation/widgets/cart_sheet.dart';
import 'package:ekshate_app/features/daily_sale/domain/daily_listing.dart';
import 'package:ekshate_app/features/daily_sale/domain/batch_bucket.dart';
import 'package:ekshate_app/features/auth/domain/user_profile.dart';
import 'package:ekshate_app/features/auth/data/auth_repository.dart';
import 'package:ekshate_app/features/wallet/data/wallet_repository.dart';

void main() {
  late MockAuthRepository mockAuthRepo;
  late MockWalletRepository mockWalletRepo;

  setUp(() {
    mockAuthRepo = MockAuthRepository(
      initialUser: const UserProfile(
        uid: 'user_dev_01',
        phoneNumber: '+8801711000001',
        displayName: 'Sheikh Buyer',
        availableBalance: 5000.0,
        escrowBalance: 0.0,
        deliveryAddress: 'House 12, Road 5, Dhanmondi, Dhaka',
      ),
    );
    mockWalletRepo = MockWalletRepository(authRepository: mockAuthRepo);
  });

  Widget buildTestApp({required WidgetTester tester}) {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuthRepo),
        walletRepositoryProvider.overrideWithValue(mockWalletRepo),
      ],
      child: ShadApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => CartSheet.show(context),
              child: const Text('Open Cart Sheet'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('CartSheet empty state aligns details in the center vertically and horizontally', (tester) async {
    await tester.pumpWidget(buildTestApp(tester: tester));
    await tester.pumpAndSettle();

    // Open sheet
    await tester.tap(find.text('Open Cart Sheet'));
    await tester.pumpAndSettle();

    expect(find.byType(CartSheet), findsOneWidget);
    expect(find.text('Your batch cart is empty'), findsOneWidget);
    expect(find.text('Select items from today\'s active campaign wholesale drops'), findsOneWidget);
    expect(find.text('Explore Deals'), findsOneWidget);

    // Verify Center alignment widget wraps the empty state content
    final emptyTextFinder = find.text('Your batch cart is empty');
    final centerFinder = find.ancestor(of: emptyTextFinder, matching: find.byType(Center));
    expect(centerFinder, findsWidgets);

    // Verify horizontal and vertical centering within the cart sheet content
    final centerWidgetFinder = find.ancestor(of: emptyTextFinder, matching: find.byType(Center)).first;
    final centerBox = tester.getRect(centerWidgetFinder);
    final emptyTextBox = tester.getRect(emptyTextFinder);

    // Horizontal centering: the text center X matches the Center widget center X
    expect((centerBox.center.dx - emptyTextBox.center.dx).abs(), lessThan(5.0));

    // Vertical centering: the text is centered within the Center widget (which expands to fill sheet content)
    expect(centerBox.height, greaterThan(500.0));
    expect((centerBox.center.dy - emptyTextBox.center.dy).abs(), lessThan(30.0));
    // The empty state text is vertically centered on the 800px viewport (within ~40px of screen center)
    expect((400.0 - emptyTextBox.center.dy).abs(), lessThan(50.0));
  });

  testWidgets('CartSheet item card displays product image, details, stepper, and adjusts quantity', (tester) async {
    await tester.pumpWidget(buildTestApp(tester: tester));
    await tester.pumpAndSettle();

    // Add item to cart
    final element = tester.element(find.text('Open Cart Sheet'));
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
            imageUrl: 'https://example.com/orange.png',
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
          2.0, // 2 kg @ 180 = 360
        );

    // Open sheet
    await tester.tap(find.text('Open Cart Sheet'));
    await tester.pumpAndSettle();

    // Verify product card is displayed
    expect(find.byKey(const Key('cart_sheet_item_listing_orange_01')), findsOneWidget);
    expect(find.text('Nagpur Oranges (1 kg)'), findsOneWidget);
    expect(find.text('৳180 / kg'), findsOneWidget);
    expect(find.text('৳360'), findsWidgets);

    // Verify quantity selector and current quantity
    expect(find.byKey(const Key('cart_sheet_qty_listing_orange_01')), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.byKey(const Key('cart_sheet_plus_listing_orange_01')), findsOneWidget);
    expect(find.byKey(const Key('cart_sheet_minus_listing_orange_01')), findsOneWidget);

    // Tap plus button to increment quantity
    await tester.tap(find.byKey(const Key('cart_sheet_plus_listing_orange_01')));
    await tester.pumpAndSettle();

    expect(find.text('3'), findsOneWidget);
    expect(find.text('৳540'), findsWidgets); // 3 * 180 = 540

    // Tap minus button to decrement quantity
    await tester.tap(find.byKey(const Key('cart_sheet_minus_listing_orange_01')));
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);
    expect(find.text('৳360'), findsWidgets);

    // Tap remove button
    await tester.tap(find.byKey(const Key('cart_sheet_remove_listing_orange_01')));
    await tester.pumpAndSettle();

    // Sheet should now display empty state
    expect(find.text('Your batch cart is empty'), findsOneWidget);
  });
}
