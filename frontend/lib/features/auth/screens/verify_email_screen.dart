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
  final TextEditingController _codeCtrl = TextEditingController();
  final FocusNode _codeFocus = FocusNode();
  bool _resendEnabled = true;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  String get _code => _codeCtrl.text;

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
                        // 6-digit code input — single hidden field + visual boxes
                        GestureDetector(
                          onTap: () => _codeFocus.requestFocus(),
                          child: Stack(
                            children: [
                              // Hidden real TextField
                              Opacity(
                                opacity: 0,
                                child: SizedBox(
                                  height: 56,
                                  child: TextField(
                                    controller: _codeCtrl,
                                    focusNode: _codeFocus,
                                    autofocus: true,
                                    keyboardType: TextInputType.number,
                                    maxLength: 6,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(6),
                                    ],
                                    decoration: const InputDecoration(
                                      counterText: '',
                                      border: InputBorder.none,
                                    ),
                                    onChanged: (v) {
                                      setState(() {});
                                      if (v.length == 6) _submit();
                                    },
                                  ),
                                ),
                              ),
                              // Visual digit boxes
                              IgnorePointer(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(6, (i) {
                                    final hasChar = i < _codeCtrl.text.length;
                                    final isFocused = _codeFocus.hasFocus &&
                                        i == _codeCtrl.text.length;
                                    return AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 150),
                                      width: 48,
                                      height: 56,
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF3F4F6),
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isFocused
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                              : hasChar
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                      .withValues(alpha: 0.4)
                                                  : Colors.transparent,
                                          width: 1.5,
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: Text(
                                        hasChar
                                            ? _codeCtrl.text[i]
                                            : '',
                                        style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                            ],
                          ),
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
