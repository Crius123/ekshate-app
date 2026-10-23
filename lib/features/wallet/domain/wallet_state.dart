enum DepositGateway {
  bkash,
  sslcommerz;

  String get displayName {
    switch (this) {
      case DepositGateway.bkash:
        return 'bKash Tokenized';
      case DepositGateway.sslcommerz:
        return 'SSLCommerz';
    }
  }
}

class DepositSession {
  final String paymentId;
  final DepositGateway gateway;
  final double amount;
  final String redirectUrl;
  final String gatewayTrxId;
  final String status; // 'initiated' | 'processing' | 'completed' | 'failed'
  final DateTime createdAt;

  const DepositSession({
    required this.paymentId,
    required this.gateway,
    required this.amount,
    required this.redirectUrl,
    required this.gatewayTrxId,
    this.status = 'initiated',
    required this.createdAt,
  });

  DepositSession copyWith({
    String? paymentId,
    DepositGateway? gateway,
    double? amount,
    String? redirectUrl,
    String? gatewayTrxId,
    String? status,
    DateTime? createdAt,
  }) {
    return DepositSession(
      paymentId: paymentId ?? this.paymentId,
      gateway: gateway ?? this.gateway,
      amount: amount ?? this.amount,
      redirectUrl: redirectUrl ?? this.redirectUrl,
      gatewayTrxId: gatewayTrxId ?? this.gatewayTrxId,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class WalletTransaction {
  final String trxId;
  final String userId;
  final String type; // 'top_up' | 'order_hold' | 'order_settle' | 'order_refund'
  final double amount;
  final String status;
  final String? gateway; // 'bkash' | 'sslcommerz' | 'internal'
  final String? orderId;
  final String? referenceId;
  final DateTime createdAt;

  const WalletTransaction({
    required this.trxId,
    required this.userId,
    required this.type,
    required this.amount,
    required this.status,
    this.gateway,
    this.orderId,
    this.referenceId,
    required this.createdAt,
  });

  bool get isCredit => amount > 0;

  String get typeLabel {
    switch (type) {
      case 'top_up':
        return gateway != null && gateway!.isNotEmpty
            ? 'Deposit (${gateway!.toUpperCase()})'
            : 'Deposit';
      case 'order_hold':
        return 'Batch Order Escrow';
      case 'order_settle':
        return 'Batch Order Settled';
      case 'order_refund':
        return 'Failed Bucket Refund';
      default:
        return type.replaceAll('_', ' ').toUpperCase();
    }
  }

  String get formattedAmount {
    if (amount < 0 || type == 'order_hold') {
      return '-৳${amount.abs().toStringAsFixed(0)}';
    }
    final prefix = isCredit ? '+' : '';
    return '$prefix৳${amount.abs().toStringAsFixed(0)}';
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'trx_id': trxId,
      'user_id': userId,
      'type': type,
      'amount': amount,
      'status': status,
      if (gateway != null) 'gateway': gateway,
      if (orderId != null) 'order_id': orderId,
      if (referenceId != null) 'reference_id': referenceId,
      'created_at': createdAt,
    };
  }

  factory WalletTransaction.fromFirestore(Map<String, dynamic> data, String id) {
    DateTime parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      try {
        return (value as dynamic).toDate() as DateTime;
      } catch (_) {
        return DateTime.now();
      }
    }

    return WalletTransaction(
      trxId: (data['trx_id'] as String?) ?? id,
      userId: (data['user_id'] as String?) ?? '',
      type: (data['type'] as String?) ?? 'top_up',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      status: (data['status'] as String?) ?? 'completed',
      gateway: data['gateway'] as String?,
      orderId: data['order_id'] as String?,
      referenceId: data['reference_id'] as String?,
      createdAt: parseDate(data['created_at']),
    );
  }
}
