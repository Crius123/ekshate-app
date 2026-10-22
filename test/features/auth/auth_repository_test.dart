import 'package:flutter_test/flutter_test.dart';
import 'package:ekshate_app/core/errors/app_exception.dart';
import 'package:ekshate_app/features/auth/data/auth_repository.dart';

void main() {
  late MockAuthRepository repository;

  setUp(() {
    repository = MockAuthRepository(
      defaultOtp: '123456',
      simulatedDelay: Duration.zero,
      initialUser: null,
    );
  });

  group('AuthRepository - SMS OTP Flow', () {
    test('sendOtp throws InvalidPhoneNumberException on invalid phone', () async {
      expect(
        () => repository.sendOtp('01211000000'),
        throwsA(isA<InvalidPhoneNumberException>()),
      );
      expect(
        () => repository.sendOtp('123'),
        throwsA(isA<InvalidPhoneNumberException>()),
      );
    });

    test('sendOtp succeeds with valid Bangladeshi number', () async {
      await expectLater(repository.sendOtp('01711000001'), completes);
    });

    test('verifyOtp throws InvalidOtpException on wrong OTP', () async {
      await repository.sendOtp('01711000001');

      expect(
        () => repository.verifyOtp(
          phoneNumber: '01711000001',
          otp: '999999',
        ),
        throwsA(isA<InvalidOtpException>()),
      );
    });

    test('verifyOtp throws ExpiredOtpException when OTP expires', () async {
      await repository.sendOtp('01711000001');
      repository.expireOtp('01711000001');

      expect(
        () => repository.verifyOtp(
          phoneNumber: '01711000001',
          otp: '123456',
        ),
        throwsA(isA<ExpiredOtpException>()),
      );
    });

    test('verifyOtp on first login creates user with zero balances and customer role', () async {
      await repository.sendOtp('01711000001');
      final user = await repository.verifyOtp(
        phoneNumber: '01711000001',
        otp: '123456',
      );

      expect(user.phoneNumber, equals('+8801711000001'));
      expect(user.availableBalance, equals(0.0));
      expect(user.escrowBalance, equals(0.0));
      expect(user.role, equals('customer'));
      expect(user.isProfileComplete, isFalse);
      expect(repository.currentUser?.uid, equals(user.uid));
    });

    test('completeProfile updates name and address without altering balances', () async {
      await repository.sendOtp('01711000001');
      final initialUser = await repository.verifyOtp(
        phoneNumber: '01711000001',
        otp: '123456',
      );

      final updated = await repository.completeProfile(
        uid: initialUser.uid,
        displayName: 'Karim Ullah',
        deliveryAddress: 'Flat 3A, House 10, Road 4, Dhanmondi, Dhaka',
      );

      expect(updated.displayName, equals('Karim Ullah'));
      expect(updated.deliveryAddress, equals('Flat 3A, House 10, Road 4, Dhanmondi, Dhaka'));
      expect(updated.isProfileComplete, isTrue);
      // Ensure balances and role remain immutable
      expect(updated.availableBalance, equals(0.0));
      expect(updated.escrowBalance, equals(0.0));
      expect(updated.role, equals('customer'));
      expect(repository.currentUser?.isProfileComplete, isTrue);
    });

    test('signOut clears current user and emits null', () async {
      await repository.sendOtp('01711000001');
      await repository.verifyOtp(
        phoneNumber: '01711000001',
        otp: '123456',
      );
      expect(repository.currentUser, isNotNull);

      await repository.signOut();
      expect(repository.currentUser, isNull);
    });

    test('simulates network timeout when enabled', () async {
      repository.simulateNetworkTimeout = true;

      expect(
        () => repository.sendOtp('01711000001'),
        throwsA(isA<AuthNetworkTimeoutException>()),
      );
    });
  });
}
