import 'package:flutter/material.dart';

/// Design tokens and glassmorphism styling helpers for modern fintech bulk commerce UI.
class AppColors {
  AppColors._();

  // Core Brand Colors
  static const Color emerald = Color(0xFF10B981); // Emerald 500
  static const Color emeraldDark = Color(0xFF059669); // Emerald 600
  static const Color emeraldLight = Color(0xFF34D399); // Emerald 400
  static const Color emeraldGlow = Color(0x3310B981);

  // Backgrounds & Surfaces
  static const Color darkBackground = Color(0xFF090D16);
  static const Color cardSurface = Color(0xFF111827); // Gray 900
  static const Color cardSurfaceElevated = Color(0xFF1A2234);
  static const Color cardSurfaceTranslucent = Color(0xDD111827);

  // Borders
  static const Color borderSubtle = Color(0xFF1F293D);
  static const Color borderHighlight = Color(0xFF2E3D59);
  static const Color borderEmerald = Color(0x4D10B981);

  // Status & Accents
  static const Color amberEscrow = Color(0xFFF59E0B);
  static const Color amberGlow = Color(0x33F59E0B);
  static const Color skyCourier = Color(0xFF0EA5E9);
  static const Color skyGlow = Color(0x330EA5E9);
  static const Color roseRefund = Color(0xFFEF4444);

  // Typography
  static const Color textPrimary = Color(0xFFF9FAFB);
  static const Color textSecondary = Color(0xFFE5E7EB);
  static const Color textMuted = Color(0xFF94A3B8);
}

/// Reusable BoxDecorations for glassmorphism, micro-gradients, and soft glowing elevations.
class AppDecorations {
  AppDecorations._();

  /// Primary modern glassmorphic card decoration with subtle border and elevation.
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
          color: Colors.black.withValues(alpha: 0.35),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
        if (hasGlow)
          BoxShadow(
            color: glowColor,
            blurRadius: 20,
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

  /// Modern dark hero banner gradient.
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF111827),
      Color(0xFF0F172A),
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
