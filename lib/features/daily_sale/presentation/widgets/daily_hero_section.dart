import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ekshate_app/core/config/theme/app_decorations.dart';

/// Hero Section for Ekshate's daily bulk campaign landing surface.
///
/// Features:
/// - Persuasive hook text communicating community wholesale batch buying.
/// - Value proposition badges (wholesale savings, money-back protection, fresh dispatch).
/// - Contextual high-resolution photography showcasing farm-fresh produce.
/// - Floating trust milestone badge.
class DailyHeroSection extends StatelessWidget {
  const DailyHeroSection({super.key});

  static const String _heroImageUrl =
      'https://images.unsplash.com/photo-1542838132-92c53300491e?auto=format&fit=crop&w=1200&q=80';

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 800;

    return Container(
      decoration: AppDecorations.glassCard(
        surfaceColor: AppColors.cardSurface,
        borderColor: AppColors.borderSubtle,
        borderRadius: 16,
      ),
      clipBehavior: Clip.antiAlias,
      child: isDesktop ? _buildDesktopLayout(theme) : _buildMobileLayout(theme),
    );
  }

  Widget _buildDesktopLayout(ShadThemeData theme) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Column: Hook text, value badges, and call to action
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Wholesale pantry prices,\nunlocked together.',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                      height: 1.18,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Pool daily bulk batch orders with your community to bypass intermediary markups and unlock wholesale prices with zero-loss buyer protection.',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF475569),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Value proposition badges
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildPill(
                        icon: LucideIcons.zap,
                        iconColor: const Color(0xFF10B981),
                        label: 'Up to 25% Savings',
                      ),
                      _buildPill(
                        icon: LucideIcons.shieldCheck,
                        iconColor: const Color(0xFFD97706),
                        label: '100% Money-Back Guarantee',
                      ),
                      _buildPill(
                        icon: LucideIcons.truck,
                        iconColor: const Color(0xFF0284C7),
                        label: 'Morning Fresh Dispatch',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Right Column: High-resolution market photography with overlaid micro-card
          Expanded(
            flex: 2,
            child: _buildHeroImage(),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(ShadThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Top Banner Image
        SizedBox(
          height: 160,
          child: _buildHeroImage(),
        ),

        // Bottom Content
        Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Wholesale pantry prices,\nunlocked together.',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  height: 1.2,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Pool batch orders with your neighborhood to unlock genuine wholesale rates with zero-loss refund protection.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF475569),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildPill(
                    icon: LucideIcons.zap,
                    iconColor: const Color(0xFF10B981),
                    label: '25% Savings',
                  ),
                  _buildPill(
                    icon: LucideIcons.shieldCheck,
                    iconColor: const Color(0xFFD97706),
                    label: 'Money-Back Guarantee',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroImage() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          _heroImageUrl,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.medium,
          errorBuilder: (context, error, stackTrace) => Container(
            color: const Color(0xFFF1F5F9),
            child: const Center(
              child: Icon(LucideIcons.shoppingBasket, size: 48, color: Color(0xFF94A3B8)),
            ),
          ),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: const Color(0xFFF1F5F9),
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF10B981),
                  ),
                ),
              ),
            );
          },
        ),

        // Deep gradient scrim for contrast
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.25),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPill({
    required IconData icon,
    required Color iconColor,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: iconColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }
}
