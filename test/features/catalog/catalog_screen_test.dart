import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:ekshate_app/core/router/route_paths.dart';
import 'package:ekshate_app/features/catalog/presentation/catalog_screen.dart';
import 'package:ekshate_app/features/catalog/presentation/widgets/catalog_category_select.dart';
import 'package:ekshate_app/features/daily_sale/presentation/category_products_screen.dart';
import 'package:ekshate_app/features/daily_sale/presentation/daily_sale_controller.dart';
import 'package:ekshate_app/features/daily_sale/domain/daily_listing.dart';
import 'package:ekshate_app/features/daily_sale/domain/batch_bucket.dart';

void main() {
  void configureViewport(WidgetTester tester, {Size size = const Size(1440, 900)}) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Widget createSubject() {
    final router = GoRouter(
      initialLocation: RoutePaths.catalog,
      routes: [
        GoRoute(
          path: RoutePaths.catalog,
          builder: (context, state) => const CatalogScreen(),
        ),
        GoRoute(
          path: RoutePaths.categoryProducts,
          builder: (context, state) {
            final raw = state.pathParameters['categoryName'] ?? '';
            return CategoryProductsScreen(categoryName: Uri.decodeComponent(raw));
          },
        ),
      ],
    );

    return ProviderScope(
      child: ShadApp.router(
        routerConfig: router,
      ),
    );
  }

  group('CatalogScreen and Category Select Tests', () {
    testWidgets('renders catalog screen with category select button and category cards', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      expect(find.text('Product Catalog'), findsOneWidget);
      expect(find.text('Wholesale Product Categories'), findsOneWidget);

      // Verify the Catalog Select button is displayed
      expect(find.byKey(const Key('catalog_select_button')), findsOneWidget);
      expect(find.text('Select Product Category...'), findsOneWidget);

      // Verify category cards
      expect(find.text('Fresh Fruits'), findsOneWidget);
      expect(find.text('Fresh Vegetables'), findsOneWidget);
      expect(find.text('Grains & Staples'), findsOneWidget);
    });

    testWidgets('selecting a category from catalog select button navigates to CategoryProductsScreen', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      // Tap catalog select button to open options dropdown
      await tester.tap(find.byKey(const Key('catalog_select_button')));
      await tester.pumpAndSettle();

      // Options dropdown should display wholesale categories
      expect(find.text('Wholesale Categories'), findsOneWidget);
      expect(find.byKey(const Key('category_option_fresh_fruits')), findsOneWidget);
      expect(find.byKey(const Key('category_option_fresh_vegetables')), findsOneWidget);
      expect(find.byKey(const Key('category_option_grains_&_staples')), findsOneWidget);

      // Tap 'Fresh Fruits' option
      await tester.tap(find.byKey(const Key('category_option_fresh_fruits')));
      await tester.pumpAndSettle();

      // Verify navigation to CategoryProductsScreen
      expect(find.text('Fresh Fruits'), findsWidgets);
      expect(find.text('4 Wholesale Deals Available'), findsOneWidget);
      expect(find.text('Wholesale Fresh Fruits'), findsOneWidget);
      expect(find.text('Nagpur Oranges (1 kg)'), findsOneWidget);

      // Verify constrained width (maxWidth: 1200) with white space on both sides on 1440px viewport
      final contentFinder = find.byWidgetPredicate(
        (widget) => widget is ConstrainedBox && widget.constraints.maxWidth == 1200,
      );
      expect(contentFinder, findsWidgets);

      final contentRect = tester.getRect(contentFinder.first);
      // Container width should be at most 1200
      expect(contentRect.width, lessThanOrEqualTo(1200.0));
      // White spaces on left and right: (1440 - 1200) / 2 = 120px
      expect(contentRect.left, greaterThanOrEqualTo(100.0));
    });

    testWidgets('tapping a category card navigates to CategoryProductsScreen with 4-card desktop layout', (tester) async {
      configureViewport(tester, size: const Size(1440, 900));
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      // Tap Fresh Vegetables card
      await tester.tap(find.byKey(const Key('category_card_fresh_vegetables')));
      await tester.pumpAndSettle();

      // Verify CategoryProductsScreen
      expect(find.text('Fresh Vegetables'), findsWidgets);
      expect(find.text('4 Wholesale Deals Available'), findsOneWidget);
      expect(find.text('Wholesale Fresh Vegetables'), findsOneWidget);
      expect(find.text('Munshiganj Diamond Potatoes (20 kg sack)'), findsOneWidget);

      // Verify GridView with crossAxisCount = 4
      final gridFinder = find.byType(GridView);
      expect(gridFinder, findsOneWidget);
      final gridView = tester.widget<GridView>(gridFinder);
      final delegate = gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
      expect(delegate.crossAxisCount, equals(4));
    });
  });
}
