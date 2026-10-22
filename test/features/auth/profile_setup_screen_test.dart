import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:ekshate_app/core/router/route_paths.dart';
import 'package:ekshate_app/features/auth/data/auth_repository.dart';
import 'package:ekshate_app/features/auth/presentation/profile_setup_screen.dart';
import 'package:ekshate_app/features/auth/domain/user_profile.dart';

void main() {
  late MockAuthRepository mockRepo;

  Widget createSubject({
    required UserProfile initialUser,
  }) {
    mockRepo = MockAuthRepository(
      defaultOtp: '123456',
      simulatedDelay: Duration.zero,
      initialUser: initialUser,
    );

    final router = GoRouter(
      initialLocation: RoutePaths.profileSetup,
      routes: [
        GoRoute(
          path: RoutePaths.profileSetup,
          builder: (context, state) => const ProfileSetupScreen(),
        ),
        GoRoute(
          path: RoutePaths.dailySale,
          builder: (context, state) => const Scaffold(body: Text('Daily Sale Screen')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockRepo),
      ],
      child: ShadApp.router(
        routerConfig: router,
      ),
    );
  }

  group('ProfileSetupScreen Widget Tests', () {
    testWidgets('renders profile setup card with structured address inputs', (tester) async {
      final user = UserProfile.initialCustomer(
        uid: 'user_onboarding_01',
        phoneNumber: '+8801711000001',
      );

      await tester.pumpWidget(createSubject(initialUser: user));
      await tester.pumpAndSettle();

      expect(find.text('Delivery Profile'), findsOneWidget);
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Street / House / Flat'), findsOneWidget);
      expect(find.text('Area / Neighborhood'), findsOneWidget);
      expect(find.text('City'), findsOneWidget);
      expect(find.text('Save & Continue'), findsOneWidget);
    });

    testWidgets('shows validation errors when required fields are empty', (tester) async {
      final user = UserProfile.initialCustomer(
        uid: 'user_onboarding_02',
        phoneNumber: '+8801711000001',
      );

      await tester.pumpWidget(createSubject(initialUser: user));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save & Continue'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Full name is required'), findsOneWidget);
    });

    testWidgets('submits complete profile and navigates to Daily Sale screen', (tester) async {
      final user = UserProfile.initialCustomer(
        uid: 'user_onboarding_03',
        phoneNumber: '+8801711000001',
      );

      await tester.pumpWidget(createSubject(initialUser: user));
      await tester.pumpAndSettle();

      // Enter Full Name
      final inputs = find.byType(ShadInput);
      // inputs: 0: Full Name, 1: Street, 2: Area, 3: City
      await tester.enterText(inputs.at(0), 'Tariqul Islam');
      await tester.enterText(inputs.at(1), 'House 14, Road 7, Flat 2B');
      await tester.enterText(inputs.at(2), 'Dhanmondi');
      await tester.enterText(inputs.at(3), 'Dhaka');
      await tester.pump();

      await tester.tap(find.text('Save & Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Daily Sale Screen'), findsOneWidget);
      expect(mockRepo.currentUser?.displayName, equals('Tariqul Islam'));
      expect(
        mockRepo.currentUser?.deliveryAddress,
        equals('House 14, Road 7, Flat 2B, Dhanmondi, Dhaka'),
      );
      expect(mockRepo.currentUser?.isProfileComplete, isTrue);
    });

    testWidgets('displays error boundary contextual message when submission fails', (tester) async {
      final user = UserProfile.initialCustomer(
        uid: 'user_onboarding_04',
        phoneNumber: '+8801711000001',
      );

      await tester.pumpWidget(createSubject(initialUser: user));
      await tester.pumpAndSettle();

      mockRepo.simulateNetworkTimeout = true;

      final inputs = find.byType(ShadInput);
      await tester.enterText(inputs.at(0), 'Tariqul Islam');
      await tester.enterText(inputs.at(1), 'House 14, Road 7');
      await tester.enterText(inputs.at(2), 'Dhanmondi');
      await tester.pump();

      await tester.tap(find.text('Save & Continue'));
      await tester.pumpAndSettle();

      expect(find.textContaining('timed out'), findsOneWidget);
    });
  });
}
