import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:ekshate_app/core/router/route_paths.dart';
import 'package:ekshate_app/features/auth/data/auth_repository.dart';
import 'package:ekshate_app/features/auth/presentation/login_screen.dart';
import 'package:ekshate_app/features/auth/domain/user_profile.dart';

void main() {
  late MockAuthRepository mockRepo;

  Widget createSubject({
    String initialLocation = RoutePaths.login,
    List<RouteBase>? extraRoutes,
  }) {
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: RoutePaths.login,
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: RoutePaths.profileSetup,
          builder: (context, state) => const Scaffold(body: Text('Profile Setup Screen')),
        ),
        GoRoute(
          path: RoutePaths.dailySale,
          builder: (context, state) => const Scaffold(body: Text('Daily Sale Screen')),
        ),
        ...?extraRoutes,
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

  setUp(() {
    mockRepo = MockAuthRepository(
      defaultOtp: '123456',
      simulatedDelay: Duration.zero,
      initialUser: null,
    );
  });

  group('LoginScreen Widget Tests', () {
    testWidgets('renders phone number input and welcome card', (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      expect(find.text('Welcome to Ekshate'), findsOneWidget);
      expect(find.text('+88'), findsOneWidget);
      expect(find.text('Send Verification Code'), findsOneWidget);
    });

    testWidgets('shows validation error when invalid Bangladeshi number is entered', (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      final phoneInput = find.byType(ShadInput);
      await tester.enterText(phoneInput, '01211000000'); // 012 is invalid prefix
      await tester.pump();

      await tester.tap(find.text('Send Verification Code'));
      await tester.pumpAndSettle();

      expect(find.textContaining('valid Bangladeshi mobile number'), findsOneWidget);
      // OTP view should not be shown
      expect(find.text('Enter 6-digit SMS OTP'), findsNothing);
    });

    testWidgets('transitions to OTP screen with countdown timer on valid phone number', (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      final phoneInput = find.byType(ShadInput);
      await tester.enterText(phoneInput, '01711000001');
      await tester.pump();

      await tester.tap(find.text('Send Verification Code'));
      await tester.pumpAndSettle();

      expect(find.text('Enter 6-digit SMS OTP'), findsOneWidget);
      expect(find.textContaining('+880 1711-000001'), findsOneWidget);
      expect(find.textContaining('Resend code in'), findsOneWidget);
      expect(find.text('Verify & Continue'), findsOneWidget);
    });

    testWidgets('displays error boundary contextual banner when invalid OTP is entered', (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      // Enter valid phone
      await tester.enterText(find.byType(ShadInput), '01711000001');
      await tester.tap(find.text('Send Verification Code'));
      await tester.pumpAndSettle();

      // Enter wrong OTP
      await tester.enterText(find.byType(ShadInput), '999999');
      await tester.tap(find.text('Verify & Continue'));
      await tester.pumpAndSettle();

      expect(find.textContaining('invalid'), findsOneWidget);
    });

    testWidgets('displays expired OTP feedback and allows resend after countdown', (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(ShadInput), '01711000001');
      await tester.tap(find.text('Send Verification Code'));
      await tester.pumpAndSettle();

      // Expire OTP in repository
      mockRepo.expireOtp('01711000001');

      // Enter OTP
      await tester.enterText(find.byType(ShadInput), '123456');
      await tester.tap(find.text('Verify & Continue'));
      await tester.pumpAndSettle();

      expect(find.textContaining('expired'), findsOneWidget);

      // Advance timer by 65 seconds
      await tester.pump(const Duration(seconds: 65));
      await tester.pumpAndSettle();

      expect(find.text('Resend Code'), findsOneWidget);
      await tester.tap(find.text('Resend Code'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Resend code in'), findsOneWidget);
    });

    testWidgets('displays contextual error when network times out', (tester) async {
      mockRepo.simulateNetworkTimeout = true;

      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(ShadInput), '01711000001');
      await tester.tap(find.text('Send Verification Code'));
      await tester.pumpAndSettle();

      expect(find.textContaining('timed out'), findsOneWidget);
    });

    testWidgets('allows returning to phone edit view via Change Number', (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(ShadInput), '01711000001');
      await tester.tap(find.text('Send Verification Code'));
      await tester.pumpAndSettle();

      expect(find.text('Change Number'), findsOneWidget);
      await tester.tap(find.text('Change Number'));
      await tester.pumpAndSettle();

      expect(find.text('Send Verification Code'), findsOneWidget);
    });

    testWidgets('navigates to Profile Setup when new user verifies OTP', (tester) async {
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(ShadInput), '01711000001');
      await tester.tap(find.text('Send Verification Code'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(ShadInput), '123456');
      await tester.tap(find.text('Verify & Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Profile Setup Screen'), findsOneWidget);
    });

    testWidgets('navigates to Daily Sale when existing user with complete profile logs in', (tester) async {
      // Pre-seed completed user
      mockRepo.seedUser(
        const UserProfile(
          uid: 'usr_8801711000001',
          phoneNumber: '+8801711000001',
          displayName: 'Sheikh Buyer',
          deliveryAddress: 'House 12, Road 5, Dhanmondi, Dhaka',
          role: 'customer',
          availableBalance: 5000.0,
          escrowBalance: 0.0,
        ),
      );

      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(ShadInput), '01711000001');
      await tester.tap(find.text('Send Verification Code'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(ShadInput), '123456');
      await tester.tap(find.text('Verify & Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Daily Sale Screen'), findsOneWidget);
    });
  });
}
