import 'batch_bucket.dart';

class DailyListing {
  final String id;
  final String productId;
  final String productTitle;
  final String unit;
  final double marketPrice;
  final double unitPrice;
  final double discountPercent;
  final double moqThreshold;
  final int activeBucketNumber;
  final int totalBucketsCount;
  final double totalVolumeOrdered;
  final String status; // 'preview' | 'active' | 'closed' | 'settled'
  final BatchBucket? activeBucket;
  final String? imageUrl;
  final String? category;
  final String? description;
  final String? origin;
  final List<String>? highlights;

  const DailyListing({
    required this.id,
    required this.productId,
    required this.productTitle,
    required this.unit,
    required this.marketPrice,
    required this.unitPrice,
    required this.discountPercent,
    required this.moqThreshold,
    required this.activeBucketNumber,
    required this.totalBucketsCount,
    required this.totalVolumeOrdered,
    required this.status,
    this.activeBucket,
    this.imageUrl,
    this.category,
    this.description,
    this.origin,
    this.highlights,
  });

  double get savingsPerUnit => marketPrice - unitPrice;

  DailyListing copyWith({
    String? id,
    String? productId,
    String? productTitle,
    String? unit,
    double? marketPrice,
    double? unitPrice,
    double? discountPercent,
    double? moqThreshold,
    int? activeBucketNumber,
    int? totalBucketsCount,
    double? totalVolumeOrdered,
    String? status,
    BatchBucket? activeBucket,
    String? imageUrl,
    String? category,
    String? description,
    String? origin,
    List<String>? highlights,
  }) {
    return DailyListing(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productTitle: productTitle ?? this.productTitle,
      unit: unit ?? this.unit,
      marketPrice: marketPrice ?? this.marketPrice,
      unitPrice: unitPrice ?? this.unitPrice,
      discountPercent: discountPercent ?? this.discountPercent,
      moqThreshold: moqThreshold ?? this.moqThreshold,
      activeBucketNumber: activeBucketNumber ?? this.activeBucketNumber,
      totalBucketsCount: totalBucketsCount ?? this.totalBucketsCount,
      totalVolumeOrdered: totalVolumeOrdered ?? this.totalVolumeOrdered,
      status: status ?? this.status,
      activeBucket: activeBucket ?? this.activeBucket,
      imageUrl: imageUrl ?? this.imageUrl,
      category: category ?? this.category,
      description: description ?? this.description,
      origin: origin ?? this.origin,
      highlights: highlights ?? this.highlights,
    );
  }
}
