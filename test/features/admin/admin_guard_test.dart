import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ekshate_app/core/router/app_router.dart';
import 'package:ekshate_app/core/router/route_paths.dart';
import 'package:ekshate_app/features/auth/data/auth_repository.dart';
import 'package:ekshate_app/features/auth/domain/user_profile.dart';
import 'package:ekshate_app/features/admin/data/admin_repository.dart';
import 'package:ekshate_app/features/admin/presentation/admin_screen.dart';

void main() {
  testWidgets('GoRouter role guard redirects customer away from /admin', (tester) async {
    final mockAuthRepo = MockAuthRepository(
      initialUser: const UserProfile(
        uid: 'cust_01',
        phoneNumber: '+8801711000001',
        displayName: 'Sheikh Buyer',
        role: 'customer',
        availableBalance: 5000.0,
      ),
    );

    final mockAdminRepo = MockAdminRepository(authRepository: mockAuthRepo);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepo),
          adminRepositoryProvider.overrideWithValue(mockAdminRepo),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            final router = ref.watch(appRouterProvider);
            return ShadApp.router(
              routerConfig: router,
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify initial route is DailySale
    expect(find.byType(AdminScreen), findsNothing);

    // Attempt to navigate to /admin as a customer
    final container = ProviderScope.containerOf(tester.element(find.byType(ShadApp)));
    final router = container.read(appRouterProvider);
    router.go(RoutePaths.admin);
    await tester.pumpAndSettle();

    // Guard should redirect to RoutePaths.dailySale, so AdminScreen is NOT displayed
    expect(find.byType(AdminScreen), findsNothing);
  });

  testWidgets('GoRouter role guard allows users with role == admin to access /admin', (tester) async {
    final mockAuthRepo = MockAuthRepository(
      initialUser: const UserProfile(
        uid: 'admin_01',
        phoneNumber: '+8801711999999',
        displayName: 'Operations Admin',
        role: 'admin',
        availableBalance: 250000.0,
      ),
    );

    final mockAdminRepo = MockAdminRepository(authRepository: mockAuthRepo);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepo),
          adminRepositoryProvider.overrideWithValue(mockAdminRepo),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            final router = ref.watch(appRouterProvider);
            return ShadApp.router(
              routerConfig: router,
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Navigate to /admin as an admin
    final container = ProviderScope.containerOf(tester.element(find.byType(ShadApp)));
    final router = container.read(appRouterProvider);
    router.go(RoutePaths.admin);
    await tester.pumpAndSettle();

    // AdminScreen is successfully displayed
    expect(find.byType(AdminScreen), findsOneWidget);
    expect(find.text('Admin Console'), findsOneWidget);
    expect(find.text('Campaign Momentum & Financial Review'), findsOneWidget);
  });

  testWidgets('Quick-switch in customer profile allows switching to admin role and entering dashboard', (tester) async {
    final mockAuthRepo = MockAuthRepository(
      initialUser: const UserProfile(
        uid: 'user_dev_01',
        phoneNumber: '+8801711000001',
        displayName: 'Sheikh Buyer',
        role: 'customer',
        availableBalance: 8500.0,
        escrowBalance: 1800.0,
      ),
    );

    final mockAdminRepo = MockAdminRepository(authRepository: mockAuthRepo);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepo),
          adminRepositoryProvider.overrideWithValue(mockAdminRepo),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            final router = ref.watch(appRouterProvider);
            return ShadApp.router(
              routerConfig: router,
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Navigate to wallet where the profile card lives
    final container = ProviderScope.containerOf(tester.element(find.byType(ShadApp)));
    final router = container.read(appRouterProvider);
    router.go(RoutePaths.wallet);
    await tester.pumpAndSettle();

    // Find the quick switch button
    final switchButton = find.byKey(const Key('quick_switch_role_button'));
    expect(switchButton, findsOneWidget);

    // Tap to switch to admin
    await tester.tap(switchButton);
    await tester.pumpAndSettle();

    // Role is updated to admin and user is navigated to AdminScreen
    expect(mockAuthRepo.currentUser?.role, 'admin');
    expect(find.byType(AdminScreen), findsOneWidget);
  });
}
