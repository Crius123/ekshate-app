import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:ekshate_app/core/router/route_paths.dart';
import 'package:ekshate_app/core/widgets/app_scaffold.dart';
import 'package:ekshate_app/features/auth/data/auth_repository.dart';
import 'package:ekshate_app/features/auth/presentation/login_screen.dart';
import 'package:ekshate_app/features/auth/presentation/profile_setup_screen.dart';
import 'package:ekshate_app/features/wallet/data/wallet_repository.dart';
import 'package:ekshate_app/features/wallet/presentation/wallet_screen.dart';
import 'package:ekshate_app/features/wallet/presentation/widgets/deposit_modal.dart';
import 'package:ekshate_app/features/wallet/presentation/widgets/bkash_checkout_dialog.dart';
import 'package:ekshate_app/features/daily_sale/presentation/daily_sale_screen.dart';
import 'package:ekshate_app/features/daily_sale/presentation/daily_sale_controller.dart';
import 'package:ekshate_app/features/catalog/presentation/catalog_screen.dart';
import 'package:ekshate_app/features/cart/presentation/cart_screen.dart';
import 'package:ekshate_app/features/checkout/presentation/checkout_screen.dart';
import 'package:ekshate_app/features/orders/presentation/orders_screen.dart';
import 'package:ekshate_app/features/orders/data/orders_repository.dart';
import 'package:ekshate_app/features/procurement/presentation/procurement_screen.dart';
import 'package:ekshate_app/features/notifications/presentation/notifications_screen.dart';
import 'package:ekshate_app/features/admin/presentation/admin_screen.dart';
import 'package:ekshate_app/features/admin/data/admin_repository.dart';
import 'package:ekshate_app/features/admin/presentation/widgets/overview_monitor_tab.dart';
import 'package:ekshate_app/features/admin/presentation/widgets/daily_deal_scheduler_tab.dart';
import 'package:ekshate_app/features/admin/presentation/widgets/withdrawal_payouts_tab.dart';

void main() {
  late MockAuthRepository mockAuthRepo;
  late MockWalletRepository mockWalletRepo;
  late MockOrdersRepository mockOrdersRepo;
  late MockAdminRepository mockAdminRepo;
  late GoRouter router;

  void configureViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Widget createSubject({String initialLocation = RoutePaths.login}) {
    router = GoRouter(
      initialLocation: initialLocation,
      redirect: (context, state) {
        if (state.uri.path.startsWith(RoutePaths.admin)) {
          if (mockAuthRepo.currentUser?.role != 'admin') {
            return RoutePaths.dailySale;
          }
        }
        return null;
      },
      routes: [
        ShellRoute(
          builder: (context, state, child) => AppScaffold(child: child),
          routes: [
            GoRoute(
              path: RoutePaths.dailySale,
              builder: (context, state) => const DailySaleScreen(),
            ),
            GoRoute(
              path: RoutePaths.catalog,
              builder: (context, state) => const CatalogScreen(),
            ),
            GoRoute(
              path: RoutePaths.cart,
              builder: (context, state) => const CartScreen(),
            ),
            GoRoute(
              path: RoutePaths.orders,
              builder: (context, state) => const OrdersScreen(),
            ),
            GoRoute(
              path: RoutePaths.wallet,
              builder: (context, state) => const WalletScreen(),
            ),
            GoRoute(
              path: RoutePaths.procurement,
              builder: (context, state) => const ProcurementScreen(),
            ),
          ],
        ),
        GoRoute(
          path: RoutePaths.login,
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: RoutePaths.checkout,
          builder: (context, state) => const CheckoutScreen(),
        ),
        GoRoute(
          path: RoutePaths.profileSetup,
          builder: (context, state) => const ProfileSetupScreen(),
        ),
        GoRoute(
          path: RoutePaths.notifications,
          builder: (context, state) => const NotificationsScreen(),
        ),
        GoRoute(
          path: RoutePaths.admin,
          builder: (context, state) => const ScaffoldMessenger(child: AdminScreen()),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuthRepo),
        walletRepositoryProvider.overrideWithValue(mockWalletRepo),
        ordersRepositoryProvider.overrideWithValue(mockOrdersRepo),
        adminRepositoryProvider.overrideWithValue(mockAdminRepo),
        campaignClockProvider.overrideWithValue(() => DateTime(2026, 10, 23, 14, 0, 0)),
      ],
      child: ShadApp.router(
        routerConfig: router,
      ),
    );
  }

  setUp(() {
    mockAuthRepo = MockAuthRepository(
      defaultOtp: '123456',
      simulatedDelay: Duration.zero,
      initialUser: null, // Start unauthenticated
    );

    mockWalletRepo = MockWalletRepository(
      authRepository: mockAuthRepo,
      simulatedDelay: Duration.zero,
    );

    mockOrdersRepo = MockOrdersRepository(
      authRepository: mockAuthRepo,
      walletRepository: mockWalletRepo,
      simulatedDelay: Duration.zero,
      initialOrders: [], // Empty initially for fresh lifecycle
    );

    mockAdminRepo = MockAdminRepository(
      authRepository: mockAuthRepo,
      walletRepository: mockWalletRepo,
      simulatedDelay: Duration.zero,
    );
  });

  group('Flutter Unified Acceptance & End-to-End Bulk Buying Lifecycle Suite', () {
    testWidgets(
      'executes full customer & operator lifecycle across auth, wallet, daily sale, cart, orders, and admin',
      (tester) async {
        configureViewport(tester);

        // =====================================================================
        // Phase 1: Customer Mobile OTP Authentication & Profile Setup
        // =====================================================================
        await tester.pumpWidget(createSubject(initialLocation: RoutePaths.login));
        await tester.pumpAndSettle();

        // 1. Verify Welcome & Phone Input UI
        expect(find.text('Welcome to Ekshate'), findsOneWidget);
        expect(find.text('Send Verification Code'), findsOneWidget);

        final phoneInput = find.byType(ShadInput);
        await tester.enterText(phoneInput, '01711000001');
        await tester.pump();

        // Tap Send Verification Code
        await tester.tap(find.text('Send Verification Code'));
        await tester.pumpAndSettle();

        // 2. Verify OTP Screen & Enter 6-digit SMS OTP
        expect(find.text('Enter 6-digit SMS OTP'), findsOneWidget);
        expect(find.textContaining('+880 1711-000001'), findsOneWidget);
        expect(find.text('Verify & Continue'), findsOneWidget);

        final otpInput = find.byType(ShadInput);
        await tester.enterText(otpInput, '123456');
        await tester.pump();

        await tester.tap(find.text('Verify & Continue'));
        await tester.pumpAndSettle();

        // 3. User is unprofiled -> Transitions to Delivery Profile Setup
        expect(find.text('Delivery Profile'), findsOneWidget);
        expect(find.text('Full Name'), findsOneWidget);
        expect(find.text('Street / House / Flat'), findsOneWidget);

        final profileInputs = find.byType(ShadInput);
        await tester.enterText(profileInputs.at(0), 'Sheikh Buyer');
        await tester.enterText(profileInputs.at(1), 'House 12, Road 5, Flat 4A');
        await tester.enterText(profileInputs.at(2), 'Dhanmondi');
        await tester.enterText(profileInputs.at(3), 'Dhaka');
        await tester.pump();

        await tester.tap(find.text('Save & Continue'));
        await tester.pumpAndSettle();

        // 4. Transitions to Daily Sale Home Screen
        expect(find.text('Daily Bulk Campaign'), findsOneWidget);
        expect(mockAuthRepo.currentUser?.displayName, equals('Sheikh Buyer'));
        expect(mockAuthRepo.currentUser?.isProfileComplete, isTrue);

        // =====================================================================
        // Phase 2: Digital Wallet Deposit via bKash Dialog & Available Balance
        // =====================================================================
        // Navigate to Wallet screen
        router.go(RoutePaths.wallet);
        await tester.pumpAndSettle();

        expect(find.text('My Wallet'), findsOneWidget);
        // Initial balance is 0 for newly onboarded user
        expect(find.text('৳0'), findsWidgets);

        // Tap bKash Top-up button
        await tester.tap(find.text('bKash Top-up'));
        await tester.pumpAndSettle();

        // DepositModal appears
        expect(find.byType(DepositModal), findsOneWidget);
        expect(find.text('Deposit Funds'), findsWidgets);

        // Select +৳2500 quick amount chip
        await tester.tap(find.text('+৳2500'));
        await tester.pumpAndSettle();

        // Tap Proceed to open bKash Tokenized Checkout Dialog
        await tester.tap(find.text('Proceed'));
        await tester.pumpAndSettle();

        expect(find.byType(BkashCheckoutDialog), findsOneWidget);
        expect(find.text('bKash Tokenized'), findsOneWidget);
        expect(find.text('Enter bKash Account PIN'), findsOneWidget);

        // Tap Confirm payment
        await tester.tap(find.text('Confirm'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pumpAndSettle();

        // Deposit success feedback
        expect(find.text('Deposit Successful!'), findsOneWidget);
        expect(find.textContaining('credited to Available Balance'), findsOneWidget);

        // Close dialog
        await tester.tap(find.text('Back to Wallet'));
        await tester.pumpAndSettle();

        // Available balance card updated to ৳2500
        expect(find.text('৳2500'), findsOneWidget);
        expect(mockAuthRepo.currentUser?.availableBalance, equals(2500.0));

        // =====================================================================
        // Phase 3: Daily Sale Browsing, Capacity Clamping & Batch Cart Reserve
        // =====================================================================
        // Navigate back to Daily Sale screen
        router.go(RoutePaths.dailySale);
        await tester.pumpAndSettle();

        expect(find.text('Active Wholesale Deals'), findsOneWidget);
        expect(find.text('Nagpur Oranges (1 kg)'), findsOneWidget);
        expect(find.text('৳180/kg'), findsOneWidget);
        expect(find.text('25% OFF'), findsOneWidget);

        // Capacity Quantity Selector: Tap plus button twice to select 3 kg
        final plusBtn = find.byKey(const Key('capacity_qty_plus')).first;
        await tester.tap(plusBtn);
        await tester.pumpAndSettle();
        await tester.tap(plusBtn);
        await tester.pumpAndSettle();

        expect(find.text('3 kg'), findsOneWidget);
        expect(find.text('৳540'), findsOneWidget);

        // Tap "Reserve Volume" button
        final reserveBtn = find.byKey(const Key('reserve_volume_btn_listing_orange_01'));
        await tester.ensureVisible(reserveBtn);
        await tester.tap(reserveBtn);
        await tester.pumpAndSettle();

        // Toast feedback displayed
        expect(find.text('Added to Batch Cart'), findsOneWidget);

        // =====================================================================
        // Phase 4: Batch Cart Checkout & Order Tracking Dashboard (PENDING ESCROW)
        // =====================================================================
        // Navigate to Batch Cart screen
        router.go(RoutePaths.cart);
        await tester.pumpAndSettle();

        expect(find.text('Batch Order Cart'), findsOneWidget);
        expect(find.text('Nagpur Oranges (1 kg)'), findsOneWidget);
        expect(find.text('3 kg'), findsOneWidget);
        expect(find.text('৳540'), findsWidgets);

        // Tap "Proceed to Checkout" button
        final proceedBtn = find.byKey(const Key('proceed_to_checkout_btn'));
        expect(proceedBtn, findsOneWidget);
        await tester.tap(proceedBtn);
        await tester.pumpAndSettle();

        // Now on Checkout Screen: Tap "Confirm & Place Order" button
        final confirmBtn = find.byKey(const Key('confirm_escrow_funds_btn'));
        expect(confirmBtn, findsOneWidget);
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        // Redirected to OrdersScreen
        expect(find.text('My Bulk Orders'), findsOneWidget);
        expect(find.text('PENDING'), findsOneWidget);
        expect(find.text('3 kg'), findsOneWidget);
        expect(find.text('৳540'), findsOneWidget);
        expect(find.text('Allocated Bucket #1'), findsOneWidget);
        expect(find.text('Payment is held safely until the group reaches its wholesale target.'), findsOneWidget);

        // User balances updated: 2500 - 540 = 1960 available, 540 escrow
        expect(mockAuthRepo.currentUser?.availableBalance, equals(1960.0));
        expect(mockAuthRepo.currentUser?.escrowBalance, equals(540.0));

        // =====================================================================
        // Phase 5: Campaign Settlement & Multi-Courier Last-Mile Dispatch Updates
        // =====================================================================
        // 1. Simulate Deal Confirmed (Bucket achieves MOQ)
        await mockOrdersRepo.simulateSettlement(
          campaignDate: '', // Applies to all pending orders
          targetMet: true,
        );
        await tester.pumpAndSettle();

        // Tap Confirmed Deals tab
        await tester.tap(find.text('Confirmed Deals'));
        await tester.pumpAndSettle();

        expect(find.text('CONFIRMED'), findsOneWidget);
        expect(find.text('Nagpur Oranges (1 kg)'), findsOneWidget);
        expect(find.text('Bucket met MOQ and order is queued for morning procurement.'), findsOneWidget);

        // Escrow captured
        expect(mockAuthRepo.currentUser?.escrowBalance, equals(0.0));

        // 2. Simulate Multi-Courier Last-Mile Dispatch (Pathao)
        await mockOrdersRepo.simulateDispatch(
          campaignDate: '',
          courierPartner: 'pathao',
        );
        await tester.pumpAndSettle();

        // Tap Dispatched tab
        await tester.tap(find.text('Dispatched (In Transit)'));
        await tester.pumpAndSettle();

        expect(find.text('DISPATCHED'), findsOneWidget);
        expect(find.text('Pathao Courier'), findsOneWidget);
        expect(find.textContaining('PTH-TRK-'), findsOneWidget);
        expect(find.text('Weight: 3.0 kg'), findsOneWidget);

        // =====================================================================
        // Phase 6: Admin Dashboard Access, Deal Scheduler & Withdrawal Review
        // =====================================================================
        // Elevate user role to admin
        mockAuthRepo.switchRole('admin');
        expect(mockAuthRepo.currentUser?.role, equals('admin'));

        // Navigate to /admin
        router.go(RoutePaths.admin);
        await tester.pumpAndSettle();

        // Admin Console rendered with Overview Monitor
        expect(find.text('Admin Console'), findsOneWidget);
        expect(find.byType(OverviewMonitorTab), findsOneWidget);
        expect(find.text("Today's GMV"), findsOneWidget);
        expect(find.text('Escrow Volume'), findsOneWidget);
        expect(find.text('Campaign Quota Completion Gauge'), findsOneWidget);
        expect(find.byKey(const Key('emergency_settlement_button')), findsOneWidget);
        expect(find.byKey(const Key('manual_dispatch_button')), findsOneWidget);

        // 1. Deal Scheduler Form Submission
        await tester.tap(find.byKey(const Key('tab_deal_scheduler')));
        await tester.pumpAndSettle();

        expect(find.byType(DailyDealSchedulerTab), findsOneWidget);

        // Enter Benchmark Price 280 and Bulk Price 210
        await tester.enterText(find.byKey(const Key('deal_market_price_input')), '280');
        await tester.enterText(find.byKey(const Key('deal_unit_price_input')), '210');
        await tester.pumpAndSettle();

        // Dynamic discount computation verification: 25.0% OFF • Saves ৳70/kg
        expect(find.textContaining('25.0% OFF • Saves ৳70/kg'), findsOneWidget);

        // Enter Title and MOQ
        await tester.enterText(find.byKey(const Key('deal_title_input')), 'Fresh Rajshahi Mangoes');
        await tester.enterText(find.byKey(const Key('deal_moq_input')), '50');
        await tester.pumpAndSettle();

        // Submit form
        await tester.tap(find.byKey(const Key('schedule_deal_submit_button')));
        await tester.pumpAndSettle();

        // Snackbar confirmation
        expect(
          find.textContaining('Successfully scheduled "Fresh Rajshahi Mangoes" with Bucket #1!'),
          findsOneWidget,
        );

        // Advance past deal scheduler snackbar
        await tester.pump(const Duration(seconds: 4));
        await tester.pumpAndSettle();

        // 2. Withdrawal Payout Review
        await tester.tap(find.byKey(const Key('tab_withdrawal_payouts')));
        await tester.pumpAndSettle();

        expect(find.byType(WithdrawalPayoutsTab), findsOneWidget);
        expect(find.text('৳1500'), findsOneWidget);
        expect(find.text('bKash'), findsWidgets);

        // Approve pending withdrawal
        final approveBtn = find.byKey(const Key('approve_button_wreq_101'));
        await tester.tap(approveBtn);
        await tester.pumpAndSettle();

        expect(find.text('Approve Withdrawal & Disburse'), findsOneWidget);
        await tester.tap(find.byKey(const Key('confirm_approve_payout_button')));
        await tester.pumpAndSettle();

        // Success notification
        expect(find.textContaining('Payout for ৳1500 approved and ledger recorded!'), findsOneWidget);
      },
    );
  });
}
