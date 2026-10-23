class DailySearchResult {
  final String listingId;
  final String productId;
  final String productTitle;
  final String category;
  final String unit;
  final double unitPrice;
  final double marketPrice;
  final double discountPercent;
  final double moqThreshold;
  final int activeBucketNumber;
  final double totalVolumeOrdered;
  final double bucketCurrentQuantity;
  final double bucketRemainingCapacity;
  final double bucketProgressPercent;
  final String bucketStatus;
  final String thumbnailUrl;

  const DailySearchResult({
    required this.listingId,
    required this.productId,
    required this.productTitle,
    required this.category,
    required this.unit,
    required this.unitPrice,
    required this.marketPrice,
    required this.discountPercent,
    required this.moqThreshold,
    required this.activeBucketNumber,
    required this.totalVolumeOrdered,
    required this.bucketCurrentQuantity,
    required this.bucketRemainingCapacity,
    required this.bucketProgressPercent,
    required this.bucketStatus,
    required this.thumbnailUrl,
  });

  double get savingsPerUnit => (marketPrice - unitPrice).clamp(0.0, double.infinity);

  bool get hasCapacity => bucketRemainingCapacity >= 1.0;

  factory DailySearchResult.fromAlgoliaHit(Map<String, dynamic> hit) {
    final moq = (hit['moq_threshold'] as num?)?.toDouble() ?? 0.0;
    final currentQty = (hit['active_bucket_current_qty'] as num?)?.toDouble() ?? 0.0;
    final remainingCap = (hit['active_bucket_remaining_capacity'] as num?)?.toDouble() ??
        (moq > 0 ? (moq - currentQty).clamp(0.0, moq) : 0.0);
    final progressPercent = (hit['active_bucket_progress_percent'] as num?)?.toDouble() ??
        (moq > 0 ? (currentQty / moq).clamp(0.0, 1.0) : 0.0);

    return DailySearchResult(
      listingId: hit['listing_id'] as String? ?? hit['objectID'] as String? ?? '',
      productId: hit['product_id'] as String? ?? '',
      productTitle: hit['product_title'] as String? ?? '',
      category: hit['category'] as String? ?? 'General',
      unit: hit['unit'] as String? ?? 'kg',
      unitPrice: (hit['unit_price'] as num?)?.toDouble() ?? 0.0,
      marketPrice: (hit['market_price'] as num?)?.toDouble() ?? 0.0,
      discountPercent: (hit['discount_percent'] as num?)?.toDouble() ?? 0.0,
      moqThreshold: moq,
      activeBucketNumber: (hit['active_bucket_number'] as num?)?.toInt() ?? 1,
      totalVolumeOrdered: (hit['total_volume_ordered'] as num?)?.toDouble() ?? 0.0,
      bucketCurrentQuantity: currentQty,
      bucketRemainingCapacity: remainingCap,
      bucketProgressPercent: progressPercent,
      bucketStatus: hit['active_bucket_status'] as String? ?? 'open',
      thumbnailUrl: hit['thumbnail_url'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'objectID': listingId,
      'listing_id': listingId,
      'product_id': productId,
      'product_title': productTitle,
      'category': category,
      'unit': unit,
      'unit_price': unitPrice,
      'market_price': marketPrice,
      'discount_percent': discountPercent,
      'moq_threshold': moqThreshold,
      'active_bucket_number': activeBucketNumber,
      'total_volume_ordered': totalVolumeOrdered,
      'active_bucket_current_qty': bucketCurrentQuantity,
      'active_bucket_remaining_capacity': bucketRemainingCapacity,
      'active_bucket_progress_percent': bucketProgressPercent,
      'active_bucket_status': bucketStatus,
      'thumbnail_url': thumbnailUrl,
    };
  }

  DailySearchResult copyWith({
    String? listingId,
    String? productId,
    String? productTitle,
    String? category,
    String? unit,
    double? unitPrice,
    double? marketPrice,
    double? discountPercent,
    double? moqThreshold,
    int? activeBucketNumber,
    double? totalVolumeOrdered,
    double? bucketCurrentQuantity,
    double? bucketRemainingCapacity,
    double? bucketProgressPercent,
    String? bucketStatus,
    String? thumbnailUrl,
  }) {
    return DailySearchResult(
      listingId: listingId ?? this.listingId,
      productId: productId ?? this.productId,
      productTitle: productTitle ?? this.productTitle,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      unitPrice: unitPrice ?? this.unitPrice,
      marketPrice: marketPrice ?? this.marketPrice,
      discountPercent: discountPercent ?? this.discountPercent,
      moqThreshold: moqThreshold ?? this.moqThreshold,
      activeBucketNumber: activeBucketNumber ?? this.activeBucketNumber,
      totalVolumeOrdered: totalVolumeOrdered ?? this.totalVolumeOrdered,
      bucketCurrentQuantity: bucketCurrentQuantity ?? this.bucketCurrentQuantity,
      bucketRemainingCapacity: bucketRemainingCapacity ?? this.bucketRemainingCapacity,
      bucketProgressPercent: bucketProgressPercent ?? this.bucketProgressPercent,
      bucketStatus: bucketStatus ?? this.bucketStatus,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    );
  }
}
