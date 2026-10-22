import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'daily_sale_controller.dart';
import 'widgets/capacity_quantity_selector.dart';
import '../../cart/presentation/cart_controller.dart';
import '../../search/presentation/widgets/daily_search_bar.dart';
import '../../../core/config/app_constants.dart';

class DailySaleScreen extends ConsumerStatefulWidget {
  const DailySaleScreen({super.key});

  @override
  ConsumerState<DailySaleScreen> createState() => _DailySaleScreenState();
}

class _DailySaleScreenState extends ConsumerState<DailySaleScreen> {
  final Map<String, double> _selectedQuantities = {};

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final listings = ref.watch(dailyListingsProvider);
    final campaignStatus = ref.watch(dailyCampaignStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(LucideIcons.flame, color: Color(0xFF10B981), size: 20),
            const SizedBox(width: 8),
            Text(AppConstants.appName, style: theme.textTheme.h4),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ShadBadge.outline(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.clock, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    campaignStatus == 'active' ? 'Active: Closes 11:59 PM' : 'Preview Mode',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const DailySearchBar(),
          const SizedBox(height: 16),
          ...listings.map((listing) {
            final bucket = listing.activeBucket;
            final remainingCapacity = bucket?.remainingCapacity ?? 0.0;
            final selectedQty = _selectedQuantities[listing.id] ?? 1.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: ShadCard(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      listing.productTitle,
                      style: theme.textTheme.h4,
                    ),
                  ),
                  ShadBadge(
                    child: Text('Bucket #${listing.activeBucketNumber}'),
                  ),
                ],
              ),
              description: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '৳${listing.unitPrice.toStringAsFixed(0)}/${listing.unit}',
                        style: theme.textTheme.h3.copyWith(color: const Color(0xFF10B981)),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '৳${listing.marketPrice.toStringAsFixed(0)}',
                        style: theme.textTheme.muted.copyWith(
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(width: 8),
                      ShadBadge.secondary(
                        child: Text('${listing.discountPercent.toStringAsFixed(0)}% OFF'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Bucket progress indicator
                  Text(
                    'Batch Quota: ${bucket?.currentQuantity.toStringAsFixed(0)}/${bucket?.moqThreshold.toStringAsFixed(0)} ${listing.unit} ordered',
                    style: theme.textTheme.small,
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: bucket?.progressPercentage ?? 0.0,
                    backgroundColor: Colors.white10,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 16),
                  // Capacity Clamped Quantity Selector
                  CapacityQuantitySelector(
                    currentQuantity: selectedQty,
                    remainingCapacity: remainingCapacity,
                    unit: listing.unit,
                    onQuantityChanged: (qty) {
                      setState(() {
                        _selectedQuantities[listing.id] = qty;
                      });
                    },
                  ),
                ],
              ),
              footer: Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Subtotal: ৳${(listing.unitPrice * selectedQty).toStringAsFixed(0)}',
                      style: theme.textTheme.large.copyWith(fontWeight: FontWeight.bold),
                    ),
                    ShadButton(
                      enabled: remainingCapacity > 0,
                      onPressed: () {
                        try {
                          ref.read(cartProvider.notifier).addItem(listing, selectedQty);
                          ShadToaster.of(context).show(
                            ShadToast(
                              title: const Text('Added to Batch Cart'),
                              description: Text('Added ${selectedQty.toStringAsFixed(0)} ${listing.unit} to your order.'),
                            ),
                          );
                        } catch (e) {
                          ShadToaster.of(context).show(
                            ShadToast.destructive(
                              title: const Text('Capacity Exceeded'),
                              description: Text(e.toString()),
                            ),
                          );
                        }
                      },
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.shoppingBag, size: 16),
                          SizedBox(width: 8),
                          Text('Reserve Volume'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),
          );
        }),
      ],
    ),
    );
  }
}
