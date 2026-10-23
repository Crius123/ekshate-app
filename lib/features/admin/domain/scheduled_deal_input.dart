class ScheduledDealInput {
  final String date;
  final String productTitle;
  final String category;
  final String unit;
  final double marketPrice;
  final double unitPrice;
  final double moqThreshold;
  final String imageUrl;
  final String? description;

  const ScheduledDealInput({
    required this.date,
    required this.productTitle,
    required this.category,
    required this.unit,
    required this.marketPrice,
    required this.unitPrice,
    required this.moqThreshold,
    required this.imageUrl,
    this.description,
  });

  double get savingsPerUnit => marketPrice - unitPrice;

  double get discountPercent {
    if (marketPrice <= 0 || unitPrice <= 0 || unitPrice >= marketPrice) {
      return 0.0;
    }
    return ((marketPrice - unitPrice) / marketPrice) * 100;
  }

  bool get isValid =>
      productTitle.trim().isNotEmpty &&
      category.trim().isNotEmpty &&
      unit.trim().isNotEmpty &&
      marketPrice > 0 &&
      unitPrice > 0 &&
      unitPrice < marketPrice &&
      moqThreshold > 0;

  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'productTitle': productTitle,
      'category': category,
      'unit': unit,
      'marketPrice': marketPrice,
      'unitPrice': unitPrice,
      'moqThreshold': moqThreshold,
      'imageUrl': imageUrl,
      if (description != null) 'description': description,
    };
  }

  ScheduledDealInput copyWith({
    String? date,
    String? productTitle,
    String? category,
    String? unit,
    double? marketPrice,
    double? unitPrice,
    double? moqThreshold,
    String? imageUrl,
    String? description,
  }) {
    return ScheduledDealInput(
      date: date ?? this.date,
      productTitle: productTitle ?? this.productTitle,
      category: category ?? this.category,
      unit: unit ?? this.unit,
      marketPrice: marketPrice ?? this.marketPrice,
      unitPrice: unitPrice ?? this.unitPrice,
      moqThreshold: moqThreshold ?? this.moqThreshold,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
    );
  }
}
