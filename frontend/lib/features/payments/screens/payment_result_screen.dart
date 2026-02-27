import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:baseshop/core/di/injection.dart';
import 'package:baseshop/core/theme/app_theme.dart';
import 'package:baseshop/features/orders/repository/orders_repository.dart';
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
  final _currency = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
  final _dateFmt = DateFormat("d 'de' MMMM, yyyy · h:mm a", 'es');

  /// Immediate status from PayU's transactionState (before backend confirms).
  String? _immediateStatus;

  /// Order detail fetched from API.
  Map<String, dynamic>? _orderDetail;
  bool _orderLoading = true;

  @override
  void initState() {
    super.initState();
    _paymentsBloc = getIt<PaymentsBloc>();

    // Fetch order detail for showing items, totals, etc.
    _fetchOrderDetail();

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

  Future<void> _fetchOrderDetail() async {
    if (widget.orderId.isEmpty) {
      setState(() => _orderLoading = false);
      return;
    }
    try {
      final repo = getIt<OrdersRepository>();
      final data = await repo.getOrderDetail(widget.orderId);
      if (mounted) setState(() { _orderDetail = data; _orderLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _orderLoading = false);
    }
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

    // -- Gather display data from payment + order + queryParams --
    final amount = payment['amount'] ?? widget.queryParams['TX_VALUE'];
    final currency = (payment['currency'] ?? widget.queryParams['currency'] ?? 'COP').toString();
    final paymentMethod = _paymentMethodLabel(
      payment['payment_method']?.toString() ?? widget.queryParams['lapPaymentMethod'] ?? '',
    );
    final providerRef = (payment['provider_reference'] ?? widget.queryParams['transactionId'] ?? '').toString();
    final referenceCode = (payment['id'] ?? widget.queryParams['referenceCode'] ?? '').toString();

    // Date: prefer payment created_at, fallback to order, fallback to now
    DateTime? txDate;
    final paymentDateStr = (payment['created_at'] ?? '').toString();
    final orderDateStr = (_orderDetail?['created_at'] ?? '').toString();
    if (paymentDateStr.isNotEmpty) {
      txDate = DateTime.tryParse(paymentDateStr);
    } else if (orderDateStr.isNotEmpty) {
      txDate = DateTime.tryParse(orderDateStr);
    }

    // Order data
    final orderNumber = (_orderDetail?['order_number'] ?? '').toString();
    final items = List<Map<String, dynamic>>.from(_orderDetail?['items'] ?? []);
    final subtotal = double.tryParse(_orderDetail?['subtotal']?.toString() ?? '') ?? 0;
    final tax = double.tryParse(_orderDetail?['tax']?.toString() ?? '') ?? 0;
    final shipping = double.tryParse(_orderDetail?['shipping_cost']?.toString() ?? '') ?? 0;
    final total = double.tryParse(
      _orderDetail?['total']?.toString() ?? amount?.toString() ?? '0',
    ) ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        children: [
          // ── Status header ──
          Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: color),
          ),
          const SizedBox(height: 20),
          Text(title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 8),
          Text(subtitle, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.5)),

          if (isValidating) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: color)),
                const SizedBox(width: 8),
                Text('Confirmando con el servidor...', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ],

          const SizedBox(height: 24),

          // ── Total amount highlight ──
          if (total > 0)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Text('Total pagado', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                  const SizedBox(height: 4),
                  Text(
                    _currency.format(total),
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                  ),
                  if (currency != 'COP')
                    Text(currency, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // ── Transaction details card ──
          _card(
            title: 'Detalles de la transacción',
            icon: Icons.receipt_long_rounded,
            children: [
              if (orderNumber.isNotEmpty)
                _detailRow(Icons.tag_rounded, 'Pedido', '#$orderNumber'),
              _detailRow(Icons.circle, 'Estado', _statusLabel(status),
                valueColor: color, valueBold: true),
              if (paymentMethod.isNotEmpty)
                _detailRow(Icons.credit_card_rounded, 'Método de pago', paymentMethod),
              if (txDate != null)
                _detailRow(Icons.calendar_today_rounded, 'Fecha', _dateFmt.format(txDate.toLocal())),
              if (referenceCode.isNotEmpty)
                _detailRow(Icons.key_rounded, 'Referencia', referenceCode, mono: true),
              if (providerRef.isNotEmpty)
                _detailRow(Icons.numbers_rounded, 'ID transacción', providerRef, mono: true),
            ],
          ),

          // ── Order items card ──
          if (items.isNotEmpty) ...[
            const SizedBox(height: 16),
            _card(
              title: 'Productos',
              icon: Icons.shopping_bag_rounded,
              children: [
                ...items.map((item) {
                  final name = (item['product_name'] ?? '').toString();
                  final qty = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
                  final price = double.tryParse(item['product_price']?.toString() ?? '0') ?? 0;
                  final image = (item['product_image'] ?? '').toString();
                  return _itemRow(name, qty, price, image);
                }),
              ],
            ),
          ],

          // ── Price breakdown card ──
          if (subtotal > 0) ...[
            const SizedBox(height: 16),
            _card(
              title: 'Resumen de pago',
              icon: Icons.calculate_rounded,
              children: [
                _priceRow('Subtotal', subtotal),
                if (tax > 0)
                  _priceRow('IVA (19%)', tax),
                if (shipping > 0)
                  _priceRow('Envío', shipping)
                else
                  _priceRow('Envío', 0, freeLabel: true),
                const Divider(height: 20),
                _priceRow('Total', total, bold: true, large: true),
              ],
            ),
          ],

          const SizedBox(height: 28),

          // ── Action buttons ──
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () => context.go('/orders'),
              icon: const Icon(Icons.list_alt_rounded, size: 20),
              label: const Text('Ver mis pedidos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),

          if (isPending || isNegative) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () {
                  _paymentsBloc.add(CheckPaymentStatus(widget.orderId));
                },
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text('Verificar de nuevo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: TextButton.icon(
              onPressed: () => context.go('/home'),
              icon: const Icon(Icons.storefront_rounded, size: 20),
              label: const Text('Seguir comprando', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Card wrapper ──
  Widget _card({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            ],
          ),
          const Divider(height: 20),
          ...children,
        ],
      ),
    );
  }

  // ── Detail row with icon ──
  Widget _detailRow(IconData icon, String label, String value, {
    Color? valueColor, bool valueBold = false, bool mono = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade400),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: valueBold ? FontWeight.w700 : FontWeight.w600,
                color: valueColor ?? AppTheme.textPrimary,
                fontFamily: mono ? 'monospace' : null,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Product item row ──
  Widget _itemRow(String name, int qty, double price, String image) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Product image
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: image.isNotEmpty
                ? Image.network(image, width: 44, height: 44, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _imagePlaceholder())
                : _imagePlaceholder(),
          ),
          const SizedBox(width: 12),
          // Product info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('Cant: $qty × ${_currency.format(price)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Line total
          Text(_currency.format(price * qty),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 44, height: 44,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.image_rounded, size: 20, color: Colors.grey.shade400),
    );
  }

  // ── Price breakdown row ──
  Widget _priceRow(String label, double value, {bool bold = false, bool large = false, bool freeLabel = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            fontSize: large ? 15 : 13,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            color: bold ? AppTheme.textPrimary : Colors.grey.shade600,
          )),
          Text(
            freeLabel && value == 0 ? 'Gratis' : _currency.format(value),
            style: TextStyle(
              fontSize: large ? 16 : 13,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              color: freeLabel && value == 0 ? AppTheme.successColor : (bold ? AppTheme.textPrimary : AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  String _paymentMethodLabel(String method) {
    final m = method.toUpperCase();
    if (m.contains('VISA')) return 'Visa';
    if (m.contains('MASTERCARD')) return 'Mastercard';
    if (m.contains('AMEX')) return 'American Express';
    if (m.contains('DINERS')) return 'Diners Club';
    if (m.contains('PSE')) return 'PSE';
    if (m.contains('NEQUI')) return 'Nequi';
    if (m.contains('CREDIT') || m.contains('CARD') || m == 'CARD') return 'Tarjeta de crédito';
    if (method.isNotEmpty) return method;
    return '';
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
