import 'package:flutter/material.dart';

/// Design tokens and styling helpers for modern fintech bulk commerce light mode UI.
class AppColors {
  AppColors._();

  // Core Brand Colors
  static const Color emerald = Color(0xFF10B981); // Emerald 500
  static const Color emeraldDark = Color(0xFF059669); // Emerald 600
  static const Color emeraldLight = Color(0xFF34D399); // Emerald 400
  static const Color emeraldGlow = Color(0x1F10B981);

  // Backgrounds & Surfaces (Light Mode)
  static const Color background = Color(0xFFF8FAFC); // Slate 50
  static const Color cardSurface = Color(0xFFFFFFFF); // Pure white
  static const Color cardSurfaceElevated = Color(0xFFF1F5F9); // Slate 100
  static const Color cardSurfaceTranslucent = Color(0xF2FFFFFF);

  // Borders
  static const Color borderSubtle = Color(0xFFE2E8F0); // Slate 200
  static const Color borderHighlight = Color(0xFFCBD5E1); // Slate 300
  static const Color borderEmerald = Color(0x4D10B981);

  // Status & Accents
  static const Color amberEscrow = Color(0xFFD97706); // Amber 600 (high contrast for light UI)
  static const Color amberGlow = Color(0x1FD97706);
  static const Color skyCourier = Color(0xFF0284C7); // Sky 600
  static const Color skyGlow = Color(0x1F0284C7);
  static const Color roseRefund = Color(0xFFDC2626); // Rose 600

  // Typography (Dark charcoal & slate for crisp readability)
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF334155); // Slate 700
  static const Color textMuted = Color(0xFF64748B); // Slate 500
}

/// Reusable BoxDecorations for light glassmorphism, micro-gradients, and soft crisp elevations.
class AppDecorations {
  AppDecorations._();

  /// Primary modern card decoration with subtle border and elevation in light mode.
  static BoxDecoration glassCard({
    Color? surfaceColor,
    Color? borderColor,
    double borderRadius = 16.0,
    bool hasGlow = false,
    Color glowColor = AppColors.emeraldGlow,
  }) {
    return BoxDecoration(
      color: surfaceColor ?? AppColors.cardSurface,
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: borderColor ?? AppColors.borderSubtle,
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0x0A0F172A),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
        if (hasGlow)
          BoxShadow(
            color: glowColor,
            blurRadius: 18,
            spreadRadius: -2,
            offset: const Offset(0, 2),
          ),
      ],
    );
  }

  /// Modern emerald gradient for primary action buttons.
  static const LinearGradient emeraldButtonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF10B981),
      Color(0xFF059669),
    ],
  );

  /// Modern hero banner gradient for light mode.
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFFFFFF),
      Color(0xFFF8FAFC),
    ],
  );

  /// Subtle glass badge decoration.
  static BoxDecoration glassBadge({
    required Color color,
    double borderRadius = 6.0,
  }) {
    return BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: color.withValues(alpha: 0.28),
        width: 1.0,
      ),
    );
  }
}
