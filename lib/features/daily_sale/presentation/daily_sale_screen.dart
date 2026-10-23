import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ekshate_app/features/daily_sale/presentation/daily_sale_controller.dart';
import 'package:ekshate_app/features/daily_sale/presentation/widgets/campaign_countdown_header.dart';
import 'package:ekshate_app/features/daily_sale/presentation/widgets/bulk_deal_card.dart';
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
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // 1. Search Bar with Algolia live drop-down & quick-reserve
          const DailySearchBar(),
          const SizedBox(height: 16),

          // 2. Campaign Countdown Header (Dynamic countdown to 10:00 AM or 11:59 PM BDT)
          const CampaignCountdownHeader(),
          const SizedBox(height: 20),

          // 3. Section Title
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
          const SizedBox(height: 12),

          // 4. High-Fidelity Bulk Deal Cards
          ...listings.map((listing) {
            return BulkDealCard(
              key: ValueKey(listing.id),
              listing: listing,
            ).animate().fadeIn(duration: 250.ms).slideY(begin: 0.05, end: 0);
          }),
        ],
      ),
    );
  }
}
