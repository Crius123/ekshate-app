import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ekshate_app/core/config/theme/app_decorations.dart';
import 'package:ekshate_app/core/router/route_paths.dart';
import 'package:ekshate_app/features/daily_sale/domain/daily_listing.dart';
import 'package:ekshate_app/features/daily_sale/presentation/widgets/bulk_deal_card.dart';

class CategoryDealRow extends StatelessWidget {
  final String categoryName;
  final IconData icon;
  final List<DailyListing> listings;

  const CategoryDealRow({
    super.key,
    required this.categoryName,
    required this.icon,
    required this.listings,
  });

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final top4 = listings.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Row Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Category Icon + Title
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.emerald.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: AppColors.emeraldDark, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        categoryName,
                        style: theme.textTheme.h4.copyWith(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Top Selling Wholesale Drops',
                        style: theme.textTheme.muted.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),

              // "View All" Button
              InkWell(
                key: Key('view_all_btn_${categoryName.replaceAll(' ', '_').toLowerCase()}'),
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  context.push(RoutePaths.categoryProductsPath(categoryName));
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View All',
                        style: theme.textTheme.small.copyWith(
                          color: AppColors.emeraldDark,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        LucideIcons.chevronRight,
                        size: 15,
                        color: AppColors.emeraldDark,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Horizontal Line of 4 Top Selling Products
        LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;

            if (isDesktop) {
              // On Desktop/Web: 4 items arranged in a responsive horizontal grid/row
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int i = 0; i < top4.length; i++) ...[
                    if (i > 0) const SizedBox(width: 14),
                    Expanded(
                      child: SizedBox(
                        height: 450,
                        child: BulkDealCard(
                          key: ValueKey(top4[i].id),
                          listing: top4[i],
                        ),
                      ),
                    ),
                  ],
                ],
              );
            }

            // On Mobile/Tablet: Smooth horizontal scrolling list showing the 4 top selling products
            return SizedBox(
              height: 440,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: top4.length,
                separatorBuilder: (context, index) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final listing = top4[index];
                  return SizedBox(
                    width: 300,
                    child: BulkDealCard(
                      key: ValueKey(listing.id),
                      listing: listing,
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}
