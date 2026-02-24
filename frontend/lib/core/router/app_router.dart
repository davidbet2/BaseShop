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
import 'package:baseshop/features/admin/screens/admin_products_screen.dart';
import 'package:baseshop/features/admin/screens/admin_orders_screen.dart';
import 'package:baseshop/features/admin/screens/admin_dashboard_screen.dart';
import 'package:baseshop/features/home/screens/shell_screen.dart';

// ── Auth-only paths (require login) ─────────────────────────
const _authRequiredPaths = <String>{
  '/orders',
  '/profile',
  '/checkout',
  '/addresses',
  '/admin/dashboard',
  '/admin/products',
  '/admin/orders',
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
};

/// Listenable that notifies GoRouter when auth state changes.
class _AuthNotifier extends ChangeNotifier {
  late final StreamSubscription<AuthState> _sub;

  _AuthNotifier() {
    _sub = getIt<AuthBloc>().stream.listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final _authNotifier = _AuthNotifier();

// ── Router ──────────────────────────────────────────────────
final GoRouter appRouter = GoRouter(
  initialLocation: '/home',
  debugLogDiagnostics: true,
  refreshListenable: _authNotifier,
  redirect: (BuildContext context, GoRouterState state) {
    final authState = getIt<AuthBloc>().state;
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
      builder: (context, state, child) => ShellScreen(child: child),
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
      ],
    ),

    // ── Full-screen routes (outside shell) ───────────────────
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
      path: '/checkout',
      builder: (context, state) => const CheckoutScreen(),
    ),
    GoRoute(
      path: '/addresses',
      builder: (context, state) => const AddressesScreen(),
    ),
  ],
);
