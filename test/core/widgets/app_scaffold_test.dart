import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ekshate_app/core/router/route_paths.dart';
import 'package:ekshate_app/core/widgets/app_scaffold.dart';
import 'package:ekshate_app/features/auth/data/auth_repository.dart';
import 'package:ekshate_app/features/auth/domain/user_profile.dart';
import 'package:ekshate_app/features/wallet/data/wallet_repository.dart';

void main() {
  late MockAuthRepository mockAuthRepo;
  late MockWalletRepository mockWalletRepo;

  setUp(() {
    mockAuthRepo = MockAuthRepository(
      initialUser: const UserProfile(
        uid: 'user_01',
        phoneNumber: '+8801711000001',
        displayName: 'Amina Begum',
        role: 'customer',
        availableBalance: 3200.0,
        escrowBalance: 800.0,
      ),
    );
    mockWalletRepo = MockWalletRepository(authRepository: mockAuthRepo);
  });

  Widget buildTestApp({required WidgetTester tester, required Size viewportSize}) {
    tester.view.physicalSize = viewportSize;
    tester.view.devicePixelRatio = 1.0;

    final router = GoRouter(
      initialLocation: RoutePaths.dailySale,
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppScaffold(child: child),
          routes: [
            GoRoute(
              path: RoutePaths.dailySale,
              builder: (context, state) => const Scaffold(body: Text('Daily Deals Content')),
            ),
            GoRoute(
              path: RoutePaths.catalog,
              builder: (context, state) => const Scaffold(body: Text('Catalog Content')),
            ),
          ],
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuthRepo),
        walletRepositoryProvider.overrideWithValue(mockWalletRepo),
      ],
      child: ShadApp.router(
        routerConfig: router,
      ),
    );
  }

  group('AdaptiveLayout & AppScaffold Tests', () {
    testWidgets('Smartphone viewport (< 900px) renders bottom NavigationBar and hides Web Header',
        (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestApp(
          tester: tester,
          viewportSize: const Size(400, 800), // Mobile portrait
        ),
      );
      await tester.pumpAndSettle();

      // Mobile bottom navigation bar is present
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Daily Sale'), findsOneWidget);
      expect(find.text('Catalog'), findsOneWidget);
      expect(find.text('Batch Cart'), findsOneWidget);
      expect(find.text('Orders'), findsOneWidget);
      expect(find.text('Wallet'), findsOneWidget);

      // Desktop web header elements are NOT rendered
      expect(find.text('Wholesale Grocery Co-Op'), findsNothing);
      expect(find.text('Available: ৳3200'), findsNothing);
    });

    testWidgets('Desktop viewport (>= 900px) renders Web Navigation Header and hides bottom NavigationBar',
        (tester) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestApp(
          tester: tester,
          viewportSize: const Size(1200, 800), // Desktop widescreen
        ),
      );
      await tester.pumpAndSettle();

      // Bottom NavigationBar is removed on desktop web
      expect(find.byType(NavigationBar), findsNothing);

      // Web header brand and elements are rendered
      expect(find.text('Ekshate'), findsOneWidget);
      expect(find.text('একসাথে'), findsNothing);
      expect(find.text('Available: ৳3200'), findsOneWidget);
      expect(find.text('Amina Begum'), findsOneWidget);
      expect(find.text('Daily Sale'), findsNothing);
      expect(find.text('Catalog'), findsOneWidget);

      // Clicking Profile Select displays options: View Orders, Manage My Account, Sign Out
      await tester.tap(find.text('Amina Begum'));
      await tester.pumpAndSettle();
      expect(find.text('View Orders'), findsOneWidget);
      expect(find.text('Manage My Account'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);

      // Dismiss dropdown and click Catalog in web header
      await tester.tap(find.text('Amina Begum'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Catalog'));
      await tester.pumpAndSettle();
      expect(find.text('Catalog Content'), findsOneWidget);
    });
  });
}
