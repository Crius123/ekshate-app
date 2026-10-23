import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ekshate_app/features/auth/data/auth_repository.dart';
import 'package:ekshate_app/features/wallet/data/wallet_repository.dart';
import 'package:ekshate_app/features/wallet/domain/wallet_state.dart';
import 'package:ekshate_app/features/wallet/presentation/wallet_controller.dart';

void main() {
  late MockAuthRepository mockAuthRepo;
  late MockWalletRepository mockWalletRepo;
  late ProviderContainer container;

  setUp(() {
    mockAuthRepo = MockAuthRepository(
      simulatedDelay: Duration.zero,
    );
    mockWalletRepo = MockWalletRepository(
      authRepository: mockAuthRepo,
      simulatedDelay: Duration.zero,
    );

    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockAuthRepo),
        walletRepositoryProvider.overrideWithValue(mockWalletRepo),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('WalletController & Providers Tests', () {
    test('walletBalanceProvider computes available, escrow, and total balance correctly', () {
      final balance = container.read(walletBalanceProvider);

      expect(balance.available, equals(8500.0));
      expect(balance.escrow, equals(1800.0));
      expect(balance.total, equals(10300.0));
    });

    test('filteredTransactionsProvider filters ledger entries by category', () async {
      // Allow initial stream emission
      await Future.delayed(Duration.zero);

      final all = container.read(filteredTransactionsProvider);
      expect(all.length, equals(4));

      // Filter by deposits (top_up)
      container.read(transactionFilterProvider.notifier).state = 'top_up';
      final deposits = container.read(filteredTransactionsProvider);
      expect(deposits.length, equals(1));
      expect(deposits.first.type, equals('top_up'));

      // Filter by holds
      container.read(transactionFilterProvider.notifier).state = 'order_hold';
      final holds = container.read(filteredTransactionsProvider);
      expect(holds.length, equals(1));
      expect(holds.first.type, equals('order_hold'));

      // Filter by refunds
      container.read(transactionFilterProvider.notifier).state = 'order_refund';
      final refunds = container.read(filteredTransactionsProvider);
      expect(refunds.length, equals(1));
      expect(refunds.first.type, equals('order_refund'));
    });

    test('DepositController starts checkout session and completes payment polling', () async {
      final controller = container.read(depositControllerProvider.notifier);

      // 1. Start Session
      final session = await controller.startDepositSession(
        amount: 1500,
        gateway: DepositGateway.bkash,
      );

      expect(session, isNotNull);
      expect(session!.amount, equals(1500));
      expect(container.read(depositControllerProvider).status, equals(DepositFlowStatus.awaitingPayment));

      // 2. Confirm and Poll Payment
      final tx = await controller.confirmAndPollPayment(pin: '12345');

      expect(tx, isNotNull);
      expect(tx!.amount, equals(1500));
      expect(tx.gateway, equals('bkash'));
      expect(container.read(depositControllerProvider).status, equals(DepositFlowStatus.completed));

      // Verify wallet balance updated
      final updatedBalance = container.read(walletBalanceProvider);
      expect(updatedBalance.available, equals(8500.0 + 1500.0));
    });
  });
}
