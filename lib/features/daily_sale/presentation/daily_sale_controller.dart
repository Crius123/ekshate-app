import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/daily_listing.dart';
import '../domain/batch_bucket.dart';

final dailyCampaignStatusProvider = StateProvider<String>((ref) => 'active'); // 'preview' | 'active' | 'settling' | 'settled'

final dailyListingsProvider = NotifierProvider<DailySaleController, List<DailyListing>>(() {
  return DailySaleController();
});

class DailySaleController extends Notifier<List<DailyListing>> {
  @override
  List<DailyListing> build() {
    return [
      DailyListing(
        id: 'listing_orange_01',
        productId: 'prod_orange_01',
        productTitle: 'Nagpur Oranges (1 kg)',
        unit: 'kg',
        marketPrice: 240.0,
        unitPrice: 180.0,
        discountPercent: 25.0,
        moqThreshold: 100.0,
        activeBucketNumber: 1,
        totalBucketsCount: 1,
        totalVolumeOrdered: 65.0,
        status: 'active',
        activeBucket: const BatchBucket(
          bucketNumber: 1,
          listingId: 'listing_orange_01',
          date: '2026-10-21',
          moqThreshold: 100.0,
          currentQuantity: 65.0,
          remainingCapacity: 35.0, // Hard clamp: max client can buy is 35 kg
          status: 'open',
          orderCount: 4,
        ),
      ),
      DailyListing(
        id: 'listing_rice_02',
        productId: 'prod_rice_01',
        productTitle: 'Miniket Premium Rice (25 kg bag)',
        unit: 'bag',
        marketPrice: 2100.0,
        unitPrice: 1750.0,
        discountPercent: 16.6,
        moqThreshold: 50.0,
        activeBucketNumber: 2,
        totalBucketsCount: 2,
        totalVolumeOrdered: 62.0,
        status: 'active',
        activeBucket: const BatchBucket(
          bucketNumber: 2,
          listingId: 'listing_rice_02',
          date: '2026-10-21',
          moqThreshold: 50.0,
          currentQuantity: 12.0,
          remainingCapacity: 38.0,
          status: 'open',
          orderCount: 2,
        ),
      ),
    ];
  }

  /// Returns the maximum allowed order volume for a given listing
  double getRemainingCapacity(String listingId) {
    final listing = state.firstWhere(
      (l) => l.id == listingId,
      orElse: () => throw Exception('Listing not found'),
    );
    return listing.activeBucket?.remainingCapacity ?? 0.0;
  }
}
