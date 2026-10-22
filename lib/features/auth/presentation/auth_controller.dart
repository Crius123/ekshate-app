import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/user_profile.dart';
import '../domain/delivery_address.dart';
import '../data/auth_repository.dart';

final authStateProvider = NotifierProvider<AuthController, AsyncValue<UserProfile?>>(() {
  return AuthController();
});

class AuthController extends Notifier<AsyncValue<UserProfile?>> {
  late final AuthRepository _repository;
  StreamSubscription<UserProfile?>? _authSubscription;

  @override
  AsyncValue<UserProfile?> build() {
    _repository = ref.watch(authRepositoryProvider);

    _authSubscription?.cancel();
    _authSubscription = _repository.authStateChanges.listen((user) {
      state = AsyncValue.data(user);
    });

    ref.onDispose(() {
      _authSubscription?.cancel();
    });

    return AsyncValue.data(_repository.currentUser);
  }

  Future<void> sendOtp(String phoneNumber) async {
    await _repository.sendOtp(phoneNumber);
  }

  Future<UserProfile> verifyOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repository.verifyOtp(
        phoneNumber: phoneNumber,
        otp: otp,
      );
      state = AsyncValue.data(user);
      return user;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> resendOtp(String phoneNumber) async {
    await _repository.resendOtp(phoneNumber);
  }

  Future<UserProfile> completeProfile({
    required String displayName,
    DeliveryAddress? address,
    String? addressLine,
    String? area,
    String? city,
  }) async {
    final current = state.asData?.value ?? _repository.currentUser;
    if (current == null) {
      throw StateError('Cannot complete profile: No authenticated user');
    }

    final deliveryAddress = address ??
        DeliveryAddress(
          addressLine: addressLine ?? '',
          area: area ?? '',
          city: city ?? 'Dhaka',
        );

    state = const AsyncValue.loading();
    try {
      final updated = await _repository.completeProfile(
        uid: current.uid,
        displayName: displayName,
        deliveryAddress: deliveryAddress.formattedAddress,
      );
      state = AsyncValue.data(updated);
      return updated;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    await _repository.signOut();
    state = const AsyncValue.data(null);
  }
}
