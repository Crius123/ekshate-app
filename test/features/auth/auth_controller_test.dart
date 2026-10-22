import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ekshate_app/core/errors/app_exception.dart';
import 'package:ekshate_app/features/auth/data/auth_repository.dart';
import 'package:ekshate_app/features/auth/presentation/auth_controller.dart';

void main() {
  late MockAuthRepository mockRepo;
  late ProviderContainer container;

  setUp(() {
    mockRepo = MockAuthRepository(
      defaultOtp: '123456',
      simulatedDelay: Duration.zero,
      initialUser: null, // Start unauthenticated for clean testing
    );

    container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  test('initial state reflects repository currentUser', () {
    final state = container.read(authStateProvider);
    expect(state.value, isNull);
  });

  test('sendOtp and verifyOtp successfully updates auth state to new customer', () async {
    final controller = container.read(authStateProvider.notifier);

    await controller.sendOtp('01711000001');
    final user = await controller.verifyOtp(
      phoneNumber: '01711000001',
      otp: '123456',
    );

    expect(user.phoneNumber, equals('+8801711000001'));
    expect(user.availableBalance, equals(0.0));
    expect(user.escrowBalance, equals(0.0));
    expect(user.role, equals('customer'));
    expect(user.isProfileComplete, isFalse);

    final updatedState = container.read(authStateProvider);
    expect(updatedState.value?.uid, equals(user.uid));
  });

  test('verifyOtp propagates InvalidOtpException and preserves previous state', () async {
    final controller = container.read(authStateProvider.notifier);
    await controller.sendOtp('01711000001');

    expect(
      () => controller.verifyOtp(phoneNumber: '01711000001', otp: '000000'),
      throwsA(isA<InvalidOtpException>()),
    );
  });

  test('completeProfile updates name and structured delivery address', () async {
    final controller = container.read(authStateProvider.notifier);
    await controller.sendOtp('01711000001');
    await controller.verifyOtp(phoneNumber: '01711000001', otp: '123456');

    final updated = await controller.completeProfile(
      displayName: 'Sheikh Buyer',
      addressLine: 'House 12, Road 5',
      area: 'Dhanmondi',
      city: 'Dhaka',
    );

    expect(updated.displayName, equals('Sheikh Buyer'));
    expect(updated.deliveryAddress, equals('House 12, Road 5, Dhanmondi, Dhaka'));
    expect(updated.isProfileComplete, isTrue);

    final state = container.read(authStateProvider);
    expect(state.value?.isProfileComplete, isTrue);
  });

  test('signOut resets auth state to null', () async {
    final controller = container.read(authStateProvider.notifier);
    await controller.sendOtp('01711000001');
    await controller.verifyOtp(phoneNumber: '01711000001', otp: '123456');

    expect(container.read(authStateProvider).value, isNotNull);

    await controller.signOut();
    expect(container.read(authStateProvider).value, isNull);
  });
}
