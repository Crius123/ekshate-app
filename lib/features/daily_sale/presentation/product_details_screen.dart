import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ekshate_app/core/config/theme/app_decorations.dart';
import 'package:ekshate_app/core/router/route_paths.dart';
import 'package:ekshate_app/core/errors/app_exception.dart';
import 'package:ekshate_app/features/daily_sale/domain/daily_listing.dart';
import 'package:ekshate_app/features/daily_sale/presentation/daily_sale_controller.dart';
import 'package:ekshate_app/features/daily_sale/presentation/widgets/batch_quota_indicator.dart';
import 'package:ekshate_app/features/daily_sale/presentation/widgets/capacity_quantity_selector.dart';
import 'package:ekshate_app/features/cart/presentation/cart_controller.dart';

class ProductDetailsScreen extends ConsumerStatefulWidget {
  final String listingId;

  const ProductDetailsScreen({
    super.key,
    required this.listingId,
  });

  @override
  ConsumerState<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends ConsumerState<ProductDetailsScreen> {
  double _selectedQuantity = 1.0;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final listing = ref.watch(dailyListingByIdProvider(widget.listingId));
    final cartItems = ref.watch(cartProvider);

    if (listing == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Product Not Found'),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.packageSearch, size: 48, color: AppColors.textMuted),
              const SizedBox(height: 16),
              Text('Product listing could not be found.', style: theme.textTheme.large),
              const SizedBox(height: 12),
              ShadButton(
                onPressed: () => context.go(RoutePaths.dailySale),
                child: const Text('Back to Daily Deals'),
              ),
            ],
          ),
        ),
      );
    }

    final bucket = listing.activeBucket;
    final remainingCapacity = bucket?.remainingCapacity ?? 0.0;
    final subtotal = listing.unitPrice * _selectedQuantity;
    final totalSavings = listing.savingsPerUnit * _selectedQuantity;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimary),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(RoutePaths.dailySale);
            }
          },
        ),
        title: Text(
          listing.productTitle,
          style: theme.textTheme.h4.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.share2, color: AppColors.textPrimary, size: 20),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: 'https://ekshate.com/product/${listing.id}'));
              ShadToaster.of(context).show(
                const ShadToast(
                  title: Text('Link Copied'),
                  description: Text('Product link copied to clipboard.'),
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(LucideIcons.shoppingBag, color: AppColors.textPrimary),
                  onPressed: () => context.push(RoutePaths.cart),
                ),
                if (cartItems.isNotEmpty)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.emerald,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        '${cartItems.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 900;
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 24.0 : 16.0,
                    vertical: 16.0,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: isDesktop
                          ? _buildDesktopLayout(context, theme, listing, bucket, remainingCapacity, subtotal, totalSavings)
                          : _buildMobileLayout(context, theme, listing, bucket, remainingCapacity, subtotal, totalSavings),
                    ),
                  ),
                ),
              ),

              // Sticky Bottom Action Bar (always accessible)
              _buildStickyActionBar(context, theme, listing, remainingCapacity, subtotal, totalSavings),
            ],
          );
        },
      ),
    );
  }

  // ===========================================================================
  // Desktop 2-Column Layout
  // ===========================================================================
  Widget _buildDesktopLayout(
    BuildContext context,
    ShadThemeData theme,
    DailyListing listing,
    dynamic bucket,
    double remainingCapacity,
    double subtotal,
    double totalSavings,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Photography showcase & Trust Badges
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildImageCard(listing),
              const SizedBox(height: 16),
              _buildTrustCards(theme),
            ],
          ),
        ),
        const SizedBox(width: 24),

        // Right Column: Details, Quota Progress, Description, Specs
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTitleAndPricing(theme, listing),
              const SizedBox(height: 16),
              if (bucket != null) ...[
                _buildQuotaSection(theme, listing, bucket),
                const SizedBox(height: 16),
              ],
              _buildQuantityControlCard(theme, listing, remainingCapacity, subtotal, totalSavings),
              const SizedBox(height: 20),
              _buildProductDescriptionSection(theme, listing),
              const SizedBox(height: 20),
              _buildSpecificationsCard(theme, listing),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Mobile Single-Column Layout
  // ===========================================================================
  Widget _buildMobileLayout(
    BuildContext context,
    ShadThemeData theme,
    DailyListing listing,
    dynamic bucket,
    double remainingCapacity,
    double subtotal,
    double totalSavings,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. High Resolution Product Image
        _buildImageCard(listing),
        const SizedBox(height: 16),

        // 2. Title, Badges, & Wholesale vs Retail Pricing
        _buildTitleAndPricing(theme, listing),
        const SizedBox(height: 16),

        // 3. Batch Quota Progress & Community Milestone
        if (bucket != null) ...[
          _buildQuotaSection(theme, listing, bucket),
          const SizedBox(height: 16),
        ],

        // 4. Quantity Stepper & Subtotal Box
        _buildQuantityControlCard(theme, listing, remainingCapacity, subtotal, totalSavings),
        const SizedBox(height: 20),

        // 5. Product Description Section (Dedicated & Comprehensive)
        _buildProductDescriptionSection(theme, listing),
        const SizedBox(height: 20),

        // 6. Product Technical Specifications
        _buildSpecificationsCard(theme, listing),
        const SizedBox(height: 20),

        // 7. Trust & Wholesale Batch Buying Explainer
        _buildTrustCards(theme),
        const SizedBox(height: 24),
      ],
    );
  }

  // ===========================================================================
  // Product Image Showcase
  // ===========================================================================
  Widget _buildImageCard(DailyListing listing) {
    return Container(
      height: 320,
      decoration: AppDecorations.glassCard(
        surfaceColor: AppColors.cardSurface,
        borderColor: AppColors.borderSubtle,
        borderRadius: 16,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          listing.imageUrl != null && listing.imageUrl!.isNotEmpty
              ? Image.network(
                  listing.imageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
                )
              : _buildPlaceholder(),

          // Subtle Bottom Dark Gradient
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
                    Colors.black.withValues(alpha: 0.65),
                  ],
                ),
              ),
            ),
          ),

          // Top Left: Discount Badge
          Positioned(
            top: 12,
            left: 12,
            child: ShadBadge.secondary(
              backgroundColor: AppColors.emerald,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Text(
                '${listing.discountPercent.toStringAsFixed(0)}% OFF WHOLESALE',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
          ),

          // Top Right: Bucket Number Badge
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.emerald.withValues(alpha: 0.4), width: 1.0),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.package2, size: 12, color: AppColors.emerald),
                  const SizedBox(width: 5),
                  Text(
                    'Bucket #${listing.activeBucketNumber}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Left: Category Pill
          if (listing.category != null)
            Positioned(
              bottom: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  listing.category!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: const Center(
        child: Icon(LucideIcons.image, size: 48, color: AppColors.textMuted),
      ),
    );
  }

  // ===========================================================================
  // Title & Pricing Block
  // ===========================================================================
  Widget _buildTitleAndPricing(ShadThemeData theme, DailyListing listing) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.glassCard(
        surfaceColor: AppColors.cardSurface,
        borderColor: AppColors.borderSubtle,
        borderRadius: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (listing.origin != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.emerald.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.mapPin, size: 12, color: AppColors.emeraldDark),
                      const SizedBox(width: 4),
                      Text(
                        listing.origin!,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.emeraldDark,
                        ),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              ShadBadge.outline(
                child: Text('Base Unit: ${listing.unit}'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            listing.productTitle,
            style: theme.textTheme.h3.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.borderSubtle),
          const SizedBox(height: 12),

          // Pricing Breakdown Row
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Wholesale Price (Emerald, bold)
              Text(
                '৳${listing.unitPrice.toStringAsFixed(0)}/${listing.unit}',
                style: theme.textTheme.h2.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.emerald,
                ),
              ),

              // Retail Benchmark (strikethrough)
              Text(
                '৳${listing.marketPrice.toStringAsFixed(0)}',
                style: theme.textTheme.muted.copyWith(
                  fontSize: 16,
                  decoration: TextDecoration.lineThrough,
                  fontWeight: FontWeight.w500,
                ),
              ),

              // Savings Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.emerald.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'Save ৳${listing.savingsPerUnit.toStringAsFixed(0)}/${listing.unit} (${listing.discountPercent.toStringAsFixed(0)}% Off)',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.emeraldDark,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Community Batch Quota Section
  // ===========================================================================
  Widget _buildQuotaSection(ShadThemeData theme, DailyListing listing, dynamic bucket) {
    final double percent = ((bucket.currentQuantity / bucket.moqThreshold) * 100).clamp(0.0, 100.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.glassCard(
        surfaceColor: const Color(0xFFF0FDF4),
        borderColor: AppColors.emerald.withValues(alpha: 0.3),
        borderRadius: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.users, size: 16, color: AppColors.emeraldDark),
                  const SizedBox(width: 6),
                  Text(
                    'Community Batch Goal',
                    style: theme.textTheme.h4.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.emeraldDark,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.emerald,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${percent.toStringAsFixed(0)}% Unlocked',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          BatchQuotaIndicator(
            bucket: bucket,
            unit: listing.unit,
            showBucketBadge: false,
            showRemainingInfo: true,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Target MOQ: ${bucket.moqThreshold.toStringAsFixed(0)} ${listing.unit}',
                style: theme.textTheme.muted.copyWith(fontSize: 11.5),
              ),
              Text(
                '${bucket.remainingCapacity.toStringAsFixed(0)} ${listing.unit} remaining',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.emeraldDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Interactive Quantity Control Card
  // ===========================================================================
  Widget _buildQuantityControlCard(
    ShadThemeData theme,
    DailyListing listing,
    double remainingCapacity,
    double subtotal,
    double totalSavings,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.glassCard(
        surfaceColor: AppColors.cardSurface,
        borderColor: AppColors.borderSubtle,
        borderRadius: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Order Volume',
            style: theme.textTheme.h4.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: CapacityQuantitySelector(
                  currentQuantity: _selectedQuantity,
                  remainingCapacity: remainingCapacity,
                  unit: listing.unit,
                  onQuantityChanged: (qty) {
                    setState(() {
                      _selectedQuantity = qty;
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Subtotal', style: theme.textTheme.muted.copyWith(fontSize: 11)),
                  Text(
                    '৳${subtotal.toStringAsFixed(0)}',
                    style: theme.textTheme.h3.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Total wholesale savings: ৳${totalSavings.toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.emeraldDark,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PRODUCT DESCRIPTION SECTION (Requested feature)
  // ===========================================================================
  Widget _buildProductDescriptionSection(ShadThemeData theme, DailyListing listing) {
    final description = listing.description ??
        'High-quality wholesale produce sourced directly from farmers and mandis. Graded for freshness and purity.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppDecorations.glassCard(
        surfaceColor: AppColors.cardSurface,
        borderColor: AppColors.borderSubtle,
        borderRadius: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.fileText, size: 18, color: AppColors.emerald),
              const SizedBox(width: 8),
              Text(
                'Product Description',
                style: theme.textTheme.h4.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: theme.textTheme.p.copyWith(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),

          // Sourcing Highlights
          if (listing.highlights != null && listing.highlights!.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.borderSubtle),
            const SizedBox(height: 14),
            Text(
              'Highlights & Sourcing Quality',
              style: theme.textTheme.h4.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            for (final item in listing.highlights!)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2.0),
                      child: Icon(LucideIcons.checkCircle2, size: 14, color: AppColors.emerald),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // Technical Specifications Table
  // ===========================================================================
  Widget _buildSpecificationsCard(ShadThemeData theme, DailyListing listing) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AppDecorations.glassCard(
        surfaceColor: AppColors.cardSurface,
        borderColor: AppColors.borderSubtle,
        borderRadius: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.slidersHorizontal, size: 18, color: AppColors.emerald),
              const SizedBox(width: 8),
              Text(
                'Product Specifications',
                style: theme.textTheme.h4.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildSpecRow('Category', listing.category ?? 'Wholesale Commodity'),
          _buildSpecRow('Base Order Unit', listing.unit),
          _buildSpecRow('Sourcing Mandi', listing.origin ?? 'Direct Regional Haat'),
          _buildSpecRow('MOQ Threshold', '${listing.moqThreshold.toStringAsFixed(0)} ${listing.unit}'),
          _buildSpecRow('Active Bucket', 'Bucket #${listing.activeBucketNumber}'),
          _buildSpecRow('Fulfillment Schedule', 'Next morning delivery after 11:59 PM settlement'),
        ],
      ),
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Trust Cards
  // ===========================================================================
  Widget _buildTrustCards(ShadThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.glassCard(
        surfaceColor: const Color(0xFFF8FAFC),
        borderColor: AppColors.borderSubtle,
        borderRadius: 16,
      ),
      child: Column(
        children: [
          _buildTrustItem(
            LucideIcons.shieldCheck,
            'Escrow-Protected Wallet',
            'Your funds remain safely locked in escrow until the community batch target is unlocked.',
            AppColors.amberEscrow,
          ),
          const SizedBox(height: 12),
          _buildTrustItem(
            LucideIcons.refreshCw,
            'Zero-Loss Guarantee',
            'If the batch goal is not met by 11:59 PM BDT, your money is instantly refunded to your wallet.',
            AppColors.emerald,
          ),
          const SizedBox(height: 12),
          _buildTrustItem(
            LucideIcons.truck,
            'Next-Morning Direct Delivery',
            'Procured fresh at 4:00 AM from wholesale markets and dispatched directly to your doorstep.',
            const Color(0xFF0284C7),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustItem(IconData icon, String title, String subtitle, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textMuted,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // Sticky Bottom Action Bar
  // ===========================================================================
  Widget _buildStickyActionBar(
    BuildContext context,
    ShadThemeData theme,
    DailyListing listing,
    double remainingCapacity,
    double subtotal,
    double totalSavings,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.cardSurface,
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 10,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Row(
              children: [
                // Price & Savings Summary
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Total: ৳${subtotal.toStringAsFixed(0)}',
                      style: theme.textTheme.h3.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Saving ৳${totalSavings.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.emeraldDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),

                // Primary Reserve Button
                Expanded(
                  child: ShadButton(
                    key: Key('details_reserve_volume_btn_${listing.id}'),
                    enabled: remainingCapacity > 0,
                    backgroundColor: AppColors.emerald,
                    foregroundColor: Colors.white,
                    height: 48,
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      try {
                        ref.read(cartProvider.notifier).addItem(listing, _selectedQuantity);
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
                      }
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(LucideIcons.shoppingBag, size: 18, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          remainingCapacity > 0 ? 'Reserve Volume' : 'Bucket Full',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
