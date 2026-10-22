class OrderEntity {
  final String orderId;
  final String userId;
  final String listingId;
  final int bucketNumber;
  final String productTitle;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double totalAmount;
  final String status; // 'pending_bucket' | 'confirmed' | 'refunded' | 'delivered'
  final String deliveryAddress;
  final DateTime createdAt;

  const OrderEntity({
    required this.orderId,
    required this.userId,
    required this.listingId,
    required this.bucketNumber,
    required this.productTitle,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.totalAmount,
    required this.status,
    required this.deliveryAddress,
    required this.createdAt,
  });

  bool get isConfirmed => status == 'confirmed';
  bool get isPending => status == 'pending_bucket';
  bool get isRefunded => status == 'refunded';
}
