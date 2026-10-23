import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ekshate_app/features/orders/data/orders_repository.dart';
import 'package:ekshate_app/features/orders/presentation/orders_controller.dart';
import 'package:ekshate_app/features/auth/domain/user_profile.dart';
import 'package:ekshate_app/features/auth/data/auth_repository.dart';
import 'package:ekshate_app/features/wallet/data/wallet_repository.dart';
import 'package:ekshate_app/core/errors/app_exception.dart';

void main() {
  group('OrdersRepository & OrdersController Integration Tests', () {
    late MockAuthRepository mockAuth;
    late MockWalletRepository mockWallet;
    late MockOrdersRepository ordersRepo;
    late ProviderContainer container;

    setUp(() {
      mockAuth = MockAuthRepository(
        initialUser: const UserProfile(
          uid: 'user_dev_01',
          phoneNumber: '+8801711000001',
          displayName: 'Sheikh Buyer',
          availableBalance: 5000.0,
          escrowBalance: 1800.0,
          deliveryAddress: 'House 12, Road 5, Dhanmondi, Dhaka',
        ),
      );
      mockWallet = MockWalletRepository(authRepository: mockAuth);
      ordersRepo = MockOrdersRepository(
        authRepository: mockAuth,
        walletRepository: mockWallet,
        simulatedDelay: Duration.zero,
      );

      container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuth),
          walletRepositoryProvider.overrideWithValue(mockWallet),
          ordersRepositoryProvider.overrideWithValue(ordersRepo),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('initial orders provider yields seeded orders and segmented counts', () {
      final orders = container.read(ordersListProvider);
      expect(orders.length, 3);
      expect(orders[0].listingId, 'listing_orange_01');
      expect(orders[0].status, 'pending_bucket');
      expect(orders[1].status, 'confirmed');
      expect(orders[2].status, 'refunded');

      final counts = container.read(orderCountsProvider);
      expect(counts[OrderFilterTab.activeEscrow], 1);
      expect(counts[OrderFilterTab.confirmed], 1);
      expect(counts[OrderFilterTab.refunded], 1);

      // Default filter is activeEscrow
      final filteredPending = container.read(filteredOrdersProvider);
      expect(filteredPending.length, 1);
      expect(filteredPending.first.status, 'pending_bucket');

      // Switch tab to confirmed
      container.read(orderFilterTabProvider.notifier).state = OrderFilterTab.confirmed;
      final filteredConfirmed = container.read(filteredOrdersProvider);
      expect(filteredConfirmed.length, 1);
      expect(filteredConfirmed.first.status, 'confirmed');

      // Switch tab to refunded
      container.read(orderFilterTabProvider.notifier).state = OrderFilterTab.refunded;
      final filteredRefunded = container.read(filteredOrdersProvider);
      expect(filteredRefunded.length, 1);
      expect(filteredRefunded.first.status, 'refunded');
    });

    test('placeOrder rejects when available balance is insufficient', () async {
      // 30 kg @ 200 = 6000 > 5000
      expect(
        () => ordersRepo.placeOrder(
          listingId: 'listing_orange_01',
          productTitle: 'Nagpur Oranges (1 kg)',
          quantity: 30.0,
          unit: 'kg',
          unitPrice: 200.0,
          deliveryAddress: 'House 12, Road 5, Dhanmondi, Dhaka',
          date: '2026-10-22',
        ),
        throwsA(isA<InsufficientWalletBalanceException>()),
      );

      // Balances must remain unchanged
      expect(mockAuth.currentUser!.availableBalance, 5000.0);
      expect(mockAuth.currentUser!.escrowBalance, 1800.0);
    });

    test('placeOrder successfully deducts available balance, credits escrow, and writes audit ledger', () async {
      // 10 kg @ 180 = 1800 BDT
      final order = await ordersRepo.placeOrder(
        listingId: 'listing_orange_01',
        productTitle: 'Nagpur Oranges (1 kg)',
        quantity: 10.0,
        unit: 'kg',
        unitPrice: 180.0,
        deliveryAddress: 'House 12, Road 5, Dhanmondi, Dhaka',
        date: '2026-10-22',
        bucketNumber: 1,
      );

      expect(order.orderId.startsWith('ord_'), isTrue);
      expect(order.status, 'pending_bucket');
      expect(order.totalAmount, 1800.0);
      expect(order.deliveryAddress, 'House 12, Road 5, Dhanmondi, Dhaka');

      // 1. Verify User Balances
      final updatedUser = mockAuth.currentUser!;
      expect(updatedUser.availableBalance, 3200.0); // 5000 - 1800
      expect(updatedUser.escrowBalance, 3600.0);    // 1800 + 1800

      // 2. Verify Wallet Audit Ledger
      final txs = mockWallet.currentTransactions;
      final holdTx = txs.firstWhere((t) => t.orderId == order.orderId);
      expect(holdTx.type, 'order_hold');
      expect(holdTx.amount, -1800.0);
      expect(holdTx.gateway, 'internal');

      // 3. Verify Order appears in reactive provider
      await Future.delayed(const Duration(milliseconds: 10));
      final currentOrders = container.read(ordersListProvider);
      expect(currentOrders.first.orderId, order.orderId);
    });

    test('simulateSettlement with targetMet confirms orders, captures escrow, and logs order_settle', () async {
      await container.read(ordersListProvider.notifier).simulateSettlement(
        campaignDate: '2026-10-21',
        targetMet: true,
      );

      final orders = container.read(ordersListProvider);
      final orangeOrder = orders.firstWhere((o) => o.orderId == 'ord_orange_001');
      expect(orangeOrder.status, 'confirmed');

      // User escrow balance captured: 1800 - 1800 = 0
      expect(mockAuth.currentUser!.escrowBalance, 0.0);
      expect(mockAuth.currentUser!.availableBalance, 5000.0);

      // Verify transaction ledger
      final txs = mockWallet.currentTransactions;
      final settleTx = txs.firstWhere((t) => t.orderId == 'ord_orange_001' && t.type == 'order_settle');
      expect(settleTx.amount, 1800.0);
    });

    test('simulateSettlement with targetMet=false refunds orders, restores available balance, and logs order_refund', () async {
      await container.read(ordersListProvider.notifier).simulateSettlement(
        campaignDate: '2026-10-21',
        targetMet: false,
      );

      final orders = container.read(ordersListProvider);
      final orangeOrder = orders.firstWhere((o) => o.orderId == 'ord_orange_001');
      expect(orangeOrder.status, 'refunded');

      // User escrow restored: available 5000 + 1800 = 6800, escrow 1800 - 1800 = 0
      expect(mockAuth.currentUser!.availableBalance, 6800.0);
      expect(mockAuth.currentUser!.escrowBalance, 0.0);

      // Verify transaction ledger
      final txs = mockWallet.currentTransactions;
      final refundTx = txs.firstWhere((t) => t.orderId == 'ord_orange_001' && t.type == 'order_refund');
      expect(refundTx.amount, 1800.0);
    });

    test('simulateDispatch transitions confirmed order to dispatched with courier tracking fields', () async {
      final initialOrders = container.read(ordersListProvider);
      final confirmedOrder = initialOrders.firstWhere((o) => o.orderId == 'ord_rice_000');
      expect(confirmedOrder.status, 'confirmed');
      expect(confirmedOrder.isDispatched, isFalse);

      await container.read(ordersListProvider.notifier).simulateDispatch(
        campaignDate: '2026-10-21',
        courierPartner: 'pathao',
      );

      final updatedOrders = container.read(ordersListProvider);
      final dispatchedOrder = updatedOrders.firstWhere((o) => o.orderId == 'ord_rice_000');

      expect(dispatchedOrder.status, 'dispatched');
      expect(dispatchedOrder.isDispatched, isTrue);
      expect(dispatchedOrder.courierPartner, 'pathao');
      expect(dispatchedOrder.consignmentId, 'PTH-CON-rice_000');
      expect(dispatchedOrder.trackingCode, 'PTH-TRK-rice_000');
      expect(dispatchedOrder.parcelWeightKg, 25.0); // 1 bag * 25 kg
      expect(dispatchedOrder.dispatchedAt, isNotNull);
      expect(dispatchedOrder.statusBadgeText, 'DISPATCHED');
      expect(dispatchedOrder.statusExplanation, contains('PATHAO'));

      // Filtered tab verification
      final counts = container.read(orderCountsProvider);
      expect(counts[OrderFilterTab.confirmed], 0);
      expect(counts[OrderFilterTab.dispatched], 1);

      container.read(orderFilterTabProvider.notifier).state = OrderFilterTab.dispatched;
      final filteredDispatched = container.read(filteredOrdersProvider);
      expect(filteredDispatched.length, 1);
      expect(filteredDispatched.first.orderId, 'ord_rice_000');
    });
  });
}
