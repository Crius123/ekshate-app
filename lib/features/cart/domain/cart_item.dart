class CartItem {
  final String listingId;
  final String productTitle;
  final double unitPrice;
  final String unit;
  final double quantity;
  final double maxAllowedCapacity; // Hard clamped to bucket.remainingCapacity
  final String? date;
  final String? imageUrl;

  const CartItem({
    required this.listingId,
    required this.productTitle,
    required this.unitPrice,
    required this.unit,
    required this.quantity,
    required this.maxAllowedCapacity,
    this.date,
    this.imageUrl,
  });

  double get totalAmount => unitPrice * quantity;

  CartItem copyWith({
    double? quantity,
    double? maxAllowedCapacity,
    String? date,
    String? imageUrl,
  }) {
    return CartItem(
      listingId: listingId,
      productTitle: productTitle,
      unitPrice: unitPrice,
      unit: unit,
      quantity: quantity ?? this.quantity,
      maxAllowedCapacity: maxAllowedCapacity ?? this.maxAllowedCapacity,
      date: date ?? this.date,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
