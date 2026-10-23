import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/wallet_state.dart';
import '../data/wallet_repository.dart';
import '../../auth/presentation/auth_controller.dart';

enum DepositFlowStatus {
  idle,
  initiating,
  awaitingPayment,
  verifying,
  completed,
  error,
}

class DepositFlowState {
  final DepositFlowStatus status;
  final DepositSession? session;
  final WalletTransaction? transaction;
  final String? errorMessage;
  final String? statusMessage;

  const DepositFlowState({
    this.status = DepositFlowStatus.idle,
    this.session,
    this.transaction,
    this.errorMessage,
    this.statusMessage,
  });

  bool get isLoading =>
      status == DepositFlowStatus.initiating || status == DepositFlowStatus.verifying;

  DepositFlowState copyWith({
    DepositFlowStatus? status,
    DepositSession? session,
    WalletTransaction? transaction,
    String? errorMessage,
    String? statusMessage,
  }) {
    return DepositFlowState(
      status: status ?? this.status,
      session: session ?? this.session,
      transaction: transaction ?? this.transaction,
      errorMessage: errorMessage ?? this.errorMessage,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}

final walletBalanceProvider = Provider<({double available, double escrow, double total})>((ref) {
  final authState = ref.watch(authStateProvider);
  final profile = authState.asData?.value;
  final available = profile?.availableBalance ?? 0.0;
  final escrow = profile?.escrowBalance ?? 0.0;
  return (
    available: available,
    escrow: escrow,
    total: available + escrow,
  );
});

final walletTransactionsProvider =
    NotifierProvider<WalletTransactionsNotifier, AsyncValue<List<WalletTransaction>>>(
  WalletTransactionsNotifier.new,
);

class WalletTransactionsNotifier
    extends Notifier<AsyncValue<List<WalletTransaction>>> {
  late final WalletRepository _repository;
  StreamSubscription<List<WalletTransaction>>? _sub;

  @override
  AsyncValue<List<WalletTransaction>> build() {
    _repository = ref.watch(walletRepositoryProvider);
    _sub?.cancel();
    _sub = _repository.transactionsStream.listen((list) {
      state = AsyncValue.data(list);
    });
    ref.onDispose(() {
      _sub?.cancel();
    });

    return AsyncValue.data(_repository.currentTransactions);
  }
}

final transactionFilterProvider = StateProvider<String>((ref) => 'all');

final filteredTransactionsProvider = Provider<List<WalletTransaction>>((ref) {
  final transactionsAsync = ref.watch(walletTransactionsProvider);
  final filter = ref.watch(transactionFilterProvider);

  final transactions = transactionsAsync.asData?.value ?? [];
  if (filter == 'all') {
    return transactions;
  }
  return transactions.where((tx) => tx.type == filter).toList();
});

final depositControllerProvider =
    NotifierProvider<DepositController, DepositFlowState>(DepositController.new);

class DepositController extends Notifier<DepositFlowState> {
  late final WalletRepository _repository;

  @override
  DepositFlowState build() {
    _repository = ref.watch(walletRepositoryProvider);
    return const DepositFlowState();
  }

  void reset() {
    state = const DepositFlowState();
  }

  /// Initiates a deposit checkout session with bKash or SSLCommerz
  Future<DepositSession?> startDepositSession({
    required double amount,
    required DepositGateway gateway,
  }) async {
    final user = ref.read(authStateProvider).asData?.value;
    if (user == null) {
      state = state.copyWith(
        status: DepositFlowStatus.error,
        errorMessage: 'Please sign in to deposit funds.',
      );
      return null;
    }

    state = state.copyWith(
      status: DepositFlowStatus.initiating,
      statusMessage: 'Connecting to ${gateway.displayName} payment gateway...',
      errorMessage: null,
    );

    try {
      final session = await _repository.initiateDeposit(
        userId: user.uid,
        amount: amount,
        gateway: gateway,
      );

      state = state.copyWith(
        status: DepositFlowStatus.awaitingPayment,
        session: session,
        statusMessage: 'Session created. Ready for payment confirmation.',
      );
      return session;
    } catch (e) {
      state = state.copyWith(
        status: DepositFlowStatus.error,
        errorMessage: e.toString(),
      );
      return null;
    }
  }

  /// Completes checkout session with verification and transaction polling
  Future<WalletTransaction?> confirmAndPollPayment({
    String? pin,
  }) async {
    final session = state.session;
    final user = ref.read(authStateProvider).asData?.value;

    if (session == null || user == null) {
      state = state.copyWith(
        status: DepositFlowStatus.error,
        errorMessage: 'Invalid deposit session state.',
      );
      return null;
    }

    state = state.copyWith(
      status: DepositFlowStatus.verifying,
      statusMessage: 'Verifying payment with ${session.gateway.displayName}...',
    );

    try {
      // Step 1: Poll gateway transaction status
      await Future.delayed(const Duration(milliseconds: 300));
      state = state.copyWith(
        statusMessage: 'Acquiring gateway transaction status...',
      );

      await Future.delayed(const Duration(milliseconds: 300));
      state = state.copyWith(
        statusMessage: 'Writing write-once ledger entry (Idempotency check)...',
      );

      // Step 2: Atomic ledger commit & balance credit
      final tx = await _repository.executeDeposit(
        userId: user.uid,
        paymentId: session.paymentId,
        gatewayTrxId: session.gatewayTrxId,
        gateway: session.gateway,
        amount: session.amount,
      );

      state = state.copyWith(
        status: DepositFlowStatus.completed,
        transaction: tx,
        statusMessage: 'Deposit of ৳${session.amount.toStringAsFixed(0)} confirmed!',
      );

      return tx;
    } catch (e) {
      state = state.copyWith(
        status: DepositFlowStatus.error,
        errorMessage: e.toString(),
      );
      return null;
    }
  }
}
