import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ekshate_app/features/auth/data/auth_repository.dart';
import 'package:ekshate_app/features/auth/domain/user_profile.dart';
import 'package:ekshate_app/features/admin/data/admin_repository.dart';
import 'package:ekshate_app/features/admin/presentation/admin_screen.dart';
import 'package:ekshate_app/features/admin/presentation/widgets/overview_monitor_tab.dart';
import 'package:ekshate_app/features/admin/presentation/widgets/daily_deal_scheduler_tab.dart';
import 'package:ekshate_app/features/admin/presentation/widgets/withdrawal_payouts_tab.dart';

void main() {
  late MockAuthRepository mockAuthRepo;
  late MockAdminRepository mockAdminRepo;

  setUp(() {
    mockAuthRepo = MockAuthRepository(
      initialUser: const UserProfile(
        uid: 'admin_dev_01',
        phoneNumber: '+8801711999999',
        displayName: 'Operations Admin',
        role: 'admin',
        availableBalance: 250000.0,
      ),
    );
    mockAdminRepo = MockAdminRepository(authRepository: mockAuthRepo);
  });

  tearDown(() {
    mockAdminRepo.dispose();
  });

  void configureViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Widget createSubject() {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuthRepo),
        adminRepositoryProvider.overrideWithValue(mockAdminRepo),
      ],
      child: const ShadApp(
        home: ScaffoldMessenger(
          child: AdminScreen(),
        ),
      ),
    );
  }

  group('AdminScreen Widget Tests', () {
    testWidgets('renders AdminScreen tabs and Overview monitor by default', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      expect(find.text('Admin Console'), findsOneWidget);
      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byType(OverviewMonitorTab), findsOneWidget);

      // Financial KPI metrics
      expect(find.text("Today's GMV"), findsOneWidget);
      expect(find.text('৳148500'), findsOneWidget);
      expect(find.text('Escrow Volume'), findsOneWidget);
      expect(find.text('৳34200'), findsOneWidget);

      // Momentum Gauge
      expect(find.text('Campaign Quota Completion Gauge'), findsOneWidget);
      expect(find.text('79.0% Completed'), findsOneWidget);

      // Override buttons
      expect(find.byKey(const Key('emergency_settlement_button')), findsOneWidget);
      expect(find.byKey(const Key('manual_dispatch_button')), findsOneWidget);

      // Bucket Momentum item
      expect(find.text('Organic Sonali Chicken'), findsOneWidget);
      expect(find.text('Bucket #1'), findsWidgets);
    });

    testWidgets('triggers Emergency Settlement confirmation modal and performs settlement', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      final settlementBtn = find.byKey(const Key('emergency_settlement_button'));
      expect(settlementBtn, findsOneWidget);
      await tester.tap(settlementBtn);
      await tester.pumpAndSettle();

      // Verify modal dialog
      expect(find.text('Emergency Campaign Settlement'), findsOneWidget);
      final confirmBtn = find.byKey(const Key('confirm_settlement_action_button'));
      expect(confirmBtn, findsOneWidget);

      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Settlement completes and displays confirmation snackbar
      expect(find.textContaining('settlement complete'), findsOneWidget);
    });

    testWidgets('triggers Manual Courier Dispatch confirmation modal and dispatches orders', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      final dispatchBtn = find.byKey(const Key('manual_dispatch_button'));
      expect(dispatchBtn, findsOneWidget);
      await tester.tap(dispatchBtn);
      await tester.pumpAndSettle();

      // Verify modal dialog
      expect(find.text('Manual Courier Dispatch'), findsOneWidget);
      final confirmBtn = find.byKey(const Key('confirm_dispatch_action_button'));
      expect(confirmBtn, findsOneWidget);

      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Dispatch completes and displays confirmation snackbar
      expect(find.textContaining('Dispatched 12 orders'), findsOneWidget);
    });

    testWidgets('Scheduler Tab dynamically computes savings and provisions listing', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      // Switch to Deal Scheduler tab
      final schedulerTab = find.byKey(const Key('tab_deal_scheduler'));
      await tester.tap(schedulerTab);
      await tester.pumpAndSettle();

      expect(find.byType(DailyDealSchedulerTab), findsOneWidget);

      // Enter Benchmark Price 320 and Bulk Price 240
      final marketPriceField = find.byKey(const Key('deal_market_price_input'));
      final unitPriceField = find.byKey(const Key('deal_unit_price_input'));

      await tester.enterText(marketPriceField, '320');
      await tester.enterText(unitPriceField, '240');
      await tester.pumpAndSettle();

      // Verify dynamically computed discount badge: 25.0% OFF • Saves ৳80/kg
      expect(find.textContaining('25.0% OFF • Saves ৳80/kg'), findsOneWidget);

      // Fill remaining required fields
      final titleField = find.byKey(const Key('deal_title_input'));
      final moqField = find.byKey(const Key('deal_moq_input'));

      await tester.enterText(titleField, 'Deshi Moshur Dal');
      await tester.enterText(moqField, '60');
      await tester.pumpAndSettle();

      // Submit Form
      final submitBtn = find.byKey(const Key('schedule_deal_submit_button'));
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Success snackbar displayed
      expect(find.textContaining('Successfully scheduled "Deshi Moshur Dal" with Bucket #1!'), findsOneWidget);
    });

    testWidgets('Withdrawals Tab renders requests and approves pending withdrawal', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      // Switch to Withdrawals tab
      final withdrawalsTab = find.byKey(const Key('tab_withdrawal_payouts'));
      await tester.tap(withdrawalsTab);
      await tester.pumpAndSettle();

      expect(find.byType(WithdrawalPayoutsTab), findsOneWidget);

      // Verify pending request is displayed (wreq_101 for ৳1500)
      expect(find.text('৳1500'), findsOneWidget);
      expect(find.text('bKash'), findsWidgets);

      // Tap Approve & Payout button
      final approveBtn = find.byKey(const Key('approve_button_wreq_101'));
      expect(approveBtn, findsOneWidget);
      await tester.tap(approveBtn);
      await tester.pumpAndSettle();

      // Confirmation modal
      expect(find.text('Approve Withdrawal & Disburse'), findsOneWidget);
      final confirmApproveBtn = find.byKey(const Key('confirm_approve_payout_button'));
      expect(confirmApproveBtn, findsOneWidget);

      await tester.tap(confirmApproveBtn);
      await tester.pumpAndSettle();

      // Success snackbar displayed
      expect(find.textContaining('Payout for ৳1500 approved and ledger recorded!'), findsOneWidget);
    });

    testWidgets('Withdrawals Tab rejects pending withdrawal with reason', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createSubject());
      await tester.pumpAndSettle();

      final withdrawalsTab = find.byKey(const Key('tab_withdrawal_payouts'));
      await tester.tap(withdrawalsTab);
      await tester.pumpAndSettle();

      final rejectBtn = find.byKey(const Key('reject_button_wreq_102'));
      expect(rejectBtn, findsOneWidget);
      await tester.tap(rejectBtn);
      await tester.pumpAndSettle();

      // Rejection dialog
      expect(find.text('Reject Withdrawal Request'), findsOneWidget);
      final reasonField = find.byKey(const Key('rejection_reason_input'));
      expect(reasonField, findsOneWidget);

      await tester.enterText(reasonField, 'Bank account number invalid');
      await tester.pumpAndSettle();

      final confirmRejectBtn = find.byKey(const Key('confirm_reject_button'));
      await tester.tap(confirmRejectBtn);
      await tester.pumpAndSettle();

      expect(find.text('Withdrawal request rejected.'), findsOneWidget);
    });
  });
}
