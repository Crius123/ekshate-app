/// Represents a single item quota in the wholesale morning procurement manifest.
class ProcurementItem {
  final String sku;
  final String listingId;
  final String productId;
  final String productTitle;
  final String category;
  final double totalVolume;
  final String unit;
  final int confirmedBucketsCount;
  final double estimatedUnitCost;
  final double totalBudget;
  final String targetMarket;
  final String packagingNotes;
  final bool isProcured;

  const ProcurementItem({
    required this.sku,
    required this.listingId,
    required this.productId,
    required this.productTitle,
    required this.category,
    required this.totalVolume,
    required this.unit,
    required this.confirmedBucketsCount,
    required this.estimatedUnitCost,
    required this.totalBudget,
    required this.targetMarket,
    required this.packagingNotes,
    this.isProcured = false,
  });

  ProcurementItem copyWith({
    String? sku,
    String? listingId,
    String? productId,
    String? productTitle,
    String? category,
    double? totalVolume,
    String? unit,
    int? confirmedBucketsCount,
    double? estimatedUnitCost,
    double? totalBudget,
    String? targetMarket,
    String? packagingNotes,
    bool? isProcured,
  }) {
    return ProcurementItem(
      sku: sku ?? this.sku,
      listingId: listingId ?? this.listingId,
      productId: productId ?? this.productId,
      productTitle: productTitle ?? this.productTitle,
      category: category ?? this.category,
      totalVolume: totalVolume ?? this.totalVolume,
      unit: unit ?? this.unit,
      confirmedBucketsCount: confirmedBucketsCount ?? this.confirmedBucketsCount,
      estimatedUnitCost: estimatedUnitCost ?? this.estimatedUnitCost,
      totalBudget: totalBudget ?? this.totalBudget,
      targetMarket: targetMarket ?? this.targetMarket,
      packagingNotes: packagingNotes ?? this.packagingNotes,
      isProcured: isProcured ?? this.isProcured,
    );
  }

  factory ProcurementItem.fromMap(Map<String, dynamic> map) {
    return ProcurementItem(
      sku: (map['sku'] as String?) ?? '',
      listingId: (map['listing_id'] as String?) ?? '',
      productId: (map['product_id'] as String?) ?? '',
      productTitle: (map['product_title'] as String?) ?? 'Wholesale Product',
      category: (map['category'] as String?) ?? 'General Wholesale',
      totalVolume: ((map['total_volume'] as num?) ?? 0).toDouble(),
      unit: (map['unit'] as String?) ?? 'kg',
      confirmedBucketsCount: ((map['confirmed_buckets_count'] as num?) ?? 1).toInt(),
      estimatedUnitCost: ((map['estimated_unit_cost'] as num?) ?? 0).toDouble(),
      totalBudget: ((map['total_budget'] as num?) ?? 0).toDouble(),
      targetMarket: (map['target_market'] as String?) ?? 'Karwan Bazar Wholesale Hub, Dhaka',
      packagingNotes: (map['packaging_notes'] as String?) ?? 'Wholesale crates/sacks',
      isProcured: map['status'] == 'procured' || map['is_procured'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sku': sku,
      'listing_id': listingId,
      'product_id': productId,
      'product_title': productTitle,
      'category': category,
      'total_volume': totalVolume,
      'unit': unit,
      'confirmed_buckets_count': confirmedBucketsCount,
      'estimated_unit_cost': estimatedUnitCost,
      'total_budget': totalBudget,
      'target_market': targetMarket,
      'packaging_notes': packagingNotes,
      'status': isProcured ? 'procured' : 'pending',
    };
  }

  /// Standard RFC 4180 CSV escaping
  static String escapeCsv(dynamic val) {
    if (val == null) return '';
    final s = val.toString();
    if (s.contains(',') || s.contains('"') || s.contains('\n') || s.contains('\r')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  String toCsvRow() {
    return [
      escapeCsv(sku),
      escapeCsv(productTitle),
      escapeCsv(category),
      escapeCsv(totalVolume),
      escapeCsv(unit),
      escapeCsv(estimatedUnitCost),
      escapeCsv(totalBudget),
      escapeCsv(targetMarket),
      escapeCsv(packagingNotes),
    ].join(',');
  }
}

/// Status of the morning wholesale procurement manifest
enum ManifestStatus {
  pendingProcurement,
  inProcurement,
  procured,
}

extension ManifestStatusX on ManifestStatus {
  String toDbString() {
    switch (this) {
      case ManifestStatus.pendingProcurement:
        return 'pending_procurement';
      case ManifestStatus.inProcurement:
        return 'in_procurement';
      case ManifestStatus.procured:
        return 'procured';
    }
  }

  static ManifestStatus fromDbString(String? val) {
    switch (val) {
      case 'in_procurement':
        return ManifestStatus.inProcurement;
      case 'procured':
        return ManifestStatus.procured;
      case 'pending_procurement':
      default:
        return ManifestStatus.pendingProcurement;
    }
  }

  String get label {
    switch (this) {
      case ManifestStatus.pendingProcurement:
        return 'Pending Procurement';
      case ManifestStatus.inProcurement:
        return 'In Progress (At Market)';
      case ManifestStatus.procured:
        return 'Procurement Complete';
    }
  }
}

/// Immutable record aggregated from all confirmed won buckets for a campaign date.
class ProcurementManifest {
  final String date;
  final double totalConfirmedVolume;
  final double totalProcurementCost;
  final int totalItemsCount;
  final int totalBucketsCount;
  final List<ProcurementItem> items;
  final String csvPayload;
  final ManifestStatus status;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProcurementManifest({
    required this.date,
    required this.totalConfirmedVolume,
    required this.totalProcurementCost,
    required this.totalItemsCount,
    required this.totalBucketsCount,
    required this.items,
    required this.csvPayload,
    this.status = ManifestStatus.pendingProcurement,
    this.createdAt,
    this.updatedAt,
  });

  int get procuredItemsCount => items.where((i) => i.isProcured).length;

  double get completionRatio =>
      totalItemsCount > 0 ? (procuredItemsCount / totalItemsCount) : 0.0;

  bool get isFullyProcured =>
      totalItemsCount > 0 && procuredItemsCount == totalItemsCount;

  ProcurementManifest copyWith({
    String? date,
    double? totalConfirmedVolume,
    double? totalProcurementCost,
    int? totalItemsCount,
    int? totalBucketsCount,
    List<ProcurementItem>? items,
    String? csvPayload,
    ManifestStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProcurementManifest(
      date: date ?? this.date,
      totalConfirmedVolume: totalConfirmedVolume ?? this.totalConfirmedVolume,
      totalProcurementCost: totalProcurementCost ?? this.totalProcurementCost,
      totalItemsCount: totalItemsCount ?? this.totalItemsCount,
      totalBucketsCount: totalBucketsCount ?? this.totalBucketsCount,
      items: items ?? this.items,
      csvPayload: csvPayload ?? this.csvPayload,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory ProcurementManifest.fromMap(Map<String, dynamic> map, String docDate) {
    final rawItems = map['items'] as List<dynamic>? ?? [];
    final itemsList = rawItems
        .map((itemMap) => ProcurementItem.fromMap(Map<String, dynamic>.from(itemMap as Map)))
        .toList();

    return ProcurementManifest(
      date: (map['date'] as String?) ?? docDate,
      totalConfirmedVolume: ((map['total_confirmed_volume'] as num?) ?? 0).toDouble(),
      totalProcurementCost: ((map['total_procurement_cost'] as num?) ?? 0).toDouble(),
      totalItemsCount: ((map['total_items_count'] as num?) ?? itemsList.length).toInt(),
      totalBucketsCount: ((map['total_buckets_count'] as num?) ?? 0).toInt(),
      items: itemsList,
      csvPayload: (map['csv_payload'] as String?) ?? generateStandardCsv(itemsList),
      status: ManifestStatusX.fromDbString(map['status'] as String?),
      createdAt: map['created_at'] != null ? DateTime.tryParse(map['created_at'].toString()) : null,
      updatedAt: map['updated_at'] != null ? DateTime.tryParse(map['updated_at'].toString()) : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'total_confirmed_volume': totalConfirmedVolume,
      'total_procurement_cost': totalProcurementCost,
      'total_items_count': totalItemsCount,
      'total_buckets_count': totalBucketsCount,
      'items': items.map((i) => i.toMap()).toList(),
      'csv_payload': csvPayload.isNotEmpty ? csvPayload : generateStandardCsv(items),
      'status': status.toDbString(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Generates standardized CSV string adhering to RFC 4180
  static String generateStandardCsv(List<ProcurementItem> itemsList) {
    final headers = [
      'SKU',
      'Product Title',
      'Category',
      'Total Volume',
      'Unit',
      'Estimated Unit Cost',
      'Total Budget',
      'Target Wholesale Market / Supplier',
      'Packaging Notes',
    ];

    final headerLine = headers.join(',');
    if (itemsList.isEmpty) {
      return '$headerLine\n';
    }

    final rowLines = itemsList.map((item) => item.toCsvRow()).toList();
    return '$headerLine\n${rowLines.join('\n')}\n';
  }
}
