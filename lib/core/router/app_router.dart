import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'route_paths.dart';
import '../widgets/app_scaffold.dart';
import '../errors/error_boundary_widget.dart';
import '../../features/daily_sale/presentation/daily_sale_screen.dart';
import '../../features/catalog/presentation/catalog_screen.dart';
import '../../features/cart/presentation/cart_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../../features/wallet/presentation/wallet_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/profile_setup_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final rootNavigatorKey = GlobalKey<NavigatorState>();
  final shellNavigatorKey = GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: RoutePaths.dailySale,
    errorBuilder: (context, state) => Scaffold(
      body: ErrorBoundaryWidget(
        error: state.error ?? 'Page not found',
        onRetry: () => context.go(RoutePaths.dailySale),
      ),
    ),
    routes: [
      ShellRoute(
        navigatorKey: shellNavigatorKey,
        builder: (context, state, child) {
          return AppScaffold(child: child);
        },
        routes: [
          GoRoute(
            path: RoutePaths.dailySale,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: DailySaleScreen(),
            ),
          ),
          GoRoute(
            path: RoutePaths.catalog,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CatalogScreen(),
            ),
          ),
          GoRoute(
            path: RoutePaths.cart,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CartScreen(),
            ),
          ),
          GoRoute(
            path: RoutePaths.orders,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: OrdersScreen(),
            ),
          ),
          GoRoute(
            path: RoutePaths.wallet,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: WalletScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: RoutePaths.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: RoutePaths.profileSetup,
        builder: (context, state) => const ProfileSetupScreen(),
      ),
    ],
  );
});
