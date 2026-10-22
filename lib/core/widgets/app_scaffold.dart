import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../router/route_paths.dart';
import '../../features/cart/presentation/cart_controller.dart';

class AppScaffold extends ConsumerWidget {
  final Widget child;

  const AppScaffold({super.key, required this.child});

  int _calculateSelectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location == RoutePaths.catalog) return 1;
    if (location == RoutePaths.cart) return 2;
    if (location == RoutePaths.orders) return 3;
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

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
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
              label: Text('${cartItems.length}'),
              child: const Icon(LucideIcons.shoppingBag),
            ),
            label: 'Batch Cart',
          ),
          const NavigationDestination(
            icon: Icon(LucideIcons.package),
            label: 'Orders',
          ),
          const NavigationDestination(
            icon: Icon(LucideIcons.wallet),
            label: 'Wallet',
          ),
        ],
      ),
    );
  }
}
