import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/daily_search_result.dart';
import '../../daily_sale/presentation/daily_sale_controller.dart';
import '../../daily_sale/domain/daily_listing.dart';

abstract class SearchRepository {
  Future<List<DailySearchResult>> search(String query, {String? category});
}

class SearchNetworkException implements Exception {
  final String message;
  const SearchNetworkException([this.message = 'Network error while searching listings.']);

  @override
  String toString() => message;
}

/// Production / Default Search Repository.
/// Matches active daily campaign deals by title, category, description, or unit.
class LocalOrAlgoliaSearchRepository implements SearchRepository {
  final List<DailyListing> Function() getListings;
  final bool simulateNetworkError;

  LocalOrAlgoliaSearchRepository({
    required this.getListings,
    this.simulateNetworkError = false,
  });

  @override
  Future<List<DailySearchResult>> search(String query, {String? category}) async {
    if (simulateNetworkError) {
      throw const SearchNetworkException('Connection timeout to Algolia search cluster.');
    }

    final trimmedQuery = query.trim().toLowerCase();
    final trimmedCategory = category?.trim().toLowerCase();

    if (trimmedQuery.isEmpty && (trimmedCategory == null || trimmedCategory.isEmpty)) {
      return [];
    }

    final listings = getListings();

    final filtered = listings.where((listing) {
      final title = listing.productTitle.toLowerCase();
      final cat = (listing.category ?? '').toLowerCase();
      final unit = listing.unit.toLowerCase();
      final desc = (listing.description ?? '').toLowerCase();

      // Check category filter if provided
      if (trimmedCategory != null && trimmedCategory.isNotEmpty) {
        final singularCat = trimmedCategory.endsWith('s')
            ? trimmedCategory.substring(0, trimmedCategory.length - 1)
            : trimmedCategory;
        if (!cat.contains(singularCat) && !title.contains(singularCat)) {
          return false;
        }
      }

      if (trimmedQuery.isEmpty) {
        return true;
      }

      // Query matching across title, category, unit, description
      if (title.contains(trimmedQuery) ||
          cat.contains(trimmedQuery) ||
          unit.contains(trimmedQuery) ||
          desc.contains(trimmedQuery)) {
        return true;
      }

      // Check singular/plural variant (e.g. 'fruits' -> 'fruit', 'grains' -> 'grain')
      final singularQuery = trimmedQuery.endsWith('s')
          ? trimmedQuery.substring(0, trimmedQuery.length - 1)
          : trimmedQuery;
      if (cat.contains(singularQuery) || title.contains(singularQuery)) {
        return true;
      }

      return false;
    }).map((listing) {
      final bucket = listing.activeBucket;
      return DailySearchResult(
        listingId: listing.id,
        productId: listing.productId,
        productTitle: listing.productTitle,
        category: listing.category ?? 'General',
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
        thumbnailUrl: listing.imageUrl ?? '',
      );
    }).toList();

    return filtered;
  }
}

/// Provider for the SearchRepository.
final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return LocalOrAlgoliaSearchRepository(
    getListings: () => ref.read(dailyListingsProvider),
  );
});
