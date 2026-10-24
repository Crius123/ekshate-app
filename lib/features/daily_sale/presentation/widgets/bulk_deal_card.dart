import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ekshate_app/core/config/theme/app_decorations.dart';
import 'package:ekshate_app/core/router/route_paths.dart';
import 'package:ekshate_app/features/daily_sale/domain/daily_listing.dart';
import 'package:ekshate_app/features/daily_sale/presentation/widgets/batch_quota_indicator.dart';
import 'package:ekshate_app/features/daily_sale/presentation/widgets/capacity_quantity_selector.dart';
import 'package:ekshate_app/features/cart/presentation/cart_controller.dart';
import 'package:ekshate_app/core/errors/app_exception.dart';

class BulkDealCard extends ConsumerStatefulWidget {
  final DailyListing listing;
  final EdgeInsetsGeometry? margin;

  const BulkDealCard({
    super.key,
    required this.listing,
    this.margin,
  });

  @override
  ConsumerState<BulkDealCard> createState() => _BulkDealCardState();
}

class _BulkDealCardState extends ConsumerState<BulkDealCard> {
  late double _selectedQuantity;

  @override
  void initState() {
    super.initState();
    _selectedQuantity = 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final listing = widget.listing;
    final bucket = listing.activeBucket;
    final remainingCapacity = bucket?.remainingCapacity ?? 0.0;
    final subtotal = listing.unitPrice * _selectedQuantity;

    return Container(
      margin: widget.margin ?? EdgeInsets.zero,
      decoration: AppDecorations.glassCard(
        surfaceColor: AppColors.cardSurface,
        borderColor: AppColors.borderSubtle,
        borderRadius: 16,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. High-Resolution Product Photography Section (Flex: 3)
          Expanded(
            flex: 3,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                context.push(RoutePaths.productDetailsPath(listing.id));
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                listing.imageUrl != null && listing.imageUrl!.isNotEmpty
                    ? Image.network(
                        listing.imageUrl!,
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildImagePlaceholder(listing);
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return _buildImageLoadingShimmer();
                        },
                      )
                    : _buildImagePlaceholder(listing),

                // Gradient Overlay on Image Bottom
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 48,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.75),
                        ],
                      ),
                    ),
                  ),
                ),

                // Badges Overlaid on Photography
                Positioned(
                  top: 8,
                  left: 8,
                  child: ShadBadge.secondary(
                    key: Key('discount_badge_${listing.id}'),
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Text(
                      '${listing.discountPercent.toStringAsFixed(0)}% OFF',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
                    ),
                  ),
                ),

                Positioned(
                  top: 8,
                  right: 8,
                  child: ShadBadge(
                    key: Key('bucket_badge_overlay_${listing.id}'),
                    backgroundColor: const Color(0xFF27272A).withValues(alpha: 0.9),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.package2, size: 10, color: Color(0xFF10B981)),
                        const SizedBox(width: 4),
                        Text(
                          'Bucket #${listing.activeBucketNumber}',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),

                // Category Tag
                if (listing.category != null)
                  Positioned(
                    bottom: 6,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        listing.category!,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFFE4E4E7),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),

        // 2. Deal Content & Live Indicators (Flex: 5, image takes up proportion of this space)
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10.0, 7.0, 10.0, 7.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Group: Product Title & Pricing Row
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () {
                          context.push(RoutePaths.productDetailsPath(listing.id));
                        },
                        child: Text(
                          listing.productTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.h4.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                            color: AppColors.textPrimary,
                            height: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '৳${listing.unitPrice.toStringAsFixed(0)}/${listing.unit}',
                            style: theme.textTheme.h3.copyWith(
                              color: const Color(0xFF10B981),
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                            ),
                          ),
                          Text(
                            '৳${listing.marketPrice.toStringAsFixed(0)}',
                            style: theme.textTheme.muted.copyWith(
                              decoration: TextDecoration.lineThrough,
                              fontSize: 11.5,
                            ),
                          ),
                          ShadBadge.outline(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            child: Text(
                              'Save ৳${listing.savingsPerUnit.toStringAsFixed(0)}/${listing.unit}',
                              style: const TextStyle(
                                fontSize: 9,
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Middle Group: Quota Progress Bar (without redundant text) & Volume Selector
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (bucket != null)
                        BatchQuotaIndicator(
                          bucket: bucket,
                          unit: listing.unit,
                          showBucketBadge: false,
                          showRemainingInfo: false,
                        ),
                      const SizedBox(height: 3),
                      CapacityQuantitySelector(
                        currentQuantity: _selectedQuantity,
                        remainingCapacity: remainingCapacity,
                        unit: listing.unit,
                        onQuantityChanged: (qty) {
                          setState(() {
                            _selectedQuantity = qty;
                          });
                        },
                      ),
                    ],
                  ),

                  // Bottom Group: Subtotal and "Reserve Volume" Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Subtotal',
                            style: theme.textTheme.muted.copyWith(fontSize: 9.5),
                          ),
                          Text(
                            '৳${subtotal.toStringAsFixed(0)}',
                            style: theme.textTheme.h4.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: ShadButton(
                          key: Key('reserve_volume_btn_${listing.id}'),
                          size: ShadButtonSize.sm,
                          enabled: remainingCapacity > 0,
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                          onPressed: () {
                            HapticFeedback.mediumImpact();

                            try {
                              ref
                                  .read(cartProvider.notifier)
                                  .addItem(listing, _selectedQuantity);

                              ShadToaster.of(context).show(
                                ShadToast(
                                  title: const Text('Added to Batch Cart'),
                                  description: Text(
                                    'Added ${_selectedQuantity.toStringAsFixed(0)} ${listing.unit} of ${listing.productTitle} to your order.',
                                  ),
                                ),
                              );
                            } on BucketCapacityExceededException catch (e) {
                              HapticFeedback.heavyImpact();
                              ShadToaster.of(context).show(
                                ShadToast.destructive(
                                  title: const Text('Capacity Exceeded'),
                                  description: Text(e.message),
                                ),
                              );
                            } catch (e) {
                              ShadToaster.of(context).show(
                                ShadToast.destructive(
                                  title: const Text('Cart Error'),
                                  description: Text(e.toString()),
                                ),
                              );
                            }
                          },
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.shoppingBag, size: 11),
                              SizedBox(width: 3),
                              Text(
                                'Reserve Volume',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10.0),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder(DailyListing listing) {
    return Container(
      key: Key('deal_image_placeholder_${listing.id}'),
      color: AppColors.cardSurfaceElevated,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.image, size: 28, color: AppColors.textMuted),
            SizedBox(height: 4),
            Text(
              'Wholesale Produce',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageLoadingShimmer() {
    return Container(
      color: AppColors.cardSurfaceElevated,
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF10B981),
          ),
        ),
      ),
    );
  }
}
