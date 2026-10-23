import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ekshate_app/features/procurement/domain/procurement_manifest.dart';
import 'package:ekshate_app/features/procurement/data/procurement_repository.dart';
import 'package:ekshate_app/features/procurement/presentation/procurement_screen.dart';
import 'package:ekshate_app/features/procurement/presentation/procurement_controller.dart';

void main() {
  late InMemoryProcurementRepository mockRepo;
  const testDate = '2026-10-22';

  void configureViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Widget createTestWidget({List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: [
        procurementRepositoryProvider.overrideWithValue(mockRepo),
        selectedProcurementDateProvider.overrideWith((ref) => testDate),
        ...overrides,
      ],
      child: const ShadApp(
        home: ScaffoldMessenger(
          child: ProcurementScreen(),
        ),
      ),
    );
  }

  setUp(() {
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
    ];

    final manifest = ProcurementManifest(
      date: testDate,
      totalConfirmedVolume: 280,
      totalProcurementCost: 24200,
      totalItemsCount: items.length,
      totalBucketsCount: 3,
      items: items,
      csvPayload: ProcurementManifest.generateStandardCsv(items),
      status: ManifestStatus.inProcurement,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    mockRepo = InMemoryProcurementRepository(initialData: {
      testDate: manifest,
    });
  });

  tearDown(() {
    mockRepo.dispose();
  });

  group('ProcurementScreen Widget & Integration Tests', () {
    testWidgets('renders morning depot banner and summary metric cards accurately', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('Morning Procurement'), findsOneWidget);
      expect(find.text('4:00 AM Physical Purchasing Manifest'), findsOneWidget);

      // Verify Operations Banner
      expect(find.text('Karwan Bazar & Farm Depots'), findsOneWidget);
      expect(find.text('4:00 AM RUN'), findsOneWidget);

      // Verify Summary Cards
      expect(find.text('280 kg'), findsOneWidget);
      expect(find.text('3 Confirmed Buckets'), findsOneWidget);

      expect(find.text('Est. Wholesale Budget'), findsOneWidget);
      expect(find.text('৳ 24200'), findsOneWidget);

      expect(find.text('Distinct SKUs'), findsOneWidget);
      expect(find.text('2 Products'), findsOneWidget);

      expect(find.text('In Progress (At Market)'), findsOneWidget);

      // Verify Progress Bar
      expect(find.text('Purchasing Completion'), findsOneWidget);
      expect(find.text('50% Complete'), findsOneWidget);
    });

    testWidgets('renders itemized wholesale checklist with quotas, budgets, and packaging notes', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Item 1: Miniket Rice
      expect(find.text('Premium Miniket Rice (50kg Sacks)'), findsOneWidget);
      expect(find.text('SKU-RICE-01'), findsOneWidget);
      expect(find.text('Grains & Staples'), findsOneWidget);
      expect(find.text('200 kg'), findsOneWidget);
      expect(find.text('৳ 65 / kg'), findsOneWidget);
      expect(find.text('Budget: ৳ 13000'), findsOneWidget);
      expect(find.text('Badamtoli Wholesale Depot, Dhaka'), findsOneWidget);
      expect(find.text('Packaging Spec: 4 x 50 kg burlap bags'), findsOneWidget);
      expect(find.text('PROCURED'), findsOneWidget);

      // Item 2: Nagpur Oranges
      expect(find.text('Fresh Nagpur Sweet Oranges'), findsOneWidget);
      expect(find.text('SKU-ORANGE-02'), findsOneWidget);
      expect(find.text('Fresh Fruits'), findsOneWidget);
      expect(find.text('80 kg'), findsOneWidget);
      expect(find.text('৳ 140 / kg'), findsOneWidget);
      expect(find.text('Budget: ৳ 11200'), findsOneWidget);
      expect(find.text('Karwan Bazar Arat #4, Dhaka'), findsOneWidget);
      expect(find.text('Packaging Spec: 8 x 10 kg crates'), findsOneWidget);
      expect(find.text('PENDING'), findsOneWidget);
    });

    testWidgets('tapping item checkbox toggles item procured status and updates progress bar', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Initially 50% Complete (1/2 procured)
      expect(find.text('50% Complete'), findsOneWidget);
      expect(find.text('1 / 2 Procured'), findsOneWidget);

      // Tap orange item checkbox to mark as procured
      final toggleOrange = find.byKey(const Key('toggle_procured_SKU-ORANGE-02'));
      expect(toggleOrange, findsOneWidget);
      await tester.tap(toggleOrange);
      await tester.pumpAndSettle();

      // Both items are now procured -> 100% complete
      expect(find.text('100% Complete'), findsOneWidget);
      expect(find.text('2 / 2 Procured'), findsOneWidget);
      expect(find.text('Procurement Complete'), findsOneWidget);
    });

    testWidgets('tapping 1-Tap CSV Export copies standardized CSV to clipboard and shows SnackBar', (tester) async {
      configureViewport(tester);

      // Register mock method call handler for Clipboard
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            return null;
          }
          return null;
        },
      );

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap 1-Tap CSV Export button
      final exportButton = find.byKey(const Key('export_csv_button'));
      expect(exportButton, findsOneWidget);
      await tester.tap(exportButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify SnackBar confirmation
      expect(find.byKey(const Key('csv_export_snackbar')), findsOneWidget);
      expect(
        find.text('Procurement manifest CSV copied to clipboard! Standardized for Excel/Karwan Bazar agents.'),
        findsOneWidget,
      );
    });

    testWidgets('tapping Preview button opens CSV modal dialog with raw payload and close/copy actions', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final previewButton = find.byKey(const Key('preview_csv_button'));
      expect(previewButton, findsOneWidget);
      await tester.tap(previewButton);
      await tester.pumpAndSettle();

      // Dialog is displayed
      expect(find.text('Standardized CSV Payload'), findsOneWidget);
      expect(find.text('Copy CSV'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      // Tap Close button
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // Dialog dismissed
      expect(find.text('Standardized CSV Payload'), findsNothing);
    });

    testWidgets('renders empty state when date has zero confirmed buckets', (tester) async {
      configureViewport(tester);
      const emptyDate = '2026-10-23';

      await tester.pumpWidget(createTestWidget(overrides: [
        selectedProcurementDateProvider.overrideWith((ref) => emptyDate),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('No Confirmed Buckets'), findsOneWidget);
      expect(find.textContaining('No batch buckets met MOQ for date 2026-10-23'), findsOneWidget);
    });
  });
}
