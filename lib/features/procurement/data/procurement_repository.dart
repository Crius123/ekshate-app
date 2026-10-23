import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/procurement_manifest.dart';

abstract class ProcurementRepository {
  Future<ProcurementManifest?> getManifest(String date);
  Stream<ProcurementManifest?> watchManifest(String date);
  Future<void> toggleItemStatus(String date, String sku, bool isProcured);
  Future<void> updateManifestStatus(String date, ManifestStatus status);
  Future<void> saveManifest(ProcurementManifest manifest);
}

class InMemoryProcurementRepository implements ProcurementRepository {
  final Map<String, ProcurementManifest> _storage = {};
  final _controller = StreamController<ProcurementManifest?>.broadcast();

  InMemoryProcurementRepository({Map<String, ProcurementManifest>? initialData}) {
    if (initialData != null) {
      _storage.addAll(initialData);
    } else {
      _seedDefaultManifest();
    }
  }

  void _seedDefaultManifest() {
    final today = _getTodayDateString();
    final items = [
      const ProcurementItem(
        sku: 'SKU-RICE-01',
        listingId: 'listing_rice_01',
        productId: 'prod_rice_01',
        productTitle: 'Premium Miniket Rice (50kg Sacks)',
        category: 'Grains & Staples',
        totalVolume: 200,
        unit: 'kg',
        confirmedBucketsCount: 2,
        estimatedUnitCost: 65,
        totalBudget: 13000,
        targetMarket: 'Badamtoli Wholesale Depot, Dhaka',
        packagingNotes: '4 x 50 kg burlap bags',
        isProcured: true,
      ),
      const ProcurementItem(
        sku: 'SKU-ORANGE-02',
        listingId: 'listing_orange_02',
        productId: 'prod_orange_02',
        productTitle: 'Fresh Nagpur Sweet Oranges',
        category: 'Fresh Fruits',
        totalVolume: 80,
        unit: 'kg',
        confirmedBucketsCount: 1,
        estimatedUnitCost: 140,
        totalBudget: 11200,
        targetMarket: 'Karwan Bazar Arat #4, Dhaka',
        packagingNotes: '8 x 10 kg crates',
        isProcured: false,
      ),
      const ProcurementItem(
        sku: 'SKU-OIL-03',
        listingId: 'listing_oil_03',
        productId: 'prod_oil_03',
        productTitle: 'Pure Mustard & Soybean Oil',
        category: 'Edible Oils',
        totalVolume: 50,
        unit: 'liter',
        confirmedBucketsCount: 1,
        estimatedUnitCost: 165,
        totalBudget: 8250,
        targetMarket: 'Kaptan Bazar Depot, Old Dhaka',
        packagingNotes: '10 x 5 L containers',
        isProcured: false,
      ),
      const ProcurementItem(
        sku: 'SKU-POTATO-04',
        listingId: 'listing_potato_04',
        productId: 'prod_potato_04',
        productTitle: 'Bogura Diamond Red Potatoes',
        category: 'Vegetables',
        totalVolume: 150,
        unit: 'kg',
        confirmedBucketsCount: 1,
        estimatedUnitCost: 35,
        totalBudget: 5250,
        targetMarket: 'Shyambazar Vegetable Arat, Dhaka',
        packagingNotes: '3 x 50 kg burlap bags',
        isProcured: false,
      ),
    ];

    final manifest = ProcurementManifest(
      date: today,
      totalConfirmedVolume: 480,
      totalProcurementCost: 37700,
      totalItemsCount: items.length,
      totalBucketsCount: 5,
      items: items,
      csvPayload: ProcurementManifest.generateStandardCsv(items),
      status: ManifestStatus.inProcurement,
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      updatedAt: DateTime.now(),
    );

    _storage[today] = manifest;
  }

  static String _getTodayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Future<ProcurementManifest?> getManifest(String date) async {
    return _storage[date];
  }

  @override
  Stream<ProcurementManifest?> watchManifest(String date) async* {
    yield _storage[date];
    yield* _controller.stream.where((m) => m == null || m.date == date);
  }

  @override
  Future<void> toggleItemStatus(String date, String sku, bool isProcured) async {
    final current = _storage[date];
    if (current == null) return;

    final updatedItems = current.items.map((item) {
      if (item.sku == sku) {
        return item.copyWith(isProcured: isProcured);
      }
      return item;
    }).toList();

    final allProcured = updatedItems.isNotEmpty && updatedItems.every((i) => i.isProcured);
    final anyProcured = updatedItems.any((i) => i.isProcured);

    ManifestStatus newStatus = current.status;
    if (allProcured) {
      newStatus = ManifestStatus.procured;
    } else if (anyProcured) {
      newStatus = ManifestStatus.inProcurement;
    }

    final updatedManifest = current.copyWith(
      items: updatedItems,
      status: newStatus,
      updatedAt: DateTime.now(),
    );

    _storage[date] = updatedManifest;
    _controller.add(updatedManifest);
  }

  @override
  Future<void> updateManifestStatus(String date, ManifestStatus status) async {
    final current = _storage[date];
    if (current == null) return;

    final updatedManifest = current.copyWith(
      status: status,
      updatedAt: DateTime.now(),
    );

    _storage[date] = updatedManifest;
    _controller.add(updatedManifest);
  }

  @override
  Future<void> saveManifest(ProcurementManifest manifest) async {
    _storage[manifest.date] = manifest;
    _controller.add(manifest);
  }

  void dispose() {
    _controller.close();
  }
}

final procurementRepositoryProvider = Provider<ProcurementRepository>((ref) {
  return InMemoryProcurementRepository();
});
