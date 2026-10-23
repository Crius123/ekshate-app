import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/order_entity.dart';
import '../data/orders_repository.dart';

enum OrderFilterTab {
  activeEscrow, // 'Active Escrow (Pending)'
  confirmed,    // 'Confirmed Deals'
  dispatched,   // 'Dispatched (In Transit)'
  refunded,     // 'Refunded Deals'
}

final orderFilterTabProvider =
    StateProvider<OrderFilterTab>((ref) => OrderFilterTab.activeEscrow);

final ordersListProvider =
    NotifierProvider<OrdersListNotifier, List<OrderEntity>>(OrdersListNotifier.new);

final filteredOrdersProvider = Provider<List<OrderEntity>>((ref) {
  final orders = ref.watch(ordersListProvider);
  final filter = ref.watch(orderFilterTabProvider);

  switch (filter) {
    case OrderFilterTab.activeEscrow:
      return orders.where((o) => o.isPending).toList();
    case OrderFilterTab.confirmed:
      return orders.where((o) => o.isConfirmed).toList();
    case OrderFilterTab.dispatched:
      return orders.where((o) => o.isDispatched).toList();
    case OrderFilterTab.refunded:
      return orders.where((o) => o.isRefunded).toList();
  }
});

final orderCountsProvider = Provider<Map<OrderFilterTab, int>>((ref) {
  final orders = ref.watch(ordersListProvider);
  return {
    OrderFilterTab.activeEscrow: orders.where((o) => o.isPending).length,
    OrderFilterTab.confirmed: orders.where((o) => o.isConfirmed).length,
    OrderFilterTab.dispatched: orders.where((o) => o.isDispatched).length,
    OrderFilterTab.refunded: orders.where((o) => o.isRefunded).length,
  };
});

class OrdersListNotifier extends Notifier<List<OrderEntity>> {
  late final OrdersRepository _repository;
  StreamSubscription<List<OrderEntity>>? _subscription;

  @override
  List<OrderEntity> build() {
    _repository = ref.watch(ordersRepositoryProvider);
    _subscription?.cancel();
    _subscription = _repository.ordersStream.listen((orders) {
      state = orders;
    });

    ref.onDispose(() {
      _subscription?.cancel();
    });

    return _repository.currentOrders;
  }

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
    final order = await _repository.placeOrder(
      listingId: listingId,
      productTitle: productTitle,
      quantity: quantity,
      unit: unit,
      unitPrice: unitPrice,
      deliveryAddress: deliveryAddress,
      date: date,
      bucketNumber: bucketNumber,
      phone: phone,
    );
    state = _repository.currentOrders;
    return order;
  }

  Future<void> simulateSettlement({
    required String campaignDate,
    required bool targetMet,
  }) async {
    await _repository.simulateSettlement(
      campaignDate: campaignDate,
      targetMet: targetMet,
    );
    state = _repository.currentOrders;
  }

  Future<void> simulateDispatch({
    required String campaignDate,
    String courierPartner = 'pathao',
  }) async {
    await _repository.simulateDispatch(
      campaignDate: campaignDate,
      courierPartner: courierPartner,
    );
    state = _repository.currentOrders;
  }
}
