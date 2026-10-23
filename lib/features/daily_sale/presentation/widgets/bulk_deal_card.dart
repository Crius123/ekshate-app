import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ekshate_app/core/config/theme/app_decorations.dart';
import 'package:ekshate_app/features/daily_sale/domain/daily_listing.dart';
import 'package:ekshate_app/features/daily_sale/presentation/widgets/batch_quota_indicator.dart';
import 'package:ekshate_app/features/daily_sale/presentation/widgets/capacity_quantity_selector.dart';
import 'package:ekshate_app/features/cart/presentation/cart_controller.dart';
import 'package:ekshate_app/core/errors/app_exception.dart';

class BulkDealCard extends ConsumerStatefulWidget {
  final DailyListing listing;

  const BulkDealCard({
    super.key,
    required this.listing,
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
      margin: const EdgeInsets.only(bottom: 20.0),
      decoration: AppDecorations.glassCard(
        surfaceColor: AppColors.cardSurface,
        borderColor: AppColors.borderSubtle,
        borderRadius: 16,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. High-Resolution Product Photography Section
          Stack(
            children: [
              SizedBox(
                height: 180,
                width: double.infinity,
                child: listing.imageUrl != null && listing.imageUrl!.isNotEmpty
                    ? Image.network(
                        listing.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return _buildImagePlaceholder(listing);
                        },
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return _buildImageLoadingShimmer();
                        },
                      )
                    : _buildImagePlaceholder(listing),
              ),

              // Gradient Overlay on Image Bottom
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 60,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.85),
                      ],
                    ),
                  ),
                ),
              ),

              // Badges Overlaid on Photography
              Positioned(
                top: 12,
                left: 12,
                child: ShadBadge.secondary(
                  key: Key('discount_badge_${listing.id}'),
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  child: Text(
                    '${listing.discountPercent.toStringAsFixed(0)}% OFF',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              Positioned(
                top: 12,
                right: 12,
                child: ShadBadge(
                  key: Key('bucket_badge_overlay_${listing.id}'),
                  backgroundColor: const Color(0xFF27272A).withValues(alpha: 0.9),
                  foregroundColor: Colors.white,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.package2, size: 12, color: Color(0xFF10B981)),
                      const SizedBox(width: 4),
                      Text('Bucket #${listing.activeBucketNumber}'),
                    ],
                  ),
                ),
              ),

              // Category Tag
              if (listing.category != null)
                Positioned(
                  bottom: 8,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      listing.category!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFFE4E4E7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // 2. Deal Content & Live Indicators
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Title
                Text(
                  listing.productTitle,
                  style: theme.textTheme.h4.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),

                if (listing.description != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    listing.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.muted.copyWith(fontSize: 12),
                  ),
                ],

                const SizedBox(height: 12),

                // Pricing Row: Wholesale Unit Price + Retail Benchmark Strike-through
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '৳${listing.unitPrice.toStringAsFixed(0)}/${listing.unit}',
                      style: theme.textTheme.h3.copyWith(
                        color: const Color(0xFF10B981),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '৳${listing.marketPrice.toStringAsFixed(0)}',
                      style: theme.textTheme.muted.copyWith(
                        decoration: TextDecoration.lineThrough,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ShadBadge.outline(
                      child: Text(
                        'Save ৳${listing.savingsPerUnit.toStringAsFixed(0)}/${listing.unit}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF10B981),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(color: AppColors.borderSubtle, height: 1),
                const SizedBox(height: 14),

                // 3. Batch Quota Indicator (Live volume vs MOQ, emerald progress bar, Bucket #1)
                if (bucket != null)
                  BatchQuotaIndicator(
                    bucket: bucket,
                    unit: listing.unit,
                    showBucketBadge: false,
                  ),

                const SizedBox(height: 16),

                // 4. Interactive Capacity-Clamped Quantity Picker
                Text(
                  'Select Wholesale Volume:',
                  style: theme.textTheme.small.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFA1A1AA),
                  ),
                ),
                const SizedBox(height: 8),
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

                const SizedBox(height: 16),
                const Divider(color: AppColors.borderSubtle, height: 1),
                const SizedBox(height: 14),

                // 5. Footer: Subtotal and "Reserve Volume" Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Subtotal',
                          style: theme.textTheme.muted.copyWith(fontSize: 11),
                        ),
                        Text(
                          '৳${subtotal.toStringAsFixed(0)}',
                          style: theme.textTheme.h4.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    ShadButton(
                      key: Key('reserve_volume_btn_${listing.id}'),
                      enabled: remainingCapacity > 0,
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      onPressed: () {
                        // 1. Instant Haptic Feedback
                        HapticFeedback.mediumImpact();

                        // 2. Add to batch cart
                        try {
                          ref
                              .read(cartProvider.notifier)
                              .addItem(listing, _selectedQuantity);

                          // 3. Instant Toast Confirmation
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
                          Icon(LucideIcons.shoppingBag, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'Reserve Volume',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
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
            Icon(LucideIcons.image, size: 36, color: AppColors.textMuted),
            SizedBox(height: 6),
            Text(
              'Product Photography',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
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
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF10B981),
          ),
        ),
      ),
    );
  }
}
