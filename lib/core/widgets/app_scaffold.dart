import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../config/app_constants.dart';
import '../config/theme/app_decorations.dart';
import '../router/route_paths.dart';
import '../../features/cart/presentation/cart_controller.dart';
import '../../features/notifications/presentation/notifications_controller.dart';
import '../../features/notifications/presentation/widgets/notification_bell_button.dart';
import '../../features/wallet/presentation/wallet_controller.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/domain/user_profile.dart';
import '../../features/search/presentation/widgets/daily_search_bar.dart';
import '../../features/cart/presentation/widgets/cart_sheet.dart';
import '../../features/catalog/presentation/widgets/catalog_category_select.dart';

/// Helper utility providing responsive platform breakpoints.
class AdaptiveLayout {
  AdaptiveLayout._();

  /// Breakpoint above which the UI adapts from smartphone layout (bottom navigation)
  /// to web/desktop layout (top header navigation).
  static const double desktopBreakpoint = 900.0;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= desktopBreakpoint;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < desktopBreakpoint;
}

/// Adaptive navigation shell for Ekshate.
///
/// Automatically presents:
/// - Smartphone: Polished bottom [NavigationBar] with thumb ergonomics.
/// - Web / Desktop: Persistent top header bar with branding, desktop nav tabs,
///   dual wallet indicators, batch cart quick-action, and user profile pill.
class AppScaffold extends ConsumerWidget {
  final Widget child;

  const AppScaffold({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location == RoutePaths.catalog) return 1;
    if (location == RoutePaths.cart) return 2;
    if (location == RoutePaths.orders) return 3;
    if (location == RoutePaths.wallet) return 4;
    if (location == RoutePaths.procurement) return 5;
    return 0; // RoutePaths.dailySale
  }

  void _onItemTapped(int index, BuildContext context) {
    switch (index) {
      case 0:
        context.go(RoutePaths.dailySale);
        break;
      case 1:
        context.go(RoutePaths.catalog);
        break;
      case 2:
        context.go(RoutePaths.cart);
        break;
      case 3:
        context.go(RoutePaths.orders);
        break;
      case 4:
        context.go(RoutePaths.wallet);
        break;
      case 5:
        context.go(RoutePaths.procurement);
        break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = _calculateSelectedIndex(context);
    final cartItems = ref.watch(cartProvider);
    final unreadNotifs = ref.watch(unreadNotificationCountProvider);
    final wallet = ref.watch(walletBalanceProvider);
    final authState = ref.watch(authStateProvider);
    final profile = authState.asData?.value;
    final isDesktop = AdaptiveLayout.isDesktop(context);

    // -------------------------------------------------------------------------
    // Desktop / Web Viewport Layout
    // -------------------------------------------------------------------------
    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            _WebNavigationHeader(
              selectedIndex: selectedIndex,
              onDestinationSelected: (idx) => _onItemTapped(idx, context),
              cartItemCount: cartItems.length,
              unreadNotifs: unreadNotifs,
              walletAvailable: wallet.available,
              walletEscrow: wallet.escrow,
              profile: profile,
            ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1240),
                  child: child,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // -------------------------------------------------------------------------
    // Smartphone Viewport Layout
    // -------------------------------------------------------------------------
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: AppColors.cardSurface,
          indicatorColor: AppColors.emerald.withValues(alpha: 0.16),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: AppColors.emerald);
            }
            return const IconThemeData(color: AppColors.textMuted);
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.emerald,
              );
            }
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
            );
          }),
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.cardSurface,
            border: Border(
              top: BorderSide(
                color: AppColors.borderSubtle,
                width: 1.2,
              ),
            ),
          ),
          child: NavigationBar(
            selectedIndex: selectedIndex > 4 ? 3 : selectedIndex,
            onDestinationSelected: (idx) => _onItemTapped(idx, context),
            destinations: [
              const NavigationDestination(
                icon: Icon(LucideIcons.flame),
                label: 'Daily Sale',
              ),
              const NavigationDestination(
                icon: Icon(LucideIcons.layoutGrid),
                label: 'Catalog',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: cartItems.isNotEmpty,
                  backgroundColor: AppColors.emerald,
                  textColor: Colors.white,
                  label: Text('${cartItems.length}'),
                  child: const Icon(LucideIcons.shoppingBag),
                ),
                label: 'Batch Cart',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: unreadNotifs > 0,
                  backgroundColor: AppColors.amberEscrow,
                  textColor: Colors.white,
                  label: Text(unreadNotifs > 99 ? '99+' : '$unreadNotifs'),
                  child: const Icon(LucideIcons.package),
                ),
                label: 'Orders',
              ),
              const NavigationDestination(
                icon: Icon(LucideIcons.wallet),
                label: 'Wallet',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Persistent top website navigation bar for desktop and tablet browsers.
class _WebNavigationHeader extends ConsumerWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final int cartItemCount;
  final int unreadNotifs;
  final double walletAvailable;
  final double walletEscrow;
  final UserProfile? profile;

  const _WebNavigationHeader({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.cartItemCount,
    required this.unreadNotifs,
    required this.walletAvailable,
    required this.walletEscrow,
    required this.profile,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 64,
      decoration: const BoxDecoration(
        color: AppColors.cardSurface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.borderSubtle,
            width: 1.2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1240),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                // 1. Brand Logo & Name
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onDestinationSelected(0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            gradient: AppDecorations.emeraldButtonGradient,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            LucideIcons.shoppingBasket,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppConstants.appName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // 2. Desktop Navigation & Expanded Web Search Bar
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        _WebNavLink(
                          label: 'Catalog',
                          icon: LucideIcons.layoutGrid,
                          isSelected: selectedIndex == 1,
                          onTap: () => onDestinationSelected(1),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 460),
                              child: const DailySearchBar(isHeader: true),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // 4. Actions Row (Right)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Wallet Pill
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => onDestinationSelected(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.emerald.withValues(alpha: 0.35),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.wallet, size: 14, color: AppColors.emerald),
                            const SizedBox(width: 6),
                            Text(
                              'Available: ৳${walletAvailable.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.emeraldDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Batch Cart Button (Opens Shadcn Sheet on Web)
                    InkWell(
                      key: const Key('web_cart_sheet_button'),
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => CartSheet.show(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: AppDecorations.emeraldButtonGradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Badge(
                              isLabelVisible: cartItemCount > 0,
                              backgroundColor: Colors.white,
                              textColor: AppColors.emeraldDark,
                              label: Text(
                                '$cartItemCount',
                                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                              child: const Icon(
                                LucideIcons.shoppingBag,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              cartItemCount > 0 ? 'Cart ($cartItemCount)' : 'Cart',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 4),

                    // Notification Bell
                    const NotificationBellButton(),

                    // User Profile Select Widget / Sign In
                    if (profile != null) ...[
                      const SizedBox(width: 4),
                      ShadSelect<String>(
                        minWidth: 150,
                        placeholder: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: AppColors.emerald.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                LucideIcons.user,
                                size: 12,
                                color: AppColors.emerald,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              profile!.displayName ?? 'Customer',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        selectedOptionBuilder: (context, _) => Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: AppColors.emerald.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                LucideIcons.user,
                                size: 12,
                                color: AppColors.emerald,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              profile!.displayName ?? 'Customer',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        trailing: const Icon(LucideIcons.chevronDown, size: 13, color: AppColors.textMuted),
                        decoration: ShadDecoration(
                          color: AppColors.cardSurfaceElevated,
                          border: ShadBorder.all(
                            color: AppColors.borderSubtle,
                            width: 1.0,
                            radius: BorderRadius.circular(8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          ),
                          focusedBorder: ShadBorder.all(
                            color: AppColors.emerald,
                            width: 1.2,
                            radius: BorderRadius.circular(8),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          ),
                          secondaryBorder: ShadBorder.none,
                          secondaryFocusedBorder: ShadBorder.none,
                        ),
                        options: const [
                          ShadOption<String>(
                            value: 'orders',
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.package, size: 14, color: AppColors.textSecondary),
                                SizedBox(width: 8),
                                Text('View Orders', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                          ShadOption<String>(
                            value: 'account',
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.userCheck, size: 14, color: AppColors.textSecondary),
                                SizedBox(width: 8),
                                Text('Manage My Account', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          ),
                          ShadOption<String>(
                            value: 'sign_out',
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.logOut, size: 14, color: AppColors.roseRefund),
                                SizedBox(width: 8),
                                Text(
                                  'Sign Out',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.roseRefund,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          if (val == 'orders') {
                            onDestinationSelected(3);
                          } else if (val == 'account') {
                            context.push(RoutePaths.profileSetup);
                          } else if (val == 'sign_out') {
                            ref.read(authStateProvider.notifier).signOut();
                          }
                        },
                      ),
                    ] else ...[
                      const SizedBox(width: 4),
                      ShadButton.outline(
                        size: ShadButtonSize.sm,
                        onPressed: () => context.push(RoutePaths.login),
                        child: const Text('Sign In'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Desktop navigation link tab with hover and selection indicators.
class _WebNavLink extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _WebNavLink({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_WebNavLink> createState() => _WebNavLinkState();
}

class _WebNavLinkState extends State<_WebNavLink> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.isSelected;

    final bgColor = isSelected
        ? AppColors.emerald.withValues(alpha: 0.12)
        : (_isHovered ? AppColors.cardSurfaceElevated : Colors.transparent);

    final textColor = isSelected
        ? AppColors.emeraldDark
        : (_isHovered ? AppColors.textPrimary : AppColors.textSecondary);

    final iconColor = isSelected
        ? AppColors.emerald
        : (_isHovered ? AppColors.textPrimary : AppColors.textMuted);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(
                    color: AppColors.emerald.withValues(alpha: 0.25),
                    width: 1.0,
                  )
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 15,
                color: iconColor,
              ),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
