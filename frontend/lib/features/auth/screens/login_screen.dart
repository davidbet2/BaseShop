import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:baseshop/core/theme/app_theme.dart';
import 'package:baseshop/core/di/injection.dart';
import 'package:baseshop/core/services/store_config_service.dart';
import 'package:baseshop/core/cubits/store_config_cubit.dart';
import 'package:baseshop/features/auth/bloc/auth_bloc.dart';
import 'package:baseshop/features/auth/bloc/auth_event.dart';
import 'package:baseshop/features/auth/bloc/auth_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(AuthLoginRequested(
      email: _emailCtrl.text.trim(),
      password: _passwordCtrl.text,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            final role = (state.user['role']?.toString().toLowerCase() ?? '');
            context.go(role == 'admin' ? '/admin/dashboard' : '/home');
          } else if (state is AuthVerificationRequired) {
            context.go('/verify-email', extra: {'email': state.email});
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: AppTheme.errorColor),
            );
          }
        },
        builder: (context, state) {
          final isLoading = state is AuthLoading;
          return SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          // Top bar: back + skip
                          Align(
                            alignment: Alignment.centerLeft,
                            child: _circleButton(Icons.arrow_back_rounded, () {
                              context.canPop() ? context.pop() : context.go('/home');
                            }),
                          ),

                          const Spacer(flex: 2),

                          // Logo
                          Builder(
                            builder: (context) {
                              final configState = getIt<StoreConfigCubit>().state;
                              final config = configState is StoreConfigLoaded ? configState.config : null;
                              final logoUrl = config?.storeLogo ?? '';
                              final primary = config?.primaryColor ?? Theme.of(context).colorScheme.primary;

                              if (logoUrl.isNotEmpty) {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(22),
                                  child: Image.network(
                                    logoUrl, width: 72, height: 72, fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => _defaultLogo(primary),
                                  ),
                                );
                              }
                              return _defaultLogo(primary);
                            },
                          ),
                          const SizedBox(height: 24),
                          Builder(
                            builder: (context) {
                              final configState = getIt<StoreConfigCubit>().state;
                              final storeName = configState is StoreConfigLoaded
                                  ? configState.config.storeName
                                  : 'BaseShop';
                              return Text(storeName, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.textPrimary));
                            },
                          ),
                          const SizedBox(height: 6),
                          const Text('Inicia sesi\u00f3n para continuar', style: TextStyle(fontSize: 15, color: AppTheme.textSecondary)),

                          const Spacer(flex: 2),

                          // Email
                          _buildInput(
                            controller: _emailCtrl,
                            hint: 'Correo electr\u00f3nico',
                            icon: Icons.email_outlined,
                            inputType: TextInputType.emailAddress,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Ingresa tu correo';
                              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v.trim())) return 'Correo inv\u00e1lido';
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          // Password
                          _buildInput(
                            controller: _passwordCtrl,
                            hint: 'Contrase\u00f1a',
                            icon: Icons.lock_outline_rounded,
                            obscure: _obscure,
                            suffix: IconButton(
                              onPressed: () => setState(() => _obscure = !_obscure),
                              icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: AppTheme.textSecondary),
                            ),
                            onSubmit: (_) => _submit(),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Ingresa tu contrase\u00f1a';
                              if (v.length < 8) return 'Mínimo 8 caracteres';
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => context.go('/forgot-password'),
                              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                              child: Text('¿Olvidaste tu contraseña?', style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.primary)),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Login button
                          SizedBox(
                            width: double.infinity, height: 54,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : _submit,
                              child: isLoading
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                : const Text('Iniciar sesi\u00f3n', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Divider
                          Row(children: [
                            const Expanded(child: Divider(color: AppTheme.dividerColor)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text('o contin\u00faa con', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                            ),
                            const Expanded(child: Divider(color: AppTheme.dividerColor)),
                          ]),
                          const SizedBox(height: 20),

                          // Social buttons
                          SizedBox(
                            width: double.infinity,
                            child: _socialButton(Icons.g_mobiledata_rounded, 'Google',
                              onTap: isLoading ? null : () => context.read<AuthBloc>().add(const AuthGoogleSignInRequested())),
                          ),

                          const Spacer(flex: 3),

                          // Register link
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('\u00bfNo tienes cuenta? ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                                GestureDetector(
                                  onTap: () => context.go('/register'),
                                  child: Text('Regístrate', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700, fontSize: 14)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42, height: 42,
        decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(14)),
        child: Icon(icon, size: 20, color: AppTheme.textPrimary),
      ),
    );
  }

  Widget _defaultLogo(Color primary) {
    return Container(
      width: 72, height: 72,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary, primary.withValues(alpha: 0.7)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: const Icon(Icons.shopping_bag_rounded, size: 34, color: Colors.white),
    );
  }

  Widget _buildInput({
    required TextEditingController controller, required String hint, required IconData icon,
    TextInputType inputType = TextInputType.text, bool obscure = false, Widget? suffix,
    ValueChanged<String>? onSubmit, String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller, keyboardType: inputType, obscureText: obscure,
      onFieldSubmitted: onSubmit, style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: AppTheme.textSecondary),
        suffixIcon: suffix,
        filled: true, fillColor: const Color(0xFFF3F4F6),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.errorColor)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: validator,
    );
  }

  Widget _socialButton(IconData icon, String label, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: AppTheme.textPrimary),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          ],
        ),
      ),
    );
  }
}
