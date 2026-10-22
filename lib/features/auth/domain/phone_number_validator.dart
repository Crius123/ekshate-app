import 'package:flutter/services.dart';

/// Canonical validator and formatter for Bangladeshi mobile numbers (+8801...)
class PhoneNumberValidator {
  PhoneNumberValidator._();

  // Valid Bangladeshi mobile operator prefixes: 013, 014, 015, 016, 017, 018, 019
  // Matches local (01XXXXXXXXX) and international (+8801XXXXXXXXX or 8801XXXXXXXXX)
  static final RegExp _bdPhoneRegex = RegExp(r'^(?:\+?880|88)?0?(1[3-9]\d{8})$');

  /// Cleans input string by removing spaces, hyphens, and parentheses
  static String clean(String input) {
    return input.replaceAll(RegExp(r'[\s\-\(\)]'), '');
  }

  /// Checks if input is a valid Bangladeshi mobile number
  static bool isValid(String input) {
    final cleaned = clean(input);
    return _bdPhoneRegex.hasMatch(cleaned);
  }

  /// Normalizes to international E.164 format: `+8801XXXXXXXXX`
  static String toCanonical(String input) {
    final cleaned = clean(input);
    final match = _bdPhoneRegex.firstMatch(cleaned);
    if (match == null) {
      throw ArgumentError('Invalid Bangladeshi phone number: $input');
    }
    final operatorAndNumber = match.group(1)!; // e.g. "1711000001"
    return '+880$operatorAndNumber';
  }

  /// Normalizes to national 11-digit format: `01XXXXXXXXX`
  static String toNational(String input) {
    final cleaned = clean(input);
    final match = _bdPhoneRegex.firstMatch(cleaned);
    if (match == null) {
      throw ArgumentError('Invalid Bangladeshi phone number: $input');
    }
    final operatorAndNumber = match.group(1)!;
    return '0$operatorAndNumber';
  }

  /// Formats for human readability: `+880 1XXX-XXXXXX`
  static String formatDisplay(String input) {
    final canonical = toCanonical(input); // e.g. +8801711000001
    final prefix = canonical.substring(4, 8); // "1711"
    final rest = canonical.substring(8); // "000001"
    return '+880 $prefix-$rest';
  }
}

/// TextInputFormatter for formatting Bangladeshi phone numbers in real-time as `01XXX-XXXXXX`
class BdPhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Strip non-digits
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Cap at 11 digits
    final cappedDigits = digits.length > 11 ? digits.substring(0, 11) : digits;

    final buffer = StringBuffer();
    for (int i = 0; i < cappedDigits.length; i++) {
      if (i == 5) {
        buffer.write('-');
      }
      buffer.write(cappedDigits[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
