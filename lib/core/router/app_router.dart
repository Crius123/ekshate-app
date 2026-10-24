import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'route_paths.dart';
import '../widgets/app_scaffold.dart';
import '../errors/error_boundary_widget.dart';
import '../../features/daily_sale/presentation/daily_sale_screen.dart';
import '../../features/catalog/presentation/catalog_screen.dart';
import '../../features/cart/presentation/cart_screen.dart';
import '../../features/checkout/presentation/checkout_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../../features/wallet/presentation/wallet_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/profile_setup_screen.dart';
import '../../features/procurement/presentation/procurement_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/admin/presentation/admin_screen.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/daily_sale/presentation/product_details_screen.dart';
import '../../features/daily_sale/presentation/category_products_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final rootNavigatorKey = GlobalKey<NavigatorState>();
  final shellNavigatorKey = GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: RoutePaths.dailySale,
    redirect: (context, state) {
      if (state.uri.path.startsWith(RoutePaths.admin)) {
        final authRepo = ref.read(authRepositoryProvider);
        if (authRepo.currentUser?.role != 'admin') {
          return RoutePaths.dailySale;
        }
      }
      return null;
    },
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
          GoRoute(
            path: RoutePaths.procurement,
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProcurementScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: RoutePaths.checkout,
        builder: (context, state) => const CheckoutScreen(),
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
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: RoutePaths.notifications,
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: RoutePaths.admin,
        builder: (context, state) => const ScaffoldMessenger(child: AdminScreen()),
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: RoutePaths.productDetails,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return ProductDetailsScreen(listingId: id);
        },
      ),
      GoRoute(
        parentNavigatorKey: rootNavigatorKey,
        path: RoutePaths.categoryProducts,
        builder: (context, state) {
          final rawCategory = state.pathParameters['categoryName'] ?? '';
          final categoryName = Uri.decodeComponent(rawCategory);
          return CategoryProductsScreen(categoryName: categoryName);
        },
      ),
    ],
  );
});
