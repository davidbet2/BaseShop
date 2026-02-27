import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
  int _page = 1;
  static const _limit = 20;

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

  static const _statusIcons = <String, IconData>{
    'pending': Icons.schedule,
    'confirmed': Icons.check_circle_outline,
    'processing': Icons.autorenew,
    'shipped': Icons.local_shipping_outlined,
    'delivered': Icons.done_all,
    'cancelled': Icons.cancel_outlined,
    'refunded': Icons.replay,
  };

  @override
  void initState() {
    super.initState();
    _bloc = getIt<OrdersBloc>();
    _loadOrders();
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  void _loadOrders() {
    _bloc.add(LoadMyOrders(status: _selectedStatus, page: _page));
  }

  void _onStatusSelected(String key) {
    setState(() {
      _selectedStatus = key == 'all' ? null : key;
      _page = 1;
    });
    _loadOrders();
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
              selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
              checkmarkColor: Theme.of(context).colorScheme.primary,
              labelStyle: TextStyle(
                color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildOrdersList(OrdersLoaded state) {
    final totalPages = (state.total / _limit).ceil().clamp(1, 999);

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              _loadOrders();
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
          ),
        ),
        if (totalPages > 1) _buildPaginationBar(totalPages),
      ],
    );
  }

  Widget _buildPaginationBar(int totalPages) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
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

  List<Map<String, dynamic>> _parseItems(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = json.decode(raw);
        if (decoded is List) {
          return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      } catch (_) {}
    }
    return [];
  }

  Widget _buildOrderCard(BuildContext context, Map<String, dynamic> order) {
    final orderId = (order['_id'] ?? order['id'] ?? '').toString();
    final orderNumber =
        (order['orderNumber'] ?? order['order_number'] ?? orderId).toString();
    final status = (order['status'] ?? 'pending').toString();
    final total = (order['total'] ?? 0) as num;
    final items = _parseItems(order['items']);
    final itemCount = order['items_count'] ?? items.length;
    final statusIcon = _statusIcons[status] ?? Icons.help_outline;

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
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/orders/$orderId'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: Order number + status badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Pedido #$orderNumber',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildStatusBadge(status),
                ],
              ),
              if (dateStr.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 13, color: Colors.grey.shade500),
                    const SizedBox(width: 4),
                    Text(
                      dateStr,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ],

              // Product thumbnails + names
              if (items.isNotEmpty) ...[
                const SizedBox(height: 10),
                ...items.take(3).map((item) {
                  final productName = (item['product_name'] ?? item['name'] ?? 'Producto').toString();
                  final productImage = (item['product_image'] ?? item['image'] ?? '').toString();
                  final qty = item['quantity'] ?? 1;
                  final price = (item['product_price'] ?? item['price'] ?? 0) as num;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: productImage.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: productImage,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => _imgPlaceholder(40),
                                )
                              : _imgPlaceholder(40),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                productName,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'x$qty · ${_currencyFormat.format(price)}',
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                if (itemCount > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '+${itemCount - 3} producto${(itemCount - 3) != 1 ? 's' : ''} más',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                    ),
                  ),
              ],

              const Divider(height: 16),
              // Bottom row: item count + total + status icon
              Row(
                children: [
                  Icon(statusIcon, size: 15, color: Colors.grey.shade400),
                  const SizedBox(width: 6),
                  Text(
                    '$itemCount artículo${itemCount != 1 ? 's' : ''}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const Spacer(),
                  Text(
                    _currencyFormat.format(total),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      color: Theme.of(context).colorScheme.primary,
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

  Widget _imgPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(Icons.inventory_2, color: Colors.grey.shade400, size: size * 0.5),
    );
  }

  Widget _buildStatusBadge(String status) {
    final config = _statusConfig(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_statusIcons[status] ?? Icons.help_outline, size: 13, color: config.color),
          const SizedBox(width: 4),
          Text(
            config.label,
            style: TextStyle(
              color: config.color,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
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
            onPressed: () => _loadOrders(),
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
            height: 160,
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
