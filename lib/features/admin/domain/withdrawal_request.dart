class WithdrawalRequest {
  final String id;
  final String userId;
  final double amount;
  final String payoutMethod; // 'bkash' | 'nagad' | 'bank'
  final String accountNumber;
  final String? bankName;
  final String? accountHolderName;
  final String status; // 'pending' | 'approved' | 'rejected'
  final String? rejectionReason;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? trxId;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const WithdrawalRequest({
    required this.id,
    required this.userId,
    required this.amount,
    required this.payoutMethod,
    required this.accountNumber,
    this.bankName,
    this.accountHolderName,
    this.status = 'pending',
    this.rejectionReason,
    this.reviewedBy,
    this.reviewedAt,
    this.trxId,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  String get formattedAmount => '৳${amount.toStringAsFixed(0)}';

  String get payoutMethodLabel {
    switch (payoutMethod.toLowerCase()) {
      case 'bkash':
        return 'bKash';
      case 'nagad':
        return 'Nagad';
      case 'bank':
        return bankName != null && bankName!.isNotEmpty ? 'Bank ($bankName)' : 'Bank Transfer';
      default:
        return payoutMethod.toUpperCase();
    }
  }

  factory WithdrawalRequest.fromJson(Map<String, dynamic> json, String docId) {
    DateTime parseDate(dynamic value) {
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      try {
        return (value as dynamic).toDate() as DateTime;
      } catch (_) {
        return DateTime.now();
      }
    }

    return WithdrawalRequest(
      id: (json['id'] as String?) ?? docId,
      userId: (json['user_id'] as String?) ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      payoutMethod: (json['payout_method'] as String?) ?? 'bkash',
      accountNumber: (json['account_number'] as String?) ?? '',
      bankName: json['bank_name'] as String?,
      accountHolderName: json['account_holder_name'] as String?,
      status: (json['status'] as String?) ?? 'pending',
      rejectionReason: json['rejection_reason'] as String?,
      reviewedBy: json['reviewed_by'] as String?,
      reviewedAt: json['reviewed_at'] != null ? parseDate(json['reviewed_at']) : null,
      trxId: json['trx_id'] as String?,
      createdAt: json['created_at'] != null ? parseDate(json['created_at']) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? parseDate(json['updated_at']) : null,
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id,
      'user_id': userId,
      'amount': amount,
      'payout_method': payoutMethod,
      'account_number': accountNumber,
      if (bankName != null) 'bank_name': bankName,
      if (accountHolderName != null) 'account_holder_name': accountHolderName,
      'status': status,
      if (rejectionReason != null) 'rejection_reason': rejectionReason,
      if (reviewedBy != null) 'reviewed_by': reviewedBy,
      if (reviewedAt != null) 'reviewed_at': reviewedAt,
      if (trxId != null) 'trx_id': trxId,
      'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }

  WithdrawalRequest copyWith({
    String? id,
    String? userId,
    double? amount,
    String? payoutMethod,
    String? accountNumber,
    String? bankName,
    String? accountHolderName,
    String? status,
    String? rejectionReason,
    String? reviewedBy,
    DateTime? reviewedAt,
    String? trxId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WithdrawalRequest(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      amount: amount ?? this.amount,
      payoutMethod: payoutMethod ?? this.payoutMethod,
      accountNumber: accountNumber ?? this.accountNumber,
      bankName: bankName ?? this.bankName,
      accountHolderName: accountHolderName ?? this.accountHolderName,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      trxId: trxId ?? this.trxId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
