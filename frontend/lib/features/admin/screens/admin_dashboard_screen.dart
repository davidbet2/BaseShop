import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:baseshop/core/theme/app_theme.dart';

/// Admin Dashboard Screen.
///
/// Displays summary stats (orders, revenue, products, customers) and
/// a list of recent orders with quick‑action buttons.
///
/// TODO: Connect to real API stats endpoint (GET /orders/stats/summary)
///       and products count once the admin BLoC layer is implemented.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _currencyFormat = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  // ── Placeholder data ────────────────────────────────────────────────
  // TODO: Replace with real data fetched from orders/stats and products count
  final int _totalOrders = 156;
  final double _monthlyRevenue = 12450000;
  final int _activeProducts = 83;
  final int _totalCustomers = 342;

  final List<Map<String, dynamic>> _recentOrders = const [
    {
      'order_number': 'ORD-20260215-001',
      'customer': 'Juan Pérez',
      'total': 245000,
      'status': 'pending',
      'date': '2026-02-15',
    },
    {
      'order_number': 'ORD-20260214-005',
      'customer': 'María López',
      'total': 189000,
      'status': 'confirmed',
      'date': '2026-02-14',
    },
    {
      'order_number': 'ORD-20260214-003',
      'customer': 'Carlos Gómez',
      'total': 520000,
      'status': 'shipped',
      'date': '2026-02-14',
    },
    {
      'order_number': 'ORD-20260213-012',
      'customer': 'Ana Rodríguez',
      'total': 98000,
      'status': 'delivered',
      'date': '2026-02-13',
    },
    {
      'order_number': 'ORD-20260213-008',
      'customer': 'Pedro Martínez',
      'total': 372000,
      'status': 'processing',
      'date': '2026-02-13',
    },
  ];

  // ── Status helpers ──────────────────────────────────────────────────

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

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Administración'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // TODO: Dispatch refresh event to admin stats BLoC
          await Future<void>.delayed(const Duration(milliseconds: 500));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildStatsGrid(),
            const SizedBox(height: 24),
            _buildQuickActions(),
            const SizedBox(height: 24),
            _buildRecentOrdersSection(),
          ],
        ),
      ),
    );
  }

  // ── Stats grid ──────────────────────────────────────────────────────

  Widget _buildStatsGrid() {
    final stats = <_StatItem>[
      _StatItem(
        icon: Icons.assignment,
        color: AppTheme.primaryColor,
        value: _totalOrders.toString(),
        label: 'Total de Pedidos',
      ),
      _StatItem(
        icon: Icons.attach_money,
        color: AppTheme.successColor,
        value: _currencyFormat.format(_monthlyRevenue),
        label: 'Ingresos del Mes',
      ),
      _StatItem(
        icon: Icons.inventory_2,
        color: AppTheme.accentColor,
        value: _activeProducts.toString(),
        label: 'Productos Activos',
      ),
      _StatItem(
        icon: Icons.people,
        color: Colors.purple,
        value: _totalCustomers.toString(),
        label: 'Clientes',
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stats.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.45,
      ),
      itemBuilder: (context, index) => _buildStatCard(stats[index]),
    );
  }

  Widget _buildStatCard(_StatItem item) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(item.icon, color: item.color, size: 26),
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                item.value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Quick actions ───────────────────────────────────────────────────

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              // TODO: Navigate to add product screen / open form
              context.push('/admin/products');
            },
            icon: const Icon(Icons.add_box_outlined, size: 20),
            label: const Text('Nuevo Producto'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              context.push('/admin/orders');
            },
            icon: const Icon(Icons.list_alt, size: 20),
            label: const Text('Ver Pedidos'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              side: const BorderSide(color: AppTheme.primaryColor),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Recent orders ───────────────────────────────────────────────────

  Widget _buildRecentOrdersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Pedidos Recientes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            TextButton(
              onPressed: () => context.push('/admin/orders'),
              child: const Text('Ver todos'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._recentOrders.map(_buildRecentOrderCard),
      ],
    );
  }

  Widget _buildRecentOrderCard(Map<String, dynamic> order) {
    final status = order['status'] as String? ?? 'pending';
    final statusLabel = _statusLabels[status] ?? status;
    final statusColor = _statusColors[status] ?? Colors.grey;
    final total = (order['total'] as num?)?.toDouble() ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          order['order_number'] as String? ?? '',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${order['customer'] ?? ''} · ${order['date'] ?? ''}',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _currencyFormat.format(total),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
        onTap: () {
          // TODO: Navigate to order detail
        },
      ),
    );
  }
}

// ── Helper model ────────────────────────────────────────────────────────
class _StatItem {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _StatItem({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });
}
