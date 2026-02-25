import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:baseshop/core/di/injection.dart';
import 'package:baseshop/core/theme/app_theme.dart';
import 'package:baseshop/features/orders/bloc/orders_bloc.dart';
import 'package:baseshop/features/orders/bloc/orders_event.dart';
import 'package:baseshop/features/orders/bloc/orders_state.dart';

/// Full order detail for admin – loaded via admin GET /orders/:id.
class AdminOrderDetailScreen extends StatefulWidget {
  final String orderId;

  const AdminOrderDetailScreen({super.key, required this.orderId});

  @override
  State<AdminOrderDetailScreen> createState() =>
      _AdminOrderDetailScreenState();
}

class _AdminOrderDetailScreenState extends State<AdminOrderDetailScreen> {
  late final OrdersBloc _bloc;
  final _currencyFmt = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  static const _statusLabels = <String, String>{
    'pending': 'Pendiente',
    'confirmed': 'Confirmado',
    'processing': 'En proceso',
    'shipped': 'Enviado',
    'delivered': 'Entregado',
    'cancelled': 'Cancelado',
    'refunded': 'Reembolsado',
  };

  static const _statusColors = <String, Color>{
    'pending': Colors.orange,
    'confirmed': Color(0xFF1565C0),
    'processing': Colors.purple,
    'shipped': Colors.indigo,
    'delivered': Color(0xFF388E3C),
    'cancelled': Color(0xFFD32F2F),
    'refunded': Color(0xFF795548),
  };

  static const _statusTransitions = <String, List<String>>{
    'pending': ['confirmed', 'cancelled'],
    'confirmed': ['processing', 'cancelled'],
    'processing': ['shipped', 'cancelled'],
    'shipped': ['delivered'],
    'delivered': ['refunded'],
    'cancelled': [],
    'refunded': [],
  };

  @override
  void initState() {
    super.initState();
    _bloc = getIt<OrdersBloc>();
    _bloc.add(LoadAdminOrderDetail(widget.orderId));
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        appBar: AppBar(title: const Text('Detalle del Pedido')),
        body: BlocConsumer<OrdersBloc, OrdersState>(
          listener: (context, state) {
            if (state is OrderStatusUpdated) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Estado actualizado')),
              );
              _bloc.add(LoadAdminOrderDetail(widget.orderId));
            }
            if (state is OrdersError) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(state.message)),
              );
            }
          },
          builder: (context, state) {
            if (state is OrdersLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is OrderDetailLoaded) {
              return _buildContent(state.order);
            }
            if (state is OrdersError) {
              return Center(child: Text(state.message));
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildContent(Map<String, dynamic> order) {
    final isWide = MediaQuery.of(context).size.width > 800;
    final status = order['status'] as String? ?? 'pending';
    final items = List<Map<String, dynamic>>.from(order['items'] ?? []);
    final statusHistory =
        List<Map<String, dynamic>>.from(order['status_history'] ?? []);
    final shipping = order['shipping_address'];
    final nextStatuses = _statusTransitions[status] ?? <String>[];

    return ListView(
      padding: EdgeInsets.symmetric(
        horizontal: isWide ? 48 : 16,
        vertical: 20,
      ),
      children: [
        // ── Header ──
        _buildHeader(order, status, nextStatuses),
        const SizedBox(height: 24),
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _buildItemsCard(items)),
              const SizedBox(width: 20),
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    _buildCustomerCard(order),
                    const SizedBox(height: 16),
                    if (shipping != null) _buildShippingCard(shipping),
                    const SizedBox(height: 16),
                    _buildSummaryCard(order),
                    if (statusHistory.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildHistoryCard(statusHistory),
                    ],
                  ],
                ),
              ),
            ],
          )
        else ...[
          _buildItemsCard(items),
          const SizedBox(height: 16),
          _buildCustomerCard(order),
          const SizedBox(height: 16),
          if (shipping != null) ...[
            _buildShippingCard(shipping),
            const SizedBox(height: 16),
          ],
          _buildSummaryCard(order),
          if (statusHistory.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildHistoryCard(statusHistory),
          ],
        ],
      ],
    );
  }

  // ── Header ─────────────────────────────────────────────────

  Widget _buildHeader(Map<String, dynamic> order, String status,
      List<String> nextStatuses) {
    final color = _statusColors[status] ?? Colors.grey;
    final label = _statusLabels[status] ?? status;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          spacing: 16,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order['order_number'] as String? ?? '#${order['id']}',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  _fmtDate(order['created_at']),
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(label,
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: color)),
                ),
                if (nextStatuses.isNotEmpty) ...[
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => _showChangeDialog(order),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cambiar Estado'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Items ──────────────────────────────────────────────────

  Widget _buildItemsCard(List<Map<String, dynamic>> items) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Productos',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ...items.map((item) {
              final price = (item['price'] as num?)?.toDouble() ?? 0;
              final qty = item['quantity'] as int? ?? 1;
              final name = item['product_name'] ?? item['name'] ?? 'Producto';
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    if (item['product_image'] != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          item['product_image'].toString(),
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.image_not_supported, size: 48),
                        ),
                      )
                    else
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.inventory_2_outlined,
                            color: Colors.grey),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name.toString(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          Text('x$qty',
                              style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 13)),
                        ],
                      ),
                    ),
                    Text(_currencyFmt.format(price * qty),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Customer ───────────────────────────────────────────────

  Widget _buildCustomerCard(Map<String, dynamic> order) {
    final name = order['customer_name'] ??
        order['user_name'] ??
        order['customer'] ??
        'N/A';
    final email = order['customer_email'] ?? order['user_email'] ?? '';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cliente',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Row(children: [
              const Icon(Icons.person_outline, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(child: Text(name.toString())),
            ]),
            if (email.toString().isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.email_outlined, size: 18, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(child: Text(email.toString())),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  // ── Shipping ───────────────────────────────────────────────

  Widget _buildShippingCard(dynamic shipping) {
    final addr = shipping is Map ? shipping : {};
    final street = addr['street'] ?? addr['address'] ?? '';
    final city = addr['city'] ?? '';
    final state = addr['state'] ?? '';
    final zip = addr['zip_code'] ?? addr['postal_code'] ?? '';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Dirección de Envío',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            if (street.toString().isNotEmpty) Text(street.toString()),
            if (city.toString().isNotEmpty || state.toString().isNotEmpty)
              Text('$city, $state $zip'),
          ],
        ),
      ),
    );
  }

  // ── Summary ────────────────────────────────────────────────

  Widget _buildSummaryCard(Map<String, dynamic> order) {
    final subtotal = (order['subtotal'] as num?)?.toDouble() ??
        (order['total'] as num?)?.toDouble() ??
        0;
    final shipping = (order['shipping_cost'] as num?)?.toDouble() ?? 0;
    final total = (order['total'] as num?)?.toDouble() ?? subtotal;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Resumen',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            _summaryRow('Subtotal', _currencyFmt.format(subtotal)),
            _summaryRow('Envío', _currencyFmt.format(shipping)),
            const Divider(height: 20),
            _summaryRow('Total', _currencyFmt.format(total), bold: true),
            const SizedBox(height: 8),
            Text(
              'Método de pago: ${order['payment_method'] ?? 'N/A'}',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
          Text(value,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
        ],
      ),
    );
  }

  // ── Status history ─────────────────────────────────────────

  Widget _buildHistoryCard(List<Map<String, dynamic>> history) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Historial de Estado',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ...history.map((h) {
              final s = h['status'] as String? ?? '';
              final color = _statusColors[s] ?? Colors.grey;
              final date = _fmtDate(h['changed_at'] ?? h['created_at']);
              final note = h['note'] ?? '';

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(top: 5),
                      decoration: BoxDecoration(
                          shape: BoxShape.circle, color: color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_statusLabels[s] ?? s,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: color)),
                              Text(date,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500)),
                            ],
                          ),
                          if (note.toString().isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(note.toString(),
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  // ── Status change dialog ───────────────────────────────────

  void _showChangeDialog(Map<String, dynamic> order) {
    final status = order['status'] as String? ?? 'pending';
    final nextStatuses = _statusTransitions[status] ?? <String>[];
    if (nextStatuses.isEmpty) return;

    String? selected;
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, ss) => AlertDialog(
          title: const Text('Cambiar Estado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selected,
                decoration: InputDecoration(
                  labelText: 'Nuevo estado',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                items: nextStatuses
                    .map((s) => DropdownMenuItem(
                        value: s, child: Text(_statusLabels[s] ?? s)))
                    .toList(),
                onChanged: (v) => ss(() => selected = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Nota (opcional)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: selected == null
                  ? null
                  : () {
                      Navigator.pop(ctx);
                      _bloc.add(UpdateOrderStatus(
                        orderId: widget.orderId,
                        status: selected!,
                        note: noteCtrl.text.trim().isEmpty
                            ? null
                            : noteCtrl.text.trim(),
                      ));
                    },
              child: const Text('Actualizar'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────

  String _fmtDate(dynamic raw) {
    if (raw == null) return '';
    try {
      return DateFormat('dd/MM/yy HH:mm')
          .format(DateTime.parse(raw.toString()));
    } catch (_) {
      return raw.toString();
    }
  }
}
