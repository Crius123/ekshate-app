class BatchBucket {
  final int bucketNumber;
  final String listingId;
  final String date;
  final double moqThreshold;
  final double currentQuantity;
  final double remainingCapacity;
  final String status; // 'open' | 'target_met' | 'failed' | 'confirmed'
  final int orderCount;

  const BatchBucket({
    required this.bucketNumber,
    required this.listingId,
    required this.date,
    required this.moqThreshold,
    required this.currentQuantity,
    required this.remainingCapacity,
    required this.status,
    required this.orderCount,
  });

  double get progressPercentage => (currentQuantity / moqThreshold).clamp(0.0, 1.0);
  bool get isTargetMet => status == 'target_met' || status == 'confirmed';
  bool get isOpen => status == 'open';
}
