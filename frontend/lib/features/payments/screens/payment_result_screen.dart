import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:baseshop/core/di/injection.dart';
import 'package:baseshop/core/theme/app_theme.dart';
import 'package:baseshop/features/payments/bloc/payments_bloc.dart';
import 'package:baseshop/features/payments/bloc/payments_event.dart';
import 'package:baseshop/features/payments/bloc/payments_state.dart';

/// Screen shown after PayU redirects back to the app.
/// Checks payment status and shows result.
class PaymentResultScreen extends StatefulWidget {
  final String orderId;

  const PaymentResultScreen({super.key, required this.orderId});

  @override
  State<PaymentResultScreen> createState() => _PaymentResultScreenState();
}

class _PaymentResultScreenState extends State<PaymentResultScreen> {
  late final PaymentsBloc _paymentsBloc;

  @override
  void initState() {
    super.initState();
    _paymentsBloc = getIt<PaymentsBloc>();
    // Check payment status
    _paymentsBloc.add(CheckPaymentStatus(widget.orderId));
  }

  @override
  void dispose() {
    _paymentsBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return BlocProvider.value(
      value: _paymentsBloc,
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
        appBar: AppBar(
          title: const Text('Resultado del pago'),
          automaticallyImplyLeading: false,
        ),
        body: BlocBuilder<PaymentsBloc, PaymentsState>(
          builder: (context, state) {
            if (state is PaymentsLoading || state is PaymentsInitial) {
              return _buildLoading(colorScheme);
            }

            if (state is PaymentStatusLoaded) {
              return _buildResult(context, state.status, state.payment);
            }

            if (state is PaymentsError) {
              return _buildResult(context, 'pending', {});
            }

            return _buildLoading(colorScheme);
          },
        ),
      ),
    );
  }

  Widget _buildLoading(ColorScheme colorScheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 48, height: 48,
            child: CircularProgressIndicator(strokeWidth: 3, color: colorScheme.primary),
          ),
          const SizedBox(height: 24),
          const Text('Verificando tu pago...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          const Text('Esto puede tomar unos segundos', style: TextStyle(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildResult(BuildContext context, String status, Map<String, dynamic> payment) {
    final isApproved = status == 'approved';
    final isPending = status == 'pending';
    final isDeclined = status == 'declined' || status == 'expired' || status == 'error';

    IconData icon;
    Color color;
    String title;
    String subtitle;

    if (isApproved) {
      icon = Icons.check_circle_rounded;
      color = AppTheme.successColor;
      title = '¡Pago aprobado!';
      subtitle = 'Tu pago ha sido procesado correctamente. Tu pedido está siendo preparado.';
    } else if (isPending) {
      icon = Icons.schedule_rounded;
      color = Colors.orange;
      title = 'Pago pendiente';
      subtitle = 'Tu pago está siendo procesado. Te notificaremos cuando se confirme.';
    } else {
      icon = Icons.cancel_rounded;
      color = AppTheme.errorColor;
      title = isDeclined ? 'Pago rechazado' : 'Error en el pago';
      subtitle = isDeclined
          ? 'Tu pago fue rechazado por la entidad financiera. Puedes intentar con otro método de pago.'
          : 'Ocurrió un error procesando tu pago. Por favor intenta nuevamente.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 56, color: color),
            ),
            const SizedBox(height: 28),
            Text(title, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 12),
            Text(subtitle, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary, height: 1.5)),

            if (payment.isNotEmpty) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.5)),
                ),
                child: Column(
                  children: [
                    _infoRow('Referencia', payment['id']?.toString() ?? '-'),
                    const SizedBox(height: 8),
                    _infoRow('Estado', _statusLabel(status)),
                    if (payment['provider_reference']?.toString().isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      _infoRow('Transacción', payment['provider_reference'].toString()),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => context.go('/orders'),
                child: const Text('Ver mis pedidos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),

            if (isDeclined) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () {
                    // Retry — reload payment status or go back to checkout
                    _paymentsBloc.add(CheckPaymentStatus(widget.orderId));
                  },
                  child: const Text('Verificar de nuevo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
        Flexible(
          child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            textAlign: TextAlign.end, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'approved': return 'Aprobado';
      case 'pending': return 'Pendiente';
      case 'declined': return 'Rechazado';
      case 'expired': return 'Expirado';
      case 'error': return 'Error';
      default: return status;
    }
  }
}
