import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ekshate_app/core/router/route_paths.dart';
import 'package:ekshate_app/features/daily_sale/presentation/daily_sale_screen.dart';
import 'package:ekshate_app/features/daily_sale/presentation/category_products_screen.dart';
import 'package:ekshate_app/features/daily_sale/presentation/daily_sale_controller.dart';

void main() {
  void configureViewport(WidgetTester tester, {Size size = const Size(800, 1600)}) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Widget createTestApp() {
    final router = GoRouter(
      initialLocation: RoutePaths.dailySale,
      routes: [
        GoRoute(
          path: RoutePaths.dailySale,
          builder: (context, state) => const DailySaleScreen(),
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
      overrides: [
        campaignClockProvider.overrideWithValue(() => DateTime(2026, 10, 22, 14, 0, 0)),
      ],
      child: ShadApp.router(
        routerConfig: router,
      ),
    );
  }

  group('Category Rows & CategoryProductsScreen Tests', () {
    testWidgets('renders three horizontal category rows with Top Selling products and View All buttons', (tester) async {
      configureViewport(tester, size: const Size(800, 2400));
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Check category section titles
      expect(find.text('Fresh Fruits'), findsWidgets);
      expect(find.text('Grains & Staples'), findsWidgets);
      expect(find.text('Fresh Vegetables'), findsWidgets);

      // Check View All buttons
      expect(find.byKey(const Key('view_all_btn_fresh_fruits')), findsOneWidget);
      expect(find.byKey(const Key('view_all_btn_grains_&_staples')), findsOneWidget);
      expect(find.byKey(const Key('view_all_btn_fresh_vegetables')), findsOneWidget);

      // Verify top-selling products in each line
      expect(find.text('Nagpur Oranges (1 kg)'), findsOneWidget);
      expect(find.text('Miniket Premium Rice (25 kg bag)'), findsOneWidget);
      expect(find.text('Munshiganj Diamond Potatoes (20 kg sack)'), findsOneWidget);
    });

    testWidgets('tapping "View All" on Fresh Fruits row navigates to CategoryProductsScreen', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Tap View All on Fresh Fruits
      final viewAllBtn = find.byKey(const Key('view_all_btn_fresh_fruits'));
      await tester.tap(viewAllBtn);
      await tester.pumpAndSettle();

      // Category screen displayed
      expect(find.text('Fresh Fruits'), findsWidgets);
      expect(find.text('4 Wholesale Deals Available'), findsOneWidget);
      expect(find.text('Wholesale Fresh Fruits'), findsOneWidget);
      expect(find.text('Nagpur Oranges (1 kg)'), findsOneWidget);
      expect(find.text('Rajshahi Himsagar Mangoes (10 kg crate)'), findsOneWidget);
    });

    testWidgets('tapping "View All" on Fresh Vegetables row navigates to CategoryProductsScreen', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createTestApp());
      await tester.pumpAndSettle();

      // Scroll down to Fresh Vegetables View All button using vertical scrollable
      final viewAllBtn = find.byKey(const Key('view_all_btn_fresh_vegetables'));
      await tester.scrollUntilVisible(
        viewAllBtn,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(viewAllBtn);
      await tester.pumpAndSettle();

      // Category screen displayed
      expect(find.text('Fresh Vegetables'), findsWidgets);
      expect(find.text('4 Wholesale Deals Available'), findsOneWidget);
      expect(find.text('Wholesale Fresh Vegetables'), findsOneWidget);
      expect(find.text('Munshiganj Diamond Potatoes (20 kg sack)'), findsOneWidget);
      expect(find.text('Faridpur Red Onions (10 kg mesh)'), findsOneWidget);
    });
  });
}
