class WalletTransaction {
  final String trxId;
  final String userId;
  final String type; // 'top_up' | 'order_hold' | 'order_settle' | 'order_refund'
  final double amount;
  final String status;
  final String? orderId;
  final DateTime createdAt;

  const WalletTransaction({
    required this.trxId,
    required this.userId,
    required this.type,
    required this.amount,
    required this.status,
    this.orderId,
    required this.createdAt,
  });

  bool get isCredit => amount > 0;
}
