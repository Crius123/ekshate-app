/// Customer Profile entity conforming to Firestore `users/{userId}` security rules
class UserProfile {
  final String uid;
  final String? phoneNumber;
  final String? displayName;
  final String? email;
  final String? deliveryAddress;
  final String role; // 'customer' | 'admin'
  final double availableBalance;
  final double escrowBalance;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserProfile({
    required this.uid,
    this.phoneNumber,
    this.displayName,
    this.email,
    this.deliveryAddress,
    this.role = 'customer',
    this.availableBalance = 0.0,
    this.escrowBalance = 0.0,
    this.createdAt,
    this.updatedAt,
  });

  /// Factory for strictly creating a new customer profile adhering to security rules:
  /// - `available_balance == 0`
  /// - `escrow_balance == 0`
  /// - `role == 'customer'`
  factory UserProfile.initialCustomer({
    required String uid,
    required String phoneNumber,
    DateTime? createdAt,
  }) {
    return UserProfile(
      uid: uid,
      phoneNumber: phoneNumber,
      role: 'customer',
      availableBalance: 0.0,
      escrowBalance: 0.0,
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  /// Whether the customer has completed their onboarding details (name & delivery address)
  bool get isProfileComplete =>
      (displayName != null && displayName!.trim().isNotEmpty) &&
      (deliveryAddress != null && deliveryAddress!.trim().isNotEmpty);

  double get totalWalletValue => availableBalance + escrowBalance;

  Map<String, dynamic> toFirestoreMap() {
    return {
      'uid': uid,
      if (phoneNumber != null) 'phone_number': phoneNumber,
      if (displayName != null) 'display_name': displayName,
      if (email != null) 'email': email,
      if (deliveryAddress != null) 'delivery_address': deliveryAddress,
      'role': role,
      'available_balance': availableBalance,
      'escrow_balance': escrowBalance,
      // DateTime writes directly as Firestore Timestamp
      'created_at': createdAt ?? DateTime.now(),
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }

  factory UserProfile.fromFirestore(Map<String, dynamic> data, String uid) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is String) return DateTime.tryParse(value);
      // If Firebase Timestamp or custom object with toDate()
      try {
        return (value as dynamic).toDate() as DateTime;
      } catch (_) {
        return null;
      }
    }

    return UserProfile(
      uid: (data['uid'] as String?) ?? uid,
      phoneNumber: data['phone_number'] as String?,
      displayName: data['display_name'] as String?,
      email: data['email'] as String?,
      deliveryAddress: data['delivery_address'] as String?,
      role: (data['role'] as String?) ?? 'customer',
      availableBalance: (data['available_balance'] as num?)?.toDouble() ?? 0.0,
      escrowBalance: (data['escrow_balance'] as num?)?.toDouble() ?? 0.0,
      createdAt: parseDate(data['created_at']),
      updatedAt: parseDate(data['updated_at']),
    );
  }

  UserProfile copyWith({
    String? uid,
    String? phoneNumber,
    String? displayName,
    String? email,
    String? deliveryAddress,
    String? role,
    double? availableBalance,
    double? escrowBalance,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      role: role ?? this.role,
      availableBalance: availableBalance ?? this.availableBalance,
      escrowBalance: escrowBalance ?? this.escrowBalance,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
