import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ekshate_app/features/search/domain/daily_search_result.dart';
import 'package:ekshate_app/features/search/data/search_repository.dart';
import 'package:ekshate_app/features/search/presentation/search_controller.dart';
import 'package:ekshate_app/features/search/presentation/widgets/daily_search_bar.dart';
import 'package:ekshate_app/features/cart/presentation/cart_controller.dart';

void main() {
  void configureViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Widget createSearchWidget({
    List<Override> overrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        searchDebounceDurationProvider.overrideWithValue(Duration.zero),
        ...overrides,
      ],
      child: const ShadApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16.0),
            child: DailySearchBar(),
          ),
        ),
      ),
    );
  }

  group('DailySearchBar Widget Tests', () {
    testWidgets('Idle state renders popular category suggestion chips', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createSearchWidget());
      await tester.pumpAndSettle();

      // Tap the search input to focus and trigger the popover
      final inputFinder = find.byKey(const Key('daily_search_input'));
      expect(inputFinder, findsOneWidget);
      await tester.tap(inputFinder);
      await tester.pumpAndSettle();

      // State 1: Idle state
      expect(find.byKey(const Key('search_idle_state')), findsOneWidget);
      expect(find.text('Popular Categories'), findsOneWidget);
      expect(find.byKey(const Key('chip_category_Fruits')), findsOneWidget);
      expect(find.byKey(const Key('chip_category_Grains')), findsOneWidget);
      expect(find.byKey(const Key('chip_category_Oils')), findsOneWidget);
      expect(find.byKey(const Key('chip_category_Vegetables')), findsOneWidget);
    });

    testWidgets('Tapping category chip triggers search and updates input text', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createSearchWidget());
      await tester.pumpAndSettle();

      // Open popover
      await tester.tap(find.byKey(const Key('daily_search_input')));
      await tester.pumpAndSettle();

      // Tap Fruits chip
      await tester.tap(find.byKey(const Key('chip_category_Fruits')));
      await tester.pumpAndSettle();

      // Input text should be updated
      final inputWidget = tester.widget<ShadInput>(find.byKey(const Key('daily_search_input')));
      expect(inputWidget.controller?.text, 'Fruits');

      // Results rendered
      expect(find.byKey(const Key('search_results_list')), findsOneWidget);
      expect(find.text('Nagpur Oranges (1 kg)'), findsOneWidget);
    });

    testWidgets('Success state renders product title, discount badge, savings, bucket #, and quota bar', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createSearchWidget());
      await tester.pumpAndSettle();

      // Enter query "Orange"
      await tester.enterText(find.byKey(const Key('daily_search_input')), 'Orange');
      await tester.pumpAndSettle();

      // Tile rendered
      expect(find.byKey(const Key('search_tile_listing_orange_01')), findsOneWidget);
      expect(find.text('Nagpur Oranges (1 kg)'), findsOneWidget);

      // Discount badge
      expect(find.byKey(const Key('search_discount_badge_listing_orange_01')), findsOneWidget);
      expect(find.text('25% OFF'), findsOneWidget);

      // Wholesale price, strikethrough retail price, savings badge
      expect(find.text('৳180/kg'), findsOneWidget);
      expect(find.text('৳240'), findsOneWidget);
      expect(find.text('Save ৳60/kg'), findsOneWidget);

      // Active bucket badge & quota progress bar
      expect(find.byKey(const Key('search_bucket_badge_listing_orange_01')), findsOneWidget);
      expect(find.text('Bucket #1'), findsOneWidget);
      expect(find.text('Batch Quota: 65% Filled'), findsOneWidget);
      expect(find.text('Remaining: 35 kg'), findsOneWidget);
      expect(find.byKey(const Key('search_progress_bar_listing_orange_01')), findsOneWidget);

      // 1-tap Quick Reserve button
      expect(find.byKey(const Key('quick_reserve_btn_listing_orange_01')), findsOneWidget);
      expect(find.text('Quick Reserve (1 unit)'), findsOneWidget);
    });

    testWidgets('1-tap Quick Reserve button inserts 1 unit into batch cart and triggers confirmation toast', (tester) async {
      configureViewport(tester);
      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            searchDebounceDurationProvider.overrideWithValue(Duration.zero),
          ],
          child: Consumer(
            builder: (context, ref, child) {
              container = ProviderScope.containerOf(context);
              return const ShadApp(
                home: Scaffold(
                  body: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: DailySearchBar(),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Cart initially empty
      expect(container.read(cartProvider), isEmpty);

      // Search for "Orange"
      await tester.enterText(find.byKey(const Key('daily_search_input')), 'Orange');
      await tester.pumpAndSettle();

      // Tap Quick Reserve button
      final reserveBtnFinder = find.byKey(const Key('quick_reserve_btn_listing_orange_01'));
      expect(reserveBtnFinder, findsOneWidget);
      await tester.tap(reserveBtnFinder);
      await tester.pumpAndSettle();

      // Cart now contains 1 unit of Nagpur Oranges
      final cart = container.read(cartProvider);
      expect(cart.length, 1);
      expect(cart.first.listingId, 'listing_orange_01');
      expect(cart.first.productTitle, 'Nagpur Oranges (1 kg)');
      expect(cart.first.quantity, 1.0);
      expect(cart.first.unitPrice, 180.0);

      // Toast displayed
      expect(find.text('Added to Batch Cart'), findsOneWidget);
      expect(find.text('Added 1 kg of Nagpur Oranges (1 kg) to order.'), findsOneWidget);
    });

    testWidgets('Quick Reserve validates remaining capacity and disables when bucket is full', (tester) async {
      configureViewport(tester);

      final fullListingResult = [
        const DailySearchResult(
          listingId: 'l_full',
          productId: 'p_full',
          productTitle: 'Full Bucket Mangoes',
          category: 'Fruits',
          unit: 'crate',
          unitPrice: 1200,
          marketPrice: 1500,
          discountPercent: 20,
          moqThreshold: 50,
          activeBucketNumber: 1,
          totalVolumeOrdered: 50,
          bucketCurrentQuantity: 50,
          bucketRemainingCapacity: 0.0, // Remaining capacity is 0
          bucketProgressPercent: 1.0,
          bucketStatus: 'target_met',
          thumbnailUrl: '',
        ),
      ];

      await tester.pumpWidget(
        createSearchWidget(
          overrides: [
            searchRepositoryProvider.overrideWithValue(
              _MockSpecificSearchRepo(fullListingResult),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Search
      await tester.enterText(find.byKey(const Key('daily_search_input')), 'Mangoes');
      await tester.pumpAndSettle();

      // Tile rendered
      expect(find.byKey(const Key('search_tile_l_full')), findsOneWidget);
      expect(find.text('Batch Quota: 100% Filled'), findsOneWidget);
      expect(find.text('Remaining: 0 crate'), findsOneWidget);

      // Button is disabled with "Bucket Full" text
      final btnFinder = find.byKey(const Key('quick_reserve_btn_l_full'));
      expect(btnFinder, findsOneWidget);
      expect(find.text('Bucket Full'), findsOneWidget);

      final shadBtn = tester.widget<ShadButton>(btnFinder);
      expect(shadBtn.enabled, isFalse);
    });

    testWidgets('Empty state renders when no listings match query', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createSearchWidget());
      await tester.pumpAndSettle();

      // Enter query with no matches
      await tester.enterText(find.byKey(const Key('daily_search_input')), 'Exotic Dragonfruit');
      await tester.pumpAndSettle();

      // State 2: Empty state
      expect(find.byKey(const Key('search_empty_state')), findsOneWidget);
      expect(find.text('No products found for "Exotic Dragonfruit"'), findsOneWidget);
      expect(find.text('Try searching for Oranges, Rice, or Mustard Oil'), findsOneWidget);
    });

    testWidgets('Error state renders offline message and retry button when network fails', (tester) async {
      configureViewport(tester);
      final repo = _FailingSearchRepository();

      await tester.pumpWidget(
        createSearchWidget(
          overrides: [
            searchRepositoryProvider.overrideWithValue(repo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Enter search query to trigger failure
      await tester.enterText(find.byKey(const Key('daily_search_input')), 'Rice');
      await tester.pumpAndSettle();

      expect(repo.callCount, 1);

      // State 5: Error state
      expect(find.byKey(const Key('search_error_state')), findsOneWidget);
      expect(find.text('Search unavailable offline'), findsOneWidget);
      expect(find.byKey(const Key('search_retry_button')), findsOneWidget);

      // Tap Retry
      await tester.tap(find.byKey(const Key('search_retry_button')));
      await tester.pumpAndSettle();

      // Verify retry re-executed search
      expect(repo.callCount, 2);
    });

    testWidgets('Trailing clear button clears search text and resets query', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createSearchWidget());
      await tester.pumpAndSettle();

      // Enter query
      await tester.enterText(find.byKey(const Key('daily_search_input')), 'Mustard');
      await tester.pumpAndSettle();

      // Trailing clear button appears
      final clearBtn = find.byKey(const Key('search_clear_button'));
      expect(clearBtn, findsOneWidget);

      // Tap clear button
      await tester.tap(clearBtn);
      await tester.pumpAndSettle();

      // Input is now cleared
      final inputWidget = tester.widget<ShadInput>(find.byKey(const Key('daily_search_input')));
      expect(inputWidget.controller?.text, '');

      // Trailing clear button is hidden
      expect(find.byKey(const Key('search_clear_button')), findsNothing);
    });
  });
}

class _MockSpecificSearchRepo implements SearchRepository {
  final List<DailySearchResult> results;
  _MockSpecificSearchRepo(this.results);

  @override
  Future<List<DailySearchResult>> search(String query, {String? category}) async {
    return results;
  }
}

class _FailingSearchRepository implements SearchRepository {
  int callCount = 0;

  @override
  Future<List<DailySearchResult>> search(String query, {String? category}) async {
    callCount++;
    throw const SearchNetworkException('Connection timeout to Algolia cluster.');
  }
}
