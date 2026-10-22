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

  factory DailySearchResult.fromAlgoliaHit(Map<String, dynamic> hit) {
    return DailySearchResult(
      listingId: hit['listing_id'] as String? ?? hit['objectID'] as String? ?? '',
      productId: hit['product_id'] as String? ?? '',
      productTitle: hit['product_title'] as String? ?? '',
      category: hit['category'] as String? ?? 'General',
      unit: hit['unit'] as String? ?? 'kg',
      unitPrice: (hit['unit_price'] as num?)?.toDouble() ?? 0.0,
      marketPrice: (hit['market_price'] as num?)?.toDouble() ?? 0.0,
      discountPercent: (hit['discount_percent'] as num?)?.toDouble() ?? 0.0,
      moqThreshold: (hit['moq_threshold'] as num?)?.toDouble() ?? 0.0,
      activeBucketNumber: (hit['active_bucket_number'] as num?)?.toInt() ?? 1,
      totalVolumeOrdered: (hit['total_volume_ordered'] as num?)?.toDouble() ?? 0.0,
      bucketCurrentQuantity: (hit['active_bucket_current_qty'] as num?)?.toDouble() ?? 0.0,
      bucketRemainingCapacity: (hit['active_bucket_remaining_capacity'] as num?)?.toDouble() ?? 0.0,
      bucketProgressPercent: (hit['active_bucket_progress_percent'] as num?)?.toDouble() ?? 0.0,
      bucketStatus: hit['active_bucket_status'] as String? ?? 'open',
      thumbnailUrl: hit['thumbnail_url'] as String? ?? '',
    );
  }
}
