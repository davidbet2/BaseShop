import 'dart:convert';
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

/// Admin Orders Management Screen – redesigned for web.
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
  static const _limit = 20;

  // Stats
  Map<String, dynamic>? _stats;
  bool _statsLoading = true;

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

  static const _statusIcons = <String, IconData>{
    'pending': Icons.schedule,
    'confirmed': Icons.check_circle_outline,
    'processing': Icons.autorenew,
    'shipped': Icons.local_shipping_outlined,
    'delivered': Icons.done_all,
    'cancelled': Icons.cancel_outlined,
    'refunded': Icons.replay,
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
    _loadStats();
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

  void _loadStats() async {
    try {
      final repo = _bloc.repository;
      final stats = await repo.getOrderStats();
      if (mounted) setState(() { _stats = stats; _statsLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _statsLoading = false);
    }
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
    _loadStats();
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;

    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        appBar: AppBar(title: const Text('Gestionar Pedidos')),
        body: RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 24 : 12,
              vertical: 16,
            ),
            children: [
              if (isWide) _buildStatsRow(),
              _buildSearchBar(),
              _buildStatusChips(),
              const SizedBox(height: 8),
              _buildOrdersList(isWide),
            ],
          ),
        ),
      ),
    );
  }

  // ── Stats Cards ────────────────────────────────────────────

  Widget _buildStatsRow() {
    if (_statsLoading) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          children: List.generate(4, (_) => Expanded(
            child: Shimmer.fromColors(
              baseColor: Colors.grey.shade300,
              highlightColor: Colors.grey.shade100,
              child: Container(
                height: 90,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          )),
        ),
      );
    }

    if (_stats == null) return const SizedBox.shrink();

    final totalOrders = _stats!['totalOrders'] ?? 0;
    final revenue = _stats!['revenue'] ?? {};
    final byStatus = Map<String, dynamic>.from(_stats!['byStatus'] ?? {});
    final pendingCount = byStatus['pending'] ?? 0;
    final todayRevenue = (revenue['today']?['amount'] as num?)?.toDouble() ?? 0;
    final monthRevenue = (revenue['month']?['amount'] as num?)?.toDouble() ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          _statCard('Total Pedidos', totalOrders.toString(),
              Icons.shopping_bag_outlined, Colors.blue),
          _statCard('Pendientes', pendingCount.toString(),
              Icons.schedule, Colors.orange),
          _statCard('Hoy', _currencyFmt.format(todayRevenue),
              Icons.today, Colors.green),
          _statCard('Este Mes', _currencyFmt.format(monthRevenue),
              Icons.calendar_month, Colors.purple),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(label,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Search ─────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 4),
      child: TextField(
        controller: _searchCtrl,
        decoration: InputDecoration(
          hintText: 'Buscar por número, nombre o email…',
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
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: _statusFilters.entries.map((e) {
          final sel = e.key == current;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(e.value),
              selected: sel,
              selectedColor:
                  Theme.of(context).colorScheme.primary.withOpacity(0.15),
              checkmarkColor: Theme.of(context).colorScheme.primary,
              labelStyle: TextStyle(
                color: sel
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.shade700,
                fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
              ),
              onSelected: (_) => _onFilterChanged(e.key),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Orders list ────────────────────────────────────────────

  Widget _buildOrdersList(bool isWide) {
    return BlocConsumer<OrdersBloc, OrdersState>(
      listener: (context, state) {
        if (state is OrderStatusUpdated) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Estado actualizado')),
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
          final totalPages = (state.total / _limit).ceil().clamp(1, 999);
          return Column(
            children: [
              isWide ? _buildTable(state) : _buildMobileCards(state),
              if (totalPages > 1) _buildPaginationBar(totalPages),
            ],
          );
        }
        if (state is OrdersError) return _error(state.message);
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildPaginationBar(int totalPages) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _page > 1
                ? () {
                    setState(() => _page--);
                    _loadOrders();
                  }
                : null,
          ),
          const SizedBox(width: 8),
          Text(
            'Página $_page de $totalPages',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _page < totalPages
                ? () {
                    setState(() => _page++);
                    _loadOrders();
                  }
                : null,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ── WEB TABLE ──────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════

  Widget _buildTable(OrdersLoaded state) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
                columnSpacing: 20,
                columns: const [
                  DataColumn(label: Text('Pedido',
                      style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('Cliente',
                      style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('Productos',
                      style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('Total',
                      style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('Estado',
                      style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('Fecha',
                      style: TextStyle(fontWeight: FontWeight.w600))),
                  DataColumn(label: Text('Acciones',
                      style: TextStyle(fontWeight: FontWeight.w600))),
                ],
                rows: state.orders.map((order) => _buildTableRow(order)).toList(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  DataRow _buildTableRow(Map<String, dynamic> order) {
    final status = order['status'] as String? ?? 'pending';
    final total = (order['total'] as num?)?.toDouble() ?? 0;
    final customerName = _customerName(order);
    final customerEmail = order['customer_email'] ?? '';
    final itemsCount = order['items_count'] ?? 0;
    final date = _fmtDate(order['created_at'] ?? order['date']);
    final nextStatuses = _statusTransitions[status] ?? <String>[];

    return DataRow(
      cells: [
        // Pedido
        DataCell(
          Text(
            order['order_number'] as String? ?? '#${order['id']}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
        // Cliente
        DataCell(
          SizedBox(
            width: 180,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(customerName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    overflow: TextOverflow.ellipsis),
                if (customerEmail.toString().isNotEmpty)
                  Text(customerEmail.toString(),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
        // Productos
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('$itemsCount items',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ),
        // Total
        DataCell(Text(_currencyFmt.format(total),
            style: const TextStyle(fontWeight: FontWeight.w700))),
        // Estado
        DataCell(_statusBadge(status)),
        // Fecha
        DataCell(Text(date, style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
        // Acciones
        DataCell(Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (nextStatuses.isNotEmpty)
              _miniActionBtn(order, nextStatuses),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.visibility_outlined, size: 20),
              tooltip: 'Ver detalle',
              onPressed: () {
                final id = order['id']?.toString() ?? '';
                if (id.isNotEmpty) context.push('/admin/orders/$id');
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
  }

  // ═══════════════════════════════════════════════════════════
  // ── MOBILE CARDS ───────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════

  Widget _buildMobileCards(OrdersLoaded state) {
    return Column(
      children: state.orders.map((o) => _orderCard(o)).toList(),
    );
  }

  Widget _orderCard(Map<String, dynamic> order) {
    final status = order['status'] as String? ?? 'pending';
    final total = (order['total'] as num?)?.toDouble() ?? 0;
    final customerName = _customerName(order);
    final customerEmail = order['customer_email'] ?? '';
    final shippingAddr = _parseShippingAddress(order['shipping_address']);
    final itemsCount = order['items_count'] ?? 0;
    final date = _fmtDate(order['created_at'] ?? order['date']);
    final nextStatuses = _statusTransitions[status] ?? <String>[];
    final statusIcon = _statusIcons[status] ?? Icons.help_outline;
    final statusColor = _statusColors[status] ?? Colors.grey;

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
              // Row 1: Order number + status badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      order['order_number'] as String? ?? '#${order['id']}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _statusBadge(status),
                ],
              ),
              const SizedBox(height: 10),
              // Row 2: Customer info
              Row(
                children: [
                  Icon(Icons.person_outline, size: 15, color: statusColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      customerName + (customerEmail.toString().isNotEmpty
                          ? ' · $customerEmail'
                          : ''),
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              // Row 3: Shipping address
              if (shippingAddr.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined,
                        size: 15, color: Colors.grey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(shippingAddr,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              // Row 4: Total, items count, date, action
              Row(
                children: [
                  Text(
                    _currencyFmt.format(total),
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('$itemsCount items',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600)),
                  ),
                  const Spacer(),
                  Icon(statusIcon, size: 14, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text(date,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500)),
                ],
              ),
              // Row 5: Quick action
              if (nextStatuses.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _miniActionBtn(order, nextStatuses),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ── SHARED WIDGETS ─────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════

  Widget _statusBadge(String status) {
    final label = _statusLabels[status] ?? status;
    final color = _statusColors[status] ?? Colors.grey;
    final icon = _statusIcons[status] ?? Icons.help_outline;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _miniActionBtn(
      Map<String, dynamic> order, List<String> nextStatuses) {
    final primary = nextStatuses.firstWhere(
        (s) => s != 'cancelled',
        orElse: () => nextStatuses.first);
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
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 11)),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ── DIALOGS ────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════

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

  // ═══════════════════════════════════════════════════════════
  // ── HELPERS ────────────────────────────────────────────────
  // ═══════════════════════════════════════════════════════════

  String _customerName(Map<String, dynamic> order) {
    // Check each field for non-null AND non-empty
    for (final key in ['customer_name', 'customer', 'user_name']) {
      final val = order[key];
      if (val != null && val.toString().isNotEmpty) return val.toString();
    }
    // Fallback to email prefix
    final email = (order['customer_email'] ?? order['user_email'] ?? '').toString();
    if (email.isNotEmpty) return email.split('@').first;
    return 'Sin nombre';
  }

  String _parseShippingAddress(dynamic raw) {
    if (raw == null || raw.toString().isEmpty) return '';
    try {
      if (raw is String) {
        final parsed = json.decode(raw);
        if (parsed is Map) {
          final parts = <String>[];
          final street = parsed['street'] ?? parsed['address'] ?? '';
          final city = parsed['city'] ?? '';
          final state = parsed['state'] ?? '';
          final zip = parsed['zip_code'] ?? parsed['postal_code'] ?? '';
          if (street.toString().isNotEmpty) parts.add(street.toString());
          if (city.toString().isNotEmpty) parts.add(city.toString());
          if (state.toString().isNotEmpty) parts.add(state.toString());
          if (zip.toString().isNotEmpty) parts.add(zip.toString());
          return parts.join(', ');
        }
        return raw;
      }
      if (raw is Map) {
        final parts = <String>[];
        final street = raw['street'] ?? raw['address'] ?? '';
        final city = raw['city'] ?? '';
        final state = raw['state'] ?? '';
        if (street.toString().isNotEmpty) parts.add(street.toString());
        if (city.toString().isNotEmpty) parts.add(city.toString());
        if (state.toString().isNotEmpty) parts.add(state.toString());
        return parts.join(', ');
      }
    } catch (_) {
      return raw.toString();
    }
    return raw.toString();
  }

  String _fmtDate(dynamic raw) {
    if (raw == null) return '';
    try {
      return DateFormat('dd/MM/yy HH:mm')
          .format(DateTime.parse(raw.toString()));
    } catch (_) {
      return raw.toString();
    }
  }

  Widget _shimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Column(
        children: List.generate(
          5,
          (_) => Container(
            height: 80,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
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
