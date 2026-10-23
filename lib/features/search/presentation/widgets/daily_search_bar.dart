import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ekshate_app/core/errors/app_exception.dart';
import 'package:ekshate_app/features/cart/presentation/cart_controller.dart';
import 'package:ekshate_app/features/daily_sale/domain/daily_listing.dart';
import 'package:ekshate_app/features/daily_sale/domain/batch_bucket.dart';
import 'package:ekshate_app/features/search/domain/daily_search_result.dart';
import 'package:ekshate_app/features/search/presentation/search_controller.dart';

class DailySearchBar extends ConsumerStatefulWidget {
  const DailySearchBar({super.key});

  @override
  ConsumerState<DailySearchBar> createState() => _DailySearchBarState();
}

class _DailySearchBarState extends ConsumerState<DailySearchBar> {
  final TextEditingController _textController = TextEditingController();
  final ShadPopoverController _popoverController = ShadPopoverController();
  final FocusNode _focusNode = FocusNode();

  static const List<String> popularCategories = [
    'Fruits',
    'Grains',
    'Oils',
    'Vegetables',
  ];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && !_popoverController.isOpen) {
        _popoverController.show();
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _popoverController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onCategoryChipTapped(String cat) {
    _textController.text = cat;
    ref.read(searchQueryProvider.notifier).state = cat;
    if (!_popoverController.isOpen) {
      _popoverController.show();
    }
  }

  void _clearSearch() {
    _textController.clear();
    ref.read(searchQueryProvider.notifier).state = '';
    ref.read(selectedCategoryProvider.notifier).state = null;
    if (_popoverController.isOpen) {
      // Re-render Idle popover state or hide
      _popoverController.show();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final query = ref.watch(searchQueryProvider);
    final searchAsync = ref.watch(debouncedSearchResultsProvider);

    return ShadPopover(
      controller: _popoverController,
      popover: (context) => Container(
        key: const Key('search_popover_container'),
        width: MediaQuery.of(context).size.width - 32,
        constraints: const BoxConstraints(maxHeight: 400),
        child: searchAsync.when(
          data: (results) {
            // STATE 1: IDLE
            if (query.trim().isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  key: const Key('search_idle_state'),
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(LucideIcons.sparkles, size: 16, color: Color(0xFF10B981)),
                        const SizedBox(width: 6),
                        Text(
                          'Popular Categories',
                          style: theme.textTheme.small.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: popularCategories.map((cat) {
                        return ActionChip(
                          key: Key('chip_category_$cat'),
                          backgroundColor: theme.colorScheme.muted,
                          label: Text(
                            cat,
                            style: TextStyle(
                              color: theme.colorScheme.foreground,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          onPressed: () => _onCategoryChipTapped(cat),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            }

            // STATE 2: EMPTY
            if (results.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 16.0),
                child: Column(
                  key: const Key('search_empty_state'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.searchX, size: 40, color: Colors.grey),
                    const SizedBox(height: 10),
                    Text(
                      'No products found for "$query"',
                      style: theme.textTheme.large.copyWith(fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Try searching for Oranges, Rice, or Mustard Oil',
                      style: theme.textTheme.muted,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            // STATE 3: SUCCESS
            return ListView.separated(
              key: const Key('search_results_list'),
              shrinkWrap: true,
              padding: const EdgeInsets.all(8.0),
              itemCount: results.length,
              separatorBuilder: (_, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = results[index];
                return _SearchResultTile(
                  key: Key('search_tile_${item.listingId}'),
                  item: item,
                );
              },
            );
          },
          // STATE 4: LOADING
          loading: () => const Center(
            key: Key('search_loading_state'),
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                    strokeWidth: 2.5,
                  ),
                  SizedBox(height: 12),
                  Text('Searching wholesale deals...'),
                ],
              ),
            ),
          ),
          // STATE 5: ERROR
          error: (err, _) => Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              key: const Key('search_error_state'),
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.wifiOff, size: 36, color: Colors.redAccent),
                const SizedBox(height: 8),
                Text(
                  'Search unavailable offline',
                  style: theme.textTheme.large.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  err.toString(),
                  style: theme.textTheme.muted,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                ShadButton.outline(
                  key: const Key('search_retry_button'),
                  size: ShadButtonSize.sm,
                  onPressed: () {
                    ref.invalidate(debouncedSearchResultsProvider);
                  },
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.refreshCw, size: 14),
                      SizedBox(width: 6),
                      Text('Retry Search'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      child: ShadInput(
        key: const Key('daily_search_input'),
        controller: _textController,
        focusNode: _focusNode,
        placeholder: const Text('Search active daily bulk deals (e.g. Oranges, Rice)...'),
        leading: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.0),
          child: Icon(LucideIcons.search, size: 18),
        ),
        trailing: query.isNotEmpty
            ? IconButton(
                key: const Key('search_clear_button'),
                icon: const Icon(LucideIcons.x, size: 16),
                onPressed: _clearSearch,
              )
            : null,
        onChanged: (val) {
          ref.read(searchQueryProvider.notifier).state = val;
          if (!_popoverController.isOpen) {
            _popoverController.show();
          }
        },
      ),
    );
  }
}

class _SearchResultTile extends ConsumerWidget {
  final DailySearchResult item;
  const _SearchResultTile({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final hasCapacity = item.hasCapacity;
    final savings = item.savingsPerUnit;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Product Title & Discount Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  item.productTitle,
                  style: theme.textTheme.large.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              ShadBadge.secondary(
                key: Key('search_discount_badge_${item.listingId}'),
                child: Text('${item.discountPercent.toStringAsFixed(0)}% OFF'),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Row 2: Price Savings, Wholesale Unit Price, Strikethrough Retail Benchmark, Bucket Badge
          Row(
            children: [
              Text(
                '৳${item.unitPrice.toStringAsFixed(0)}/${item.unit}',
                style: theme.textTheme.h4.copyWith(
                  color: const Color(0xFF10B981),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '৳${item.marketPrice.toStringAsFixed(0)}',
                style: theme.textTheme.muted.copyWith(decoration: TextDecoration.lineThrough),
              ),
              if (savings > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Save ৳${savings.toStringAsFixed(0)}/${item.unit}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF10B981),
                    ),
                  ),
                ),
              ],
              const Spacer(),
              ShadBadge.outline(
                key: Key('search_bucket_badge_${item.listingId}'),
                child: Text('Bucket #${item.activeBucketNumber}'),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Row 3: Live Batch Quota Fill Progress & Remaining Capacity
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Batch Quota: ${(item.bucketProgressPercent * 100).toStringAsFixed(0)}% Filled',
                style: theme.textTheme.small.copyWith(fontWeight: FontWeight.w500),
              ),
              Text(
                'Remaining: ${item.bucketRemainingCapacity.toStringAsFixed(0)} ${item.unit}',
                style: theme.textTheme.small.copyWith(
                  color: hasCapacity ? const Color(0xFF10B981) : Colors.orangeAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Progress Bar
          LinearProgressIndicator(
            key: Key('search_progress_bar_${item.listingId}'),
            value: item.bucketProgressPercent.clamp(0.0, 1.0),
            backgroundColor: Colors.white10,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 8),

          // Row 4: 1-Tap Quick Reserve (1 unit) Button
          Align(
            alignment: Alignment.centerRight,
            child: ShadButton(
              key: Key('quick_reserve_btn_${item.listingId}'),
              size: ShadButtonSize.sm,
              enabled: hasCapacity,
              onPressed: () {
                final listing = DailyListing(
                  id: item.listingId,
                  productId: item.productId,
                  productTitle: item.productTitle,
                  unit: item.unit,
                  marketPrice: item.marketPrice,
                  unitPrice: item.unitPrice,
                  discountPercent: item.discountPercent,
                  moqThreshold: item.moqThreshold,
                  activeBucketNumber: item.activeBucketNumber,
                  totalBucketsCount: 1,
                  totalVolumeOrdered: item.totalVolumeOrdered,
                  status: item.bucketStatus,
                  activeBucket: BatchBucket(
                    bucketNumber: item.activeBucketNumber,
                    listingId: item.listingId,
                    date: '',
                    moqThreshold: item.moqThreshold,
                    currentQuantity: item.bucketCurrentQuantity,
                    remainingCapacity: item.bucketRemainingCapacity,
                    status: item.bucketStatus,
                    orderCount: 0,
                  ),
                );

                try {
                  ref.read(cartProvider.notifier).addItem(listing, 1.0);
                  ShadToaster.of(context).show(
                    ShadToast(
                      title: const Text('Added to Batch Cart'),
                      description: Text('Added 1 ${item.unit} of ${item.productTitle} to order.'),
                    ),
                  );
                } on BucketCapacityExceededException catch (e) {
                  ShadToaster.of(context).show(
                    ShadToast.destructive(
                      title: const Text('Capacity Limit Reached'),
                      description: Text(e.message),
                    ),
                  );
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.shoppingBag, size: 14),
                  const SizedBox(width: 4),
                  Text(hasCapacity ? 'Quick Reserve (1 unit)' : 'Bucket Full'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
