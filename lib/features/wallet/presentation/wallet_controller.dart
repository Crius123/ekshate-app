import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/wallet_state.dart';
import '../../auth/presentation/auth_controller.dart';

final walletTransactionsProvider = StateProvider<List<WalletTransaction>>((ref) {
  return [
    WalletTransaction(
      trxId: 'trx_bkash_91823',
      userId: 'user_dev_01',
      type: 'top_up',
      amount: 10000.0,
      status: 'completed',
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
    ),
    WalletTransaction(
      trxId: 'trx_hold_81726',
      userId: 'user_dev_01',
      type: 'order_hold',
      amount: -1800.0,
      status: 'completed',
      orderId: 'ord_orange_001',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
  ];
});

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
