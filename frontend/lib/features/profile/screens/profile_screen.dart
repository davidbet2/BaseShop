import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:get_it/get_it.dart';

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
  final String _appVersion = '1.0.0+1';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: BlocConsumer<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthUnauthenticated) {
              context.go('/home');
            }
          },
          builder: (context, state) {
            if (state is! AuthAuthenticated) {
              return _buildGuestView();
            }
            final user = state.user;
            final firstName = (user['first_name'] ?? user['firstName'] ?? '').toString();
            final lastName = (user['last_name'] ?? user['lastName'] ?? '').toString();
            final email = (user['email'] ?? '').toString();
            final role = (user['role'] ?? '').toString().toLowerCase();
            final fullName = '$firstName $lastName'.trim();
            final initials = '${firstName.isNotEmpty ? firstName[0] : ''}${lastName.isNotEmpty ? lastName[0] : ''}'.toUpperCase();

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // Avatar & info
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.5)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.primaryColor, Color(0xFFFB923C)],
                              begin: Alignment.topLeft, end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Center(child: Text(initials, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white))),
                        ),
                        const SizedBox(height: 14),
                        Text(fullName.isNotEmpty ? fullName : 'Usuario',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                        const SizedBox(height: 4),
                        Text(email, style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: role == 'admin' ? const Color(0xFFFEF3C7) : AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            role == 'admin' ? 'Administrador' : 'Cliente',
                            style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600,
                              color: role == 'admin' ? const Color(0xFFD97706) : AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Account section
                  _buildSection('Cuenta', [
                    _buildMenuItem(Icons.person_outline_rounded, 'Editar perfil', () => _showEditProfileDialog(user)),
                    _buildMenuItem(Icons.lock_outline_rounded, 'Cambiar contrase\u00f1a', () => _showChangePasswordDialog()),
                  ]),

                  const SizedBox(height: 14),

                  // Features section (non-admin only)
                  if (role != 'admin') ...[
                    _buildSection('Mis actividades', [
                      _buildMenuItem(Icons.favorite_border_rounded, 'Favoritos', () => context.push('/favorites')),
                      _buildMenuItem(Icons.receipt_long_rounded, 'Mis pedidos', () {}),
                      _buildMenuItem(Icons.star_border_rounded, 'Mis rese\u00f1as', () {}),
                    ]),
                    const SizedBox(height: 14),
                  ],

                  // Admin section
                  if (role == 'admin') ...[
                    _buildSection('Administraci\u00f3n', [
                      _buildMenuItem(Icons.dashboard_rounded, 'Panel de control', () => context.go('/admin/dashboard')),
                      _buildMenuItem(Icons.inventory_2_outlined, 'Gestionar productos', () => context.go('/admin/products')),
                    ]),
                    const SizedBox(height: 14),
                  ],

                  // General section
                  _buildSection('General', [
                    _buildMenuItem(Icons.help_outline_rounded, 'Ayuda y soporte', () {}),
                    _buildMenuItem(Icons.info_outline_rounded, 'Acerca de', () => _showAboutDialog()),
                  ]),

                  const SizedBox(height: 14),

                  // Logout
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.5)),
                    ),
                    child: ListTile(
                      onTap: () => _showLogoutDialog(),
                      leading: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.logout_rounded, size: 20, color: AppTheme.errorColor),
                      ),
                      title: const Text('Cerrar sesi\u00f3n', style: TextStyle(fontWeight: FontWeight.w600, color: AppTheme.errorColor)),
                      trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.errorColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),

                  const SizedBox(height: 20),
                  Text('Versi\u00f3n $_appVersion', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGuestView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_outline_rounded, size: 48, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 24),
          const Text('Inicia sesi\u00f3n', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          const Text('Accede a tu cuenta para ver tu perfil', style: TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.push('/login'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14)),
            child: const Text('Iniciar sesi\u00f3n', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> items) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 0.5)),
          ),
          ...items,
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: AppTheme.textPrimary),
      ),
      title: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
      trailing: const Icon(Icons.chevron_right_rounded, size: 22, color: AppTheme.textSecondary),
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('\u00bfCerrar sesi\u00f3n?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Se cerrar\u00e1 tu sesi\u00f3n actual.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuthBloc>().add(const AuthLogoutRequested());
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Cerrar sesi\u00f3n'),
          ),
        ],
      ),
    );
  }

  void _showEditProfileDialog(Map<String, dynamic> user) {
    final firstCtrl = TextEditingController(text: (user['first_name'] ?? user['firstName'] ?? '').toString());
    final lastCtrl = TextEditingController(text: (user['last_name'] ?? user['lastName'] ?? '').toString());
    final phoneCtrl = TextEditingController(text: (user['phone'] ?? '').toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Editar perfil', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: firstCtrl, decoration: const InputDecoration(labelText: 'Nombre')),
            const SizedBox(height: 12),
            TextField(controller: lastCtrl, decoration: const InputDecoration(labelText: 'Apellido')),
            const SizedBox(height: 12),
            TextField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Tel\u00e9fono')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Perfil actualizado'),
                  backgroundColor: AppTheme.successColor,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cambiar contrase\u00f1a', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: currentCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Contrase\u00f1a actual')),
            const SizedBox(height: 12),
            TextField(controller: newCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Nueva contrase\u00f1a')),
            const SizedBox(height: 12),
            TextField(controller: confirmCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Confirmar contrase\u00f1a')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (newCtrl.text != confirmCtrl.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: const Text('Las contrase\u00f1as no coinciden'), backgroundColor: AppTheme.errorColor),
                );
                return;
              }
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Contrase\u00f1a actualizada'),
                  backgroundColor: AppTheme.successColor,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            child: const Text('Cambiar'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.shopping_bag_rounded, size: 22, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 12),
            const Text('BaseShop', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Versi\u00f3n $_appVersion', style: const TextStyle(color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            const Text('Tu tienda en l\u00ednea favorita.', style: TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }
}
