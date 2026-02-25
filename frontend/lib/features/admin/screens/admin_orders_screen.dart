import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';

import 'package:baseshop/core/di/injection.dart';
import 'package:baseshop/core/theme/app_theme.dart';
import 'package:baseshop/features/orders/bloc/orders_bloc.dart';
import 'package:baseshop/features/orders/bloc/orders_event.dart';
import 'package:baseshop/features/orders/bloc/orders_state.dart';

/// Admin Orders Management Screen – uses admin /orders endpoint.
class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  late final OrdersBloc _bloc;
  final _searchCtrl = TextEditingController();
  String? _selectedStatus;
  int _page = 1;

  final _currencyFmt = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  static const _statusFilters = <String, String>{
    'all': 'Todos',
    'pending': 'Pendiente',
    'confirmed': 'Confirmado',
    'processing': 'En proceso',
    'shipped': 'Enviado',
    'delivered': 'Entregado',
    'cancelled': 'Cancelado',
  };

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
    _loadOrders();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _bloc.close();
    super.dispose();
  }

  void _loadOrders() {
    _bloc.add(LoadAllOrders(
      status: _selectedStatus,
      search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
      page: _page,
    ));
  }

  void _onFilterChanged(String key) {
    setState(() {
      _selectedStatus = key == 'all' ? null : key;
      _page = 1;
    });
    _loadOrders();
  }

  void _refresh() {
    _page = 1;
    _loadOrders();
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;

    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        appBar: AppBar(title: const Text('Gestionar Pedidos')),
        body: Column(
          children: [
            _buildSearchBar(),
            _buildStatusChips(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => _refresh(),
                child: BlocConsumer<OrdersBloc, OrdersState>(
                  listener: (context, state) {
                    if (state is OrderStatusUpdated) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Estado actualizado')),
                      );
                      _refresh();
                    }
                    if (state is OrdersError) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(state.message)),
                      );
                    }
                  },
                  builder: (context, state) {
                    if (state is OrdersLoading) return _shimmer();
                    if (state is OrdersLoaded) {
                      if (state.orders.isEmpty) return _empty();
                      return isWide
                          ? _buildTable(state)
                          : _buildList(state);
                    }
                    if (state is OrdersError) return _error(state.message);
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Search ─────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: 'Buscar por número de pedido…',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchCtrl.clear();
                    _refresh();
                  },
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onSubmitted: (_) => _refresh(),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  // ── Status chips ───────────────────────────────────────────

  Widget _buildStatusChips() {
    final current = _selectedStatus ?? 'all';
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: _statusFilters.entries.map((e) {
          final sel = e.key == current;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(e.value),
              selected: sel,
              selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
              checkmarkColor: Theme.of(context).colorScheme.primary,
              labelStyle: TextStyle(
                color: sel ? Theme.of(context).colorScheme.primary : Colors.grey.shade700,
                fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
              ),
              onSelected: (_) => _onFilterChanged(e.key),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Table view (wide) ──────────────────────────────────────

  Widget _buildTable(OrdersLoaded state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
            columnSpacing: 20,
            columns: const [
              DataColumn(label: Text('Pedido',
                  style: TextStyle(fontWeight: FontWeight.w600))),
              DataColumn(label: Text('Cliente',
                  style: TextStyle(fontWeight: FontWeight.w600))),
              DataColumn(label: Text('Fecha',
                  style: TextStyle(fontWeight: FontWeight.w600))),
              DataColumn(label: Text('Total',
                  style: TextStyle(fontWeight: FontWeight.w600))),
              DataColumn(label: Text('Estado',
                  style: TextStyle(fontWeight: FontWeight.w600))),
              DataColumn(label: Text('Acciones',
                  style: TextStyle(fontWeight: FontWeight.w600))),
            ],
            rows: state.orders.map((order) {
              final status = order['status'] as String? ?? 'pending';
              final total = (order['total'] as num?)?.toDouble() ?? 0;
              final customer = order['customer_name'] ??
                  order['customer'] ??
                  order['user_name'] ??
                  'N/A';
              final date = _fmtDate(order['created_at'] ?? order['date']);
              final nextStatuses =
                  _statusTransitions[status] ?? <String>[];

              return DataRow(
                cells: [
                  DataCell(Text(
                    order['order_number'] as String? ?? '#${order['id']}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  )),
                  DataCell(Text(customer.toString())),
                  DataCell(Text(date)),
                  DataCell(Text(_currencyFmt.format(total))),
                  DataCell(_badge(status)),
                  DataCell(Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (nextStatuses.isNotEmpty)
                        _miniActionBtn(order, nextStatuses),
                      IconButton(
                        icon: const Icon(Icons.visibility_outlined, size: 20),
                        tooltip: 'Ver detalle',
                        onPressed: () {
                          final id = order['id']?.toString() ?? '';
                          if (id.isNotEmpty) {
                            context.push('/admin/orders/$id');
                          }
                        },
                      ),
                    ],
                  )),
                ],
                onSelectChanged: (_) {
                  final id = order['id']?.toString() ?? '';
                  if (id.isNotEmpty) context.push('/admin/orders/$id');
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _miniActionBtn(
      Map<String, dynamic> order, List<String> nextStatuses) {
    // Show the primary next status as a small button
    final primary =
        nextStatuses.firstWhere((s) => s != 'cancelled', orElse: () => nextStatuses.first);
    final color = _statusColors[primary] ?? Colors.grey;
    final label = _statusLabels[primary] ?? primary;

    return SizedBox(
      height: 28,
      child: OutlinedButton(
        onPressed: () => _confirmChange(order, primary),
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color.withOpacity(0.5)),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 11)),
      ),
    );
  }

  // ── List view (mobile) ─────────────────────────────────────

  Widget _buildList(OrdersLoaded state) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: state.orders.length,
      itemBuilder: (_, i) => _orderCard(state.orders[i]),
    );
  }

  Widget _orderCard(Map<String, dynamic> order) {
    final status = order['status'] as String? ?? 'pending';
    final total = (order['total'] as num?)?.toDouble() ?? 0;
    final customer = order['customer_name'] ??
        order['customer'] ??
        order['user_name'] ??
        'N/A';
    final date = _fmtDate(order['created_at'] ?? order['date']);
    final nextStatuses = _statusTransitions[status] ?? <String>[];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          final id = order['id']?.toString() ?? '';
          if (id.isNotEmpty) context.push('/admin/orders/$id');
        },
        onLongPress: nextStatuses.isNotEmpty
            ? () => _showStatusDialog(order)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      order['order_number'] as String? ??
                          '#${order['id']}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _badge(status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person_outline,
                      size: 15, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      customer.toString(),
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(date,
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _currencyFmt.format(total),
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary),
                  ),
                  if (nextStatuses.isNotEmpty)
                    _miniActionBtn(order, nextStatuses),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Confirm quick status change ────────────────────────────

  Future<void> _confirmChange(
      Map<String, dynamic> order, String newStatus) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cambiar a ${_statusLabels[newStatus] ?? newStatus}'),
        content: Text(
            '¿Cambiar estado del pedido ${order['order_number'] ?? '#${order['id']}'}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmar')),
        ],
      ),
    );
    if (confirmed == true) {
      _bloc.add(UpdateOrderStatus(
        orderId: order['id'].toString(),
        status: newStatus,
      ));
    }
  }

  // ── Full status dialog (long-press) ────────────────────────

  void _showStatusDialog(Map<String, dynamic> order) {
    final currentStatus = order['status'] as String? ?? 'pending';
    final nextStatuses = _statusTransitions[currentStatus] ?? <String>[];
    if (nextStatuses.isEmpty) return;

    String? selected;
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Cambiar Estado'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Pedido: ${order['order_number'] ?? '#${order['id']}'}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
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
                onChanged: (v) => setDialogState(() => selected = v),
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
                        orderId: order['id'].toString(),
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

  Widget _badge(String status) {
    final label = _statusLabels[status] ?? status;
    final color = _statusColors[status] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  String _fmtDate(dynamic raw) {
    if (raw == null) return '';
    try {
      return DateFormat('dd/MM/yy HH:mm').format(DateTime.parse(raw.toString()));
    } catch (_) {
      return raw.toString();
    }
  }

  Widget _shimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: 6,
        itemBuilder: (_, __) => Container(
          height: 100,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _error(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment_outlined,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('No hay pedidos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              _selectedStatus != null
                  ? 'No se encontraron pedidos con este filtro'
                  : 'Los pedidos aparecerán aquí',
              style: TextStyle(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
