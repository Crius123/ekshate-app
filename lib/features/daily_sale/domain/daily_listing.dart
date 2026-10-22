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
  });

  double get savingsPerUnit => marketPrice - unitPrice;
}
