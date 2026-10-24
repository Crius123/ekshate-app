import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ekshate_app/core/widgets/app_scaffold.dart';
import 'package:ekshate_app/features/daily_sale/presentation/daily_sale_controller.dart';
import 'package:ekshate_app/features/daily_sale/presentation/widgets/campaign_countdown_header.dart';
import 'package:ekshate_app/features/daily_sale/presentation/widgets/daily_hero_section.dart';
import 'package:ekshate_app/features/daily_sale/presentation/widgets/category_deal_row.dart';
import 'package:ekshate_app/features/search/presentation/widgets/daily_search_bar.dart';
import 'package:ekshate_app/features/notifications/presentation/widgets/notification_bell_button.dart';
import 'package:ekshate_app/core/config/app_constants.dart';

class DailySaleScreen extends ConsumerWidget {
  const DailySaleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ShadTheme.of(context);
    final listings = ref.watch(dailyListingsProvider);
    final campaignStatus = ref.watch(dailyCampaignStatusProvider);
    final isMobile = AdaptiveLayout.isMobile(context);

    // Group and sort listings for the 3 featured categories
    final vegListings = listings
        .where((l) => l.category == 'Fresh Vegetables')
        .toList()
      ..sort((a, b) => b.totalVolumeOrdered.compareTo(a.totalVolumeOrdered));

    final grainListings = listings
        .where((l) => l.category == 'Grains & Staples')
        .toList()
      ..sort((a, b) => b.totalVolumeOrdered.compareTo(a.totalVolumeOrdered));

    final fruitListings = listings
        .where((l) => l.category == 'Fresh Fruits')
        .toList()
      ..sort((a, b) => b.totalVolumeOrdered.compareTo(a.totalVolumeOrdered));

    // Handle any listings outside the 3 primary categories (e.g. tests or other commodities)
    final otherListings = listings
        .where((l) =>
            l.category != 'Fresh Vegetables' &&
            l.category != 'Grains & Staples' &&
            l.category != 'Fresh Fruits')
        .toList()
      ..sort((a, b) => b.totalVolumeOrdered.compareTo(a.totalVolumeOrdered));

    return Scaffold(
      appBar: isMobile
          ? AppBar(
              title: Row(
                children: [
                  const Icon(LucideIcons.flame, color: Color(0xFF10B981), size: 20),
                  const SizedBox(width: 8),
                  Text(AppConstants.appName, style: theme.textTheme.h4),
                ],
              ),
              actions: [
                const NotificationBellButton(),
                Padding(
                  padding: const EdgeInsets.only(right: 16.0),
                  child: ShadBadge.outline(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.clock, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          campaignStatus == 'active'
                              ? 'Active: Closes 11:59 PM'
                              : 'Preview Mode',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // 1. Search Bar with Algolia live drop-down & quick-reserve (shown in body on smartphone)
          if (isMobile) ...[
            const DailySearchBar(),
            const SizedBox(height: 16),
          ],

          // 2. Hero Section with hook text, value propositions, and direct mandi context imagery
          const DailyHeroSection(),
          const SizedBox(height: 20),

          // 3. Campaign Countdown Header (Dynamic countdown to 10:00 AM or 11:59 PM BDT)
          const CampaignCountdownHeader(),
          const SizedBox(height: 20),

          // 4. Section Title Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Active Wholesale Deals',
                style: theme.textTheme.h4.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              ShadBadge.secondary(
                child: Text('${listings.length} Deals Live'),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 5. Horizontal Line 1: Fresh Fruits (Top 4 Selling + View All)
          if (fruitListings.isNotEmpty) ...[
            CategoryDealRow(
              categoryName: 'Fresh Fruits',
              icon: LucideIcons.apple,
              listings: fruitListings,
            ),
            const SizedBox(height: 26),
          ],

          // 6. Horizontal Line 2: Grains & Staples (Top 4 Selling + View All)
          if (grainListings.isNotEmpty) ...[
            CategoryDealRow(
              categoryName: 'Grains & Staples',
              icon: LucideIcons.boxes,
              listings: grainListings,
            ),
            const SizedBox(height: 26),
          ],

          // 7. Horizontal Line 3: Fresh Vegetables (Top 4 Selling + View All)
          if (vegListings.isNotEmpty) ...[
            CategoryDealRow(
              categoryName: 'Fresh Vegetables',
              icon: LucideIcons.carrot,
              listings: vegListings,
            ),
            const SizedBox(height: 26),
          ],

          // 8. Other / Supplemental Listings (if any)
          if (otherListings.isNotEmpty) ...[
            CategoryDealRow(
              categoryName: otherListings.first.category ?? 'Featured Wholesale Deals',
              icon: LucideIcons.tags,
              listings: otherListings,
            ),
            const SizedBox(height: 26),
          ],
        ],
      ),
    );
  }
}
