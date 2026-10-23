import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/daily_listing.dart';
import '../domain/batch_bucket.dart';
import '../domain/campaign_timer_info.dart';

/// Campaign status: 'preview' | 'active' | 'settling' | 'settled'
final dailyCampaignStatusProvider = StateProvider<String>((ref) => 'active');

/// Provider for clock function returning current BDT time (UTC+6).
/// Override this in widget tests for deterministic countdown testing.
final campaignClockProvider = Provider<DateTime Function()>((ref) {
  return () => DateTime.now().toUtc().add(const Duration(hours: 6));
});

/// Reactive provider calculating current countdown timer details.
final campaignTimerInfoProvider = Provider<CampaignTimerInfo>((ref) {
  final clock = ref.watch(campaignClockProvider);
  final status = ref.watch(dailyCampaignStatusProvider);
  final nowBdt = clock();
  return calculateCampaignTimerInfo(nowBdt, overrideStatus: status);
});

final dailyListingsProvider =
    NotifierProvider<DailySaleController, List<DailyListing>>(() {
  return DailySaleController();
});

class DailySaleController extends Notifier<List<DailyListing>> {
  @override
  List<DailyListing> build() {
    return [
      const DailyListing(
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
        imageUrl:
            'https://images.unsplash.com/photo-1611080626919-7cf5a9dbab5b?auto=format&fit=crop&w=800&q=80',
        category: 'Fresh Fruits',
        description:
            'Farm-fresh Nagpur juicy oranges sourced directly from wholesale orchards. High vitamin C, fresh harvest.',
        activeBucket: BatchBucket(
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
      const DailyListing(
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
        imageUrl:
            'https://images.unsplash.com/photo-1586201375761-83865001e31c?auto=format&fit=crop&w=800&q=80',
        category: 'Grains & Staples',
        description:
            'Polished extra-long grain Miniket rice straight from Dinajpur auto mills. Pure white, fragrant aroma.',
        activeBucket: BatchBucket(
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
      const DailyListing(
        id: 'listing_oil_03',
        productId: 'prod_oil_01',
        productTitle: 'Pure Mustard Oil (5 L jar)',
        unit: 'jar',
        marketPrice: 950.0,
        unitPrice: 780.0,
        discountPercent: 18.0,
        moqThreshold: 80.0,
        activeBucketNumber: 1,
        totalBucketsCount: 1,
        totalVolumeOrdered: 45.0,
        status: 'active',
        imageUrl:
            'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?auto=format&fit=crop&w=800&q=80',
        category: 'Edible Oils',
        description:
            'Cold-pressed 100% natural mustard oil with high pungency and traditional taste.',
        activeBucket: BatchBucket(
          bucketNumber: 1,
          listingId: 'listing_oil_03',
          date: '2026-10-21',
          moqThreshold: 80.0,
          currentQuantity: 45.0,
          remainingCapacity: 35.0,
          status: 'open',
          orderCount: 3,
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

  /// Updates volume for testing or live order simulation
  void updateListingQuantity(String listingId, double addedQuantity) {
    state = [
      for (final listing in state)
        if (listing.id == listingId && listing.activeBucket != null)
          _incrementBucket(listing, addedQuantity)
        else
          listing,
    ];
  }

  DailyListing _incrementBucket(DailyListing listing, double addedQuantity) {
    final bucket = listing.activeBucket!;
    final newCurrent = (bucket.currentQuantity + addedQuantity).clamp(0.0, bucket.moqThreshold);
    final newRemaining = (bucket.moqThreshold - newCurrent).clamp(0.0, bucket.moqThreshold);
    final newStatus = newCurrent >= bucket.moqThreshold ? 'target_met' : 'open';

    final updatedBucket = bucket.copyWith(
      currentQuantity: newCurrent,
      remainingCapacity: newRemaining,
      status: newStatus,
      orderCount: bucket.orderCount + 1,
    );

    return listing.copyWith(
      totalVolumeOrdered: listing.totalVolumeOrdered + addedQuantity,
      activeBucket: updatedBucket,
    );
  }
}
