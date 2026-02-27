import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:baseshop/core/di/injection.dart';
import 'package:baseshop/core/router/not_found_screen.dart';
import 'package:baseshop/features/auth/bloc/auth_bloc.dart';
import 'package:baseshop/features/auth/bloc/auth_state.dart';
import 'package:baseshop/features/products/bloc/products_bloc.dart';

import 'package:baseshop/features/auth/screens/login_screen.dart';
import 'package:baseshop/features/auth/screens/register_screen.dart';
import 'package:baseshop/features/home/screens/home_screen.dart';
import 'package:baseshop/features/products/screens/products_screen.dart';
import 'package:baseshop/features/products/screens/product_detail_screen.dart';
import 'package:baseshop/features/cart/screens/cart_screen.dart';
import 'package:baseshop/features/orders/screens/orders_screen.dart';
import 'package:baseshop/features/orders/screens/order_detail_screen.dart';

import 'package:baseshop/features/profile/screens/profile_screen.dart';
import 'package:baseshop/features/profile/screens/addresses_screen.dart';

import 'package:baseshop/features/checkout/screens/checkout_screen.dart';
import 'package:baseshop/features/payments/screens/payu_checkout_screen.dart';
import 'package:baseshop/features/payments/screens/payment_result_screen.dart';
import 'package:baseshop/features/admin/screens/admin_products_screen.dart';
import 'package:baseshop/features/admin/screens/admin_orders_screen.dart';
import 'package:baseshop/features/admin/screens/admin_dashboard_screen.dart';
import 'package:baseshop/features/admin/screens/admin_order_detail_screen.dart';
import 'package:baseshop/features/admin/screens/admin_store_config_screen.dart';
import 'package:baseshop/features/admin/screens/admin_policies_screen.dart';
import 'package:baseshop/features/policies/screens/policies_screen.dart';
import 'package:baseshop/features/home/screens/shell_screen.dart';

// ── Auth-only paths (require login) ─────────────────────────
const _authRequiredPaths = <String>{
  '/orders',
  '/profile',
  '/checkout',
  '/payu-checkout',
  // '/payment-result' — intentionally NOT auth-required so PayU redirects work
  // even when the token hasn't been restored from storage yet (full page reload).
  '/addresses',
  '/admin/dashboard',
  '/admin/products',
  '/admin/orders',
  '/admin/config',
  '/admin/policies',
};

// ── Auth pages (login/register) ─────────────────────────────
const _authPages = <String>{
  '/login',
  '/register',
  '/forgot-password',
};

// ── Admin-only paths ────────────────────────────────────────
const _adminPaths = <String>{
  '/admin/dashboard',
  '/admin/products',
  '/admin/orders',
  '/admin/config',
  '/admin/policies',
};

/// Listenable that notifies GoRouter when auth state changes.
class _AuthNotifier extends ChangeNotifier {
  StreamSubscription<AuthState>? _sub;

  _AuthNotifier() {
    _init();
  }

  void _init() {
    try {
      if (getIt.isRegistered<AuthBloc>()) {
        _sub = getIt<AuthBloc>().stream.listen((_) => notifyListeners());
      }
    } catch (_) {
      // DI not ready yet — will work on next router evaluation
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

late final _authNotifier = _AuthNotifier();

// ── Router ──────────────────────────────────────────────────
late final GoRouter appRouter = GoRouter(
  initialLocation: '/home',
  debugLogDiagnostics: true,
  refreshListenable: _authNotifier,
  redirect: (BuildContext context, GoRouterState state) {
    try {
      if (!getIt.isRegistered<AuthBloc>()) return null;
      final authState = getIt<AuthBloc>().state;

    // While auth is still initializing, don't redirect — preserve the URL
    // (critical for PayU return: app reloads and auth hasn't restored yet)
    if (authState is AuthInitial || authState is AuthLoading) return null;

    final isAuthenticated = authState is AuthAuthenticated;
    final currentPath = state.matchedLocation;
    final isAuthPage = _authPages.contains(currentPath);
    final isAuthRequired = _authRequiredPaths.contains(currentPath) ||
        currentPath.startsWith('/orders/') ||
        currentPath.startsWith('/admin/');

    // ── Not authenticated trying to access protected route → login
    if (!isAuthenticated && isAuthRequired) {
      return '/login';
    }

    // ── Authenticated on login/register → redirect to home (or admin dashboard)
    if (isAuthenticated && isAuthPage) {
      final role =
          (authState as AuthAuthenticated).user['role']?.toString().toLowerCase() ?? '';
      return role == 'admin' ? '/admin/dashboard' : '/home';
    }

    // ── Admin-only paths: authenticated non-admin → home
    if (isAuthenticated && _adminPaths.contains(currentPath)) {
      final role =
          (authState as AuthAuthenticated).user['role']?.toString().toLowerCase() ?? '';
      if (role != 'admin') return '/home';
    }

    return null; // no redirect
    } catch (e) {
      debugPrint('[Router] Redirect error: $e');
      return null;
    }
  },
  errorBuilder: (context, state) => const NotFoundScreen(),
  routes: [
    // ── Auth routes (outside shell) ──────────────────────────
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),

    // ── Shell (bottom nav / scaffold) ────────────────────────
    ShellRoute(
      builder: (context, state, child) => ShellScreen(
        child: child,
        currentLocation: state.uri.path,
      ),
      routes: [
        GoRoute(
          path: '/home',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: HomeScreen(),
          ),
        ),
        GoRoute(
          path: '/products',
          pageBuilder: (context, state) => NoTransitionPage(
            child: BlocProvider(
              create: (_) => getIt<ProductsBloc>(),
              child: const ProductsScreen(),
            ),
          ),
        ),
        GoRoute(
          path: '/cart',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: CartScreen(),
          ),
        ),
        GoRoute(
          path: '/orders',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: OrdersScreen(),
          ),
        ),
        GoRoute(
          path: '/profile',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ProfileScreen(),
          ),
        ),
        GoRoute(
          path: '/admin/products',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: AdminProductsScreen(),
          ),
        ),
        GoRoute(
          path: '/admin/orders',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: AdminOrdersScreen(),
          ),
        ),
        GoRoute(
          path: '/admin/dashboard',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: AdminDashboardScreen(),
          ),
        ),
        GoRoute(
          path: '/admin/config',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: AdminStoreConfigScreen(),
          ),
        ),
        GoRoute(
          path: '/admin/policies',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: AdminPoliciesScreen(),
          ),
        ),
        GoRoute(
          path: '/products/:id',
          builder: (context, state) {
            final productId = state.pathParameters['id']!;
            return BlocProvider(
              create: (_) => getIt<ProductsBloc>(),
              child: ProductDetailScreen(productId: productId),
            );
          },
        ),
        GoRoute(
          path: '/orders/:id',
          builder: (context, state) {
            final orderId = state.pathParameters['id']!;
            return OrderDetailScreen(orderId: orderId);
          },
        ),
        GoRoute(
          path: '/admin/orders/:id',
          builder: (context, state) {
            final orderId = state.pathParameters['id']!;
            return AdminOrderDetailScreen(orderId: orderId);
          },
        ),
        GoRoute(
          path: '/addresses',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: AddressesScreen(),
          ),
        ),
        GoRoute(
          path: '/policies',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: PoliciesScreen(),
          ),
        ),
        GoRoute(
          path: '/checkout',
          builder: (context, state) => const CheckoutScreen(),
        ),
        GoRoute(
          path: '/payu-checkout',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>? ?? {};
            return PayuCheckoutScreen(
              orderId: extra['orderId']?.toString() ?? '',
              amount: (extra['amount'] as num?)?.toDouble() ?? 0,
              buyerEmail: extra['buyerEmail']?.toString() ?? '',
              buyerName: extra['buyerName']?.toString() ?? '',
              paymentMethod: extra['paymentMethod']?.toString() ?? '',
            );
          },
        ),
        GoRoute(
          path: '/payment-result',
          builder: (context, state) {
            final orderId = state.uri.queryParameters['orderId'] ?? '';
            final queryParams = Map<String, String>.from(state.uri.queryParameters);
            return PaymentResultScreen(orderId: orderId, queryParams: queryParams);
          },
        ),
      ],
    ),
  ],
);
