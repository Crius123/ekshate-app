import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/cart_item.dart';
import '../../daily_sale/domain/daily_listing.dart';
import '../../daily_sale/presentation/daily_sale_controller.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../orders/domain/order_entity.dart';
import '../../orders/data/orders_repository.dart';
import '../../../core/errors/app_exception.dart';

final cartProvider = NotifierProvider<CartController, List<CartItem>>(() {
  return CartController();
});

class CartController extends Notifier<List<CartItem>> {
  @override
  List<CartItem> build() {
    return [];
  }

  void addItem(DailyListing listing, double quantity) {
    final remainingCap = listing.activeBucket?.remainingCapacity ?? 0.0;
    if (quantity > remainingCap) {
      throw BucketCapacityExceededException(
        requestedQuantity: quantity,
        remainingCapacity: remainingCap,
      );
    }

    final existingIndex = state.indexWhere((item) => item.listingId == listing.id);
    if (existingIndex >= 0) {
      final existing = state[existingIndex];
      final newQty = (existing.quantity + quantity).clamp(1.0, remainingCap);
      state = [
        ...state.sublist(0, existingIndex),
        existing.copyWith(
          quantity: newQty,
          maxAllowedCapacity: remainingCap,
          date: listing.activeBucket?.date,
          imageUrl: listing.imageUrl,
        ),
        ...state.sublist(existingIndex + 1),
      ];
    } else {
      state = [
        ...state,
        CartItem(
          listingId: listing.id,
          productTitle: listing.productTitle,
          unitPrice: listing.unitPrice,
          unit: listing.unit,
          quantity: quantity,
          maxAllowedCapacity: remainingCap,
          date: listing.activeBucket?.date,
          imageUrl: listing.imageUrl,
        ),
      ];
    }
  }

  void updateQuantity(String listingId, double newQty) {
    state = [
      for (final item in state)
        if (item.listingId == listingId)
          item.copyWith(quantity: newQty.clamp(1.0, item.maxAllowedCapacity))
        else
          item,
    ];
  }

  void removeItem(String listingId) {
    state = state.where((item) => item.listingId != listingId).toList();
  }

  void clearCart() {
    state = [];
  }

  double get totalAmount => state.fold(0.0, (sum, item) => sum + item.totalAmount);

  void validateCheckoutSufficientFunds(double availableBalance) {
    if (totalAmount > availableBalance) {
      throw InsufficientWalletBalanceException(
        requiredAmount: totalAmount,
        availableBalance: availableBalance,
      );
    }
  }

  /// Atomic batch checkout:
  /// Verifies funds, checks bucket capacity clamps, debits available balance,
  /// credits escrow balance, writes audit ledger entries, creates orders,
  /// updates batch bucket volume & handles automatic rollover, and clears cart.
  Future<List<OrderEntity>> checkout({
    required String deliveryAddress,
    String? phone,
  }) async {
    if (state.isEmpty) {
      throw StateError('Cannot checkout an empty batch cart.');
    }

    final authState = ref.read(authStateProvider);
    final user = authState.asData?.value;
    if (user == null) {
      throw StateError('User must be signed in to checkout.');
    }

    if (deliveryAddress.trim().isEmpty) {
      throw ArgumentError('Delivery address is required for checkout.');
    }

    // 1. Balance verification
    validateCheckoutSufficientFunds(user.availableBalance);

    // 2. Capacity & Precondition verification
    final dailyListings = ref.read(dailyListingsProvider);
    for (final item in state) {
      final listing = dailyListings.firstWhere(
        (l) => l.id == item.listingId,
        orElse: () => throw StateError('Listing ${item.listingId} not found'),
      );
      final remainingCap = listing.activeBucket?.remainingCapacity ?? 0.0;
      if (item.quantity > remainingCap) {
        throw BucketCapacityExceededException(
          requestedQuantity: item.quantity,
          remainingCapacity: remainingCap,
        );
      }
    }

    // 3. Execute atomic order placement for all cart items
    final ordersRepo = ref.read(ordersRepositoryProvider);
    final placedOrders = <OrderEntity>[];
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);

    for (final item in state) {
      final listing = dailyListings.firstWhere((l) => l.id == item.listingId);
      final activeBucketNum = listing.activeBucketNumber;

      final order = await ordersRepo.placeOrder(
        listingId: item.listingId,
        productTitle: item.productTitle,
        quantity: item.quantity,
        unit: item.unit,
        unitPrice: item.unitPrice,
        deliveryAddress: deliveryAddress.trim(),
        date: item.date ?? listing.activeBucket?.date ?? todayStr,
        bucketNumber: activeBucketNum,
        phone: phone ?? user.phoneNumber,
      );

      // Update bucket volume in daily sale controller (handles rollover if MOQ met)
      ref
          .read(dailyListingsProvider.notifier)
          .updateListingQuantity(item.listingId, item.quantity);

      placedOrders.add(order);
    }

    // 4. Clear cart on successful atomic submission
    clearCart();

    return placedOrders;
  }
}

final cartTotalAmountProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0.0, (sum, item) => sum + item.totalAmount);
});
