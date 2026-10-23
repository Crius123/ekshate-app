import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../config/theme/app_decorations.dart';
import '../router/route_paths.dart';
import '../../features/cart/presentation/cart_controller.dart';
import '../../features/notifications/presentation/notifications_controller.dart';

class AppScaffold extends ConsumerWidget {
  final Widget child;

  const AppScaffold({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location == RoutePaths.catalog) return 1;
    if (location == RoutePaths.cart) return 2;
    if (location == RoutePaths.orders || location == RoutePaths.procurement) return 3;
    if (location == RoutePaths.wallet) return 4;
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
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = _calculateSelectedIndex(context);
    final cartItems = ref.watch(cartProvider);
    final unreadNotifs = ref.watch(unreadNotificationCountProvider);

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
            selectedIndex: selectedIndex,
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
