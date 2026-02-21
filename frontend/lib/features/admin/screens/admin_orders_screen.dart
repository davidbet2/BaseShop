import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';

import 'package:baseshop/core/di/injection.dart';
import 'package:baseshop/core/theme/app_theme.dart';
import 'package:baseshop/features/orders/bloc/orders_bloc.dart';
import 'package:baseshop/features/orders/bloc/orders_event.dart';
import 'package:baseshop/features/orders/bloc/orders_state.dart';

/// Admin Orders Management Screen.
///
/// Displays all orders with status filter chips, search, status‑update
/// dialogs, and quick‑action buttons based on current order status.
class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  late final OrdersBloc _bloc;
  final _searchController = TextEditingController();
  String? _selectedStatus;
  int _currentPage = 1;
  final _scrollController = ScrollController();

  final _currencyFormat = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  // ── Status maps ─────────────────────────────────────────────────────

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
  };

  static const _statusColors = <String, Color>{
    'pending': Colors.orange,
    'confirmed': Color(0xFF1565C0),
    'processing': Colors.purple,
    'shipped': Colors.indigo,
    'delivered': Color(0xFF388E3C),
    'cancelled': Color(0xFFD32F2F),
  };

  /// Allowed next statuses given the current status.
  static const _statusTransitions = <String, List<String>>{
    'pending': ['confirmed', 'cancelled'],
    'confirmed': ['processing', 'cancelled'],
    'processing': ['shipped', 'cancelled'],
    'shipped': ['delivered'],
    'delivered': [],
    'cancelled': [],
  };

  @override
  void initState() {
    super.initState();
    _bloc = getIt<OrdersBloc>();
    _bloc.add(const LoadMyOrders()); // admin uses same endpoint; backend scopes by role
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _bloc.close();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final state = _bloc.state;
      if (state is OrdersLoaded) {
        final totalPages = (state.total / 20).ceil();
        if (_currentPage < totalPages) {
          _currentPage++;
          _bloc.add(LoadMyOrders(status: _selectedStatus, page: _currentPage));
        }
      }
    }
  }

  void _onStatusFilterSelected(String key) {
    setState(() {
      _selectedStatus = key == 'all' ? null : key;
      _currentPage = 1;
    });
    _bloc.add(LoadMyOrders(status: _selectedStatus));
  }

  void _refresh() {
    _currentPage = 1;
    _bloc.add(LoadMyOrders(status: _selectedStatus));
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Gestionar Pedidos'),
          actions: [
            IconButton(
              icon: const Icon(Icons.filter_list),
              tooltip: 'Filtros',
              onPressed: () => _showFilterDialog(),
            ),
          ],
        ),
        body: Column(
          children: [
            // Search bar
            _buildSearchBar(),
            // Status filter chips
            _buildStatusChips(),
            // Orders list
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => _refresh(),
                child: BlocBuilder<OrdersBloc, OrdersState>(
                  builder: (context, state) {
                    if (state is OrdersLoading) return _buildLoadingShimmer();
                    if (state is OrdersLoaded) {
                      if (state.orders.isEmpty) return _buildEmptyState();
                      return _buildOrdersList(state);
                    }
                    if (state is OrdersError) {
                      return _buildErrorState(state.message);
                    }
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

  // ── Search bar ──────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Buscar por número de pedido…',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                    // TODO: filter locally or dispatch search event
                  },
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) {
          // TODO: dispatch search / filter event
        },
      ),
    );
  }

  // ── Status chips ────────────────────────────────────────────────────

  Widget _buildStatusChips() {
    final currentKey = _selectedStatus ?? 'all';
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: _statusFilters.entries.map((e) {
          final isSelected = e.key == currentKey;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(e.value),
              selected: isSelected,
              selectedColor: AppTheme.primaryColor.withOpacity(0.15),
              checkmarkColor: AppTheme.primaryColor,
              labelStyle: TextStyle(
                color: isSelected ? AppTheme.primaryColor : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              onSelected: (_) => _onStatusFilterSelected(e.key),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Orders list ─────────────────────────────────────────────────────

  Widget _buildOrdersList(OrdersLoaded state) {
    // Apply local search filter on order_number
    final searchTerm = _searchController.text.trim().toLowerCase();
    final filtered = searchTerm.isEmpty
        ? state.orders
        : state.orders.where((o) {
            final orderNum =
                (o['order_number'] as String? ?? '').toLowerCase();
            return orderNum.contains(searchTerm);
          }).toList();

    if (filtered.isEmpty) return _buildEmptyState();

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: filtered.length,
      itemBuilder: (context, index) => _buildOrderCard(filtered[index]),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final orderNumber = order['order_number'] as String? ?? '';
    final status = order['status'] as String? ?? 'pending';
    final statusLabel = _statusLabels[status] ?? status;
    final statusColor = _statusColors[status] ?? Colors.grey;
    final total = (order['total'] as num?)?.toDouble() ?? 0;
    final userId = order['user_id'] as String? ?? order['user'] as String? ?? '';
    final createdAt = order['created_at'] as String? ??
        order['createdAt'] as String? ??
        '';

    String formattedDate = createdAt;
    try {
      final dt = DateTime.parse(createdAt);
      formattedDate = DateFormat('dd/MM/yyyy HH:mm', 'es_CO').format(dt);
    } catch (_) {}

    // Determine quick actions based on current status
    final nextStatuses = _statusTransitions[status] ?? <String>[];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // TODO: Navigate to admin order detail
        },
        onLongPress: () => _showStatusChangeDialog(order),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      orderNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Details row
              Row(
                children: [
                  Icon(Icons.person_outline,
                      size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      userId.isNotEmpty ? userId : 'Cliente',
                      style: TextStyle(
                          fontSize: 13, color: Colors.grey.shade700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.calendar_today,
                      size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    formattedDate,
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Total & quick actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _currencyFormat.format(total),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: _buildQuickActions(order, nextStatuses),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Quick action buttons ────────────────────────────────────────────

  List<Widget> _buildQuickActions(
    Map<String, dynamic> order,
    List<String> nextStatuses,
  ) {
    const actionConfig = <String, _QuickAction>{
      'confirmed': _QuickAction('Confirmar', Icons.check_circle_outline,
          Color(0xFF1565C0)),
      'processing': _QuickAction(
          'Procesar', Icons.engineering_outlined, Colors.purple),
      'shipped': _QuickAction('Enviar', Icons.local_shipping_outlined,
          Colors.indigo),
      'delivered': _QuickAction(
          'Entregar', Icons.done_all, Color(0xFF388E3C)),
      'cancelled': _QuickAction(
          'Cancelar', Icons.cancel_outlined, Color(0xFFD32F2F)),
    };

    return nextStatuses
        .where((s) => s != 'cancelled') // show cancel only via long-press
        .map((nextStatus) {
      final cfg = actionConfig[nextStatus];
      if (cfg == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(left: 6),
        child: SizedBox(
          height: 32,
          child: OutlinedButton.icon(
            onPressed: () =>
                _confirmStatusChange(order, nextStatus, cfg.label),
            icon: Icon(cfg.icon, size: 16),
            label: Text(cfg.label, style: const TextStyle(fontSize: 12)),
            style: OutlinedButton.styleFrom(
              foregroundColor: cfg.color,
              side: BorderSide(color: cfg.color.withOpacity(0.5)),
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  // ── Confirm quick status change ─────────────────────────────────────

  Future<void> _confirmStatusChange(
    Map<String, dynamic> order,
    String newStatus,
    String actionLabel,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$actionLabel pedido'),
        content: Text(
          '¿Cambiar estado de "${order['order_number']}" a '
          '"${_statusLabels[newStatus] ?? newStatus}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      // TODO: Dispatch UpdateOrderStatus event
      debugPrint(
          '[AdminOrders] Update ${order['order_number']} → $newStatus');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Pedido actualizado a ${_statusLabels[newStatus] ?? newStatus}'),
        ),
      );
      _refresh();
    }
  }

  // ── Status change dialog (long‑press / full dropdown) ──────────────

  void _showStatusChangeDialog(Map<String, dynamic> order) {
    final currentStatus = order['status'] as String? ?? 'pending';
    final nextStatuses = _statusTransitions[currentStatus] ?? <String>[];
    if (nextStatuses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se puede cambiar el estado')),
      );
      return;
    }

    String? selected;
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Cambiar Estado'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Pedido: ${order['order_number'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selected,
                  decoration: InputDecoration(
                    labelText: 'Nuevo estado',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: nextStatuses.map((s) {
                    return DropdownMenuItem(
                      value: s,
                      child: Text(_statusLabels[s] ?? s),
                    );
                  }).toList(),
                  onChanged: (val) =>
                      setDialogState(() => selected = val),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Nota (opcional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: selected == null
                    ? null
                    : () {
                        // TODO: Dispatch UpdateOrderStatus(orderId, selected, note)
                        debugPrint(
                          '[AdminOrders] Status change: '
                          '${order['order_number']} → $selected '
                          '| note: ${noteCtrl.text}',
                        );
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Estado actualizado a '
                              '${_statusLabels[selected!] ?? selected}',
                            ),
                          ),
                        );
                        _refresh();
                      },
                child: const Text('Actualizar'),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Filter dialog ───────────────────────────────────────────────────

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Filtrar por estado'),
        children: _statusFilters.entries.map((e) {
          final isSelected =
              e.key == (_selectedStatus ?? 'all');
          return SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              _onStatusFilterSelected(e.key);
            },
            child: Row(
              children: [
                if (isSelected)
                  const Icon(Icons.check, color: AppTheme.primaryColor,
                      size: 20)
                else
                  const SizedBox(width: 20),
                const SizedBox(width: 12),
                Text(
                  e.value,
                  style: TextStyle(
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.normal,
                    color: isSelected
                        ? AppTheme.primaryColor
                        : Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Loading shimmer ─────────────────────────────────────────────────

  Widget _buildLoadingShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: 6,
        itemBuilder: (_, __) => Container(
          height: 110,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  // ── Error state ─────────────────────────────────────────────────────

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
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

  // ── Empty state ─────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment_outlined,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No hay pedidos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
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

// ── Helper ────────────────────────────────────────────────────────────
class _QuickAction {
  final String label;
  final IconData icon;
  final Color color;

  const _QuickAction(this.label, this.icon, this.color);
}
