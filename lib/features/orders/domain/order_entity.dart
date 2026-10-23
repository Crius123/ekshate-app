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
  final String status; // 'pending_bucket' | 'confirmed' | 'dispatched' | 'refunded' | 'delivered'
  final String deliveryAddress;
  final DateTime createdAt;
  final String? date;
  final String? userPhone;
  final String? courierPartner; // 'pathao' | 'steadfast' | 'redx'
  final String? consignmentId;
  final String? trackingCode;
  final String? trackingUrl;
  final DateTime? dispatchedAt;
  final double? parcelWeightKg;

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
    this.date,
    this.userPhone,
    this.courierPartner,
    this.consignmentId,
    this.trackingCode,
    this.trackingUrl,
    this.dispatchedAt,
    this.parcelWeightKg,
  });

  bool get isDispatched => status == 'dispatched';
  bool get isConfirmed => status == 'confirmed';
  bool get isPending => status == 'pending_bucket';
  bool get isRefunded => status == 'refunded';

  String get statusBadgeText {
    if (isDispatched) return 'DISPATCHED';
    if (isConfirmed) return 'CONFIRMED';
    if (isRefunded) return 'REFUNDED';
    return 'PENDING ESCROW';
  }

  String get statusExplanation {
    if (isDispatched) {
      final partnerName = (courierPartner ?? 'Courier').toUpperCase();
      return 'Consignment booked via $partnerName. Package is dispatched and in transit to your delivery address.';
    }
    if (isConfirmed) {
      return 'Bucket met MOQ and order is queued for morning procurement.';
    }
    if (isRefunded) {
      return 'Bucket did not meet MOQ and escrow was restored to available balance.';
    }
    return 'Funds are held securely until bucket hits MOQ.';
  }

  String get liveBucketTooltipText {
    if (isDispatched) {
      final partnerName = (courierPartner ?? 'courier').toUpperCase();
      return 'Bucket #$bucketNumber orders are dispatched via $partnerName (Tracking: ${trackingCode ?? consignmentId ?? 'Assigned'}).';
    }
    if (isConfirmed) {
      return 'Bucket #$bucketNumber met MOQ and order is queued for morning procurement.';
    }
    if (isRefunded) {
      return 'Bucket #$bucketNumber did not meet MOQ and escrow was restored to available balance.';
    }
    return 'Funds are held securely until bucket hits MOQ.';
  }

  OrderEntity copyWith({
    String? orderId,
    String? userId,
    String? listingId,
    int? bucketNumber,
    String? productTitle,
    double? quantity,
    String? unit,
    double? unitPrice,
    double? totalAmount,
    String? status,
    String? deliveryAddress,
    DateTime? createdAt,
    String? date,
    String? userPhone,
    String? courierPartner,
    String? consignmentId,
    String? trackingCode,
    String? trackingUrl,
    DateTime? dispatchedAt,
    double? parcelWeightKg,
  }) {
    return OrderEntity(
      orderId: orderId ?? this.orderId,
      userId: userId ?? this.userId,
      listingId: listingId ?? this.listingId,
      bucketNumber: bucketNumber ?? this.bucketNumber,
      productTitle: productTitle ?? this.productTitle,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      totalAmount: totalAmount ?? this.totalAmount,
      status: status ?? this.status,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      createdAt: createdAt ?? this.createdAt,
      date: date ?? this.date,
      userPhone: userPhone ?? this.userPhone,
      courierPartner: courierPartner ?? this.courierPartner,
      consignmentId: consignmentId ?? this.consignmentId,
      trackingCode: trackingCode ?? this.trackingCode,
      trackingUrl: trackingUrl ?? this.trackingUrl,
      dispatchedAt: dispatchedAt ?? this.dispatchedAt,
      parcelWeightKg: parcelWeightKg ?? this.parcelWeightKg,
    );
  }
}
