import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/wallet_state.dart';

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  return MockWalletRepository(authRepository: authRepo);
});

abstract class WalletRepository {
  List<WalletTransaction> get currentTransactions;
  Stream<List<WalletTransaction>> get transactionsStream;
  Future<List<WalletTransaction>> getTransactions(String userId);
  Future<DepositSession> initiateDeposit({
    required String userId,
    required double amount,
    required DepositGateway gateway,
    String? callbackUrl,
  });
  Future<WalletTransaction> executeDeposit({
    required String userId,
    required String paymentId,
    required String gatewayTrxId,
    required DepositGateway gateway,
    required double amount,
  });
  Future<bool> simulateIpnWebhook({
    required String gatewayTrxId,
    required String userId,
    required double amount,
    required DepositGateway gateway,
    String? referenceId,
  });
  Future<WalletTransaction> recordOrderHold({
    required String userId,
    required String orderId,
    required double amount,
    String? listingId,
    int? bucketNumber,
  });
  Future<WalletTransaction> recordOrderSettle({
    required String userId,
    required String orderId,
    required double amount,
    String? listingId,
    int? bucketNumber,
  });
  Future<WalletTransaction> recordOrderRefund({
    required String userId,
    required String orderId,
    required double amount,
    String? listingId,
    int? bucketNumber,
  });
}

class MockWalletRepository implements WalletRepository {
  final AuthRepository authRepository;
  final Duration simulatedDelay;

  final StreamController<List<WalletTransaction>> _transactionsController =
      StreamController<List<WalletTransaction>>.broadcast();

  // Write-once ledger indexed by gatewayTrxId
  final Map<String, WalletTransaction> _ledger = {};

  MockWalletRepository({
    required this.authRepository,
    this.simulatedDelay = const Duration(milliseconds: 300),
    List<WalletTransaction>? initialTransactions,
  }) {
    final seed = initialTransactions ?? _defaultSeedTransactions;
    for (final tx in seed) {
      _ledger[tx.trxId] = tx;
    }
  }

  static List<WalletTransaction> get _defaultSeedTransactions => [
        WalletTransaction(
          trxId: 'trx_bkash_91823',
          userId: 'user_dev_01',
          type: 'top_up',
          amount: 10000.0,
          status: 'completed',
          gateway: 'bkash',
          referenceId: 'bkash_pay_01',
          createdAt: DateTime.now().subtract(const Duration(hours: 8)),
        ),
        WalletTransaction(
          trxId: 'trx_hold_81726',
          userId: 'user_dev_01',
          type: 'order_hold',
          amount: -1800.0,
          status: 'completed',
          gateway: 'internal',
          orderId: 'ord_orange_001',
          createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        ),
        WalletTransaction(
          trxId: 'trx_settle_71625',
          userId: 'user_dev_01',
          type: 'order_settle',
          amount: 1800.0,
          status: 'completed',
          gateway: 'internal',
          orderId: 'ord_orange_001',
          createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        ),
        WalletTransaction(
          trxId: 'trx_ref_61524',
          userId: 'user_dev_01',
          type: 'order_refund',
          amount: 1200.0,
          status: 'completed',
          gateway: 'internal',
          orderId: 'ord_rice_002',
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        ),
      ];

  @override
  List<WalletTransaction> get currentTransactions => _sortedTransactions;

  @override
  Stream<List<WalletTransaction>> get transactionsStream {
    // Emit current snapshot on listen
    Future.microtask(() {
      if (!_transactionsController.isClosed) {
        _transactionsController.add(_sortedTransactions);
      }
    });
    return _transactionsController.stream;
  }

  List<WalletTransaction> get _sortedTransactions {
    final list = _ledger.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(list);
  }

  @override
  Future<List<WalletTransaction>> getTransactions(String userId) async {
    if (simulatedDelay > Duration.zero) {
      await Future.delayed(simulatedDelay);
    }
    return _sortedTransactions;
  }

  @override
  Future<DepositSession> initiateDeposit({
    required String userId,
    required double amount,
    required DepositGateway gateway,
    String? callbackUrl,
  }) async {
    if (simulatedDelay > Duration.zero) {
      await Future.delayed(simulatedDelay);
    }
    if (amount < 10) {
      throw ArgumentError('Minimum deposit amount is 10 BDT.');
    }
    if (amount > 100000) {
      throw ArgumentError('Maximum deposit amount is 100,000 BDT.');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final randomSuffix = (now % 100000).toString().padLeft(5, '0');

    if (gateway == DepositGateway.bkash) {
      final paymentId = 'bkash_pay_$randomSuffix';
      final trxId = 'trx_bkash_$randomSuffix';
      return DepositSession(
        paymentId: paymentId,
        gateway: gateway,
        amount: amount,
        redirectUrl: 'https://checkout.sandbox.bka.sh/v1.2.0-beta?paymentID=$paymentId',
        gatewayTrxId: trxId,
        createdAt: DateTime.now(),
      );
    } else {
      final tranId = 'ssl_tran_$randomSuffix';
      final valId = 'val_ssl_$randomSuffix';
      return DepositSession(
        paymentId: tranId,
        gateway: gateway,
        amount: amount,
        redirectUrl: 'https://sandbox.sslcommerz.com/gwprocess/v4/gw.php?tran_id=$tranId',
        gatewayTrxId: valId,
        createdAt: DateTime.now(),
      );
    }
  }

  @override
  Future<WalletTransaction> executeDeposit({
    required String userId,
    required String paymentId,
    required String gatewayTrxId,
    required DepositGateway gateway,
    required double amount,
  }) async {
    if (simulatedDelay > Duration.zero) {
      await Future.delayed(simulatedDelay);
    }

    // IDEMPOTENCY CHECK: Write-once ledger verification
    if (_ledger.containsKey(gatewayTrxId)) {
      // Duplicate transaction: return existing without double-crediting
      return _ledger[gatewayTrxId]!;
    }

    final newTransaction = WalletTransaction(
      trxId: gatewayTrxId,
      userId: userId,
      type: 'top_up',
      amount: amount,
      status: 'completed',
      gateway: gateway.name,
      referenceId: paymentId,
      createdAt: DateTime.now(),
    );

    _ledger[gatewayTrxId] = newTransaction;

    // Atomically increment user available balance
    authRepository.updateBalances(
      uid: userId,
      availableBalanceDelta: amount,
    );

    _transactionsController.add(_sortedTransactions);
    return newTransaction;
  }

  @override
  Future<WalletTransaction> recordOrderHold({
    required String userId,
    required String orderId,
    required double amount,
    String? listingId,
    int? bucketNumber,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final randomSuffix = (now % 100000).toString().padLeft(5, '0');
    final trxId = 'trx_hold_$randomSuffix';

    final transaction = WalletTransaction(
      trxId: trxId,
      userId: userId,
      type: 'order_hold',
      amount: -amount.abs(),
      status: 'completed',
      gateway: 'internal',
      orderId: orderId,
      createdAt: DateTime.now(),
    );

    _ledger[trxId] = transaction;
    _transactionsController.add(_sortedTransactions);
    return transaction;
  }

  @override
  Future<WalletTransaction> recordOrderSettle({
    required String userId,
    required String orderId,
    required double amount,
    String? listingId,
    int? bucketNumber,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final randomSuffix = (now % 100000).toString().padLeft(5, '0');
    final trxId = 'trx_settle_$randomSuffix';

    final transaction = WalletTransaction(
      trxId: trxId,
      userId: userId,
      type: 'order_settle',
      amount: amount.abs(),
      status: 'completed',
      gateway: 'internal',
      orderId: orderId,
      createdAt: DateTime.now(),
    );

    _ledger[trxId] = transaction;
    _transactionsController.add(_sortedTransactions);
    return transaction;
  }

  @override
  Future<WalletTransaction> recordOrderRefund({
    required String userId,
    required String orderId,
    required double amount,
    String? listingId,
    int? bucketNumber,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final randomSuffix = (now % 100000).toString().padLeft(5, '0');
    final trxId = 'trx_ref_$randomSuffix';

    final transaction = WalletTransaction(
      trxId: trxId,
      userId: userId,
      type: 'order_refund',
      amount: amount.abs(),
      status: 'completed',
      gateway: 'internal',
      orderId: orderId,
      createdAt: DateTime.now(),
    );

    _ledger[trxId] = transaction;
    _transactionsController.add(_sortedTransactions);
    return transaction;
  }

  @override
  Future<bool> simulateIpnWebhook({
    required String gatewayTrxId,
    required String userId,
    required double amount,
    required DepositGateway gateway,
    String? referenceId,
  }) async {
    if (_ledger.containsKey(gatewayTrxId)) {
      // Idempotency: duplicate IPN rejected with false (not credited again)
      return false;
    }

    await executeDeposit(
      userId: userId,
      paymentId: referenceId ?? gatewayTrxId,
      gatewayTrxId: gatewayTrxId,
      gateway: gateway,
      amount: amount,
    );
    return true;
  }
}
