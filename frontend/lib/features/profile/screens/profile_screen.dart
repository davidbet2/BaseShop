import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:baseshop/core/di/injection.dart';
import 'package:baseshop/core/theme/app_theme.dart';
import 'package:baseshop/features/auth/bloc/auth_bloc.dart';
import 'package:baseshop/features/auth/bloc/auth_event.dart';
import 'package:baseshop/features/auth/bloc/auth_state.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const String _appVersion = '1.0.0+1';

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      bloc: getIt<AuthBloc>(),
      builder: (context, state) {
        final user =
            state is AuthAuthenticated ? state.user : <String, dynamic>{};
        final firstName = (user['firstName'] ?? user['first_name'] ?? '').toString();
        final lastName = (user['lastName'] ?? user['last_name'] ?? '').toString();
        final fullName = '$firstName $lastName'.trim();
        final email = (user['email'] ?? '').toString();
        final avatar = (user['avatar'] ?? user['profileImage'] ?? '').toString();
        final role = (user['role'] ?? 'customer').toString();
        final initials = _getInitials(firstName, lastName);

        return Scaffold(
          appBar: AppBar(title: const Text('Mi Perfil')),
          body: ListView(
            children: [
              // ── Avatar + Info Header ──
              Container(
                padding: const EdgeInsets.symmetric(vertical: 32),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.05),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: AppTheme.primaryColor,
                      backgroundImage: avatar.isNotEmpty
                          ? CachedNetworkImageProvider(avatar)
                          : null,
                      child: avatar.isEmpty
                          ? Text(
                              initials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 12),
                    if (fullName.isNotEmpty)
                      Text(
                        fullName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (email.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        email,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ── Account Section ──
              _buildSectionHeader('Cuenta'),
              _buildMenuItem(
                icon: Icons.person_outline,
                title: 'Mi Perfil',
                subtitle: 'Editar información personal',
                onTap: () => _showEditProfileDialog(context, user),
              ),
              _buildMenuItem(
                icon: Icons.location_on_outlined,
                title: 'Mis Direcciones',
                subtitle: 'Gestionar direcciones de envío',
                onTap: () {
                  // TODO: Navigate to addresses screen
                },
              ),
              _buildMenuItem(
                icon: Icons.favorite_border,
                title: 'Mis Favoritos',
                subtitle: 'Productos guardados',
                onTap: () => context.go('/favorites'),
              ),
              _buildMenuItem(
                icon: Icons.receipt_long_outlined,
                title: 'Mis Pedidos',
                subtitle: 'Historial de compras',
                onTap: () => context.go('/orders'),
              ),
              _buildMenuItem(
                icon: Icons.rate_review_outlined,
                title: 'Mis Reseñas',
                subtitle: 'Reseñas que has escrito',
                onTap: () {
                  // TODO: Navigate to my reviews screen
                },
              ),

              const Divider(height: 1),
              const SizedBox(height: 8),

              // ── Security Section ──
              _buildSectionHeader('Seguridad'),
              _buildMenuItem(
                icon: Icons.lock_outline,
                title: 'Cambiar contraseña',
                subtitle: 'Actualiza tu contraseña',
                onTap: () => _showChangePasswordDialog(context),
              ),

              // ── Admin Section ──
              if (role == 'admin') ...[
                const Divider(height: 1),
                const SizedBox(height: 8),
                _buildSectionHeader('Administración'),
                _buildMenuItem(
                  icon: Icons.dashboard_outlined,
                  title: 'Dashboard',
                  subtitle: 'Panel de control',
                  onTap: () => context.go('/admin/dashboard'),
                ),
                _buildMenuItem(
                  icon: Icons.inventory_2_outlined,
                  title: 'Gestionar Productos',
                  subtitle: 'Agregar, editar y eliminar productos',
                  onTap: () => context.go('/admin/products'),
                ),
                _buildMenuItem(
                  icon: Icons.local_shipping_outlined,
                  title: 'Gestionar Pedidos',
                  subtitle: 'Administrar pedidos de clientes',
                  onTap: () => context.go('/admin/orders'),
                ),
              ],

              const Divider(height: 1),
              const SizedBox(height: 8),

              // ── Other Section ──
              _buildSectionHeader('Otros'),
              _buildMenuItem(
                icon: Icons.info_outline,
                title: 'Sobre nosotros',
                subtitle: 'Información de la aplicación',
                onTap: () => _showAboutDialog(context),
              ),
              _buildMenuItem(
                icon: Icons.logout,
                title: 'Cerrar sesión',
                titleColor: AppTheme.errorColor,
                iconColor: AppTheme.errorColor,
                onTap: () => _confirmLogout(context),
              ),

              // ── Version ──
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Versión $_appVersion',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? titleColor,
    Color? iconColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? AppTheme.primaryColor),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: titleColor,
        ),
      ),
      subtitle: subtitle != null
          ? Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))
          : null,
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  String _getInitials(String firstName, String lastName) {
    final f = firstName.isNotEmpty ? firstName[0].toUpperCase() : '';
    final l = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    if (f.isEmpty && l.isEmpty) return '?';
    return '$f$l';
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              getIt<AuthBloc>().add(const AuthLogoutRequested());
            },
            child: const Text('Cerrar sesión',
                style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(
      BuildContext context, Map<String, dynamic> user) {
    final firstNameCtrl = TextEditingController(
        text: (user['firstName'] ?? user['first_name'] ?? '').toString());
    final lastNameCtrl = TextEditingController(
        text: (user['lastName'] ?? user['last_name'] ?? '').toString());
    final phoneCtrl = TextEditingController(
        text: (user['phone'] ?? '').toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar Perfil'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: firstNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: lastNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Apellido',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Teléfono',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: dispatch profile update event
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Perfil actualizado')),
              );
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final currentPasswordCtrl = TextEditingController();
    final newPasswordCtrl = TextEditingController();
    final confirmPasswordCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambiar Contraseña'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Contraseña actual',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newPasswordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Nueva contraseña',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPasswordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirmar contraseña',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (newPasswordCtrl.text != confirmPasswordCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Las contraseñas no coinciden'),
                    backgroundColor: AppTheme.errorColor,
                  ),
                );
                return;
              }
              // TODO: dispatch change password event
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Contraseña actualizada')),
              );
            },
            child: const Text('Cambiar'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.shopping_bag, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
            const Text('BaseShop'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tu tienda de confianza',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            if (_appVersion.isNotEmpty)
              Text(
                'Versión: $_appVersion',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            const SizedBox(height: 16),
            Text(
              '© ${DateTime.now().year} BaseShop. Todos los derechos reservados.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
