import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ekshate_app/features/auth/data/auth_repository.dart';
import 'package:ekshate_app/features/wallet/data/wallet_repository.dart';
import 'package:ekshate_app/features/wallet/presentation/wallet_screen.dart';
import 'package:ekshate_app/features/wallet/presentation/widgets/deposit_modal.dart';
import 'package:ekshate_app/features/wallet/presentation/widgets/bkash_checkout_dialog.dart';
import 'package:ekshate_app/features/wallet/presentation/widgets/sslcommerz_checkout_dialog.dart';

void main() {
  late MockAuthRepository mockAuthRepo;
  late MockWalletRepository mockWalletRepo;

  void configureViewport(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Widget createTestWidget({List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuthRepo),
        walletRepositoryProvider.overrideWithValue(mockWalletRepo),
        ...overrides,
      ],
      child: const ShadApp(
        home: WalletScreen(),
      ),
    );
  }

  setUp(() {
    mockAuthRepo = MockAuthRepository(simulatedDelay: Duration.zero);
    mockWalletRepo = MockWalletRepository(
      authRepository: mockAuthRepo,
      simulatedDelay: Duration.zero,
    );
  });

  group('WalletScreen Widget Tests', () {
    testWidgets('renders dual-balance cards for Available (emerald) and Escrow (amber)', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check header
      expect(find.text('Wallet & Escrow'), findsOneWidget);

      // Check Available Balance Card
      expect(find.text('Available Balance'), findsOneWidget);
      expect(find.text('৳8500'), findsOneWidget);
      expect(find.text('Free for orders & withdraw'), findsOneWidget);

      // Check Escrow Balance Card
      expect(find.text('Escrow Balance'), findsOneWidget);
      expect(find.text('৳1800'), findsOneWidget);
      expect(find.text('Locked in active batch deals'), findsOneWidget);
    });

    testWidgets('renders customer profile information and sign out action', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Sheikh Buyer'), findsOneWidget);
      expect(find.textContaining('House 12, Road 5, Dhanmondi, Dhaka'), findsOneWidget);
      expect(find.text('Edit Address'), findsOneWidget);
    });

    testWidgets('renders deposit action card with bKash and SSLCommerz options', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Deposit Funds'), findsOneWidget);
      expect(find.text('bKash Top-up'), findsOneWidget);
      expect(find.text('SSLCommerz'), findsOneWidget);
      expect(find.text('Instant • Zero Fee'), findsOneWidget);
    });

    testWidgets('renders categorized transaction audit ledger with copyable transaction IDs', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Transaction Audit Ledger'), findsOneWidget);

      // All 4 categories rendered
      expect(find.text('Deposit (BKASH)'), findsOneWidget);
      expect(find.text('Batch Order Escrow'), findsOneWidget);
      expect(find.text('Batch Order Settled'), findsOneWidget);
      expect(find.text('Failed Bucket Refund'), findsOneWidget);

      // Check formatted amounts
      expect(find.text('+৳10000'), findsOneWidget);
      expect(find.text('-৳1800'), findsOneWidget);
      expect(find.text('৳1800'), findsOneWidget);
      expect(find.text('+৳1200'), findsOneWidget);

      // TrxIDs rendered
      expect(find.textContaining('TrxID: trx_bkash_91823'), findsOneWidget);
      expect(find.textContaining('TrxID: trx_hold_81726'), findsOneWidget);

      // Copy icon buttons exist
      expect(find.byIcon(LucideIcons.copy), findsWidgets);
    });

    testWidgets('filters transaction ledger when filter chips are tapped', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap 'Deposits' filter
      await tester.tap(find.text('Deposits'));
      await tester.pumpAndSettle();

      expect(find.text('Deposit (BKASH)'), findsOneWidget);
      expect(find.text('Batch Order Escrow'), findsNothing);
      expect(find.text('Batch Order Settled'), findsNothing);
      expect(find.text('Failed Bucket Refund'), findsNothing);

      // Tap 'Escrow Holds' filter
      await tester.tap(find.text('Escrow Holds'));
      await tester.pumpAndSettle();

      expect(find.text('Deposit (BKASH)'), findsNothing);
      expect(find.text('Batch Order Escrow'), findsOneWidget);

      // Tap 'Refunds' filter
      await tester.tap(find.text('Refunds'));
      await tester.pumpAndSettle();

      expect(find.text('Failed Bucket Refund'), findsOneWidget);

      // Reset to 'All'
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();

      expect(find.text('Deposit (BKASH)'), findsOneWidget);
      expect(find.text('Failed Bucket Refund'), findsOneWidget);
    });

    testWidgets('tapping bKash Top-up opens DepositModal and triggers bKash Tokenized Checkout flow', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap bKash Top-up button
      await tester.tap(find.text('bKash Top-up'));
      await tester.pumpAndSettle();

      // DepositModal appears
      expect(find.byType(DepositModal), findsOneWidget);
      expect(find.text('Deposit Amount (BDT)'), findsOneWidget);
      expect(find.text('bKash Tokenized'), findsWidgets);

      // Tap +৳2500 quick chip
      await tester.tap(find.text('+৳2500'));
      await tester.pumpAndSettle();

      // Tap Proceed button
      await tester.tap(find.text('Proceed'));
      await tester.pumpAndSettle();

      // BkashCheckoutDialog appears
      expect(find.byType(BkashCheckoutDialog), findsOneWidget);
      expect(find.text('bKash Tokenized'), findsOneWidget);
      expect(find.text('৳2500'), findsOneWidget);
      expect(find.text('Enter bKash Account PIN'), findsOneWidget);

      // Confirm Payment
      await tester.tap(find.text('Confirm'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      // Success view appears
      expect(find.text('Deposit Successful!'), findsOneWidget);
      expect(find.text('৳2500 credited to Available Balance'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Back to Wallet'));
      await tester.pumpAndSettle();

      // Verify Available Balance updated on screen
      expect(find.text('৳11000'), findsOneWidget); // 8500 + 2500
    });

    testWidgets('tapping SSLCommerz opens DepositModal and triggers SSLCommerz hosted payment flow', (tester) async {
      configureViewport(tester);
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap SSLCommerz button
      await tester.tap(find.text('SSLCommerz').first);
      await tester.pumpAndSettle();

      // DepositModal appears with SSLCommerz selected
      expect(find.byType(DepositModal), findsOneWidget);

      // Tap Proceed button
      await tester.tap(find.text('Proceed'));
      await tester.pumpAndSettle();

      // SslcommerzCheckoutDialog appears
      expect(find.byType(SslcommerzCheckoutDialog), findsOneWidget);
      expect(find.text('SSLCommerz Gateway'), findsOneWidget);
      expect(find.text('৳1000'), findsOneWidget);

      // Simulate IPN Pay
      await tester.tap(find.text('Confirm'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpAndSettle();

      // Success confirmation
      expect(find.text('Payment & IPN Verified!'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Back to Wallet'));
      await tester.pumpAndSettle();

      // Verify Available Balance updated on screen
      expect(find.text('৳9500'), findsOneWidget); // 8500 + 1000
    });
  });
}
