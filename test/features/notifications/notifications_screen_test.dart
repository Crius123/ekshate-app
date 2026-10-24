import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ekshate_app/features/notifications/data/notifications_repository.dart';
import 'package:ekshate_app/features/notifications/presentation/notifications_screen.dart';
import 'package:ekshate_app/features/auth/domain/user_profile.dart';
import 'package:ekshate_app/features/auth/data/auth_repository.dart';

void main() {
  late MockAuthRepository mockAuthRepo;
  late MockNotificationsRepository mockNotifsRepo;

  void configureViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

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

  Widget createTestWidget({List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuthRepo),
        notificationsRepositoryProvider.overrideWithValue(mockNotifsRepo),
        ...overrides,
      ],
      child: const ShadApp(
        home: NotificationsScreen(),
      ),
    );
  }

  group('NotificationsScreen Widget & Interaction Tests', () {
    testWidgets('renders app bar with title, unread counter badge, mark all read, and preferences actions', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('2 new'), findsOneWidget);
      expect(find.byTooltip('Mark all as read'), findsOneWidget);
      expect(find.byTooltip('Push Preferences'), findsOneWidget);
    });

    testWidgets('renders all 4 filter tabs and lists notification cards', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('All'), findsOneWidget);
      expect(find.text('Orders'), findsOneWidget);
      expect(find.text('Wallet'), findsOneWidget);
      expect(find.text('Community Drops'), findsOneWidget);

      // Verify seed notification titles appear
      expect(find.text('🔥 Almost Unlocked!'), findsOneWidget);
      expect(find.text('🎉 MOQ Target Met!'), findsOneWidget);
      expect(find.text('🚚 Dispatched via PATHAO!'), findsOneWidget);
      expect(find.text('💸 100% Refund Returned!'), findsOneWidget);
    });

    testWidgets('filtering by tabs updates the displayed list accurately', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // 1. Tap Orders tab
      await tester.tap(find.text('Orders'));
      await tester.pumpAndSettle();

      expect(find.text('🎉 MOQ Target Met!'), findsOneWidget);
      expect(find.text('🚚 Dispatched via PATHAO!'), findsOneWidget);
      expect(find.text('💸 100% Refund Returned!'), findsNothing);
      expect(find.text('🔥 Almost Unlocked!'), findsNothing);

      // 2. Tap Wallet tab
      await tester.tap(find.text('Wallet'));
      await tester.pumpAndSettle();

      expect(find.text('💸 100% Refund Returned!'), findsOneWidget);
      expect(find.text('🎉 MOQ Target Met!'), findsNothing);
      expect(find.text('🔥 Almost Unlocked!'), findsNothing);

      // 3. Tap Community Drops tab
      await tester.tap(find.text('Community Drops'));
      await tester.pumpAndSettle();

      expect(find.text('🔥 Almost Unlocked!'), findsOneWidget);
      expect(find.text('💸 100% Refund Returned!'), findsNothing);
    });

    testWidgets('tapping Mark all as read updates unread counter and dismisses new badge', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('2 new'), findsOneWidget);

      // Tap Mark All As Read action button
      await tester.tap(find.byTooltip('Mark all as read'));
      await tester.pumpAndSettle();

      // New badge disappears
      expect(find.text('2 new'), findsNothing);
    });

    testWidgets('tapping Push Preferences button opens bottom sheet modal with functional switches', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap Push Preferences action
      await tester.tap(find.byTooltip('Push Preferences'));
      await tester.pumpAndSettle();

      expect(find.text('Push Preferences'), findsWidgets);
      expect(find.text('Order & Courier Tracking'), findsOneWidget);
      expect(find.text('Wallet & Payment Receipts'), findsOneWidget);
      expect(find.text('Community Urgency Drops'), findsOneWidget);

      // Verify switches exist and are interactive
      final switches = find.byType(ShadSwitch);
      expect(switches, findsNWidgets(3));

      // Tap Save & Close
      await tester.tap(find.text('Save & Close'));
      await tester.pumpAndSettle();

      expect(find.text('Order & Courier Tracking'), findsNothing);
    });

    testWidgets('renders empty state view when category has zero notifications', (tester) async {
      configureViewport(tester);
      // Empty repository
      final emptyRepo = MockNotificationsRepository(
        authRepository: mockAuthRepo,
        initialItems: [],
        simulatedDelay: Duration.zero,
      );

      await tester.pumpWidget(createTestWidget(overrides: [
        notificationsRepositoryProvider.overrideWithValue(emptyRepo),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('All Caught Up!'), findsOneWidget);
      expect(find.text('You have no notifications right now.'), findsOneWidget);

      // Tap Orders tab
      await tester.tap(find.text('Orders'));
      await tester.pumpAndSettle();

      expect(find.text('No Order Updates'), findsOneWidget);
    });
  });
}
