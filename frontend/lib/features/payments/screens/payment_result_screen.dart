import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:baseshop/core/di/injection.dart';
import 'package:baseshop/core/theme/app_theme.dart';
import 'package:baseshop/features/payments/bloc/payments_bloc.dart';
import 'package:baseshop/features/payments/bloc/payments_event.dart';
import 'package:baseshop/features/payments/bloc/payments_state.dart';

/// Screen shown after PayU redirects back to the app.
/// Parses PayU response query params, validates via backend, and shows result.
class PaymentResultScreen extends StatefulWidget {
  final String orderId;
  /// All query parameters from the URL (includes PayU response params).
  final Map<String, String> queryParams;

  const PaymentResultScreen({
    super.key,
    required this.orderId,
    this.queryParams = const {},
  });

  @override
  State<PaymentResultScreen> createState() => _PaymentResultScreenState();
}

class _PaymentResultScreenState extends State<PaymentResultScreen> {
  late final PaymentsBloc _paymentsBloc;

  /// Immediate status from PayU's transactionState (before backend confirms).
  String? _immediateStatus;

  @override
  void initState() {
    super.initState();
    _paymentsBloc = getIt<PaymentsBloc>();

    // Parse PayU response params for immediate feedback
    final transactionState = widget.queryParams['transactionState'] ?? '';
    final lapTransactionState = widget.queryParams['lapTransactionState'] ?? '';

    if (transactionState.isNotEmpty) {
      // Map PayU transactionState: 4=approved, 6=declined, 5=expired, 7=pending
      _immediateStatus = _mapPayUState(transactionState);

      // Send params to backend to validate & update payment + order status
      _paymentsBloc.add(ValidatePayUResponse({
        'orderId': widget.orderId,
        'transactionState': transactionState,
        'polTransactionState': widget.queryParams['polTransactionState'] ?? '',
        'referenceCode': widget.queryParams['referenceCode'] ?? '',
        'transactionId': widget.queryParams['transactionId'] ?? '',
        'TX_VALUE': widget.queryParams['TX_VALUE'] ?? '',
        'currency': widget.queryParams['currency'] ?? '',
        'signature': widget.queryParams['signature'] ?? '',
        'message': widget.queryParams['message'] ?? '',
        'lapTransactionState': lapTransactionState,
      }));
    } else {
      // No PayU params — just query our API for current status
      _paymentsBloc.add(CheckPaymentStatus(widget.orderId));
    }
  }

  String _mapPayUState(String transactionState) {
    switch (transactionState) {
      case '4': return 'approved';
      case '6': return 'declined';
      case '5': return 'expired';
      case '7': return 'pending';
      case '104': return 'error';
      case '12': return 'abandoned';
      case '14': return 'pending_validation';
      default: return 'error';
    }
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
            // Show immediate result from PayU params while backend validates
            if (_immediateStatus != null && (state is PaymentsLoading || state is PaymentsInitial)) {
              return _buildResult(context, _immediateStatus!, {}, isValidating: true);
            }

            if (state is PaymentStatusLoaded) {
              return _buildResult(context, state.status, state.payment);
            }

            if (state is PaymentsError) {
              // If we have immediate status, show that even on error
              if (_immediateStatus != null) {
                return _buildResult(context, _immediateStatus!, {});
              }
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

  Widget _buildResult(BuildContext context, String status, Map<String, dynamic> payment, {bool isValidating = false}) {
    final isApproved = status == 'approved';
    final isPending = status == 'pending' || status == 'pending_validation';
    final isDeclined = status == 'declined';
    final isExpired = status == 'expired';
    final isAbandoned = status == 'abandoned';
    final isError = status == 'error';
    final isNegative = isDeclined || isExpired || isAbandoned || isError;

    // PayU message from backend (lapTransactionState human-readable)
    final payuMessage = (payment['payu_message'] ?? '').toString();

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
      title = status == 'pending_validation' ? 'Pago en validación' : 'Pago pendiente';
      subtitle = status == 'pending_validation'
          ? 'Tu transacción está siendo revisada. Este proceso puede tardar hasta 48 horas.'
          : 'Tu pago está siendo procesado. Te notificaremos cuando se confirme.';
    } else if (isDeclined) {
      icon = Icons.cancel_rounded;
      color = AppTheme.errorColor;
      title = 'Pago rechazado';
      subtitle = payuMessage.isNotEmpty
          ? payuMessage
          : 'Tu pago fue rechazado por la entidad financiera. Puedes intentar con otro método de pago.';
    } else if (isExpired) {
      icon = Icons.timer_off_rounded;
      color = Colors.orange.shade800;
      title = 'Transacción expirada';
      subtitle = 'El tiempo para completar la transacción ha expirado. Puedes intentar nuevamente.';
    } else if (isAbandoned) {
      icon = Icons.exit_to_app_rounded;
      color = Colors.grey.shade600;
      title = 'Pago no completado';
      subtitle = 'Saliste del proceso de pago sin completar la transacción. Puedes reintentar desde tus pedidos.';
    } else {
      icon = Icons.error_outline_rounded;
      color = AppTheme.errorColor;
      title = 'Error en el pago';
      subtitle = payuMessage.isNotEmpty
          ? payuMessage
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

            if (isValidating) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: color)),
                  const SizedBox(width: 8),
                  Text('Confirmando con el servidor...', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                ],
              ),
            ],

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

            if (isPending || isNegative) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () {
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
      case 'pending_validation': return 'En validación';
      case 'declined': return 'Rechazado';
      case 'expired': return 'Expirado';
      case 'abandoned': return 'Abandonado';
      case 'error': return 'Error';
      default: return status;
    }
  }
}
