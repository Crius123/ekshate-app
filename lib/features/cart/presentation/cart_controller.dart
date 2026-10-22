import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/cart_item.dart';
import '../../daily_sale/domain/daily_listing.dart';
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
        existing.copyWith(quantity: newQty, maxAllowedCapacity: remainingCap),
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
}

final cartTotalAmountProvider = Provider<double>((ref) {
  final cart = ref.watch(cartProvider);
  return cart.fold(0.0, (sum, item) => sum + item.totalAmount);
});
