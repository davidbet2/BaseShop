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

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late final OrdersBloc _bloc;
  String? _selectedStatus;

  final _currencyFormat = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  static const _statusFilters = <String, String>{
    'all': 'Todos',
    'pending': 'Pendientes',
    'confirmed': 'Confirmados',
    'shipped': 'Enviados',
    'delivered': 'Entregados',
    'cancelled': 'Cancelados',
  };

  @override
  void initState() {
    super.initState();
    _bloc = getIt<OrdersBloc>();
    _bloc.add(const LoadMyOrders());
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  void _onStatusSelected(String key) {
    setState(() {
      _selectedStatus = key == 'all' ? null : key;
    });
    _bloc.add(LoadMyOrders(status: _selectedStatus));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        appBar: AppBar(title: const Text('Mis Pedidos')),
        body: Column(
          children: [
            _buildStatusChips(),
            Expanded(
              child: BlocBuilder<OrdersBloc, OrdersState>(
                builder: (context, state) {
                  if (state is OrdersLoading) {
                    return _buildLoadingShimmer();
                  }

                  if (state is OrdersLoaded) {
                    if (state.orders.isEmpty) {
                      return _buildEmptyState();
                    }
                    return _buildOrdersList(state);
                  }

                  if (state is OrdersError) {
                    return _buildErrorState(state.message);
                  }

                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChips() {
    final currentKey = _selectedStatus ?? 'all';
    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: _statusFilters.entries.map((entry) {
          final isSelected = entry.key == currentKey;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(entry.value),
              selected: isSelected,
              onSelected: (_) => _onStatusSelected(entry.key),
              selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
              checkmarkColor: AppTheme.primaryColor,
              labelStyle: TextStyle(
                color: isSelected ? AppTheme.primaryColor : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOrdersList(OrdersLoaded state) {
    return RefreshIndicator(
      onRefresh: () async {
        _bloc.add(LoadMyOrders(status: _selectedStatus));
        await _bloc.stream.firstWhere((s) => s is! OrdersLoading);
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: state.orders.length,
        itemBuilder: (context, index) {
          final order = state.orders[index];
          return _buildOrderCard(context, order);
        },
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context, Map<String, dynamic> order) {
    final orderId = (order['_id'] ?? order['id'] ?? '').toString();
    final orderNumber =
        (order['orderNumber'] ?? order['order_number'] ?? orderId)
            .toString();
    final status = (order['status'] ?? 'pending').toString();
    final total = (order['total'] ?? 0) as num;
    final itemCount = (order['items'] as List?)?.length ?? 0;

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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/orders/$orderId'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Pedido #$orderNumber',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildStatusBadge(status),
                ],
              ),
              if (dateStr.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  dateStr,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
              ],
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$itemCount artículo${itemCount != 1 ? 's' : ''}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    _currencyFormat.format(total),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
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
        return _StatusConfig('Confirmado', AppTheme.primaryColor);
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 100, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No tienes pedidos',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tus pedidos aparecerán aquí',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.go('/products'),
            icon: const Icon(Icons.storefront),
            label: const Text('Explorar productos'),
          ),
        ],
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
            onPressed: () =>
                _bloc.add(LoadMyOrders(status: _selectedStatus)),
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
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
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
