import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// AppTheme configures production Shadcn UI theming tailored for
/// bulk commerce with emerald accents representing community volume unlocked.
class AppTheme {
  AppTheme._();

  static ShadThemeData get lightTheme {
    return ShadThemeData(
      brightness: Brightness.light,
      colorScheme: const ShadZincColorScheme.light(
        primary: Color(0xFF10B981), // Emerald 500
        background: Color(0xFFF8FAFC), // Slate 50
        card: Color(0xFFFFFFFF), // Pure white
      ),
    );
  }

  static ShadThemeData get darkTheme {
    return ShadThemeData(
      brightness: Brightness.dark,
      colorScheme: const ShadZincColorScheme.dark(
        primary: Color(0xFF10B981), // Emerald 500
        background: Color(0xFF090D16),
        card: Color(0xFF111827),
      ),
    );
  }
}
