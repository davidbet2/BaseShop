import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:baseshop/core/di/injection.dart';
import 'package:baseshop/core/theme/app_theme.dart';
import 'package:baseshop/features/payments/bloc/payments_bloc.dart';
import 'package:baseshop/features/payments/bloc/payments_event.dart';
import 'package:baseshop/features/payments/bloc/payments_state.dart';
import 'package:baseshop/features/payments/screens/payu_form_helper.dart';

/// Screen that handles the PayU checkout redirect.
/// Creates a payment intent and then redirects to PayU's checkout page.
class PayuCheckoutScreen extends StatefulWidget {
  final String orderId;
  final double amount;
  final String buyerEmail;
  final String buyerName;
  final String paymentMethod;

  const PayuCheckoutScreen({
    super.key,
    required this.orderId,
    required this.amount,
    required this.buyerEmail,
    required this.buyerName,
    required this.paymentMethod,
  });

  @override
  State<PayuCheckoutScreen> createState() => _PayuCheckoutScreenState();
}

class _PayuCheckoutScreenState extends State<PayuCheckoutScreen> {
  late final PaymentsBloc _paymentsBloc;
  bool _redirecting = false;

  @override
  void initState() {
    super.initState();
    _paymentsBloc = getIt<PaymentsBloc>();
    // Create payment intent immediately
    _paymentsBloc.add(CreatePayment(
      orderId: widget.orderId,
      amount: widget.amount,
      buyerEmail: widget.buyerEmail,
      buyerName: widget.buyerName,
      paymentMethod: widget.paymentMethod,
    ));
  }

  @override
  void dispose() {
    _paymentsBloc.close();
    super.dispose();
  }

  void _redirectToPayU(Map<String, dynamic> formData) {
    if (_redirecting) return;
    setState(() => _redirecting = true);

    // Submit the PayU form via platform-specific helper
    submitPayUForm(formData);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return BlocProvider.value(
      value: _paymentsBloc,
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        appBar: AppBar(
          title: const Text('Procesando pago'),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => _showCancelDialog(context),
          ),
        ),
        body: BlocConsumer<PaymentsBloc, PaymentsState>(
          listener: (context, state) {
            if (state is PaymentCreated) {
              // Auto-redirect to PayU
              _redirectToPayU(state.payuFormData);
            } else if (state is PaymentsError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: AppTheme.errorColor,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            }
          },
          builder: (context, state) {
            if (state is PaymentsError) {
              return _buildError(context, state.message);
            }

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // PayU logo placeholder
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(Icons.payment_rounded, size: 40, color: colorScheme.primary),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _redirecting
                          ? 'Redirigiendo a PayU...'
                          : 'Preparando tu pago...',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _redirecting
                          ? 'Serás redirigido a la pasarela de pago segura de PayU.'
                          : 'Estamos creando tu intención de pago.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: 40, height: 40,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Security badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_rounded, size: 16, color: AppTheme.successColor),
                          SizedBox(width: 8),
                          Text('Pago seguro con PayU Latam',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.successColor)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.error_outline_rounded, size: 40, color: AppTheme.errorColor),
            ),
            const SizedBox(height: 24),
            const Text('Error al procesar el pago',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: () => context.go('/orders'),
                  child: const Text('Ver pedidos'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    _paymentsBloc.add(CreatePayment(
                      orderId: widget.orderId,
                      amount: widget.amount,
                      buyerEmail: widget.buyerEmail,
                      buyerName: widget.buyerName,
                      paymentMethod: widget.paymentMethod,
                    ));
                  },
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar pago?'),
        content: const Text('Tu pedido quedará pendiente de pago. Podrás completarlo más tarde desde tus pedidos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Continuar pagando'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/orders');
            },
            child: const Text('Cancelar', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    );
  }
}
