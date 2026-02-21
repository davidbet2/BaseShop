import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:baseshop/core/di/injection.dart';
import 'package:baseshop/core/router/not_found_screen.dart';
import 'package:baseshop/features/auth/bloc/auth_bloc.dart';
import 'package:baseshop/features/auth/bloc/auth_state.dart';

import 'package:baseshop/features/auth/screens/login_screen.dart';
import 'package:baseshop/features/auth/screens/register_screen.dart';
import 'package:baseshop/features/home/screens/home_screen.dart';
import 'package:baseshop/features/products/screens/products_screen.dart';
import 'package:baseshop/features/products/screens/product_detail_screen.dart';
import 'package:baseshop/features/cart/screens/cart_screen.dart';
import 'package:baseshop/features/orders/screens/orders_screen.dart';
import 'package:baseshop/features/orders/screens/order_detail_screen.dart';
import 'package:baseshop/features/favorites/screens/favorites_screen.dart';
import 'package:baseshop/features/profile/screens/profile_screen.dart';
import 'package:baseshop/features/admin/screens/admin_products_screen.dart';
import 'package:baseshop/features/admin/screens/admin_orders_screen.dart';
import 'package:baseshop/features/admin/screens/admin_dashboard_screen.dart';
import 'package:baseshop/features/home/screens/shell_screen.dart';

// ── Public paths (no auth required) ─────────────────────────
const _publicPaths = <String>{
  '/login',
  '/register',
  '/forgot-password',
};

// ── Router ──────────────────────────────────────────────────
final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
  debugLogDiagnostics: true,
  redirect: (BuildContext context, GoRouterState state) {
    final isAuthenticated =
        getIt<AuthBloc>().state is AuthAuthenticated;
    final currentPath = state.matchedLocation;
    final isPublicRoute = _publicPaths.contains(currentPath);

    // Not authenticated → force login (unless already on public route)
    if (!isAuthenticated && !isPublicRoute) {
      return '/login';
    }

    // Authenticated but on a public route → redirect to home
    if (isAuthenticated && isPublicRoute) {
      return '/home';
    }

    return null; // no redirect
  },
  errorBuilder: (context, state) => const NotFoundScreen(),
  routes: [
    // ── Public routes ────────────────────────────────────────
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
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ProductsScreen(),
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
          path: '/favorites',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: FavoritesScreen(),
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
        return ProductDetailScreen(productId: productId);
      },
    ),
    GoRoute(
      path: '/orders/:id',
      builder: (context, state) {
        final orderId = state.pathParameters['id']!;
        return OrderDetailScreen(orderId: orderId);
      },
    ),
  ],
);
