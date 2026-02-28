import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:baseshop/core/theme/app_theme.dart';
import 'package:baseshop/features/auth/bloc/auth_bloc.dart';
import 'package:baseshop/features/auth/bloc/auth_event.dart';
import 'package:baseshop/features/auth/bloc/auth_state.dart';

class VerifyEmailScreen extends StatefulWidget {
  final String email;
  const VerifyEmailScreen({super.key, required this.email});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _resendEnabled = true;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _submit() {
    final code = _code;
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresa el código completo de 6 dígitos'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    context.read<AuthBloc>().add(AuthVerifyEmailRequested(
          email: widget.email,
          code: code,
        ));
  }

  void _resend() {
    if (!_resendEnabled) return;
    context.read<AuthBloc>().add(
          AuthResendVerificationRequested(email: widget.email),
        );
    setState(() => _resendEnabled = false);
    Future.delayed(const Duration(seconds: 60), () {
      if (mounted) setState(() => _resendEnabled = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthAuthenticated) {
            final role =
                (state.user['role']?.toString().toLowerCase() ?? '');
            context.go(role == 'admin' ? '/admin/dashboard' : '/home');
          } else if (state is AuthVerificationResent) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Código reenviado. Revisa tu correo.'),
                backgroundColor: Colors.green,
              ),
            );
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
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: GestureDetector(
                            onTap: () => context.canPop()
                                ? context.pop()
                                : context.go('/login'),
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
                          ),
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
                          child: Icon(Icons.mark_email_read_outlined,
                              size: 40,
                              color: Theme.of(context).colorScheme.primary),
                        ),
                        const SizedBox(height: 24),
                        const Text('Verifica tu correo',
                            style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary)),
                        const SizedBox(height: 8),
                        Text(
                          'Enviamos un código de 6 dígitos a',
                          style: const TextStyle(
                              fontSize: 15, color: AppTheme.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.email,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.primary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 36),
                        // 6-digit code input
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(6, (i) {
                            return Container(
                              width: 48,
                              height: 56,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              child: TextField(
                                controller: _controllers[i],
                                focusNode: _focusNodes[i],
                                textAlign: TextAlign.center,
                                keyboardType: TextInputType.number,
                                maxLength: 1,
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: InputDecoration(
                                  counterText: '',
                                  filled: true,
                                  fillColor: const Color(0xFFF3F4F6),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        width: 1.5),
                                  ),
                                ),
                                onChanged: (v) {
                                  if (v.isNotEmpty && i < 5) {
                                    _focusNodes[i + 1].requestFocus();
                                  } else if (v.isEmpty && i > 0) {
                                    _focusNodes[i - 1].requestFocus();
                                  }
                                  if (_code.length == 6) _submit();
                                },
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 28),
                        // Verify button
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _submit,
                            child: isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white))
                                : const Text('Verificar',
                                    style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Resend
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('¿No recibiste el código? ',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 14)),
                            GestureDetector(
                              onTap: _resendEnabled ? _resend : null,
                              child: Text(
                                'Reenviar',
                                style: TextStyle(
                                  color: _resendEnabled
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.grey,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(flex: 3),
                      ],
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
}
