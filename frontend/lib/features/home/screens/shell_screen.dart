import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:baseshop/core/di/injection.dart';
import 'package:baseshop/core/theme/app_theme.dart';
import 'package:baseshop/core/services/store_config_service.dart';
import 'package:baseshop/core/cubits/store_config_cubit.dart';
import 'package:baseshop/features/auth/bloc/auth_bloc.dart';
import 'package:baseshop/features/auth/bloc/auth_state.dart';
import 'package:baseshop/features/cart/bloc/cart_bloc.dart';
import 'package:baseshop/features/cart/bloc/cart_state.dart';
import 'package:baseshop/features/notifications/bloc/notifications_bloc.dart';
import 'package:baseshop/features/notifications/bloc/notifications_event.dart';
import 'package:baseshop/features/notifications/bloc/notifications_state.dart';

class ShellScreen extends StatelessWidget {
  final Widget child;
  final String currentLocation;
  const ShellScreen({super.key, required this.child, this.currentLocation = ''});

  static const _guestDestinations = <_NavItem>[
    _NavItem(icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Inicio', path: '/home'),
    _NavItem(icon: Icons.storefront_outlined, selectedIcon: Icons.storefront_rounded, label: 'Tienda', path: '/products'),
    _NavItem(icon: Icons.policy_outlined, selectedIcon: Icons.policy_rounded, label: 'Políticas', path: '/policies'),
    _NavItem(icon: Icons.login_rounded, selectedIcon: Icons.login_rounded, label: 'Ingresar', path: '/login'),
  ];

  static const _clientDestinations = <_NavItem>[
    _NavItem(icon: Icons.home_outlined, selectedIcon: Icons.home_rounded, label: 'Inicio', path: '/home'),
    _NavItem(icon: Icons.storefront_outlined, selectedIcon: Icons.storefront_rounded, label: 'Tienda', path: '/products'),
    _NavItem(icon: Icons.shopping_bag_outlined, selectedIcon: Icons.shopping_bag_rounded, label: 'Carrito', path: '/cart'),
    _NavItem(icon: Icons.receipt_outlined, selectedIcon: Icons.receipt_rounded, label: 'Pedidos', path: '/orders'),
    _NavItem(icon: Icons.notifications_outlined, selectedIcon: Icons.notifications_rounded, label: 'Avisos', path: '/notifications'),
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

        // Wide screen → header nav; narrow screen → bottom nav bar
        final isWeb = MediaQuery.of(context).size.width > 800;
        // Use the location passed from ShellRoute builder (reliable for pushed routes)
        final location = currentLocation.isNotEmpty
            ? currentLocation
            : GoRouterState.of(context).matchedLocation;
        // Home has its own built-in header, so skip the shell header there
        final showWebHeader = isWeb && location != '/home';

        return Scaffold(
          body: showWebHeader
              ? Column(
                  children: [
                    _WebHeaderBar(
                      isAuthenticated: isAuthenticated,
                      isAdmin: isAdmin,
                    ),
                    Expanded(child: child),
                  ],
                )
              : child,
          bottomNavigationBar: isWeb ? null : Container(
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
                          backgroundColor: Theme.of(context).colorScheme.primary,
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
                          backgroundColor: Theme.of(context).colorScheme.primary,
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
    final location = currentLocation.isNotEmpty
        ? currentLocation
        : GoRouterState.of(context).matchedLocation;
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

/// Persistent web header bar with navigation links (shown on all pages except /home).
class _WebHeaderBar extends StatelessWidget {
  final bool isAuthenticated;
  final bool isAdmin;

  const _WebHeaderBar({
    required this.isAuthenticated,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final configState = getIt<StoreConfigCubit>().state;
    final config = configState is StoreConfigLoaded ? configState.config : null;
    final storeName = config?.storeName ?? 'BaseShop';
    final logoPath = config?.storeLogo ?? '';
    final primary = config?.primaryColor ?? AppTheme.defaultPrimary;
    final location = GoRouterState.of(context).matchedLocation;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 48),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          // Logo — click navigates to home (user) or dashboard (admin)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => context.go(isAdmin ? '/admin/dashboard' : '/home'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (logoPath.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        logoPath, width: 36, height: 36, fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => _defaultLogo(primary),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ] else ...[
                    _defaultLogo(primary),
                    const SizedBox(width: 10),
                  ],
                  Text(storeName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                ],
              ),
            ),
          ),

          const Spacer(),

          // Navigation links
          if (!isAdmin) ...[
            _navLink(context, 'Inicio', Icons.home_outlined, '/home', primary, location),
            const SizedBox(width: 6),
            _navLink(context, 'Tienda', Icons.storefront_outlined, '/products', primary, location),
          ],

          if (isAuthenticated && !isAdmin) ...[
            const SizedBox(width: 6),
            _cartNavLink(context, primary, location),
            const SizedBox(width: 6),
            _navLink(context, 'Pedidos', Icons.receipt_outlined, '/orders', primary, location),
          ],

          if (isAdmin) ...[
            const SizedBox(width: 6),
            _navLink(context, 'Panel', Icons.dashboard_outlined, '/admin/dashboard', primary, location),
            const SizedBox(width: 6),
            _navLink(context, 'Productos', Icons.inventory_2_outlined, '/admin/products', primary, location),
            const SizedBox(width: 6),
            _navLink(context, 'Pedidos', Icons.receipt_outlined, '/admin/orders', primary, location),
            const SizedBox(width: 6),
            _navLink(context, 'Config', Icons.settings_outlined, '/admin/config', primary, location),
            const SizedBox(width: 6),
            _navLink(context, 'Políticas', Icons.policy_outlined, '/admin/policies', primary, location),
          ],

          if (!isAdmin) ...[
            const SizedBox(width: 6),
            _navLink(context, 'Políticas', Icons.policy_outlined, '/policies', primary, location),
          ],

          const SizedBox(width: 6),
          if (isAuthenticated)
            _navLink(context, 'Perfil', Icons.person_outline_rounded, '/profile', primary, location)
          else
            _navLink(context, 'Ingresar', Icons.login_rounded, '/login', primary, location),

          // Notification bell — after profile
          if (isAuthenticated && !isAdmin) ...[
            const SizedBox(width: 6),
            _notificationBell(context, primary, location),
          ],
        ],
      ),
    );
  }

  Widget _defaultLogo(Color primary) {
    return Container(
      width: 36, height: 36,
      decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(10)),
      child: const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 18),
    );
  }

  Widget _navLink(BuildContext context, String label, IconData icon, String path, Color primary, String location) {
    final isActive = location.startsWith(path);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: () => context.go(path),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? primary.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? primary : AppTheme.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _notificationBell(BuildContext context, Color primary, String location) {
    final isActive = location.startsWith('/notifications');

    // Trigger a count refresh each time the header is built
    try {
      if (getIt.isRegistered<NotificationsBloc>()) {
        // Use a factory so we need to get it fresh — but we want a lightweight check.
        // Instead, use the repository directly for the badge.
      }
    } catch (_) {}

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: () => context.go('/notifications'),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? primary.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isActive ? Icons.notifications_rounded : Icons.notifications_outlined,
            color: isActive ? primary : AppTheme.textSecondary,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _cartNavLink(BuildContext context, Color primary, String location) {
    final isActive = location.startsWith('/cart');
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: () => context.go('/cart'),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? primary.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: BlocBuilder<CartBloc, CartState>(
            builder: (_, cartState) {
              final count = cartState is CartLoaded ? cartState.items.length : 0;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Carrito',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: isActive ? primary : AppTheme.textSecondary,
                      letterSpacing: 0.2,
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
