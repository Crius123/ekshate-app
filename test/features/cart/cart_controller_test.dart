import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ekshate_app/features/cart/presentation/cart_controller.dart';
import 'package:ekshate_app/features/daily_sale/domain/daily_listing.dart';
import 'package:ekshate_app/features/daily_sale/domain/batch_bucket.dart';
import 'package:ekshate_app/features/auth/domain/user_profile.dart';
import 'package:ekshate_app/features/auth/data/auth_repository.dart';
import 'package:ekshate_app/features/wallet/data/wallet_repository.dart';
import 'package:ekshate_app/features/orders/data/orders_repository.dart';
import 'package:ekshate_app/core/errors/app_exception.dart';

void main() {
  group('CartController & CartItem Domain Tests', () {
    late ProviderContainer container;

    final testListing = DailyListing(
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
      activeBucket: const BatchBucket(
        bucketNumber: 1,
        listingId: 'listing_orange_01',
        date: '2026-10-22',
        moqThreshold: 100.0,
        currentQuantity: 65.0,
        remainingCapacity: 35.0,
        status: 'open',
        orderCount: 4,
      ),
    );

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial cart state is empty with zero total', () {
      final cart = container.read(cartProvider);
      final total = container.read(cartTotalAmountProvider);

      expect(cart, isEmpty);
      expect(total, 0.0);
    });

    test('addItem adds item and calculates total amount correctly', () {
      final controller = container.read(cartProvider.notifier);
      controller.addItem(testListing, 5.0);

      final cart = container.read(cartProvider);
      final total = container.read(cartTotalAmountProvider);

      expect(cart.length, 1);
      expect(cart.first.listingId, 'listing_orange_01');
      expect(cart.first.quantity, 5.0);
      expect(cart.first.unitPrice, 180.0);
      expect(cart.first.totalAmount, 900.0);
      expect(total, 900.0);
    });

    test('addItem clamps and combines quantity when same item is added again', () {
      final controller = container.read(cartProvider.notifier);
      controller.addItem(testListing, 5.0);
      controller.addItem(testListing, 10.0);

      final cart = container.read(cartProvider);
      expect(cart.length, 1);
      expect(cart.first.quantity, 15.0);
      expect(cart.first.totalAmount, 2700.0);
    });

    test('addItem throws BucketCapacityExceededException if requested quantity exceeds capacity', () {
      final controller = container.read(cartProvider.notifier);

      // Remaining capacity is 35.0. Attempting to add 40.0
      expect(
        () => controller.addItem(testListing, 40.0),
        throwsA(isA<BucketCapacityExceededException>()),
      );
    });

    test('updateQuantity updates volume within clamp limits', () {
      final controller = container.read(cartProvider.notifier);
      controller.addItem(testListing, 5.0);

      controller.updateQuantity('listing_orange_01', 8.0);
      expect(container.read(cartProvider).first.quantity, 8.0);

      // Clamps to maxAllowedCapacity (35.0)
      controller.updateQuantity('listing_orange_01', 50.0);
      expect(container.read(cartProvider).first.quantity, 35.0);

      // Clamps to minimum (1.0)
      controller.updateQuantity('listing_orange_01', 0.0);
      expect(container.read(cartProvider).first.quantity, 1.0);
    });

    test('removeItem removes item from batch cart', () {
      final controller = container.read(cartProvider.notifier);
      controller.addItem(testListing, 5.0);
      expect(container.read(cartProvider), isNotEmpty);

      controller.removeItem('listing_orange_01');
      expect(container.read(cartProvider), isEmpty);
      expect(container.read(cartTotalAmountProvider), 0.0);
    });

    test('clearCart empties all items', () {
      final controller = container.read(cartProvider.notifier);
      controller.addItem(testListing, 5.0);
      controller.clearCart();

      expect(container.read(cartProvider), isEmpty);
    });

    test('validateCheckoutSufficientFunds throws when balance is less than required', () {
      final controller = container.read(cartProvider.notifier);
      controller.addItem(testListing, 5.0); // 900 BDT

      expect(
        () => controller.validateCheckoutSufficientFunds(500.0),
        throwsA(isA<InsufficientWalletBalanceException>()),
      );

      // Does not throw when balance is sufficient
      expect(
        () => controller.validateCheckoutSufficientFunds(1000.0),
        returnsNormally,
      );
    });

    test('checkout executes atomic escrow reservation, updates balances and clears cart', () async {
      final mockAuth = MockAuthRepository(
        initialUser: const UserProfile(
          uid: 'user_dev_01',
          phoneNumber: '+8801711000001',
          displayName: 'Sheikh Buyer',
          availableBalance: 5000.0,
          escrowBalance: 0.0,
          deliveryAddress: 'House 12, Road 5, Dhanmondi, Dhaka',
        ),
      );
      final mockWallet = MockWalletRepository(authRepository: mockAuth);
      final mockOrders = MockOrdersRepository(
        authRepository: mockAuth,
        walletRepository: mockWallet,
        simulatedDelay: Duration.zero,
      );

      final testContainer = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuth),
          walletRepositoryProvider.overrideWithValue(mockWallet),
          ordersRepositoryProvider.overrideWithValue(mockOrders),
        ],
      );

      final controller = testContainer.read(cartProvider.notifier);
      controller.addItem(testListing, 10.0); // 10 * 180 = 1800 BDT

      final placed = await controller.checkout(
        deliveryAddress: 'House 12, Road 5, Dhanmondi, Dhaka',
      );

      expect(placed.length, 1);
      expect(placed.first.listingId, 'listing_orange_01');
      expect(placed.first.totalAmount, 1800.0);
      expect(placed.first.status, 'pending_bucket');

      // 1. Cart must be cleared
      expect(testContainer.read(cartProvider), isEmpty);

      // 2. Available balance must be debited, escrow credited
      final updatedUser = mockAuth.currentUser!;
      expect(updatedUser.availableBalance, 3200.0); // 5000 - 1800
      expect(updatedUser.escrowBalance, 1800.0);   // 0 + 1800

      // 3. Wallet ledger must contain order_hold
      final txs = mockWallet.currentTransactions;
      expect(txs.any((t) => t.type == 'order_hold' && t.amount == -1800.0), isTrue);

      testContainer.dispose();
    });
  });
}
