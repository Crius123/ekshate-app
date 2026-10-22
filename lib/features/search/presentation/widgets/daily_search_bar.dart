import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../domain/daily_search_result.dart';
import '../search_controller.dart';
import '../../../cart/presentation/cart_controller.dart';
import '../../../daily_sale/domain/daily_listing.dart';
import '../../../daily_sale/domain/batch_bucket.dart';

class DailySearchBar extends ConsumerStatefulWidget {
  const DailySearchBar({super.key});

  @override
  ConsumerState<DailySearchBar> createState() => _DailySearchBarState();
}

class _DailySearchBarState extends ConsumerState<DailySearchBar> {
  final TextEditingController _textController = TextEditingController();
  final ShadPopoverController _popoverController = ShadPopoverController();

  @override
  void dispose() {
    _textController.dispose();
    _popoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final query = ref.watch(searchQueryProvider);
    final searchAsync = ref.watch(debouncedSearchResultsProvider);

    return ShadPopover(
      controller: _popoverController,
      popover: (context) => SizedBox(
        width: MediaQuery.of(context).size.width - 32,
        height: 380,
        child: searchAsync.when(
          data: (results) {
            // STATE 1: IDLE
            if (query.trim().isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Popular Categories', style: theme.textTheme.small),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['Fruits', 'Grains', 'Oils', 'Vegetables'].map((cat) {
                        return ActionChip(
                          label: Text(cat),
                          onPressed: () {
                            _textController.text = cat;
                            ref.read(searchQueryProvider.notifier).state = cat;
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              );
            }

            // STATE 2: EMPTY
            if (results.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.searchX, size: 36, color: Colors.grey),
                    const SizedBox(height: 8),
                    Text('No products found for "$query"', style: theme.textTheme.muted),
                  ],
                ),
              );
            }

            // STATE 3: SUCCESS
            return ListView.separated(
              padding: const EdgeInsets.all(8.0),
              itemCount: results.length,
              separatorBuilder: (_, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = results[index];
                return _SearchResultTile(item: item);
              },
            );
          },
          // STATE 4: LOADING
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(color: Color(0xFF10B981)),
            ),
          ),
          // STATE 5: ERROR
          error: (err, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.alertCircle, color: Colors.red),
                const SizedBox(height: 4),
                Text('Search error: ${err.toString()}', style: theme.textTheme.muted),
              ],
            ),
          ),
        ),
      ),
      child: ShadInput(
        controller: _textController,
        placeholder: const Text('Search active daily bulk deals (e.g. Oranges, Rice)...'),
        leading: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.0),
          child: Icon(LucideIcons.search, size: 18),
        ),
        trailing: query.isNotEmpty
            ? IconButton(
                icon: const Icon(LucideIcons.x, size: 16),
                onPressed: () {
                  _textController.clear();
                  ref.read(searchQueryProvider.notifier).state = '';
                  _popoverController.hide();
                },
              )
            : null,
        onChanged: (val) {
          ref.read(searchQueryProvider.notifier).state = val;
          if (val.trim().isNotEmpty && !_popoverController.isOpen) {
            _popoverController.show();
          } else if (val.trim().isEmpty && _popoverController.isOpen) {
            _popoverController.hide();
          }
        },
      ),
    );
  }
}

class _SearchResultTile extends ConsumerWidget {
  final DailySearchResult item;
  const _SearchResultTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final hasCapacity = item.bucketRemainingCapacity > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(item.productTitle, style: theme.textTheme.large.copyWith(fontWeight: FontWeight.bold)),
              ),
              ShadBadge.secondary(
                child: Text('${item.discountPercent.toStringAsFixed(0)}% OFF'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text('৳${item.unitPrice.toStringAsFixed(0)}/${item.unit}',
                  style: theme.textTheme.h4.copyWith(color: const Color(0xFF10B981))),
              const SizedBox(width: 8),
              Text('৳${item.marketPrice.toStringAsFixed(0)}',
                  style: theme.textTheme.muted.copyWith(decoration: TextDecoration.lineThrough)),
              const Spacer(),
              ShadBadge.outline(
                child: Text('Bucket #${item.activeBucketNumber}'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Bucket Fill Progress Indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Batch Quota: ${(item.bucketProgressPercent * 100).toStringAsFixed(0)}% Filled',
                  style: theme.textTheme.small),
              Text('Remaining: ${item.bucketRemainingCapacity.toStringAsFixed(0)} ${item.unit}',
                  style: theme.textTheme.small.copyWith(
                    color: hasCapacity ? const Color(0xFF10B981) : Colors.orangeAccent,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: item.bucketProgressPercent,
            backgroundColor: Colors.white10,
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: ShadButton(
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
                  status: 'active',
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

                ref.read(cartProvider.notifier).addItem(listing, 1.0);
                ShadToaster.of(context).show(
                  ShadToast(
                    title: const Text('Added to Batch Cart'),
                    description: Text('Added 1 ${item.unit} of ${item.productTitle} to order.'),
                  ),
                );
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.shoppingBag, size: 14),
                  SizedBox(width: 4),
                  Text('Quick Reserve (1 unit)'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
