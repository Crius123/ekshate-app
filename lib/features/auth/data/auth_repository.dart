import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/phone_number_validator.dart';
import '../domain/user_profile.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return MockAuthRepository();
});

abstract class AuthRepository {
  Stream<UserProfile?> get authStateChanges;
  UserProfile? get currentUser;
  Future<void> sendOtp(String phoneNumber);
  Future<UserProfile> verifyOtp({
    required String phoneNumber,
    required String otp,
  });
  Future<void> resendOtp(String phoneNumber);
  Future<UserProfile> completeProfile({
    required String uid,
    required String displayName,
    required String deliveryAddress,
  });
  Future<void> signOut();
}

class MockAuthRepository implements AuthRepository {
  static const defaultMockCustomer = UserProfile(
    uid: 'user_dev_01',
    phoneNumber: '+8801711000001',
    displayName: 'Sheikh Buyer',
    email: 'buyer@ekshate.com',
    deliveryAddress: 'House 12, Road 5, Dhanmondi, Dhaka',
    availableBalance: 8500.0,
    escrowBalance: 1800.0,
  );

  final Duration simulatedDelay;
  final String defaultOtp;
  bool simulateNetworkTimeout;

  final _authController = StreamController<UserProfile?>.broadcast();
  UserProfile? _currentUser;
  final Map<String, UserProfile> _users = {};
  final Map<String, ({String code, DateTime expiresAt})> _activeOtps = {};

  MockAuthRepository({
    this.simulatedDelay = const Duration(milliseconds: 300),
    this.defaultOtp = '123456',
    this.simulateNetworkTimeout = false,
    UserProfile? initialUser = defaultMockCustomer,
  }) {
    if (initialUser != null) {
      _currentUser = initialUser;
      _users[initialUser.uid] = initialUser;
    }
  }

  @override
  Stream<UserProfile?> get authStateChanges => _authController.stream;

  @override
  UserProfile? get currentUser => _currentUser;

  void seedUser(UserProfile user) {
    _users[user.uid] = user;
    if (_currentUser?.uid == user.uid) {
      _currentUser = user;
      _authController.add(user);
    }
  }

  void expireOtp(String phoneNumber) {
    final canonical = PhoneNumberValidator.isValid(phoneNumber)
        ? PhoneNumberValidator.toCanonical(phoneNumber)
        : phoneNumber;
    if (_activeOtps.containsKey(canonical)) {
      final existing = _activeOtps[canonical]!;
      _activeOtps[canonical] = (
        code: existing.code,
        expiresAt: DateTime.now().subtract(const Duration(seconds: 1)),
      );
    }
  }

  @override
  Future<void> sendOtp(String phoneNumber) async {
    if (simulatedDelay > Duration.zero) {
      await Future.delayed(simulatedDelay);
    }
    if (simulateNetworkTimeout) {
      throw const AuthNetworkTimeoutException();
    }
    if (!PhoneNumberValidator.isValid(phoneNumber)) {
      throw const InvalidPhoneNumberException();
    }

    final canonical = PhoneNumberValidator.toCanonical(phoneNumber);
    _activeOtps[canonical] = (
      code: defaultOtp,
      expiresAt: DateTime.now().add(const Duration(minutes: 2)),
    );
  }

  @override
  Future<void> resendOtp(String phoneNumber) async {
    return sendOtp(phoneNumber);
  }

  @override
  Future<UserProfile> verifyOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    if (simulatedDelay > Duration.zero) {
      await Future.delayed(simulatedDelay);
    }
    if (simulateNetworkTimeout) {
      throw const AuthNetworkTimeoutException();
    }
    if (!PhoneNumberValidator.isValid(phoneNumber)) {
      throw const InvalidPhoneNumberException();
    }

    final canonical = PhoneNumberValidator.toCanonical(phoneNumber);
    final otpEntry = _activeOtps[canonical];

    if (otpEntry == null || otpEntry.code != otp.trim()) {
      throw const InvalidOtpException();
    }

    if (DateTime.now().isAfter(otpEntry.expiresAt)) {
      throw const ExpiredOtpException();
    }

    // Lookup existing user by phone number or create new document conforming strictly to security rules
    UserProfile? existing;
    for (final user in _users.values) {
      if (user.phoneNumber == canonical) {
        existing = user;
        break;
      }
    }

    final UserProfile profile;
    if (existing != null) {
      profile = existing;
    } else {
      // First authentication: auto-create users/{userId} profile with available_balance: 0, escrow_balance: 0, role: 'customer'
      final newUid = 'usr_${canonical.replaceAll('+', '')}';
      profile = UserProfile.initialCustomer(
        uid: newUid,
        phoneNumber: canonical,
        createdAt: DateTime.now(),
      );
      _users[newUid] = profile;
    }

    _currentUser = profile;
    _authController.add(profile);
    return profile;
  }

  @override
  Future<UserProfile> completeProfile({
    required String uid,
    required String displayName,
    required String deliveryAddress,
  }) async {
    if (simulatedDelay > Duration.zero) {
      await Future.delayed(simulatedDelay);
    }
    if (simulateNetworkTimeout) {
      throw const AuthNetworkTimeoutException();
    }

    final trimmedName = displayName.trim();
    final trimmedAddress = deliveryAddress.trim();

    if (trimmedName.isEmpty || trimmedName.length > 100) {
      throw ArgumentError('Display name must be between 1 and 100 characters');
    }
    if (trimmedAddress.isEmpty || trimmedAddress.length > 500) {
      throw ArgumentError('Delivery address must be between 1 and 500 characters');
    }

    final existing = _users[uid] ?? _currentUser;
    if (existing == null) {
      throw StateError('User profile not found for uid: $uid');
    }

    // Strict security rules update: immutable balances and role are preserved
    final updated = existing.copyWith(
      displayName: trimmedName,
      deliveryAddress: trimmedAddress,
      updatedAt: DateTime.now(),
    );

    _users[uid] = updated;
    if (_currentUser?.uid == uid) {
      _currentUser = updated;
      _authController.add(updated);
    }

    return updated;
  }

  @override
  Future<void> signOut() async {
    if (simulatedDelay > Duration.zero) {
      await Future.delayed(simulatedDelay);
    }
    _currentUser = null;
    _authController.add(null);
  }
}
