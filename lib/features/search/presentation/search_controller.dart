import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/daily_search_result.dart';
import '../../daily_sale/presentation/daily_sale_controller.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');

/// Debounced Search Results Provider with 300ms Keystroke Throttle
final debouncedSearchResultsProvider = FutureProvider<List<DailySearchResult>>((ref) async {
  final query = ref.watch(searchQueryProvider).trim();

  // If query is blank, return empty results immediately
  if (query.isEmpty) {
    return [];
  }

  // 300ms Debounce Delay
  var isDisposed = false;
  ref.onDispose(() {
    isDisposed = true;
  });

  await Future.delayed(const Duration(milliseconds: 300));
  if (isDisposed) {
    throw Exception('Query debounced');
  }

  // In production with Algolia SDK, calls searchIndex.
  // In fallback / offline development mode, searches active listings from dailyListingsProvider:
  final listings = ref.watch(dailyListingsProvider);
  final lowerQuery = query.toLowerCase();

  final filtered = listings.where((listing) {
    return listing.productTitle.toLowerCase().contains(lowerQuery) ||
        listing.unit.toLowerCase().contains(lowerQuery);
  }).map((listing) {
    final bucket = listing.activeBucket;
    return DailySearchResult(
      listingId: listing.id,
      productId: listing.productId,
      productTitle: listing.productTitle,
      category: 'Produce',
      unit: listing.unit,
      unitPrice: listing.unitPrice,
      marketPrice: listing.marketPrice,
      discountPercent: listing.discountPercent,
      moqThreshold: listing.moqThreshold,
      activeBucketNumber: listing.activeBucketNumber,
      totalVolumeOrdered: listing.totalVolumeOrdered,
      bucketCurrentQuantity: bucket?.currentQuantity ?? 0.0,
      bucketRemainingCapacity: bucket?.remainingCapacity ?? listing.moqThreshold,
      bucketProgressPercent: bucket?.progressPercentage ?? 0.0,
      bucketStatus: bucket?.status ?? 'open',
      thumbnailUrl: '',
    );
  }).toList();

  return filtered;
});
