import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:baseshop/core/di/injection.dart';
import 'package:baseshop/core/network/api_client.dart';
import 'package:baseshop/core/theme/app_theme.dart';

/// Modern responsive Admin Dashboard — optimized for web.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _currencyFmt = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  bool _loading = true;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _recentOrders = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final dio = getIt<ApiClient>().dio;

    try {
      final statsRes = await dio.get('/orders/stats/summary');
      final raw = statsRes.data;
      // API wraps in { data: { ... } }
      _stats = Map<String, dynamic>.from(raw?['data'] ?? raw ?? {});
    } catch (_) {}

    try {
      final ordersRes =
          await dio.get('/orders', queryParameters: {'limit': 8, 'page': 1});
      final data = ordersRes.data;
      _recentOrders = List<Map<String, dynamic>>.from(
          data?['data'] ?? data?['orders'] ?? []);
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

  // ── Parsed stats helpers ───────────────────────────────────

  int get _totalOrders => (_stats['totalOrders'] as num?)?.toInt() ?? 0;

  Map<String, dynamic> get _byStatus =>
      Map<String, dynamic>.from(_stats['byStatus'] ?? {});

  Map<String, dynamic> get _revenue =>
      Map<String, dynamic>.from(_stats['revenue'] ?? {});

  double _revenueAmount(String period) {
    final p = _revenue[period];
    if (p is Map) return (p['amount'] as num?)?.toDouble() ?? 0;
    return 0;
  }

  int _revenueOrders(String period) {
    final p = _revenue[period];
    if (p is Map) return (p['orders'] as num?)?.toInt() ?? 0;
    return 0;
  }

  int _statusCount(String status) =>
      (_byStatus[status] as num?)?.toInt() ?? 0;

  // ── Status helpers ─────────────────────────────────────────

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

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isWide = w > 800;
    final isExtraWide = w > 1200;

    return Scaffold(
      appBar: AppBar(title: const Text('Panel de Administración')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 32 : 16,
                  vertical: 20,
                ),
                children: [
                  // ── 1. KPI Stats ──────────────────────────
                  _buildStatsGrid(isWide, isExtraWide),
                  const SizedBox(height: 24),

                  // ── 2. Revenue cards ───────────────────────
                  _buildRevenueRow(isWide),
                  const SizedBox(height: 24),

                  // ── 3. Main content ───────────────────────
                  if (isWide)
                    _buildWideLayout()
                  else ...[
                    _buildQuickActions(),
                    const SizedBox(height: 20),
                    _buildStatusBreakdown(),
                    const SizedBox(height: 20),
                    _buildRecentOrders(false),
                  ],
                ],
              ),
      ),
    );
  }

  // ── Stats grid ─────────────────────────────────────────────

  Widget _buildStatsGrid(bool isWide, bool isExtraWide) {
    final pending = _statusCount('pending');
    final delivered = _statusCount('delivered');
    final processing = _statusCount('processing');
    final shipped = _statusCount('shipped');

    final items = <_StatItem>[
      _StatItem(
        icon: Icons.assignment_rounded,
        color: Theme.of(context).colorScheme.primary,
        value: _totalOrders.toString(),
        label: 'Total Pedidos',
      ),
      _StatItem(
        icon: Icons.hourglass_top_rounded,
        color: Colors.orange,
        value: pending.toString(),
        label: 'Pendientes',
      ),
      _StatItem(
        icon: Icons.sync_rounded,
        color: Colors.purple,
        value: processing.toString(),
        label: 'En Proceso',
      ),
      _StatItem(
        icon: Icons.local_shipping_rounded,
        color: Colors.indigo,
        value: shipped.toString(),
        label: 'Enviados',
      ),
      _StatItem(
        icon: Icons.check_circle_rounded,
        color: const Color(0xFF388E3C),
        value: delivered.toString(),
        label: 'Entregados',
      ),
    ];

    final cols = isExtraWide ? 5 : isWide ? 5 : 2;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: isWide ? 1.8 : 1.45,
      ),
      itemBuilder: (_, i) => _statCard(items[i]),
    );
  }

  // ── Revenue row ────────────────────────────────────────────

  Widget _buildRevenueRow(bool isWide) {
    final revenueItems = <_StatItem>[
      _StatItem(
        icon: Icons.today_rounded,
        color: const Color(0xFF00897B),
        value: _currencyFmt.format(_revenueAmount('today')),
        label: 'Ingresos Hoy (${_revenueOrders('today')} pedidos)',
      ),
      _StatItem(
        icon: Icons.date_range_rounded,
        color: const Color(0xFF1565C0),
        value: _currencyFmt.format(_revenueAmount('week')),
        label: 'Ingresos Semana (${_revenueOrders('week')} pedidos)',
      ),
      _StatItem(
        icon: Icons.calendar_month_rounded,
        color: const Color(0xFF6A1B9A),
        value: _currencyFmt.format(_revenueAmount('month')),
        label: 'Ingresos Mes (${_revenueOrders('month')} pedidos)',
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: revenueItems.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isWide ? 3 : 1,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: isWide ? 2.5 : 3.5,
      ),
      itemBuilder: (_, i) => _statCard(revenueItems[i]),
    );
  }

  Widget _statCard(_StatItem s) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: s.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(s.icon, color: s.color, size: 24),
            ),
            const SizedBox(height: 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                s.value,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              s.label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ── Wide layout: side-by-side ──────────────────────────────

  Widget _buildWideLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: Recent orders (takes most space)
        Expanded(
          flex: 3,
          child: _buildRecentOrders(true),
        ),
        const SizedBox(width: 20),
        // Right: Quick actions + Status breakdown
        Expanded(
          flex: 1,
          child: Column(
            children: [
              _buildQuickActions(),
              const SizedBox(height: 20),
              _buildStatusBreakdown(),
            ],
          ),
        ),
      ],
    );
  }

  // ── Quick actions ──────────────────────────────────────────

  Widget _buildQuickActions() {
    final primary = Theme.of(context).colorScheme.primary;
    final actions = [
      _QuickAction(
        icon: Icons.inventory_2_rounded,
        label: 'Productos',
        color: primary,
        onTap: () => context.go('/admin/products'),
      ),
      _QuickAction(
        icon: Icons.receipt_rounded,
        label: 'Pedidos',
        color: Colors.orange,
        onTap: () => context.go('/admin/orders'),
      ),
      _QuickAction(
        icon: Icons.settings_rounded,
        label: 'Config',
        color: const Color(0xFF546E7A),
        onTap: () => context.go('/admin/config'),
      ),
    ];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Acciones Rápidas',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            ...actions.map((a) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: a.onTap,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: a.color.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(a.icon, color: a.color, size: 20),
                      const SizedBox(width: 12),
                      Text(a.label, style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: a.color,
                        fontSize: 14,
                      )),
                      const Spacer(),
                      Icon(Icons.arrow_forward_ios_rounded, size: 14, color: a.color.withOpacity(0.5)),
                    ],
                  ),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  // ── Status breakdown ───────────────────────────────────────

  Widget _buildStatusBreakdown() {
    final entries = _byStatus.entries.toList()
      ..sort((a, b) => (b.value as num).compareTo(a.value as num));

    if (entries.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pedidos por Estado',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            ...entries.map((e) {
              final status = e.key;
              final count = (e.value as num).toInt();
              final color = _statusColors[status] ?? Colors.grey;
              final label = _statusLabels[status] ?? status;
              final pct = _totalOrders > 0 ? count / _totalOrders : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
                        Text('$count', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        backgroundColor: Colors.grey.shade100,
                        color: color,
                        minHeight: 6,
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

  // ── Recent orders ──────────────────────────────────────────

  Widget _buildRecentOrders(bool isWide) {
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
              onPressed: () => context.go('/admin/orders'),
              child: const Text('Ver todos'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_recentOrders.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text('Sin pedidos aún',
                  style: TextStyle(color: Colors.grey)),
            ),
          )
        else if (isWide)
          _buildOrdersTable()
        else
          ..._recentOrders.map(_buildOrderCard),
      ],
    );
  }

  Widget _buildOrdersTable() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: DataTable(
          showCheckboxColumn: false,
          headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
          columnSpacing: 24,
          columns: const [
            DataColumn(label: Text('Pedido', style: TextStyle(fontWeight: FontWeight.w600))),
            DataColumn(label: Text('Cliente', style: TextStyle(fontWeight: FontWeight.w600))),
            DataColumn(label: Text('Fecha', style: TextStyle(fontWeight: FontWeight.w600))),
            DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.w600))),
            DataColumn(label: Text('Estado', style: TextStyle(fontWeight: FontWeight.w600))),
          ],
          rows: _recentOrders.map((order) {
            final status = order['status'] as String? ?? 'pending';
            final total =
                (order['total'] as num?)?.toDouble() ?? 0;
            final customerName = order['customer_name'] ??
                order['customer'] ??
                order['user_name'] ??
                'Sin nombre';
            final date = order['created_at'] ?? order['date'] ?? '';
            String formattedDate = '';
            if (date is String && date.isNotEmpty) {
              try {
                formattedDate =
                    DateFormat('dd/MM/yyyy').format(DateTime.parse(date));
              } catch (_) {
                formattedDate = date;
              }
            }

            return DataRow(
              cells: [
                DataCell(
                  Text(
                    order['order_number'] as String? ?? '#${order['id']}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                DataCell(Text(customerName.toString())),
                DataCell(Text(formattedDate)),
                DataCell(Text(_currencyFmt.format(total))),
                DataCell(_statusBadge(status)),
              ],
              onSelectChanged: (_) {
                final id = order['id']?.toString() ?? '';
                if (id.isNotEmpty) context.push('/admin/orders/$id');
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = order['status'] as String? ?? 'pending';
    final total = (order['total'] as num?)?.toDouble() ?? 0;
    final customerName = order['customer_name'] ??
        order['customer'] ??
        order['user_name'] ??
        'Sin nombre';
    final date = order['created_at'] ?? order['date'] ?? '';
    String formattedDate = '';
    if (date is String && date.isNotEmpty) {
      try {
        formattedDate =
            DateFormat('dd/MM/yy HH:mm').format(DateTime.parse(date));
      } catch (_) {
        formattedDate = date;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Row(
          children: [
            Expanded(
              child: Text(
                order['order_number'] as String? ?? '#${order['id']}',
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
            _statusBadge(status),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            children: [
              const Icon(Icons.person_outline, size: 14, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '$customerName  ·  $formattedDate',
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                _currencyFmt.format(total),
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ],
          ),
        ),
        onTap: () {
          final id = order['id']?.toString() ?? '';
          if (id.isNotEmpty) context.push('/admin/orders/$id');
        },
      ),
    );
  }

  Widget _statusBadge(String status) {
    final label = _statusLabels[status] ?? status;
    final color = _statusColors[status] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

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

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}
