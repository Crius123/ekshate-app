import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/order_entity.dart';
import '../../auth/data/auth_repository.dart';
import '../../wallet/data/wallet_repository.dart';
import '../../../core/errors/app_exception.dart';

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  final walletRepo = ref.watch(walletRepositoryProvider);
  return MockOrdersRepository(
    authRepository: authRepo,
    walletRepository: walletRepo,
  );
});

abstract class OrdersRepository {
  List<OrderEntity> get currentOrders;
  Stream<List<OrderEntity>> get ordersStream;
  Future<OrderEntity> placeOrder({
    required String listingId,
    required String productTitle,
    required double quantity,
    required String unit,
    required double unitPrice,
    required String deliveryAddress,
    required String date,
    int bucketNumber = 1,
    String? phone,
  });
  Future<void> simulateSettlement({
    required String campaignDate,
    required bool targetMet,
  });
  Future<void> simulateDispatch({
    required String campaignDate,
    String courierPartner = 'pathao',
  });
}

class MockOrdersRepository implements OrdersRepository {
  final AuthRepository authRepository;
  final WalletRepository walletRepository;
  final Duration simulatedDelay;

  final StreamController<List<OrderEntity>> _ordersController =
      StreamController<List<OrderEntity>>.broadcast();

  final List<OrderEntity> _orders = [];

  MockOrdersRepository({
    required this.authRepository,
    required this.walletRepository,
    this.simulatedDelay = const Duration(milliseconds: 200),
    List<OrderEntity>? initialOrders,
  }) {
    final seed = initialOrders ?? _defaultSeedOrders;
    _orders.addAll(seed);
  }

  static List<OrderEntity> get _defaultSeedOrders => [
        OrderEntity(
          orderId: 'ord_orange_001',
          userId: 'user_dev_01',
          listingId: 'listing_orange_01',
          bucketNumber: 1,
          productTitle: 'Nagpur Oranges (1 kg)',
          quantity: 10.0,
          unit: 'kg',
          unitPrice: 180.0,
          totalAmount: 1800.0,
          status: 'pending_bucket',
          deliveryAddress: 'House 12, Road 5, Dhanmondi, Dhaka',
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          date: '2026-10-21',
        ),
        OrderEntity(
          orderId: 'ord_rice_000',
          userId: 'user_dev_01',
          listingId: 'listing_rice_02',
          bucketNumber: 1,
          productTitle: 'Miniket Premium Rice (25 kg bag)',
          quantity: 1.0,
          unit: 'bag',
          unitPrice: 1750.0,
          totalAmount: 1750.0,
          status: 'confirmed',
          deliveryAddress: 'House 12, Road 5, Dhanmondi, Dhaka',
          createdAt: DateTime.now().subtract(const Duration(hours: 5)),
          date: '2026-10-21',
        ),
        OrderEntity(
          orderId: 'ord_oil_prev',
          userId: 'user_dev_01',
          listingId: 'listing_oil_03',
          bucketNumber: 1,
          productTitle: 'Pure Mustard Oil (5 L jar)',
          quantity: 2.0,
          unit: 'jar',
          unitPrice: 780.0,
          totalAmount: 1560.0,
          status: 'refunded',
          deliveryAddress: 'House 12, Road 5, Dhanmondi, Dhaka',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          date: '2026-10-20',
        ),
      ];

  @override
  List<OrderEntity> get currentOrders => List.unmodifiable(_orders);

  @override
  Stream<List<OrderEntity>> get ordersStream {
    Future.microtask(() {
      if (!_ordersController.isClosed) {
        _ordersController.add(List.unmodifiable(_orders));
      }
    });
    return _ordersController.stream;
  }

  @override
  Future<OrderEntity> placeOrder({
    required String listingId,
    required String productTitle,
    required double quantity,
    required String unit,
    required double unitPrice,
    required String deliveryAddress,
    required String date,
    int bucketNumber = 1,
    String? phone,
  }) async {
    if (simulatedDelay > Duration.zero) {
      await Future.delayed(simulatedDelay);
    }

    final user = authRepository.currentUser;
    if (user == null) {
      throw Exception('User must be signed in to place an order.');
    }

    final totalAmount = quantity * unitPrice;

    // Verify sufficient funds
    if (user.availableBalance < totalAmount) {
      throw InsufficientWalletBalanceException(
        requiredAmount: totalAmount,
        availableBalance: user.availableBalance,
      );
    }

    final orderId = 'ord_${(DateTime.now().millisecondsSinceEpoch % 100000).toString().padLeft(5, '0')}';

    // 1. Debit available balance, credit escrow balance
    authRepository.updateBalances(
      uid: user.uid,
      availableBalanceDelta: -totalAmount,
      escrowBalanceDelta: totalAmount,
    );

    // 2. Write audit ledger entry in wallet transactions
    await walletRepository.recordOrderHold(
      userId: user.uid,
      orderId: orderId,
      amount: totalAmount,
      listingId: listingId,
      bucketNumber: bucketNumber,
    );

    // 3. Create Order
    final order = OrderEntity(
      orderId: orderId,
      userId: user.uid,
      listingId: listingId,
      bucketNumber: bucketNumber,
      productTitle: productTitle,
      quantity: quantity,
      unit: unit,
      unitPrice: unitPrice,
      totalAmount: totalAmount,
      status: 'pending_bucket',
      deliveryAddress: deliveryAddress.trim(),
      createdAt: DateTime.now(),
      date: date,
      userPhone: phone ?? user.phoneNumber,
    );

    _orders.insert(0, order);
    _ordersController.add(List.unmodifiable(_orders));

    return order;
  }

  @override
  Future<void> simulateSettlement({
    required String campaignDate,
    required bool targetMet,
  }) async {
    final updatedOrders = <OrderEntity>[];
    for (final order in _orders) {
      if ((order.date == campaignDate || campaignDate.isEmpty) && order.isPending) {
        if (targetMet) {
          // Escrow captured: decrement user escrow balance
          authRepository.updateBalances(
            uid: order.userId,
            availableBalanceDelta: 0,
            escrowBalanceDelta: -order.totalAmount,
          );
          // Ledger entry
          await walletRepository.recordOrderSettle(
            userId: order.userId,
            orderId: order.orderId,
            amount: order.totalAmount,
            listingId: order.listingId,
            bucketNumber: order.bucketNumber,
          );
          updatedOrders.add(order.copyWith(status: 'confirmed'));
        } else {
          // Bucket failed: refund escrow to available balance
          authRepository.updateBalances(
            uid: order.userId,
            availableBalanceDelta: order.totalAmount,
            escrowBalanceDelta: -order.totalAmount,
          );
          // Ledger entry
          await walletRepository.recordOrderRefund(
            userId: order.userId,
            orderId: order.orderId,
            amount: order.totalAmount,
            listingId: order.listingId,
            bucketNumber: order.bucketNumber,
          );
          updatedOrders.add(order.copyWith(status: 'refunded'));
        }
      } else {
        updatedOrders.add(order);
      }
    }
    _orders.clear();
    _orders.addAll(updatedOrders);
    _ordersController.add(List.unmodifiable(_orders));
  }

  @override
  Future<void> simulateDispatch({
    required String campaignDate,
    String courierPartner = 'pathao',
  }) async {
    final updatedOrders = <OrderEntity>[];
    for (final order in _orders) {
      if ((order.date == campaignDate || campaignDate.isEmpty) && order.isConfirmed) {
        final partner = courierPartner.toLowerCase();
        final trackingPrefix = partner == 'pathao'
            ? 'PTH'
            : (partner == 'steadfast' ? 'SF' : 'REDX');
        final cleanId = order.orderId.replaceAll('ord_', '');
        final consignmentId = '$trackingPrefix-CON-$cleanId';
        final trackingCode = '$trackingPrefix-TRK-$cleanId';
        final trackingUrl = partner == 'pathao'
            ? 'https://pathao.com/courier/tracking/?consignment_id=$consignmentId'
            : (partner == 'steadfast'
                ? 'https://steadfast.com.bd/t/$trackingCode'
                : 'https://redx.com.bd/track-parcel/?trackingId=$trackingCode');

        double weight = order.quantity;
        if (order.unit.contains('bag') || order.unit.contains('sack')) {
          weight = order.quantity * 25.0;
        } else if (order.unit.contains('jar') || order.unit.contains('tin')) {
          weight = order.quantity * 5.0;
        } else if (order.unit.contains('crate')) {
          weight = order.quantity * 10.0;
        }

        updatedOrders.add(order.copyWith(
          status: 'dispatched',
          courierPartner: partner,
          consignmentId: consignmentId,
          trackingCode: trackingCode,
          trackingUrl: trackingUrl,
          dispatchedAt: DateTime.now(),
          parcelWeightKg: weight,
        ));
      } else {
        updatedOrders.add(order);
      }
    }
    _orders.clear();
    _orders.addAll(updatedOrders);
    _ordersController.add(List.unmodifiable(_orders));
  }
}
