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
    required String addressLine,
    required String area,
    required String city,
  }) async {
    final current = state.asData?.value ?? _repository.currentUser;
    if (current == null) {
      throw StateError('Cannot complete profile: No authenticated user');
    }

    final formattedAddress = DeliveryAddress(
      addressLine: addressLine,
      area: area,
      city: city,
    ).formattedAddress;

    state = const AsyncValue.loading();
    try {
      final updated = await _repository.completeProfile(
        uid: current.uid,
        displayName: displayName,
        deliveryAddress: formattedAddress,
      );
      state = AsyncValue.data(updated);
      return updated;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  void updateAddress(String newAddress) {
    state.whenData((profile) {
      if (profile != null) {
        state = AsyncValue.data(profile.copyWith(deliveryAddress: newAddress));
      }
    });
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    await _repository.signOut();
    state = const AsyncValue.data(null);
  }
}
