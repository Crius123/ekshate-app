import 'package:flutter_test/flutter_test.dart';
import 'package:ekshate_app/features/procurement/domain/procurement_manifest.dart';

void main() {
  group('Procurement Domain & CSV RFC 4180 Serialization Tests', () {
    test('ProcurementItem fromMap and toMap maintains schema integrity', () {
      final map = {
        'sku': 'SKU-RICE-01',
        'listing_id': 'list_rice_1',
        'product_id': 'prod_rice_1',
        'product_title': 'Premium Miniket Rice (Bulk)',
        'category': 'Grains & Staples',
        'total_volume': 200.0,
        'unit': 'kg',
        'confirmed_buckets_count': 2,
        'estimated_unit_cost': 65.0,
        'total_budget': 13000.0,
        'target_market': 'Badamtoli Wholesale Depot',
        'packaging_notes': '4 x 50 kg burlap bags',
        'status': 'procured',
      };

      final item = ProcurementItem.fromMap(map);
      expect(item.sku, 'SKU-RICE-01');
      expect(item.totalVolume, 200.0);
      expect(item.estimatedUnitCost, 65.0);
      expect(item.totalBudget, 13000.0);
      expect(item.confirmedBucketsCount, 2);
      expect(item.isProcured, isTrue);

      final serialized = item.toMap();
      expect(serialized['sku'], 'SKU-RICE-01');
      expect(serialized['total_volume'], 200.0);
      expect(serialized['status'], 'procured');
    });

    test('ProcurementItem RFC 4180 escaping properly handles commas and quotes', () {
      const item = ProcurementItem(
        sku: 'SKU-CITRUS-02',
        listingId: 'list_citrus_2',
        productId: 'prod_citrus_2',
        productTitle: 'Nagpur Oranges, Grade "A" Quality',
        category: 'Fresh Fruits',
        totalVolume: 50.0,
        unit: 'kg',
        confirmedBucketsCount: 1,
        estimatedUnitCost: 150.0,
        totalBudget: 7500.0,
        targetMarket: 'Karwan Bazar Arat #4, Dhaka',
        packagingNotes: '5 x 10 kg crates',
      );

      final row = item.toCsvRow();
      expect(row, contains('"Nagpur Oranges, Grade ""A"" Quality"'));
      expect(row, contains('"Karwan Bazar Arat #4, Dhaka"'));
      expect(row, contains('50.0'));
      expect(row, contains('7500.0'));
    });

    test('ProcurementManifest completion calculations and status mappings', () {
      final items = [
        const ProcurementItem(
          sku: 'SKU-1',
          listingId: 'l1',
          productId: 'p1',
          productTitle: 'Product 1',
          category: 'Category 1',
          totalVolume: 100.0,
          unit: 'kg',
          confirmedBucketsCount: 1,
          estimatedUnitCost: 50.0,
          totalBudget: 5000.0,
          targetMarket: 'Market 1',
          packagingNotes: 'Notes 1',
          isProcured: true,
        ),
        const ProcurementItem(
          sku: 'SKU-2',
          listingId: 'l2',
          productId: 'p2',
          productTitle: 'Product 2',
          category: 'Category 2',
          totalVolume: 50.0,
          unit: 'kg',
          confirmedBucketsCount: 1,
          estimatedUnitCost: 80.0,
          totalBudget: 4000.0,
          targetMarket: 'Market 2',
          packagingNotes: 'Notes 2',
          isProcured: false,
        ),
      ];

      final manifest = ProcurementManifest(
        date: '2026-10-22',
        totalConfirmedVolume: 150.0,
        totalProcurementCost: 9000.0,
        totalItemsCount: 2,
        totalBucketsCount: 2,
        items: items,
        csvPayload: ProcurementManifest.generateStandardCsv(items),
        status: ManifestStatus.inProcurement,
      );

      expect(manifest.procuredItemsCount, 1);
      expect(manifest.completionRatio, 0.5);
      expect(manifest.isFullyProcured, isFalse);

      final allDone = manifest.copyWith(
        items: items.map((i) => i.copyWith(isProcured: true)).toList(),
      );
      expect(allDone.procuredItemsCount, 2);
      expect(allDone.completionRatio, 1.0);
      expect(allDone.isFullyProcured, isTrue);
    });

    test('ProcurementManifest generateStandardCsv formats standardized header and rows', () {
      final items = [
        const ProcurementItem(
          sku: 'SKU-OIL-1',
          listingId: 'l_oil',
          productId: 'p_oil',
          productTitle: 'Mustard Oil',
          category: 'Edible Oils',
          totalVolume: 30.0,
          unit: 'liter',
          confirmedBucketsCount: 1,
          estimatedUnitCost: 160.0,
          totalBudget: 4800.0,
          targetMarket: 'Kaptan Bazar',
          packagingNotes: '6 x 5 L containers',
        ),
      ];

      final csv = ProcurementManifest.generateStandardCsv(items);
      final lines = csv.trim().split('\n');

      expect(lines.length, 2);
      expect(
        lines[0],
        'SKU,Product Title,Category,Total Volume,Unit,Estimated Unit Cost,Total Budget,Target Wholesale Market / Supplier,Packaging Notes',
      );
      expect(lines[1], contains('SKU-OIL-1'));
      expect(lines[1], contains('Mustard Oil'));
      expect(lines[1], contains('30.0'));
      expect(lines[1], contains('4800.0'));
      expect(lines[1], contains('6 x 5 L containers'));
    });
  });
}
