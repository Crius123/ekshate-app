import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ekshate_app/features/search/domain/daily_search_result.dart';
import 'package:ekshate_app/features/search/data/search_repository.dart';
import 'package:ekshate_app/features/search/presentation/search_controller.dart';
import 'package:ekshate_app/features/daily_sale/domain/daily_listing.dart';
import 'package:ekshate_app/features/daily_sale/domain/batch_bucket.dart';

void main() {
  group('DailySearchResult Domain Model Tests', () {
    test('fromAlgoliaHit maps denormalized fields and calculates metrics accurately', () {
      final hit = {
        'objectID': 'listing_orange_01',
        'listing_id': 'listing_orange_01',
        'product_id': 'prod_orange_01',
        'product_title': 'Nagpur Oranges (1 kg)',
        'category': 'Fresh Fruits',
        'unit': 'kg',
        'unit_price': 180.0,
        'market_price': 240.0,
        'discount_percent': 25.0,
        'moq_threshold': 100.0,
        'active_bucket_number': 1,
        'total_volume_ordered': 65.0,
        'active_bucket_current_qty': 65.0,
        'active_bucket_remaining_capacity': 35.0,
        'active_bucket_progress_percent': 0.65,
        'active_bucket_status': 'open',
        'thumbnail_url': 'https://example.com/orange.png',
      };

      final result = DailySearchResult.fromAlgoliaHit(hit);

      expect(result.listingId, 'listing_orange_01');
      expect(result.productTitle, 'Nagpur Oranges (1 kg)');
      expect(result.category, 'Fresh Fruits');
      expect(result.unitPrice, 180.0);
      expect(result.marketPrice, 240.0);
      expect(result.discountPercent, 25.0);
      expect(result.savingsPerUnit, 60.0);
      expect(result.activeBucketNumber, 1);
      expect(result.bucketCurrentQuantity, 65.0);
      expect(result.bucketRemainingCapacity, 35.0);
      expect(result.bucketProgressPercent, 0.65);
      expect(result.hasCapacity, isTrue);
      expect(result.bucketStatus, 'open');
      expect(result.thumbnailUrl, 'https://example.com/orange.png');
    });

    test('hasCapacity correctly reflects remaining capacity boundary', () {
      const availableHit = DailySearchResult(
        listingId: 'l1',
        productId: 'p1',
        productTitle: 'Apples',
        category: 'Fruits',
        unit: 'kg',
        unitPrice: 200,
        marketPrice: 250,
        discountPercent: 20,
        moqThreshold: 100,
        activeBucketNumber: 1,
        totalVolumeOrdered: 99,
        bucketCurrentQuantity: 99,
        bucketRemainingCapacity: 1.0,
        bucketProgressPercent: 0.99,
        bucketStatus: 'open',
        thumbnailUrl: '',
      );
      expect(availableHit.hasCapacity, isTrue);

      final fullHit = availableHit.copyWith(
        bucketRemainingCapacity: 0.0,
        bucketCurrentQuantity: 100.0,
        bucketProgressPercent: 1.0,
        bucketStatus: 'target_met',
      );
      expect(fullHit.hasCapacity, isFalse);
    });

    test('toMap serialization preserves complete Algolia record structure', () {
      const item = DailySearchResult(
        listingId: 'l2',
        productId: 'p2',
        productTitle: 'Miniket Rice',
        category: 'Grains',
        unit: 'bag',
        unitPrice: 1750,
        marketPrice: 2100,
        discountPercent: 16.6,
        moqThreshold: 50,
        activeBucketNumber: 2,
        totalVolumeOrdered: 60,
        bucketCurrentQuantity: 10,
        bucketRemainingCapacity: 40,
        bucketProgressPercent: 0.2,
        bucketStatus: 'open',
        thumbnailUrl: '',
      );

      final map = item.toMap();
      expect(map['listing_id'], 'l2');
      expect(map['product_title'], 'Miniket Rice');
      expect(map['category'], 'Grains');
      expect(map['active_bucket_current_qty'], 10);
      expect(map['active_bucket_remaining_capacity'], 40);
    });
  });

  group('LocalOrAlgoliaSearchRepository Tests', () {
    final mockListings = [
      const DailyListing(
        id: 'l_orange',
        productId: 'p_orange',
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
        category: 'Fresh Fruits',
        description: 'Juicy citrus oranges directly from orchards',
        activeBucket: BatchBucket(
          bucketNumber: 1,
          listingId: 'l_orange',
          date: '2026-10-22',
          moqThreshold: 100.0,
          currentQuantity: 65.0,
          remainingCapacity: 35.0,
          status: 'open',
          orderCount: 4,
        ),
      ),
      const DailyListing(
        id: 'l_rice',
        productId: 'p_rice',
        productTitle: 'Miniket Premium Rice',
        unit: 'bag',
        marketPrice: 2100.0,
        unitPrice: 1750.0,
        discountPercent: 16.6,
        moqThreshold: 50.0,
        activeBucketNumber: 2,
        totalBucketsCount: 2,
        totalVolumeOrdered: 62.0,
        status: 'active',
        category: 'Grains & Staples',
        description: 'Extra long grain Dinajpur fragrant rice',
        activeBucket: BatchBucket(
          bucketNumber: 2,
          listingId: 'l_rice',
          date: '2026-10-22',
          moqThreshold: 50.0,
          currentQuantity: 12.0,
          remainingCapacity: 38.0,
          status: 'open',
          orderCount: 2,
        ),
      ),
      const DailyListing(
        id: 'l_oil',
        productId: 'p_oil',
        productTitle: 'Pure Mustard Oil',
        unit: 'jar',
        marketPrice: 950.0,
        unitPrice: 780.0,
        discountPercent: 18.0,
        moqThreshold: 80.0,
        activeBucketNumber: 1,
        totalBucketsCount: 1,
        totalVolumeOrdered: 45.0,
        status: 'active',
        category: 'Edible Oils',
        description: 'Cold-pressed natural mustard oil',
        activeBucket: BatchBucket(
          bucketNumber: 1,
          listingId: 'l_oil',
          date: '2026-10-22',
          moqThreshold: 80.0,
          currentQuantity: 45.0,
          remainingCapacity: 35.0,
          status: 'open',
          orderCount: 3,
        ),
      ),
    ];

    test('search returns empty when query and category are blank', () async {
      final repo = LocalOrAlgoliaSearchRepository(getListings: () => mockListings);
      final results = await repo.search('');
      expect(results, isEmpty);
    });

    test('search matches product title case-insensitively', () async {
      final repo = LocalOrAlgoliaSearchRepository(getListings: () => mockListings);
      final results = await repo.search('orange');
      expect(results.length, 1);
      expect(results.first.listingId, 'l_orange');
      expect(results.first.savingsPerUnit, 60.0);
    });

    test('search matches category chips ("Fruits", "Grains", "Oils")', () async {
      final repo = LocalOrAlgoliaSearchRepository(getListings: () => mockListings);

      final fruitResults = await repo.search('Fruits');
      expect(fruitResults.length, 1);
      expect(fruitResults.first.listingId, 'l_orange');

      final grainResults = await repo.search('Grains');
      expect(grainResults.length, 1);
      expect(grainResults.first.listingId, 'l_rice');

      final oilResults = await repo.search('Oils');
      expect(oilResults.length, 1);
      expect(oilResults.first.listingId, 'l_oil');
    });

    test('search throws SearchNetworkException when simulated offline', () async {
      final repo = LocalOrAlgoliaSearchRepository(
        getListings: () => mockListings,
        simulateNetworkError: true,
      );

      expect(() => repo.search('rice'), throwsA(isA<SearchNetworkException>()));
    });
  });

  group('debouncedSearchResultsProvider & Riverpod Tests', () {
    test('300ms keystroke debounce cancels rapid keystrokes and executes once', () async {
      var searchExecutionCount = 0;

      final container = ProviderContainer(
        overrides: [
          searchRepositoryProvider.overrideWithValue(
            _SpySearchRepository(onSearch: () => searchExecutionCount++),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Rapidly update search query 3 times within 100ms
      container.read(searchQueryProvider.notifier).state = 'O';
      container.read(debouncedSearchResultsProvider);

      await Future.delayed(const Duration(milliseconds: 50));
      container.read(searchQueryProvider.notifier).state = 'Or';
      container.read(debouncedSearchResultsProvider);

      await Future.delayed(const Duration(milliseconds: 50));
      container.read(searchQueryProvider.notifier).state = 'Orange';
      final subscription = container.listen(debouncedSearchResultsProvider, (prev, next) {});

      // Before 300ms settles, search has NOT completed
      expect(searchExecutionCount, 0);

      // Wait for 300ms debounce to settle
      await Future.delayed(const Duration(milliseconds: 350));

      // After settling, only the final query executed
      expect(searchExecutionCount, 1);
      subscription.close();
    });

    test('immediate return when query is blank', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(searchQueryProvider.notifier).state = '';
      final results = await container.read(debouncedSearchResultsProvider.future);
      expect(results, isEmpty);
    });
  });
}

class _SpySearchRepository implements SearchRepository {
  final void Function() onSearch;

  _SpySearchRepository({required this.onSearch});

  @override
  Future<List<DailySearchResult>> search(String query, {String? category}) async {
    onSearch();
    return [
      DailySearchResult(
        listingId: 'l1',
        productId: 'p1',
        productTitle: query,
        category: category ?? 'General',
        unit: 'kg',
        unitPrice: 100,
        marketPrice: 150,
        discountPercent: 33,
        moqThreshold: 50,
        activeBucketNumber: 1,
        totalVolumeOrdered: 10,
        bucketCurrentQuantity: 10,
        bucketRemainingCapacity: 40,
        bucketProgressPercent: 0.2,
        bucketStatus: 'open',
        thumbnailUrl: '',
      ),
    ];
  }
}
