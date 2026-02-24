import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:baseshop/core/theme/app_theme.dart';
import 'package:baseshop/features/auth/bloc/auth_bloc.dart';
import 'package:baseshop/features/auth/bloc/auth_state.dart';
import 'package:baseshop/features/cart/bloc/cart_bloc.dart';
import 'package:baseshop/features/cart/bloc/cart_state.dart';

class ShellScreen extends StatelessWidget {
  final Widget child;
  const ShellScreen({super.key, required this.child});

  static const _guestDestinations = <_NavItem>[
    _NavItem(icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Inicio', path: '/home'),
    _NavItem(icon: Icons.storefront_outlined, selectedIcon: Icons.storefront_rounded, label: 'Tienda', path: '/products'),
    _NavItem(icon: Icons.login_rounded, selectedIcon: Icons.login_rounded, label: 'Ingresar', path: '/login'),
  ];

  static const _clientDestinations = <_NavItem>[
    _NavItem(icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Inicio', path: '/home'),
    _NavItem(icon: Icons.storefront_outlined, selectedIcon: Icons.storefront_rounded, label: 'Tienda', path: '/products'),
    _NavItem(icon: Icons.shopping_bag_outlined, selectedIcon: Icons.shopping_bag_rounded, label: 'Carrito', path: '/cart'),
    _NavItem(icon: Icons.receipt_outlined, selectedIcon: Icons.receipt_rounded, label: 'Pedidos', path: '/orders'),
    _NavItem(icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Perfil', path: '/profile'),
  ];

  static const _adminDestinations = <_NavItem>[
    _NavItem(icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard_rounded, label: 'Panel', path: '/admin/dashboard'),
    _NavItem(icon: Icons.inventory_2_outlined, selectedIcon: Icons.inventory_2_rounded, label: 'Productos', path: '/admin/products'),
    _NavItem(icon: Icons.receipt_outlined, selectedIcon: Icons.receipt_rounded, label: 'Pedidos', path: '/admin/orders'),
    _NavItem(icon: Icons.settings_outlined, selectedIcon: Icons.settings_rounded, label: 'Config', path: '/admin/config'),
    _NavItem(icon: Icons.person_outline_rounded, selectedIcon: Icons.person_rounded, label: 'Perfil', path: '/profile'),
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
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              border: Border(
                top: BorderSide(
                  color: AppTheme.dividerColor.withValues(alpha: 0.5),
                ),
              ),
            ),
            child: NavigationBar(
              selectedIndex: currentIndex,
              onDestinationSelected: (index) => context.go(destinations[index].path),
              destinations: destinations.map((item) {
                if (item.path == '/cart') {
                  return NavigationDestination(
                    icon: BlocBuilder<CartBloc, CartState>(
                      builder: (_, cartState) {
                        final count = cartState is CartLoaded ? cartState.items.length : 0;
                        return Badge(
                          isLabelVisible: count > 0,
                          label: Text('$count'),
                          backgroundColor: AppTheme.primaryColor,
                          child: Icon(item.icon),
                        );
                      },
                    ),
                    selectedIcon: BlocBuilder<CartBloc, CartState>(
                      builder: (_, cartState) {
                        final count = cartState is CartLoaded ? cartState.items.length : 0;
                        return Badge(
                          isLabelVisible: count > 0,
                          label: Text('$count'),
                          backgroundColor: AppTheme.primaryColor,
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
          ),
        );
      },
    );
  }

  bool _resolveIsAdmin(AuthState state) {
    if (state is AuthAuthenticated) {
      return (state.user['role']?.toString().toLowerCase() ?? '') == 'admin';
    }
    return false;
  }

  int _calculateSelectedIndex(BuildContext context, List<_NavItem> destinations) {
    final location = GoRouterState.of(context).matchedLocation;
    for (int i = 0; i < destinations.length; i++) {
      if (location.startsWith(destinations[i].path)) return i;
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
