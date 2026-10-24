import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:ekshate_app/features/notifications/data/notifications_repository.dart';
import 'package:ekshate_app/features/notifications/presentation/widgets/notification_bell_button.dart';
import 'package:ekshate_app/features/notifications/presentation/notifications_screen.dart';
import 'package:ekshate_app/features/auth/domain/user_profile.dart';
import 'package:ekshate_app/features/auth/data/auth_repository.dart';
import 'package:ekshate_app/core/router/route_paths.dart';

void main() {
  late MockAuthRepository mockAuthRepo;
  late MockNotificationsRepository mockNotifsRepo;

  setUp(() {
    mockAuthRepo = MockAuthRepository(
      initialUser: const UserProfile(
        uid: 'user_dev_01',
        phoneNumber: '+8801711000001',
        displayName: 'Sheikh Buyer',
      ),
      simulatedDelay: Duration.zero,
    );

    mockNotifsRepo = MockNotificationsRepository(
      authRepository: mockAuthRepo,
      simulatedDelay: Duration.zero,
    );
  });

  testWidgets('NotificationBellButton displays unread badge and opens ShadSelect on current page', (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            appBar: null,
            body: Center(child: NotificationBellButton()),
          ),
        ),
        GoRoute(
          path: RoutePaths.notifications,
          builder: (context, state) => const NotificationsScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepo),
          notificationsRepositoryProvider.overrideWithValue(mockNotifsRepo),
        ],
        child: ShadApp.router(
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify NotificationBellButton renders with unread count badge (2 from seed)
    expect(find.byType(NotificationBellButton), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    // Tap bell button to open ShadSelect dropdown in-place
    await tester.tap(find.byType(NotificationBellButton));
    await tester.pumpAndSettle();

    // Stays on the current page (does NOT navigate to NotificationsScreen)
    expect(find.byType(NotificationsScreen), findsNothing);

    // Shows notifications header inside the dropdown select
    expect(find.text('Notifications'), findsOneWidget);
    expect(find.text('2 new'), findsOneWidget);
    expect(find.text('Mark all as read'), findsOneWidget);
  });
}
