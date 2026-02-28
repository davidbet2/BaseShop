import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:baseshop/core/theme/app_theme.dart';
import 'package:baseshop/features/auth/bloc/auth_bloc.dart';
import 'package:baseshop/features/auth/bloc/auth_event.dart';
import 'package:baseshop/features/auth/bloc/auth_state.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _resetFormKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;

  /// 0 = enter email, 1 = enter code + new password
  int _step = 0;
  String _email = '';

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _sendCode() {
    if (!_emailFormKey.currentState!.validate()) return;
    _email = _emailCtrl.text.trim();
    context
        .read<AuthBloc>()
        .add(AuthForgotPasswordRequested(email: _email));
  }

  void _resetPassword() {
    if (!_resetFormKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(AuthResetPasswordRequested(
          email: _email,
          code: _codeCtrl.text.trim(),
          newPassword: _passCtrl.text,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthResetCodeSent) {
            setState(() => _step = 1);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
              ),
            );
          } else if (state is AuthPasswordReset) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Contraseña restablecida. Inicia sesión.'),
                backgroundColor: Colors.green,
              ),
            );
            context.go('/login');
          } else if (state is AuthError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppTheme.errorColor,
              ),
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
                    child: _step == 0
                        ? _buildEmailStep(isLoading)
                        : _buildResetStep(isLoading),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Step 0: Enter email ───────────────────────────────────
  Widget _buildEmailStep(bool isLoading) {
    return Form(
      key: _emailFormKey,
      child: Column(
        children: [
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: _backButton(() {
              context.canPop() ? context.pop() : context.go('/login');
            }),
          ),
          const Spacer(flex: 2),
          // Icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(Icons.lock_reset_rounded,
                size: 40, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 24),
          const Text('¿Olvidaste tu contraseña?',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          const Text(
            'Ingresa tu correo y te enviaremos un código de 6 dígitos para restablecer tu contraseña.',
            style: TextStyle(fontSize: 15, color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _buildInput(
            controller: _emailCtrl,
            hint: 'Correo electrónico',
            icon: Icons.email_outlined,
            inputType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Ingresa tu correo';
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(v.trim())) {
                return 'Correo inválido';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: isLoading ? null : _sendCode,
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : const Text('Enviar código',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('¿Recordaste tu contraseña? ',
                  style: TextStyle(
                      color: AppTheme.textSecondary, fontSize: 14)),
              GestureDetector(
                onTap: () => context.go('/login'),
                child: Text('Inicia sesión',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14)),
              ),
            ],
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }

  // ── Step 1: Enter code + new password ─────────────────────
  Widget _buildResetStep(bool isLoading) {
    return Form(
      key: _resetFormKey,
      child: Column(
        children: [
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: _backButton(() => setState(() => _step = 0)),
          ),
          const Spacer(flex: 1),
          // Icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(Icons.password_rounded,
                size: 40, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 24),
          const Text('Restablecer contraseña',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              text: 'Ingresa el código enviado a ',
              style: const TextStyle(
                  fontSize: 15, color: AppTheme.textSecondary),
              children: [
                TextSpan(
                  text: _email,
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          // Code field
          _buildInput(
            controller: _codeCtrl,
            hint: 'Código de 6 dígitos',
            icon: Icons.pin_outlined,
            inputType: TextInputType.number,
            formatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(6),
            ],
            validator: (v) {
              if (v == null || v.trim().length != 6) {
                return 'Ingresa el código de 6 dígitos';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          // New password
          _buildInput(
            controller: _passCtrl,
            hint: 'Nueva contraseña',
            icon: Icons.lock_outline_rounded,
            obscure: _obscure1,
            suffix: IconButton(
              onPressed: () => setState(() => _obscure1 = !_obscure1),
              icon: Icon(
                  _obscure1
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: AppTheme.textSecondary),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Ingresa tu nueva contraseña';
              if (v.length < 8) return 'Mínimo 8 caracteres';
              return null;
            },
          ),
          const SizedBox(height: 14),
          // Confirm password
          _buildInput(
            controller: _confirmCtrl,
            hint: 'Confirmar contraseña',
            icon: Icons.lock_outline_rounded,
            obscure: _obscure2,
            suffix: IconButton(
              onPressed: () => setState(() => _obscure2 = !_obscure2),
              icon: Icon(
                  _obscure2
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 20,
                  color: AppTheme.textSecondary),
            ),
            onSubmit: (_) => _resetPassword(),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Confirma tu contraseña';
              if (v != _passCtrl.text) return 'Las contraseñas no coinciden';
              return null;
            },
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: isLoading ? null : _resetPassword,
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: Colors.white))
                  : const Text('Restablecer contraseña',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  // ── Shared helpers ────────────────────────────────────────
  Widget _backButton(VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.arrow_back_rounded,
            size: 20, color: AppTheme.textPrimary),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType inputType = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
    ValueChanged<String>? onSubmit,
    String? Function(String?)? validator,
    List<TextInputFormatter>? formatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: inputType,
      obscureText: obscure,
      onFieldSubmitted: onSubmit,
      inputFormatters: formatters,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 20, color: AppTheme.textSecondary),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppTheme.errorColor)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: validator,
    );
  }
}
