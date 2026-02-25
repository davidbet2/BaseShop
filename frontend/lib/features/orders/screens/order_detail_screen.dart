import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';

import 'package:baseshop/core/di/injection.dart';
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
        appBar: AppBar(title: const Text('Detalle del Pedido')),
        body: BlocBuilder<OrdersBloc, OrdersState>(
          builder: (context, state) {
            if (state is OrdersLoading) {
              return _buildLoadingShimmer();
            }

            if (state is OrderDetailLoaded) {
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
            Card(
              child: ListTile(
                leading: Icon(Icons.payment, color: Theme.of(context).colorScheme.primary),
                title: Text(_formatPaymentMethod(paymentMethod)),
              ),
            ),
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
        ],
      ),
    );
  }

  Widget _buildOrderItem(Map<String, dynamic> item) {
    final name =
        (item['productName'] ?? item['product_name'] ?? item['name'] ?? 'Producto')
            .toString();
    final price = (item['price'] ?? item['productPrice'] ?? 0) as num;
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
    if (address is Map<String, dynamic>) {
      final street = address['street'] ?? address['address'] ?? '';
      final city = address['city'] ?? '';
      final state = address['state'] ?? address['department'] ?? '';
      final zip = address['zipCode'] ?? address['zip_code'] ?? address['postalCode'] ?? '';
      final country = address['country'] ?? 'Colombia';

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (street.toString().isNotEmpty) Text(street.toString()),
          if (city.toString().isNotEmpty || state.toString().isNotEmpty)
            Text('${city.toString()}${state.toString().isNotEmpty ? ', $state' : ''}'),
          if (zip.toString().isNotEmpty) Text('CP: $zip'),
          Text(country.toString()),
        ],
      );
    }
    return Text(address.toString());
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
