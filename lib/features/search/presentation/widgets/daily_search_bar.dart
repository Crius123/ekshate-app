import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ekshate_app/core/config/theme/app_decorations.dart';
import 'package:ekshate_app/core/errors/app_exception.dart';
import 'package:ekshate_app/features/cart/presentation/cart_controller.dart';
import 'package:ekshate_app/features/daily_sale/domain/daily_listing.dart';
import 'package:ekshate_app/features/daily_sale/domain/batch_bucket.dart';
import 'package:ekshate_app/features/search/domain/daily_search_result.dart';
import 'package:ekshate_app/features/search/presentation/search_controller.dart';

class DailySearchBar extends ConsumerStatefulWidget {
  final bool isHeader;
  final double? width;

  const DailySearchBar({
    super.key,
    this.isHeader = false,
    this.width,
  });

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
      setState(() {});
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
      _popoverController.show();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final query = ref.watch(searchQueryProvider);
    final searchAsync = ref.watch(debouncedSearchResultsProvider);

    final popoverWidth = widget.isHeader
        ? (MediaQuery.of(context).size.width < 500
            ? MediaQuery.of(context).size.width - 32
            : 460.0)
        : (MediaQuery.of(context).size.width - 32).clamp(300.0, 640.0);

    return Container(
      width: widget.width,
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(widget.isHeader ? 10 : 14),
        border: Border.all(
          color: _focusNode.hasFocus
              ? AppColors.emerald
              : AppColors.borderSubtle,
          width: _focusNode.hasFocus ? 1.5 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: _focusNode.hasFocus
                ? AppColors.emerald.withValues(alpha: 0.12)
                : const Color(0x060F172A),
            blurRadius: _focusNode.hasFocus ? 10 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ShadPopover(
        controller: _popoverController,
        popover: (context) => Container(
          key: const Key('search_popover_container'),
          width: popoverWidth,
          constraints: const BoxConstraints(maxHeight: 420),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderSubtle, width: 1.2),
            boxShadow: const [
              BoxShadow(
                color: Color(0x180F172A),
                blurRadius: 28,
                offset: Offset(0, 10),
              ),
            ],
          ),
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: AppColors.emerald.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  LucideIcons.sparkles,
                                  size: 14,
                                  color: AppColors.emerald,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Popular Categories',
                                style: theme.textTheme.small.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const Text(
                            'Wholesale Drops',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w500,
                            ),
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
                            backgroundColor: AppColors.cardSurfaceElevated,
                            side: const BorderSide(
                              color: AppColors.borderSubtle,
                              width: 1.0,
                            ),
                            labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                            avatar: Icon(
                              _getCategoryIcon(cat),
                              size: 14,
                              color: AppColors.emerald,
                            ),
                            label: Text(
                              cat,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
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
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.cardSurfaceElevated,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(LucideIcons.searchX, size: 32, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No products found for "$query"',
                        style: theme.textTheme.large.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Try searching for Oranges, Rice, or Mustard Oil',
                        style: theme.textTheme.muted.copyWith(fontSize: 12),
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
                padding: const EdgeInsets.all(10.0),
                itemCount: results.length,
                separatorBuilder: (_, index) => const Divider(
                  height: 1,
                  color: AppColors.borderSubtle,
                ),
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
                    Text(
                      'Searching wholesale deals...',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textMuted,
                      ),
                    ),
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
          placeholder: Text(
            widget.isHeader
                ? 'Search deals...'
                : 'Search active daily bulk deals (e.g. Oranges, Rice)...',
            style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          ),
          leading: Padding(
            padding: const EdgeInsets.only(left: 10.0, right: 6.0),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.emerald.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                LucideIcons.search,
                size: 14,
                color: AppColors.emerald,
              ),
            ),
          ),
          trailing: query.isNotEmpty
              ? IconButton(
                  key: const Key('search_clear_button'),
                  icon: const Icon(LucideIcons.x, size: 14, color: AppColors.textMuted),
                  onPressed: _clearSearch,
                )
              : (widget.isHeader
                  ? Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.cardSurfaceElevated,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.borderSubtle, width: 1),
                        ),
                        child: const Text(
                          '/',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    )
                  : null),
          onChanged: (val) {
            ref.read(searchQueryProvider.notifier).state = val;
            if (!_popoverController.isOpen) {
              _popoverController.show();
            }
          },
        ),
      ),
    );
  }

  static IconData _getCategoryIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'fruits':
        return LucideIcons.apple;
      case 'grains':
        return LucideIcons.wheat;
      case 'oils':
        return LucideIcons.droplet;
      case 'vegetables':
        return LucideIcons.carrot;
      default:
        return LucideIcons.tag;
    }
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
                  style: theme.textTheme.large.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              ShadBadge.secondary(
                key: Key('search_discount_badge_${item.listingId}'),
                backgroundColor: AppColors.emerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Text(
                  '${item.discountPercent.toStringAsFixed(0)}% OFF',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                ),
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
                  color: AppColors.emerald,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '৳${item.marketPrice.toStringAsFixed(0)}',
                style: theme.textTheme.muted.copyWith(
                  decoration: TextDecoration.lineThrough,
                  fontSize: 12,
                ),
              ),
              if (savings > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: AppColors.emerald.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Save ৳${savings.toStringAsFixed(0)}/${item.unit}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.emeraldDark,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              ShadBadge.outline(
                key: Key('search_bucket_badge_${item.listingId}'),
                child: Text(
                  'Bucket #${item.activeBucketNumber}',
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Row 3: Live Batch Quota Fill Progress & Remaining Capacity
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Batch Quota: ${(item.bucketProgressPercent * 100).toStringAsFixed(0)}% Filled',
                style: theme.textTheme.small.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                'Remaining: ${item.bucketRemainingCapacity.toStringAsFixed(0)} ${item.unit}',
                style: theme.textTheme.small.copyWith(
                  color: hasCapacity ? AppColors.emerald : AppColors.amberEscrow,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          // Progress Bar
          LinearProgressIndicator(
            key: Key('search_progress_bar_${item.listingId}'),
            value: item.bucketProgressPercent.clamp(0.0, 1.0),
            backgroundColor: AppColors.cardSurfaceElevated,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.emerald),
            minHeight: 5,
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
              backgroundColor: AppColors.emerald,
              foregroundColor: Colors.white,
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
                  const Icon(LucideIcons.shoppingBag, size: 13),
                  const SizedBox(width: 4),
                  Text(
                    hasCapacity ? 'Quick Reserve (1 unit)' : 'Bucket Full',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
