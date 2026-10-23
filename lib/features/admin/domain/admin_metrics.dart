class BucketMomentum {
  final String listingId;
  final String productId;
  final String productTitle;
  final String category;
  final String unit;
  final double marketPrice;
  final double unitPrice;
  final double discountPercent;
  final int activeBucketNumber;
  final double moqThreshold;
  final double currentQuantity;
  final double remainingCapacity;
  final double fillPercentage;
  final int orderCount;
  final String status;

  const BucketMomentum({
    required this.listingId,
    required this.productId,
    required this.productTitle,
    required this.category,
    required this.unit,
    required this.marketPrice,
    required this.unitPrice,
    required this.discountPercent,
    required this.activeBucketNumber,
    required this.moqThreshold,
    required this.currentQuantity,
    required this.remainingCapacity,
    required this.fillPercentage,
    required this.orderCount,
    required this.status,
  });

  factory BucketMomentum.fromJson(Map<String, dynamic> json) {
    return BucketMomentum(
      listingId: (json['listingId'] as String?) ?? '',
      productId: (json['productId'] as String?) ?? '',
      productTitle: (json['productTitle'] as String?) ?? 'Unknown Product',
      category: (json['category'] as String?) ?? 'General',
      unit: (json['unit'] as String?) ?? 'kg',
      marketPrice: (json['marketPrice'] as num?)?.toDouble() ?? 0.0,
      unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
      discountPercent: (json['discountPercent'] as num?)?.toDouble() ?? 0.0,
      activeBucketNumber: (json['activeBucketNumber'] as num?)?.toInt() ?? 1,
      moqThreshold: (json['moqThreshold'] as num?)?.toDouble() ?? 0.0,
      currentQuantity: (json['currentQuantity'] as num?)?.toDouble() ?? 0.0,
      remainingCapacity: (json['remainingCapacity'] as num?)?.toDouble() ?? 0.0,
      fillPercentage: (json['fillPercentage'] as num?)?.toDouble() ?? 0.0,
      orderCount: (json['orderCount'] as num?)?.toInt() ?? 0,
      status: (json['status'] as String?) ?? 'open',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'listingId': listingId,
      'productId': productId,
      'productTitle': productTitle,
      'category': category,
      'unit': unit,
      'marketPrice': marketPrice,
      'unitPrice': unitPrice,
      'discountPercent': discountPercent,
      'activeBucketNumber': activeBucketNumber,
      'moqThreshold': moqThreshold,
      'currentQuantity': currentQuantity,
      'remainingCapacity': remainingCapacity,
      'fillPercentage': fillPercentage,
      'orderCount': orderCount,
      'status': status,
    };
  }
}

class AdminMetrics {
  final String date;
  final String campaignStatus; // 'preview' | 'active' | 'closed' | 'settled'
  final double gmv;
  final double escrowVolume;
  final int totalOrdersCount;
  final int pendingEscrowOrdersCount;
  final int confirmedOrdersCount;
  final int dispatchedOrdersCount;
  final int refundedOrdersCount;
  final int pendingDispatchCount;
  final int listingsCount;
  final double averageFillPercentage;
  final List<BucketMomentum> bucketMomentum;
  final int pendingWithdrawalsCount;
  final double pendingWithdrawalsAmount;

  const AdminMetrics({
    required this.date,
    required this.campaignStatus,
    required this.gmv,
    required this.escrowVolume,
    required this.totalOrdersCount,
    required this.pendingEscrowOrdersCount,
    required this.confirmedOrdersCount,
    required this.dispatchedOrdersCount,
    required this.refundedOrdersCount,
    required this.pendingDispatchCount,
    required this.listingsCount,
    required this.averageFillPercentage,
    required this.bucketMomentum,
    required this.pendingWithdrawalsCount,
    required this.pendingWithdrawalsAmount,
  });

  factory AdminMetrics.empty({String? date}) {
    return AdminMetrics(
      date: date ?? '',
      campaignStatus: 'preview',
      gmv: 0.0,
      escrowVolume: 0.0,
      totalOrdersCount: 0,
      pendingEscrowOrdersCount: 0,
      confirmedOrdersCount: 0,
      dispatchedOrdersCount: 0,
      refundedOrdersCount: 0,
      pendingDispatchCount: 0,
      listingsCount: 0,
      averageFillPercentage: 0.0,
      bucketMomentum: const [],
      pendingWithdrawalsCount: 0,
      pendingWithdrawalsAmount: 0.0,
    );
  }

  factory AdminMetrics.fromJson(Map<String, dynamic> json) {
    final momentumList = (json['bucketMomentum'] as List?)
            ?.map((item) => BucketMomentum.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList() ??
        [];

    return AdminMetrics(
      date: (json['date'] as String?) ?? '',
      campaignStatus: (json['campaignStatus'] as String?) ?? 'preview',
      gmv: (json['gmv'] as num?)?.toDouble() ?? 0.0,
      escrowVolume: (json['escrowVolume'] as num?)?.toDouble() ?? 0.0,
      totalOrdersCount: (json['totalOrdersCount'] as num?)?.toInt() ?? 0,
      pendingEscrowOrdersCount: (json['pendingEscrowOrdersCount'] as num?)?.toInt() ?? 0,
      confirmedOrdersCount: (json['confirmedOrdersCount'] as num?)?.toInt() ?? 0,
      dispatchedOrdersCount: (json['dispatchedOrdersCount'] as num?)?.toInt() ?? 0,
      refundedOrdersCount: (json['refundedOrdersCount'] as num?)?.toInt() ?? 0,
      pendingDispatchCount: (json['pendingDispatchCount'] as num?)?.toInt() ?? 0,
      listingsCount: (json['listingsCount'] as num?)?.toInt() ?? momentumList.length,
      averageFillPercentage: (json['averageFillPercentage'] as num?)?.toDouble() ?? 0.0,
      bucketMomentum: momentumList,
      pendingWithdrawalsCount: (json['pendingWithdrawalsCount'] as num?)?.toInt() ?? 0,
      pendingWithdrawalsAmount: (json['pendingWithdrawalsAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'campaignStatus': campaignStatus,
      'gmv': gmv,
      'escrowVolume': escrowVolume,
      'totalOrdersCount': totalOrdersCount,
      'pendingEscrowOrdersCount': pendingEscrowOrdersCount,
      'confirmedOrdersCount': confirmedOrdersCount,
      'dispatchedOrdersCount': dispatchedOrdersCount,
      'refundedOrdersCount': refundedOrdersCount,
      'pendingDispatchCount': pendingDispatchCount,
      'listingsCount': listingsCount,
      'averageFillPercentage': averageFillPercentage,
      'bucketMomentum': bucketMomentum.map((m) => m.toJson()).toList(),
      'pendingWithdrawalsCount': pendingWithdrawalsCount,
      'pendingWithdrawalsAmount': pendingWithdrawalsAmount,
    };
  }

  AdminMetrics copyWith({
    String? date,
    String? campaignStatus,
    double? gmv,
    double? escrowVolume,
    int? totalOrdersCount,
    int? pendingEscrowOrdersCount,
    int? confirmedOrdersCount,
    int? dispatchedOrdersCount,
    int? refundedOrdersCount,
    int? pendingDispatchCount,
    int? listingsCount,
    double? averageFillPercentage,
    List<BucketMomentum>? bucketMomentum,
    int? pendingWithdrawalsCount,
    double? pendingWithdrawalsAmount,
  }) {
    return AdminMetrics(
      date: date ?? this.date,
      campaignStatus: campaignStatus ?? this.campaignStatus,
      gmv: gmv ?? this.gmv,
      escrowVolume: escrowVolume ?? this.escrowVolume,
      totalOrdersCount: totalOrdersCount ?? this.totalOrdersCount,
      pendingEscrowOrdersCount: pendingEscrowOrdersCount ?? this.pendingEscrowOrdersCount,
      confirmedOrdersCount: confirmedOrdersCount ?? this.confirmedOrdersCount,
      dispatchedOrdersCount: dispatchedOrdersCount ?? this.dispatchedOrdersCount,
      refundedOrdersCount: refundedOrdersCount ?? this.refundedOrdersCount,
      pendingDispatchCount: pendingDispatchCount ?? this.pendingDispatchCount,
      listingsCount: listingsCount ?? this.listingsCount,
      averageFillPercentage: averageFillPercentage ?? this.averageFillPercentage,
      bucketMomentum: bucketMomentum ?? this.bucketMomentum,
      pendingWithdrawalsCount: pendingWithdrawalsCount ?? this.pendingWithdrawalsCount,
      pendingWithdrawalsAmount: pendingWithdrawalsAmount ?? this.pendingWithdrawalsAmount,
    );
  }
}
