import 'package:flutter_test/flutter_test.dart';
import 'package:ekshate_app/features/auth/data/auth_repository.dart';
import 'package:ekshate_app/features/wallet/data/wallet_repository.dart';
import 'package:ekshate_app/features/wallet/domain/wallet_state.dart';

void main() {
  late MockAuthRepository mockAuthRepo;
  late MockWalletRepository walletRepo;

  setUp(() {
    mockAuthRepo = MockAuthRepository(
      simulatedDelay: Duration.zero,
    );
    walletRepo = MockWalletRepository(
      authRepository: mockAuthRepo,
      simulatedDelay: Duration.zero,
    );
  });

  group('MockWalletRepository Ledger & Idempotency Tests', () {
    test('initial transactions stream emits default seed records', () async {
      final transactions = await walletRepo.getTransactions('user_dev_01');

      expect(transactions.length, equals(4));
      // Verifies presence of all 4 categorized ledger entries
      final types = transactions.map((t) => t.type).toSet();
      expect(types, containsAll(['top_up', 'order_hold', 'order_settle', 'order_refund']));
    });

    test('initiateDeposit generates valid session for bKash and SSLCommerz', () async {
      final bkashSession = await walletRepo.initiateDeposit(
        userId: 'user_dev_01',
        amount: 1500,
        gateway: DepositGateway.bkash,
      );

      expect(bkashSession.gateway, equals(DepositGateway.bkash));
      expect(bkashSession.amount, equals(1500));
      expect(bkashSession.paymentId, startsWith('bkash_pay_'));
      expect(bkashSession.redirectUrl, contains('checkout.sandbox.bka.sh'));

      final sslSession = await walletRepo.initiateDeposit(
        userId: 'user_dev_01',
        amount: 2500,
        gateway: DepositGateway.sslcommerz,
      );

      expect(sslSession.gateway, equals(DepositGateway.sslcommerz));
      expect(sslSession.amount, equals(2500));
      expect(sslSession.paymentId, startsWith('ssl_tran_'));
      expect(sslSession.redirectUrl, contains('sandbox.sslcommerz.com'));
    });

    test('initiateDeposit rejects amounts below 10 BDT', () async {
      expect(
        () => walletRepo.initiateDeposit(
          userId: 'user_dev_01',
          amount: 5,
          gateway: DepositGateway.bkash,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('executeDeposit atomically records ledger entry and increments available_balance', () async {
      final initialBalance = mockAuthRepo.currentUser!.availableBalance;

      final tx = await walletRepo.executeDeposit(
        userId: 'user_dev_01',
        paymentId: 'pay_test_01',
        gatewayTrxId: 'trx_bkash_unique_101',
        gateway: DepositGateway.bkash,
        amount: 2000,
      );

      expect(tx.trxId, equals('trx_bkash_unique_101'));
      expect(tx.amount, equals(2000));
      expect(tx.type, equals('top_up'));
      expect(tx.gateway, equals('bkash'));

      // Check user available_balance incremented
      final updatedBalance = mockAuthRepo.currentUser!.availableBalance;
      expect(updatedBalance, equals(initialBalance + 2000));

      // Check transactions stream updated
      final updatedList = await walletRepo.getTransactions('user_dev_01');
      expect(updatedList.first.trxId, equals('trx_bkash_unique_101'));
    });

    test('Idempotency Guard: repeated executeDeposit with same gatewayTrxId produces zero duplicate credits', () async {
      final initialBalance = mockAuthRepo.currentUser!.availableBalance;

      // First execution
      await walletRepo.executeDeposit(
        userId: 'user_dev_01',
        paymentId: 'pay_dup_01',
        gatewayTrxId: 'val_ssl_duplicate_key',
        gateway: DepositGateway.sslcommerz,
        amount: 3000,
      );

      expect(mockAuthRepo.currentUser!.availableBalance, equals(initialBalance + 3000));

      // Second execution (same gatewayTrxId e.g. duplicate webhook callback)
      final duplicateTx = await walletRepo.executeDeposit(
        userId: 'user_dev_01',
        paymentId: 'pay_dup_01',
        gatewayTrxId: 'val_ssl_duplicate_key',
        gateway: DepositGateway.sslcommerz,
        amount: 3000,
      );

      expect(duplicateTx.trxId, equals('val_ssl_duplicate_key'));
      // Balance must NOT increment a second time!
      expect(
        mockAuthRepo.currentUser!.availableBalance,
        equals(initialBalance + 3000),
        reason: 'Duplicate transaction must not credit user available balance twice',
      );
    });

    test('simulateIpnWebhook returns false when duplicate callback is received', () async {
      final firstResult = await walletRepo.simulateIpnWebhook(
        gatewayTrxId: 'ipn_trx_555',
        userId: 'user_dev_01',
        amount: 500,
        gateway: DepositGateway.sslcommerz,
      );
      expect(firstResult, isTrue);

      final secondResult = await walletRepo.simulateIpnWebhook(
        gatewayTrxId: 'ipn_trx_555',
        userId: 'user_dev_01',
        amount: 500,
        gateway: DepositGateway.sslcommerz,
      );
      expect(secondResult, isFalse);
    });
  });
}
