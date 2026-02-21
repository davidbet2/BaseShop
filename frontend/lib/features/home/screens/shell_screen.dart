import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:baseshop/features/auth/bloc/auth_bloc.dart';
import 'package:baseshop/features/auth/bloc/auth_state.dart';
import 'package:baseshop/features/cart/bloc/cart_bloc.dart';
import 'package:baseshop/features/cart/bloc/cart_state.dart';

class ShellScreen extends StatelessWidget {
  final Widget child;

  const ShellScreen({super.key, required this.child});

  // ── Guest navigation (unauthenticated) ──
  static const _guestDestinations = <_NavItem>[
    _NavItem(icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'Inicio', path: '/home'),
    _NavItem(icon: Icons.store_outlined, selectedIcon: Icons.store, label: 'Productos', path: '/products'),
    _NavItem(icon: Icons.login, selectedIcon: Icons.login, label: 'Ingresar', path: '/login'),
  ];

  // ── Client navigation ──
  static const _clientDestinations = <_NavItem>[
    _NavItem(icon: Icons.home_outlined, selectedIcon: Icons.home, label: 'Inicio', path: '/home'),
    _NavItem(icon: Icons.store_outlined, selectedIcon: Icons.store, label: 'Productos', path: '/products'),
    _NavItem(icon: Icons.shopping_cart_outlined, selectedIcon: Icons.shopping_cart, label: 'Carrito', path: '/cart'),
    _NavItem(icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long, label: 'Pedidos', path: '/orders'),
    _NavItem(icon: Icons.person_outline, selectedIcon: Icons.person, label: 'Perfil', path: '/profile'),
  ];

  // ── Admin navigation ──
  static const _adminDestinations = <_NavItem>[
    _NavItem(icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard, label: 'Dashboard', path: '/admin/dashboard'),
    _NavItem(icon: Icons.inventory_2_outlined, selectedIcon: Icons.inventory_2, label: 'Productos', path: '/admin/products'),
    _NavItem(icon: Icons.receipt_long_outlined, selectedIcon: Icons.receipt_long, label: 'Pedidos', path: '/admin/orders'),
    _NavItem(icon: Icons.person_outline, selectedIcon: Icons.person, label: 'Perfil', path: '/profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final isAuthenticated = authState is AuthAuthenticated;
        final isAdmin = _resolveIsAdmin(authState);

        final destinations = !isAuthenticated
            ? _guestDestinations
            : isAdmin
                ? _adminDestinations
                : _clientDestinations;
        final currentIndex = _calculateSelectedIndex(context, destinations);

        return Scaffold(
          body: child,
          bottomNavigationBar: NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: (index) {
              final path = destinations[index].path;
              context.go(path);
            },
            destinations: destinations.map((item) {
              // Cart badge for client tab
              if (item.path == '/cart') {
                return NavigationDestination(
                  icon: BlocBuilder<CartBloc, CartState>(
                    builder: (context, cartState) {
                      final count = cartState is CartLoaded
                          ? cartState.items.length
                          : 0;
                      return Badge(
                        isLabelVisible: count > 0,
                        label: Text('$count'),
                        child: Icon(item.icon),
                      );
                    },
                  ),
                  selectedIcon: BlocBuilder<CartBloc, CartState>(
                    builder: (context, cartState) {
                      final count = cartState is CartLoaded
                          ? cartState.items.length
                          : 0;
                      return Badge(
                        isLabelVisible: count > 0,
                        label: Text('$count'),
                        child: Icon(item.selectedIcon),
                      );
                    },
                  ),
                  label: item.label,
                );
              }

              return NavigationDestination(
                icon: Icon(item.icon),
                selectedIcon: Icon(item.selectedIcon),
                label: item.label,
              );
            }).toList(),
          ),
        );
      },
    );
  }

  bool _resolveIsAdmin(AuthState state) {
    if (state is AuthAuthenticated) {
      final role = state.user['role']?.toString().toLowerCase() ?? '';
      return role == 'admin';
    }
    return false;
  }

  int _calculateSelectedIndex(BuildContext context, List<_NavItem> destinations) {
    final location = GoRouterState.of(context).matchedLocation;
    for (int i = 0; i < destinations.length; i++) {
      if (location.startsWith(destinations[i].path)) {
        return i;
      }
    }
    return 0;
  }
}

class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String path;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.path,
  });
}
