import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'package:baseshop/core/di/injection.dart';
import 'package:baseshop/core/constants/api_constants.dart';
import 'package:baseshop/core/network/api_client.dart';
import 'package:baseshop/core/theme/app_theme.dart';
import 'package:baseshop/features/orders/bloc/orders_bloc.dart';
import 'package:baseshop/features/orders/bloc/orders_event.dart';
import 'package:baseshop/features/orders/bloc/orders_state.dart';

class OrderDetailScreen extends StatefulWidget {
  final String orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late final OrdersBloc _bloc;
  Map<String, dynamic>? _currentOrder;
  Map<String, dynamic>? _paymentDetail;
  bool _paymentLoading = false;

  final _currencyFormat = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _bloc = getIt<OrdersBloc>();
    _bloc.add(LoadOrderDetail(widget.orderId));
  }

  Future<void> _fetchPaymentDetail(String orderId) async {
    if (_paymentLoading || _paymentDetail != null) return;
    _paymentLoading = true;
    try {
      final apiClient = getIt<ApiClient>();
      final resp = await apiClient.dio.get('${ApiConstants.paymentByOrder}/$orderId');
      final data = resp.data;
      if (data is Map<String, dynamic> && data.containsKey('data')) {
        if (mounted) setState(() => _paymentDetail = Map<String, dynamic>.from(data['data']));
      }
    } catch (_) {
      // Payment detail is optional, ignore errors
    } finally {
      _paymentLoading = false;
    }
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Detalle del Pedido'),
          actions: [
            if (_currentOrder != null) ...[
              IconButton(
                icon: const Icon(Icons.copy),
                tooltip: 'Copiar resumen',
                onPressed: () => _copyOrderSummary(),
              ),
              if (!kIsWeb)
                IconButton(
                  icon: const Icon(Icons.share),
                  tooltip: 'Compartir',
                  onPressed: () => _shareOrderSummary(),
                ),
            ],
          ],
        ),
        body: BlocBuilder<OrdersBloc, OrdersState>(
          builder: (context, state) {
            if (state is OrdersLoading) {
              return _buildLoadingShimmer();
            }

            if (state is OrderDetailLoaded) {
              // Store for AppBar actions + fetch payment detail
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (_currentOrder == null) {
                  setState(() => _currentOrder = state.order);
                }
                _fetchPaymentDetail(state.order['id'] ?? widget.orderId);
              });
              return _buildOrderDetail(context, state.order);
            }

            if (state is OrdersError) {
              return _buildErrorState(state.message);
            }

            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildOrderDetail(BuildContext context, Map<String, dynamic> order) {
    final orderNumber =
        (order['orderNumber'] ?? order['order_number'] ?? '').toString();
    final status = (order['status'] ?? 'pending').toString();
    final items = List<Map<String, dynamic>>.from(order['items'] ?? []);
    final subtotal = (order['subtotal'] ?? 0) as num;
    final tax = (order['tax'] ?? 0) as num;
    final shipping = (order['shippingCost'] ?? order['shipping_cost'] ?? 0) as num;
    final total = (order['total'] ?? 0) as num;
    final notes = (order['notes'] ?? '').toString();
    final paymentMethod =
        (order['paymentMethod'] ?? order['payment_method'] ?? '').toString();
    final shippingAddress =
        order['shippingAddress'] ?? order['shipping_address'];
    final statusHistory = List<Map<String, dynamic>>.from(
        order['orderStatusHistory'] ?? order['order_status_history'] ?? []);

    String dateStr = '';
    final createdAt = order['createdAt'] ?? order['created_at'];
    if (createdAt != null) {
      try {
        final date = DateTime.parse(createdAt.toString());
        dateStr = DateFormat('dd MMM yyyy, HH:mm', 'es').format(date);
      } catch (_) {
        dateStr = createdAt.toString();
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pedido #$orderNumber',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      _buildStatusBadge(status),
                    ],
                  ),
                  if (dateStr.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 6),
                        Text(
                          dateStr,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Status Timeline ──
          if (statusHistory.isNotEmpty) ...[
            const Text(
              'Historial de Estado',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            _buildStatusTimeline(statusHistory),
            const SizedBox(height: 16),
          ],

          // ── Items ──
          const Text(
            'Productos',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          ...items.map((item) => _buildOrderItem(item)),
          const SizedBox(height: 16),

          // ── Price Breakdown ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildPriceRow('Subtotal', subtotal),
                  if (tax > 0) _buildPriceRow('Impuestos', tax),
                  _buildPriceRow('Envío', shipping),
                  const Divider(),
                  _buildPriceRow('Total', total, bold: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Shipping Address ──
          if (shippingAddress != null) ...[
            const Text(
              'Dirección de Envío',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildAddress(shippingAddress),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Payment Method ──
          if (paymentMethod.isNotEmpty) ...[
            const Text(
              'Método de Pago',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            _buildPaymentCard(paymentMethod, order),
            const SizedBox(height: 16),
          ],

          // ── Notes ──
          if (notes.isNotEmpty) ...[
            const Text(
              'Notas',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.note, color: Colors.grey.shade600, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(notes)),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),

          // ── Share / Copy Buttons ──
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _copyOrderSummary,
                  icon: const Icon(Icons.copy, size: 18),
                  label: const Text('Copiar resumen'),
                ),
              ),
              if (!kIsWeb) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _shareOrderSummary,
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Compartir'),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Share / Copy helpers ──

  String _buildOrderSummaryText(Map<String, dynamic> order) {
    final orderNumber =
        (order['orderNumber'] ?? order['order_number'] ?? '').toString();
    final status = (order['status'] ?? 'pending').toString();
    final items = List<Map<String, dynamic>>.from(order['items'] ?? []);
    final subtotal = (order['subtotal'] ?? 0) as num;
    final tax = (order['tax'] ?? 0) as num;
    final shipping =
        (order['shippingCost'] ?? order['shipping_cost'] ?? 0) as num;
    final total = (order['total'] ?? 0) as num;
    final paymentMethod =
        (order['paymentMethod'] ?? order['payment_method'] ?? '').toString();
    final rawSummaryAddress =
        order['shippingAddress'] ?? order['shipping_address'];
    // Parse JSON string if needed
    dynamic shippingAddress = rawSummaryAddress;
    if (shippingAddress is String && shippingAddress.trim().startsWith('{')) {
      try {
        shippingAddress = jsonDecode(shippingAddress);
      } catch (_) {}
    }

    String dateStr = '';
    final createdAt = order['createdAt'] ?? order['created_at'];
    if (createdAt != null) {
      try {
        final date = DateTime.parse(createdAt.toString());
        dateStr = DateFormat('dd MMM yyyy, HH:mm', 'es').format(date);
      } catch (_) {
        dateStr = createdAt.toString();
      }
    }

    final buf = StringBuffer();
    buf.writeln('═══════════════════════════');
    buf.writeln('  RESUMEN DE PEDIDO');
    buf.writeln('═══════════════════════════');
    buf.writeln('Pedido: #$orderNumber');
    if (dateStr.isNotEmpty) buf.writeln('Fecha:  $dateStr');
    buf.writeln('Estado: ${_statusConfig(status).label}');
    buf.writeln('');
    buf.writeln('── Productos ──');
    for (final item in items) {
      final name =
          (item['productName'] ?? item['product_name'] ?? item['name'] ?? 'Producto')
              .toString();
      final price = (item['price'] ?? item['productPrice'] ?? item['product_price'] ?? 0) as num;
      final quantity = (item['quantity'] ?? 1) as int;
      buf.writeln('  • $name x$quantity — ${_currencyFormat.format(price * quantity)}');
    }
    buf.writeln('');
    buf.writeln('── Resumen ──');
    buf.writeln('  Subtotal:   ${_currencyFormat.format(subtotal)}');
    if (tax > 0) buf.writeln('  Impuestos:  ${_currencyFormat.format(tax)}');
    buf.writeln('  Envío:      ${_currencyFormat.format(shipping)}');
    buf.writeln('  ─────────────────');
    buf.writeln('  TOTAL:      ${_currencyFormat.format(total)}');

    if (paymentMethod.isNotEmpty) {
      buf.writeln('');
      buf.writeln('Pago: ${_formatPaymentMethod(paymentMethod)}');
    }

    if (shippingAddress != null && shippingAddress is Map<String, dynamic>) {
      final street = shippingAddress['street'] ?? shippingAddress['address'] ?? '';
      final city = shippingAddress['city'] ?? '';
      final state = shippingAddress['state'] ?? shippingAddress['department'] ?? '';
      buf.writeln('');
      buf.writeln('── Dirección ──');
      if (street.toString().isNotEmpty) buf.writeln('  $street');
      if (city.toString().isNotEmpty || state.toString().isNotEmpty) {
        buf.writeln('  $city${state.toString().isNotEmpty ? ', $state' : ''}');
      }
    }

    buf.writeln('═══════════════════════════');
    return buf.toString();
  }

  void _copyOrderSummary() {
    if (_currentOrder == null) return;
    final text = _buildOrderSummaryText(_currentOrder!);
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Resumen copiado al portapapeles'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _shareOrderSummary() {
    if (_currentOrder == null) return;
    final text = _buildOrderSummaryText(_currentOrder!);
    final orderNumber =
        (_currentOrder!['orderNumber'] ?? _currentOrder!['order_number'] ?? '')
            .toString();
    // ignore: deprecated_member_use
    Share.share(text, subject: 'Pedido #$orderNumber');
  }

  // ── Build helpers ──

  Widget _buildOrderItem(Map<String, dynamic> item) {
    final name =
        (item['productName'] ?? item['product_name'] ?? item['name'] ?? 'Producto')
            .toString();
    final price = (item['price'] ?? item['productPrice'] ?? item['product_price'] ?? 0) as num;
    final quantity = (item['quantity'] ?? 1) as int;
    final image =
        (item['productImage'] ?? item['product_image'] ?? item['image'] ?? '')
            .toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: image.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: image,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey.shade200,
                      ),
                      errorWidget: (_, __, ___) => Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    )
                  : Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.shopping_bag, color: Colors.grey),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cant: $quantity',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _currencyFormat.format(price * quantity),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, num amount, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: bold ? 16 : 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: bold ? null : Colors.grey.shade700,
            ),
          ),
          Text(
            _currencyFormat.format(amount),
            style: TextStyle(
              fontSize: bold ? 18 : 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              color: bold ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTimeline(List<Map<String, dynamic>> history) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: List.generate(history.length, (index) {
            final entry = history[index];
            final statusName = (entry['status'] ?? '').toString();
            final config = _statusConfig(statusName);
            final isLast = index == history.length - 1;

            String dateStr = '';
            final date = entry['date'] ?? entry['createdAt'] ?? entry['created_at'];
            if (date != null) {
              try {
                final d = DateTime.parse(date.toString());
                dateStr = DateFormat('dd MMM yyyy, HH:mm', 'es').format(d);
              } catch (_) {
                dateStr = date.toString();
              }
            }

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: config.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            color: Colors.grey.shade300,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            config.label,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: config.color,
                            ),
                          ),
                          if (dateStr.isNotEmpty)
                            Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildAddress(dynamic address) {
    // Parse JSON string if needed
    dynamic addr = address;
    if (addr is String && addr.trim().startsWith('{')) {
      try {
        addr = jsonDecode(addr);
      } catch (_) {
        // keep as string
      }
    }

    if (addr is Map<String, dynamic>) {
      final label = addr['label'] ?? '';
      final street = addr['street'] ?? addr['address'] ?? '';
      final city = addr['city'] ?? '';
      final state = addr['state'] ?? addr['department'] ?? '';
      final zip = addr['zipCode'] ?? addr['zip_code'] ?? addr['postalCode'] ?? '';
      final country = addr['country'] ?? 'Colombia';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Icon(Icons.home_outlined, size: 16, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 6),
                  Text(
                    label.toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          if (street.toString().isNotEmpty)
            Text(street.toString(), style: const TextStyle(fontSize: 14)),
          if (city.toString().isNotEmpty || state.toString().isNotEmpty)
            Text(
              '${city.toString()}${state.toString().isNotEmpty ? ', $state' : ''}',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
          if (zip.toString().isNotEmpty)
            Text('CP: $zip', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          Text(country.toString(), style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        ],
      );
    }
    return Text(addr.toString());
  }

  Widget _buildStatusBadge(String status) {
    final config = _statusConfig(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        config.label,
        style: TextStyle(
          color: config.color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  _StatusConfig _statusConfig(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return _StatusConfig('Pendiente', Colors.orange);
      case 'confirmed':
        return _StatusConfig('Confirmado', Theme.of(context).colorScheme.primary);
      case 'processing':
        return _StatusConfig('Procesando', Colors.blue);
      case 'shipped':
        return _StatusConfig('Enviado', Colors.indigo);
      case 'delivered':
        return _StatusConfig('Entregado', AppTheme.successColor);
      case 'cancelled':
        return _StatusConfig('Cancelado', AppTheme.errorColor);
      case 'refunded':
        return _StatusConfig('Reembolsado', Colors.purple);
      default:
        return _StatusConfig(status, Colors.grey);
    }
  }

  String _formatPaymentMethod(String method) {
    switch (method.toLowerCase()) {
      case 'card':
        return 'Tarjeta de crédito/débito';
      case 'credit_card':
      case 'creditcard':
        return 'Tarjeta de Crédito';
      case 'debit_card':
      case 'debitcard':
        return 'Tarjeta de Débito';
      case 'cash':
      case 'cash_on_delivery':
        return 'Contra Entrega';
      case 'bank_transfer':
      case 'banktransfer':
        return 'Transferencia Bancaria';
      case 'pse':
        return 'PSE';
      case 'nequi':
        return 'Nequi';
      default:
        return method;
    }
  }

  Widget _buildPaymentCard(String paymentMethod, Map<String, dynamic> order) {
    final paymentStatus = _paymentDetail?['status'];
    final provider = _paymentDetail?['provider'] ?? '';
    final providerRef = _paymentDetail?['provider_reference'] ?? '';

    String statusLabel = '';
    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.hourglass_empty;

    if (paymentStatus != null) {
      switch (paymentStatus.toString().toLowerCase()) {
        case 'approved':
          statusLabel = 'Aprobado';
          statusColor = AppTheme.successColor;
          statusIcon = Icons.check_circle_outline;
          break;
        case 'declined':
          statusLabel = 'Rechazado';
          statusColor = AppTheme.errorColor;
          statusIcon = Icons.cancel_outlined;
          break;
        case 'pending':
        case 'pending_validation':
          statusLabel = 'Pendiente';
          statusColor = Colors.orange;
          statusIcon = Icons.schedule;
          break;
        case 'expired':
          statusLabel = 'Expirado';
          statusColor = Colors.grey;
          statusIcon = Icons.timer_off;
          break;
        case 'error':
          statusLabel = 'Error';
          statusColor = AppTheme.errorColor;
          statusIcon = Icons.error_outline;
          break;
        default:
          statusLabel = paymentStatus.toString();
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  paymentMethod == 'card' ? Icons.credit_card : Icons.payment,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatPaymentMethod(paymentMethod),
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                      if (provider.toString().isNotEmpty)
                        Text(
                          'Proveedor: ${provider.toString().toUpperCase()}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                    ],
                  ),
                ),
                if (statusLabel.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, size: 14, color: statusColor),
                        const SizedBox(width: 4),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            if (providerRef.toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.receipt_long, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(
                    'Ref: ${providerRef.toString()}',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
          const SizedBox(height: 16),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _bloc.add(LoadOrderDetail(widget.orderId)),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: List.generate(
            4,
            (_) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusConfig {
  final String label;
  final Color color;

  const _StatusConfig(this.label, this.color);
}
