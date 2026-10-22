import 'package:flutter_test/flutter_test.dart';
import 'package:ekshate_app/features/auth/domain/phone_number_validator.dart';
import 'package:ekshate_app/features/auth/domain/delivery_address.dart';
import 'package:ekshate_app/features/auth/domain/user_profile.dart';

void main() {
  group('PhoneNumberValidator', () {
    test('validates valid Bangladeshi mobile numbers across all operators', () {
      expect(PhoneNumberValidator.isValid('01711000001'), isTrue); // Grameenphone
      expect(PhoneNumberValidator.isValid('01311000001'), isTrue); // Grameenphone (013)
      expect(PhoneNumberValidator.isValid('01811000001'), isTrue); // Robi
      expect(PhoneNumberValidator.isValid('01611000001'), isTrue); // Airtel
      expect(PhoneNumberValidator.isValid('01911000001'), isTrue); // Banglalink
      expect(PhoneNumberValidator.isValid('01411000001'), isTrue); // Banglalink (014)
      expect(PhoneNumberValidator.isValid('01511000001'), isTrue); // Teletalk
      expect(PhoneNumberValidator.isValid('+8801711000001'), isTrue);
      expect(PhoneNumberValidator.isValid('8801711000001'), isTrue);
      expect(PhoneNumberValidator.isValid('01711-000001'), isTrue);
      expect(PhoneNumberValidator.isValid('+880 1711 000001'), isTrue);
    });

    test('rejects invalid numbers or unallocated prefixes', () {
      expect(PhoneNumberValidator.isValid('01211000001'), isFalse); // 012 is invalid
      expect(PhoneNumberValidator.isValid('01011000001'), isFalse); // 010 is invalid
      expect(PhoneNumberValidator.isValid('01111000001'), isFalse); // 011 is CDMA/defunct
      expect(PhoneNumberValidator.isValid('017110000'), isFalse); // Too short
      expect(PhoneNumberValidator.isValid('0171100000000'), isFalse); // Too long
      expect(PhoneNumberValidator.isValid(''), isFalse);
      expect(PhoneNumberValidator.isValid('letters-only'), isFalse);
    });

    test('formats to canonical E.164 +8801... format', () {
      expect(PhoneNumberValidator.toCanonical('01711000001'), equals('+8801711000001'));
      expect(PhoneNumberValidator.toCanonical('+8801711000001'), equals('+8801711000001'));
      expect(PhoneNumberValidator.toCanonical('8801812345678'), equals('+8801812345678'));
      expect(PhoneNumberValidator.toCanonical('01911-223344'), equals('+8801911223344'));
    });

    test('formats for display with readable grouping', () {
      expect(PhoneNumberValidator.formatDisplay('01711000001'), equals('+880 1711-000001'));
      expect(PhoneNumberValidator.formatDisplay('+8801812345678'), equals('+880 1812-345678'));
    });
  });

  group('DeliveryAddress', () {
    test('creates and formats delivery address', () {
      const address = DeliveryAddress(
        addressLine: 'Flat 4B, House 12, Road 5',
        area: 'Dhanmondi',
        city: 'Dhaka',
      );

      expect(address.formattedAddress, equals('Flat 4B, House 12, Road 5, Dhanmondi, Dhaka'));
    });

    test('parses existing formatted address correctly', () {
      final parsed = DeliveryAddress.parse('House 12, Road 5, Dhanmondi, Dhaka');
      expect(parsed.addressLine, equals('House 12, Road 5'));
      expect(parsed.area, equals('Dhanmondi'));
      expect(parsed.city, equals('Dhaka'));
    });
  });

  group('UserProfile', () {
    test('initialCustomer strictly adheres to security rules', () {
      final user = UserProfile.initialCustomer(
        uid: 'user_test_99',
        phoneNumber: '+8801711000001',
      );

      expect(user.uid, equals('user_test_99'));
      expect(user.phoneNumber, equals('+8801711000001'));
      expect(user.role, equals('customer'));
      expect(user.availableBalance, equals(0.0));
      expect(user.escrowBalance, equals(0.0));
      expect(user.displayName, isNull);
      expect(user.deliveryAddress, isNull);
      expect(user.isProfileComplete, isFalse);
    });

    test('isProfileComplete becomes true when displayName and deliveryAddress are populated', () {
      final incomplete = UserProfile.initialCustomer(
        uid: 'user_1',
        phoneNumber: '+8801711000001',
      );
      expect(incomplete.isProfileComplete, isFalse);

      final completed = incomplete.copyWith(
        displayName: 'Rahim Ahmed',
        deliveryAddress: 'Flat 4B, House 12, Road 5, Dhanmondi, Dhaka',
      );
      expect(completed.isProfileComplete, isTrue);
    });

    test('Firestore map serialization adheres to security rules allowed fields', () {
      final user = UserProfile.initialCustomer(
        uid: 'user_1',
        phoneNumber: '+8801711000001',
        createdAt: DateTime(2026, 10, 22, 10, 0),
      );

      final map = user.toFirestoreMap();
      expect(map['uid'], equals('user_1'));
      expect(map['phone_number'], equals('+8801711000001'));
      expect(map['role'], equals('customer'));
      expect(map['available_balance'], equals(0.0));
      expect(map['escrow_balance'], equals(0.0));
      expect(map.containsKey('created_at'), isTrue);
      expect(map['created_at'], isA<DateTime>());

      final recreated = UserProfile.fromFirestore(map, 'user_1');
      expect(recreated.uid, equals(user.uid));
      expect(recreated.phoneNumber, equals(user.phoneNumber));
      expect(recreated.role, equals(user.role));
      expect(recreated.availableBalance, equals(0.0));
      expect(recreated.escrowBalance, equals(0.0));
    });
  });
}
