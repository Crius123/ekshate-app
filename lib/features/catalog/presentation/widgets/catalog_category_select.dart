import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ekshate_app/core/config/theme/app_decorations.dart';
import 'package:ekshate_app/core/router/route_paths.dart';
import 'package:ekshate_app/features/daily_sale/presentation/daily_sale_controller.dart';

/// Reusable select widget displaying all product categories sold in the website.
/// Selecting any category navigates the user directly to the category products page.
class CatalogCategorySelect extends ConsumerWidget {
  /// Whether this select is rendered inside the top navigation header.
  final bool isHeader;

  /// Optional custom width for the select trigger.
  final double? width;

  const CatalogCategorySelect({
    super.key,
    this.isHeader = false,
    this.width,
  });

  static IconData getCategoryIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'fresh fruits':
      case 'fruits':
        return LucideIcons.apple;
      case 'grains & staples':
      case 'staples':
      case 'grains':
        return LucideIcons.wheat;
      case 'edible oils':
      case 'oils':
        return LucideIcons.droplet;
      case 'fresh vegetables':
      case 'vegetables':
        return LucideIcons.carrot;
      default:
        return LucideIcons.tag;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(allProductCategoriesProvider);
    final allListings = ref.watch(dailyListingsProvider);

    // Header Trigger UI
    final headerTrigger = Container(
      key: const Key('catalog_select_button'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cardSurfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.borderSubtle,
          width: 1.0,
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.layoutGrid, size: 15, color: AppColors.emerald),
          SizedBox(width: 6),
          Text(
            'Catalog',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(width: 4),
          Icon(LucideIcons.chevronDown, size: 13, color: AppColors.textMuted),
        ],
      ),
    );

    // Full-page Trigger UI
    final pageTrigger = Container(
      key: const Key('catalog_select_button'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.borderEmerald,
          width: 1.2,
        ),
      ),
      child: const Row(
        children: [
          Icon(LucideIcons.layoutGrid, size: 18, color: AppColors.emerald),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Select Product Category...',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Icon(LucideIcons.chevronDown, size: 16, color: AppColors.textMuted),
        ],
      ),
    );

    return ShadSelect<String>(
      minWidth: width ?? (isHeader ? 220 : 320),
      maxWidth: isHeader ? 280 : 420,
      maxHeight: 380,
      placeholder: isHeader ? headerTrigger : pageTrigger,
      selectedOptionBuilder: (context, _) => isHeader ? headerTrigger : pageTrigger,
      trailing: const SizedBox.shrink(),
      decoration: const ShadDecoration(
        border: ShadBorder.none,
        focusedBorder: ShadBorder.none,
        secondaryBorder: ShadBorder.none,
        secondaryFocusedBorder: ShadBorder.none,
        color: Colors.transparent,
      ),
      header: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.borderSubtle, width: 1.0),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.layers, size: 14, color: AppColors.emerald),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Wholesale Categories',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      options: categories.map((cat) {
        final count = allListings.where((l) => l.category == cat).length;
        final icon = getCategoryIcon(cat);

        return ShadOption<String>(
          key: Key('category_option_${cat.replaceAll(' ', '_').toLowerCase()}'),
          value: cat,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.emerald.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(icon, size: 15, color: AppColors.emeraldDark),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        cat,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '$count deals available',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  LucideIcons.chevronRight,
                  size: 13,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        );
      }).toList(),
      onChanged: (selectedCategory) {
        if (selectedCategory != null && selectedCategory.isNotEmpty) {
          context.push(RoutePaths.categoryProductsPath(selectedCategory));
        }
      },
    );
  }
}
