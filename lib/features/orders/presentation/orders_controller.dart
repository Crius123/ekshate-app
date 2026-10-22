import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/order_entity.dart';

final ordersListProvider = StateProvider<List<OrderEntity>>((ref) {
  return [
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
    ),
  ];
});
