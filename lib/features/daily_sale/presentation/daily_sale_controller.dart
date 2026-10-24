import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/daily_listing.dart';
import '../domain/batch_bucket.dart';
import '../domain/campaign_timer_info.dart';

/// Campaign status: 'preview' | 'active' | 'settling' | 'settled'
final dailyCampaignStatusProvider = StateProvider<String>((ref) => 'active');

/// Provider for clock function returning current BDT time (UTC+6).
/// Override this in widget tests for deterministic countdown testing.
final campaignClockProvider = Provider<DateTime Function()>((ref) {
  return () => DateTime.now().toUtc().add(const Duration(hours: 6));
});

/// Reactive provider calculating current countdown timer details.
final campaignTimerInfoProvider = Provider<CampaignTimerInfo>((ref) {
  final clock = ref.watch(campaignClockProvider);
  final status = ref.watch(dailyCampaignStatusProvider);
  final nowBdt = clock();
  return calculateCampaignTimerInfo(nowBdt, overrideStatus: status);
});

/// Canonical list of featured home page categories
final featuredCategoriesProvider = Provider<List<String>>((ref) {
  return const ['Fresh Fruits', 'Grains & Staples', 'Fresh Vegetables'];
});

/// All distinct product categories currently available in the website catalog
final allProductCategoriesProvider = Provider<List<String>>((ref) {
  final listings = ref.watch(dailyListingsProvider);
  final categories = <String>{};
  for (final l in listings) {
    if (l.category != null && l.category!.trim().isNotEmpty) {
      categories.add(l.category!.trim());
    }
  }
  if (categories.isEmpty) {
    return const ['Fresh Fruits', 'Fresh Vegetables', 'Grains & Staples'];
  }
  final sorted = categories.toList()..sort();
  return sorted;
});

/// Single listing lookup provider
final dailyListingByIdProvider = Provider.family<DailyListing?, String>((ref, id) {
  final listings = ref.watch(dailyListingsProvider);
  try {
    return listings.firstWhere((l) => l.id == id);
  } catch (_) {
    return null;
  }
});

final dailyListingsProvider =
    NotifierProvider<DailySaleController, List<DailyListing>>(() {
  return DailySaleController();
});

class DailySaleController extends Notifier<List<DailyListing>> {
  @override
  List<DailyListing> build() {
    return [
      // =======================================================================
      // CATEGORY 1: FRESH FRUITS (Top 4 Selling)
      // =======================================================================
      const DailyListing(
        id: 'listing_orange_01',
        productId: 'prod_orange_01',
        productTitle: 'Nagpur Oranges (1 kg)',
        unit: 'kg',
        marketPrice: 240.0,
        unitPrice: 180.0,
        discountPercent: 25.0,
        moqThreshold: 100.0,
        activeBucketNumber: 1,
        totalBucketsCount: 1,
        totalVolumeOrdered: 65.0, // Top Seller #1 in Fruits
        status: 'active',
        imageUrl:
            'https://images.unsplash.com/photo-1611080626919-7cf5a9dbab5b?auto=format&fit=crop&w=800&q=80',
        category: 'Fresh Fruits',
        origin: 'Nagpur Wholesale Citrus Mandi',
        description:
            'Farm-fresh sweet and tangy Nagpur oranges directly imported from grower cooperatives. Loaded with juicy citrus segments, vibrant Vitamin C, and easy-peel rinds. Graded for sweetness and natural juice density.',
        highlights: [
          'Sweet & tangy citrus profile with tender juicy pulp',
          'Rich in natural Vitamin C & antioxidants',
          'Clean thin rind for effortless peeling',
          'Direct import cold-chain transit to Dhaka'
        ],
        activeBucket: BatchBucket(
          bucketNumber: 1,
          listingId: 'listing_orange_01',
          date: '2026-10-21',
          moqThreshold: 100.0,
          currentQuantity: 65.0,
          remainingCapacity: 35.0, // Hard clamp: max client can buy is 35 kg
          status: 'open',
          orderCount: 4,
        ),
      ),
      const DailyListing(
        id: 'listing_mango_07',
        productId: 'prod_mango_01',
        productTitle: 'Rajshahi Himsagar Mangoes (10 kg crate)',
        unit: 'crate',
        marketPrice: 1600.0,
        unitPrice: 1250.0,
        discountPercent: 21.8,
        moqThreshold: 50.0,
        activeBucketNumber: 1,
        totalBucketsCount: 1,
        totalVolumeOrdered: 45.0, // Top Seller #2 in Fruits
        status: 'active',
        imageUrl:
            'https://images.unsplash.com/photo-1553279768-865429fa0078?auto=format&fit=crop&w=800&q=80',
        category: 'Fresh Fruits',
        origin: 'Rajshahi Fruit Orchards',
        description:
            'Naturally ripened, chemical-free Himsagar sweet mangoes sourced directly from Rajshahi heritage orchards. Fiberless melting golden pulp, honeyed floral scent, and paper-thin skin make this the crown jewel of mango season.',
        highlights: [
          '100% formalin-free & calcium carbide-free ripening',
          'Fiberless, silky texture with high sugar brix',
          'Crated with protective sponge cushioning',
          'Sourced directly from heritage Rajshahi orchard growers'
        ],
        activeBucket: BatchBucket(
          bucketNumber: 1,
          listingId: 'listing_mango_07',
          date: '2026-10-21',
          moqThreshold: 50.0,
          currentQuantity: 45.0,
          remainingCapacity: 5.0,
          status: 'open',
          orderCount: 5,
        ),
      ),
      const DailyListing(
        id: 'listing_banana_18',
        productId: 'prod_banana_01',
        productTitle: 'Narsingdi Sagar Kola / Bananas (12 dozen cluster)',
        unit: 'cluster',
        marketPrice: 950.0,
        unitPrice: 760.0,
        discountPercent: 20.0,
        moqThreshold: 40.0,
        activeBucketNumber: 1,
        totalBucketsCount: 1,
        totalVolumeOrdered: 38.0, // Top Seller #3 in Fruits
        status: 'active',
        imageUrl:
            'https://images.unsplash.com/photo-1571771894821-ce9b6c11b08e?auto=format&fit=crop&w=800&q=80',
        category: 'Fresh Fruits',
        origin: 'Narsingdi Banana Mandi',
        description:
            'Sweet, plump Sagar bananas harvested fresh from Narsingdi agro-farms. Creamy texture, high potassium, and vibrant natural aroma. Ripened under controlled air circulation without synthetic ripening gases.',
        highlights: [
          'Plump, naturally sweet Sagar banana variety',
          'Rich in dietary potassium & energy-boosting nutrients',
          'Stem-intact cluster harvest preventing bruising',
          'Wholesale pricing for household weekly consumption'
        ],
        activeBucket: BatchBucket(
          bucketNumber: 1,
          listingId: 'listing_banana_18',
          date: '2026-10-21',
          moqThreshold: 40.0,
          currentQuantity: 38.0,
          remainingCapacity: 2.0,
          status: 'open',
          orderCount: 4,
        ),
      ),
      const DailyListing(
        id: 'listing_guava_19',
        productId: 'prod_guava_01',
        productTitle: 'Barisal Thai-7 Seedless Guavas (10 kg crate)',
        unit: 'crate',
        marketPrice: 800.0,
        unitPrice: 620.0,
        discountPercent: 22.5,
        moqThreshold: 50.0,
        activeBucketNumber: 1,
        totalBucketsCount: 1,
        totalVolumeOrdered: 30.0, // Top Seller #4 in Fruits
        status: 'active',
        imageUrl:
            'https://images.unsplash.com/photo-1536511135897-4043f1146247?auto=format&fit=crop&w=800&q=80',
        category: 'Fresh Fruits',
        origin: 'Barisal Floating Market Hub',
        description:
            'Extra-crisp, refreshing Thai-7 green guavas from Barisal floating market suppliers. Plump and firm with dense crunchy white flesh, minimal seed cavity, and 4x the Vitamin C of common citrus fruits.',
        highlights: [
          'Crunchy, sweet flesh with high water content',
          'Minimal seeds for comfortable snacking',
          '4x Vitamin C content of citrus fruits',
          'Plucked green and packed in ventilated wholesale crates'
        ],
        activeBucket: BatchBucket(
          bucketNumber: 1,
          listingId: 'listing_guava_19',
          date: '2026-10-21',
          moqThreshold: 50.0,
          currentQuantity: 30.0,
          remainingCapacity: 20.0,
          status: 'open',
          orderCount: 3,
        ),
      ),

      // =======================================================================
      // CATEGORY 2: GRAINS & STAPLES (Top 4 Selling)
      // =======================================================================
      const DailyListing(
        id: 'listing_rice_02',
        productId: 'prod_rice_01',
        productTitle: 'Miniket Premium Rice (25 kg bag)',
        unit: 'bag',
        marketPrice: 2100.0,
        unitPrice: 1750.0,
        discountPercent: 16.6,
        moqThreshold: 50.0,
        activeBucketNumber: 2,
        totalBucketsCount: 2,
        totalVolumeOrdered: 82.0, // Top Seller #1 in Grains & Staples
        status: 'active',
        imageUrl:
            'https://images.unsplash.com/photo-1586201375761-83865001e31c?auto=format&fit=crop&w=800&q=80',
        category: 'Grains & Staples',
        origin: 'Dinajpur Auto Rice Mills',
        description:
            'Polished extra-long grain Miniket rice straight from Dinajpur auto rice mills. Extra-white, clean polished grains that cook into fluffy, non-sticky rice. Sourced in moisture-proof woven jute-lined poly bags.',
        highlights: [
          'Double-polished extra-long grain variety',
          'Aged for optimal non-sticky texture',
          '100% sortex cleaned without stones or chaff',
          'Heavy-duty sealed packaging for wholesale transit'
        ],
        activeBucket: BatchBucket(
          bucketNumber: 2,
          listingId: 'listing_rice_02',
          date: '2026-10-21',
          moqThreshold: 50.0,
          currentQuantity: 32.0,
          remainingCapacity: 18.0,
          status: 'open',
          orderCount: 5,
        ),
      ),
      const DailyListing(
        id: 'listing_oil_03',
        productId: 'prod_oil_01',
        productTitle: 'Pure Mustard Oil (5 L jar)',
        unit: 'jar',
        marketPrice: 950.0,
        unitPrice: 780.0,
        discountPercent: 18.0,
        moqThreshold: 80.0,
        activeBucketNumber: 1,
        totalBucketsCount: 1,
        totalVolumeOrdered: 65.0, // Top Seller #2 in Grains & Staples
        status: 'active',
        imageUrl:
            'https://images.unsplash.com/photo-1474979266404-7eaacbcd87c5?auto=format&fit=crop&w=800&q=80',
        category: 'Grains & Staples',
        origin: 'Pabna Cold Press Co-op',
        description:
            'Cold-pressed 100% natural mustard oil with high pungency and traditional taste. Milled from organic local black mustard seeds.',
        highlights: [
          'Cold-pressed below 40°C preserving antioxidants',
          'High pungency & authentic smoky aroma',
          'Food-grade sealed 5-liter HDPE jar'
        ],
        activeBucket: BatchBucket(
          bucketNumber: 1,
          listingId: 'listing_oil_03',
          date: '2026-10-21',
          moqThreshold: 80.0,
          currentQuantity: 45.0,
          remainingCapacity: 35.0,
          status: 'open',
          orderCount: 3,
        ),
      ),
      const DailyListing(
        id: 'listing_flour_09',
        productId: 'prod_flour_01',
        productTitle: 'Whole Wheat Atta (10 kg bag)',
        unit: 'bag',
        marketPrice: 650.0,
        unitPrice: 510.0,
        discountPercent: 21.5,
        moqThreshold: 80.0,
        activeBucketNumber: 1,
        totalBucketsCount: 1,
        totalVolumeOrdered: 60.0, // Top Seller #3 in Grains & Staples
        status: 'active',
        imageUrl:
            'https://images.unsplash.com/photo-1509440159596-0249088772ff?auto=format&fit=crop&w=800&q=80',
        category: 'Grains & Staples',
        origin: 'Narayanganj Flour Mills',
        description:
            'Stone-ground 100% whole wheat chakki atta with intact bran and germ. Rich dietary fiber ensures soft, puffy rotis with authentic golden warmth. Free of all chemical bleaching agents and maida fillers.',
        highlights: [
          'Traditional slow chakki stone-ground milling',
          'High dietary fiber with natural wheat germ',
          'Produces exceptionally soft and digestive rotis',
          'Zero bleaching or synthetic flour improvers'
        ],
        activeBucket: BatchBucket(
          bucketNumber: 1,
          listingId: 'listing_flour_09',
          date: '2026-10-21',
          moqThreshold: 80.0,
          currentQuantity: 60.0,
          remainingCapacity: 20.0,
          status: 'open',
          orderCount: 6,
        ),
      ),
      const DailyListing(
        id: 'listing_sugar_08',
        productId: 'prod_sugar_01',
        productTitle: 'Deshi Refined Cane Sugar (5 kg bag)',
        unit: 'bag',
        marketPrice: 700.0,
        unitPrice: 560.0,
        discountPercent: 20.0,
        moqThreshold: 70.0,
        activeBucketNumber: 1,
        totalBucketsCount: 1,
        totalVolumeOrdered: 48.0, // Top Seller #4 in Grains & Staples
        status: 'active',
        imageUrl:
            'https://images.unsplash.com/photo-1622484212850-eb596d769edc?auto=format&fit=crop&w=800&q=80',
        category: 'Grains & Staples',
        origin: 'Kushtia Sugar Mills',
        description:
            'Premium crystal cane sugar processed in domestic sugar mills. Pure white, dry sparkling crystals that dissolve instantly in tea, sherbets, and Bengali sweets without leaving cloudy sediment.',
        highlights: [
          'High purity sparkling cane sugar crystals',
          'Fast dissolving rate with pure sweet profile',
          'Hygienically packaged in laminated moisture barrier bag',
          'Standardized 5 kg family pack'
        ],
        activeBucket: BatchBucket(
          bucketNumber: 1,
          listingId: 'listing_sugar_08',
          date: '2026-10-21',
          moqThreshold: 70.0,
          currentQuantity: 48.0,
          remainingCapacity: 22.0,
          status: 'open',
          orderCount: 4,
        ),
      ),

      // =======================================================================
      // CATEGORY 3: FRESH VEGETABLES (Top 4 Selling)
      // =======================================================================
      const DailyListing(
        id: 'listing_potato_04',
        productId: 'prod_potato_01',
        productTitle: 'Munshiganj Diamond Potatoes (20 kg sack)',
        unit: 'sack',
        marketPrice: 900.0,
        unitPrice: 680.0,
        discountPercent: 24.4,
        moqThreshold: 100.0,
        activeBucketNumber: 1,
        totalBucketsCount: 1,
        totalVolumeOrdered: 75.0, // Top Seller #1 in Vegetables
        status: 'active',
        imageUrl:
            'https://images.unsplash.com/photo-1518977676601-b53f82aba655?auto=format&fit=crop&w=800&q=80',
        category: 'Fresh Vegetables',
        origin: 'Munshiganj Cold Storage Mandi',
        description:
            'Grade-A Diamond potatoes harvested from Munshiganj fertile riverbeds. Thin skins, firm texture, and balanced starch content ideal for everyday curries, boiling, and long-term pantry storage. Cold-chain preserved without chemical sprout inhibitors.',
        highlights: [
          'Direct procurement from Munshiganj grower cooperatives',
          'Naturally firm with low moisture loss',
          'Grade-A sorting: size-graded 45mm+',
          'Store in a cool, ventilated dark dry space'
        ],
        activeBucket: BatchBucket(
          bucketNumber: 1,
          listingId: 'listing_potato_04',
          date: '2026-10-21',
          moqThreshold: 100.0,
          currentQuantity: 75.0,
          remainingCapacity: 25.0,
          status: 'open',
          orderCount: 6,
        ),
      ),
      const DailyListing(
        id: 'listing_onion_05',
        productId: 'prod_onion_01',
        productTitle: 'Faridpur Red Onions (10 kg mesh)',
        unit: 'mesh',
        marketPrice: 1100.0,
        unitPrice: 850.0,
        discountPercent: 22.7,
        moqThreshold: 80.0,
        activeBucketNumber: 1,
        totalBucketsCount: 1,
        totalVolumeOrdered: 54.0, // Top Seller #2 in Vegetables
        status: 'active',
        imageUrl:
            'https://images.unsplash.com/photo-1618512496248-a07fe83aa8cb?auto=format&fit=crop&w=800&q=80',
        category: 'Fresh Vegetables',
        origin: 'Faridpur Wholesale Haat',
        description:
            'Authentic deshi red onions from Faridpur wholesale mandi. Renowned for their crisp layers, rich reddish-purple hue, and intense pungency that elevates Bangladeshi gravies and bhortas. Sunlight cured to ensure dry necks and extended shelf-life.',
        highlights: [
          'Crisp, high-pungency deshi onion variety',
          'Sun-cured outer skin preventing rot',
          'Zero retail sorting waste, 100% usable bulbs',
          'Delivered in breathable mesh packaging'
        ],
        activeBucket: BatchBucket(
          bucketNumber: 1,
          listingId: 'listing_onion_05',
          date: '2026-10-21',
          moqThreshold: 80.0,
          currentQuantity: 54.0,
          remainingCapacity: 26.0,
          status: 'open',
          orderCount: 5,
        ),
      ),
      const DailyListing(
        id: 'listing_garlic_10',
        productId: 'prod_garlic_01',
        productTitle: 'Natore Deshi Garlic (5 kg bag)',
        unit: 'bag',
        marketPrice: 1200.0,
        unitPrice: 920.0,
        discountPercent: 23.3,
        moqThreshold: 40.0,
        activeBucketNumber: 1,
        totalBucketsCount: 1,
        totalVolumeOrdered: 36.0, // Top Seller #3 in Vegetables
        status: 'active',
        imageUrl:
            'https://images.unsplash.com/photo-1540148426945-6cf22a6b2383?auto=format&fit=crop&w=800&q=80',
        category: 'Fresh Vegetables',
        origin: 'Natore Chalan Beel Sourcing Point',
        description:
            'Authentic Natore deshi garlic with tightly packed cloves and robust aromatic essential oils. Sourced directly from Chalan Beel farming hubs. Exceptional flavour profile with sharp garlic warmth suited for spice pastes, baghaar, and medicinal home remedies.',
        highlights: [
          'Small to medium cloves with concentrated aromatics',
          'Cleaned and dry-brushed free of loose soil',
          'Long shelf-life of 6+ weeks in airy basket',
          'Direct farm price without market toll overhead'
        ],
        activeBucket: BatchBucket(
          bucketNumber: 1,
          listingId: 'listing_garlic_10',
          date: '2026-10-21',
          moqThreshold: 40.0,
          currentQuantity: 36.0,
          remainingCapacity: 4.0,
          status: 'open',
          orderCount: 4,
        ),
      ),
      const DailyListing(
        id: 'listing_chilli_13',
        productId: 'prod_chilli_01',
        productTitle: 'Bogura Fresh Green Chillies (5 kg bag)',
        unit: 'bag',
        marketPrice: 600.0,
        unitPrice: 440.0,
        discountPercent: 26.7,
        moqThreshold: 50.0,
        activeBucketNumber: 1,
        totalBucketsCount: 1,
        totalVolumeOrdered: 28.0, // Top Seller #4 in Vegetables
        status: 'active',
        imageUrl:
            'https://images.unsplash.com/photo-1588252303782-cb80119abd6d?auto=format&fit=crop&w=800&q=80',
        category: 'Fresh Vegetables',
        origin: 'Bogura Char Farmland',
        description:
            'Vibrant, hand-plucked green chillies from Bogura char lands. Crisp bite with high heat level and clean peppery freshness. Plucked on the morning of batch collection to preserve stem moisture and crispness.',
        highlights: [
          'Crisp, high heat index green chillies',
          'Stem-intact harvest ensuring lasting freshness',
          'Zero artificial waxing or coloring',
          'Sourced from prime Bogura alluvial soil'
        ],
        activeBucket: BatchBucket(
          bucketNumber: 1,
          listingId: 'listing_chilli_13',
          date: '2026-10-21',
          moqThreshold: 50.0,
          currentQuantity: 28.0,
          remainingCapacity: 22.0,
          status: 'open',
          orderCount: 3,
        ),
      ),
    ];
  }

  /// Returns the top selling listings for a specific category
  List<DailyListing> getTopSelling(String category, {int limit = 4}) {
    final list = state.where((l) => l.category == category).toList();
    list.sort((a, b) => b.totalVolumeOrdered.compareTo(a.totalVolumeOrdered));
    return list.take(limit).toList();
  }

  /// Returns all listings for a specific category
  List<DailyListing> getListingsByCategory(String category) {
    return state.where((l) => l.category == category).toList();
  }

  /// Returns the maximum allowed order volume for a given listing
  double getRemainingCapacity(String listingId) {
    final listing = state.firstWhere(
      (l) => l.id == listingId,
      orElse: () => throw Exception('Listing not found'),
    );
    return listing.activeBucket?.remainingCapacity ?? 0.0;
  }

  /// Updates volume for testing or live order simulation
  void updateListingQuantity(String listingId, double addedQuantity) {
    state = [
      for (final listing in state)
        if (listing.id == listingId && listing.activeBucket != null)
          _incrementBucket(listing, addedQuantity)
        else
          listing,
    ];
  }

  DailyListing _incrementBucket(DailyListing listing, double addedQuantity) {
    final bucket = listing.activeBucket!;
    final newCurrent = (bucket.currentQuantity + addedQuantity).clamp(0.0, bucket.moqThreshold);
    final newRemaining = (bucket.moqThreshold - newCurrent).clamp(0.0, bucket.moqThreshold);
    final newStatus = newCurrent >= bucket.moqThreshold ? 'target_met' : 'open';

    final updatedBucket = bucket.copyWith(
      currentQuantity: newCurrent,
      remainingCapacity: newRemaining,
      status: newStatus,
      orderCount: bucket.orderCount + 1,
    );

    return listing.copyWith(
      totalVolumeOrdered: listing.totalVolumeOrdered + addedQuantity,
      activeBucket: updatedBucket,
    );
  }
}
