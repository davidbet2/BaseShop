import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart' as dio_pkg;
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

import 'package:baseshop/core/utils/image_compressor.dart';
import 'package:baseshop/core/di/injection.dart';
import 'package:baseshop/core/network/api_client.dart';
import 'package:baseshop/core/theme/app_theme.dart';
import 'package:baseshop/features/products/bloc/products_bloc.dart';
import 'package:baseshop/features/products/bloc/products_event.dart';
import 'package:baseshop/features/products/bloc/products_state.dart';

/// Admin Products & Categories screen with responsive layout and tabs.
class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen>
    with SingleTickerProviderStateMixin {
  late final ProductsBloc _bloc;
  late final TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  bool _searchVisible = false;
  int _page = 1;
  static const _limit = 20;

  // ── Multi-select state ─────────────────────────────────────
  bool _selectMode = false;
  bool _bulkDeleting = false;
  final Set<String> _selectedProductIds = {};
  final Set<String> _selectedCategoryIds = {};

  final _currencyFmt = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _bloc = getIt<ProductsBloc>();
    _tabCtrl = TabController(length: 2, vsync: this);
    _bloc.add(const LoadProducts());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabCtrl.dispose();
    _bloc.close();
    super.dispose();
  }

  void _refresh() {
    _bloc.add(LoadProducts(
      search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
      page: _page,
    ));
  }

  // ── Multi-select helpers ───────────────────────────────────

  String _id(Map<String, dynamic> item) =>
      (item['_id'] ?? item['id'] ?? '').toString();

  void _toggleProductSelection(String id) {
    setState(() {
      if (_selectedProductIds.contains(id)) {
        _selectedProductIds.remove(id);
      } else {
        _selectedProductIds.add(id);
      }
    });
  }

  void _toggleCategorySelection(String id) {
    setState(() {
      if (_selectedCategoryIds.contains(id)) {
        _selectedCategoryIds.remove(id);
      } else {
        _selectedCategoryIds.add(id);
      }
    });
  }

  Future<void> _deleteSelected() async {
    final prodCount = _selectedProductIds.length;
    final catCount = _selectedCategoryIds.length;
    if (prodCount == 0 && catCount == 0) return;

    final parts = <String>[];
    if (prodCount > 0) parts.add('$prodCount producto${prodCount > 1 ? 's' : ''}');
    if (catCount > 0) parts.add('$catCount categoría${catCount > 1 ? 's' : ''}');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar seleccionados'),
        content: Text('¿Eliminar ${parts.join(' y ')}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() {
      _bulkDeleting = true;
      _selectMode = false;
    });

    int deleted = 0;
    int failed = 0;
    final totalOps = _selectedProductIds.length + _selectedCategoryIds.length;

    for (final id in List.of(_selectedProductIds)) {
      _bloc.add(DeleteProduct(productId: id));
      // Give bloc time to process each event
      await Future.delayed(const Duration(milliseconds: 100));
      deleted++;
    }
    for (final id in List.of(_selectedCategoryIds)) {
      _bloc.add(DeleteCategory(categoryId: id));
      await Future.delayed(const Duration(milliseconds: 100));
      deleted++;
    }

    // Wait for last event to settle
    await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$totalOps elemento${totalOps > 1 ? 's' : ''} eliminado${totalOps > 1 ? 's' : ''}')),
      );
      _refresh();
    }

    setState(() {
      _bulkDeleting = false;
      _selectedProductIds.clear();
      _selectedCategoryIds.clear();
    });
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        appBar: AppBar(
          title: _searchVisible
              ? TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Buscar producto…',
                    hintStyle: TextStyle(color: Colors.white70),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _refresh(),
                )
              : const Text('Gestionar Productos'),
          actions: [
            IconButton(
              icon: Icon(_searchVisible ? Icons.close : Icons.search),
              onPressed: () {
                setState(() {
                  _searchVisible = !_searchVisible;
                  if (!_searchVisible) {
                    _searchCtrl.clear();
                    _refresh();
                  }
                });
              },
            ),
          ],
          bottom: TabBar(
            controller: _tabCtrl,
            tabs: const [
              Tab(text: 'Productos'),
              Tab(text: 'Categorías'),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          onPressed: () {
            if (_tabCtrl.index == 0) {
              _showProductForm(context);
            } else {
              _showCategoryForm(context);
            }
          },
          child: const Icon(Icons.add),
        ),
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _buildProductsTab(),
            _buildCategoriesTab(),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // ── PRODUCTS TAB ──────────────────────────────────────────
  // ══════════════════════════════════════════════════════════

  Widget _buildProductsTab() {
    return Column(
      children: [
        _buildProductsSelectionBar(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: BlocConsumer<ProductsBloc, ProductsState>(
        listener: (context, state) {
          if (_bulkDeleting) return; // Suppress individual alerts during bulk delete
          if (state is ProductActionSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
            _refresh();
          }
          if (state is ProductsError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppTheme.errorColor,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is ProductsLoading) return _shimmer();
          if (state is ProductsLoaded) {
            if (state.products.isEmpty) return _emptyProducts();
            final totalPages = (state.total / _limit).ceil().clamp(1, 999);
            return Column(
              children: [
                Expanded(child: _productsList(state)),
                if (totalPages > 1) _buildProductsPagination(totalPages),
              ],
            );
          }
          if (state is ProductsError) return _errorWidget(state.message);
          return const SizedBox.shrink();
        },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductsPagination(int totalPages) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
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
                    _refresh();
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
                    _refresh();
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildProductsSelectionBar() {
    if (!_selectMode) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            TextButton.icon(
              onPressed: () => setState(() => _selectMode = true),
              icon: const Icon(Icons.checklist, size: 20),
              label: const Text('Seleccionar'),
            ),
          ],
        ),
      );
    }
    return Container(
      color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            '${_selectedProductIds.length} seleccionados',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          if (_selectedProductIds.isNotEmpty)
            TextButton.icon(
              onPressed: _deleteSelected,
              icon: Icon(Icons.delete_sweep, color: AppTheme.errorColor),
              label: Text('Eliminar', style: TextStyle(color: AppTheme.errorColor)),
            ),
          TextButton.icon(
            onPressed: () => setState(() {
              _selectMode = false;
              _selectedProductIds.clear();
            }),
            icon: const Icon(Icons.close),
            label: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  Widget _productsList(ProductsLoaded state) {
    final isWide = MediaQuery.of(context).size.width > 800;

    if (isWide) {
      // ── Web: Full-width DataTable ──
      final primary = Theme.of(context).colorScheme.primary;
      final allSelected = state.products.isNotEmpty &&
          state.products.every((p) => _selectedProductIds.contains(_id(p)));

      return Padding(
        padding: const EdgeInsets.all(20),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            child: SizedBox(
              width: double.infinity,
              child: DataTable(
                columnSpacing: 24,
                horizontalMargin: 20,
                headingRowHeight: 52,
                dataRowMinHeight: 60,
                dataRowMaxHeight: 68,
                headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
                showCheckboxColumn: _selectMode,
                columns: [
                  const DataColumn(label: Text('Imagen', style: TextStyle(fontWeight: FontWeight.w700))),
                  const DataColumn(label: Text('Nombre', style: TextStyle(fontWeight: FontWeight.w700))),
                  const DataColumn(label: Text('Precio', style: TextStyle(fontWeight: FontWeight.w700)), numeric: true),
                  const DataColumn(label: Text('Stock', style: TextStyle(fontWeight: FontWeight.w700)), numeric: true),
                  const DataColumn(label: Text('Destacado', style: TextStyle(fontWeight: FontWeight.w700))),
                  const DataColumn(label: Text('Acciones', style: TextStyle(fontWeight: FontWeight.w700))),
                ],
                rows: state.products.map((product) {
                  final pid = _id(product);
                  final name = product['name'] as String? ?? 'Sin nombre';
                  final price = (product['price'] as num?)?.toDouble() ?? 0;
                  final stock = product['stock'] as int? ?? 0;
                  final isFeatured = product['is_featured'] == true || product['is_featured'] == 1;
                  final img = _extractFirstImage(product);

                  return DataRow(
                    selected: _selectedProductIds.contains(pid),
                    onSelectChanged: _selectMode
                        ? (_) => _toggleProductSelection(pid)
                        : null,
                    cells: [
                      // Image
                      DataCell(
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: img.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: img,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  placeholder: (_, __) => _imgPlaceholder(48),
                                  errorWidget: (_, __, ___) => _imgPlaceholder(48),
                                )
                              : _imgPlaceholder(48),
                        ),
                      ),
                      // Name
                      DataCell(
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 260),
                          child: Text(
                            name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        onTap: () => _showProductForm(context, product: product),
                      ),
                      // Price
                      DataCell(Text(
                        _currencyFmt.format(price),
                        style: TextStyle(fontWeight: FontWeight.w600, color: primary),
                      )),
                      // Stock
                      DataCell(_badge(
                        stock > 0 ? '$stock' : 'Agotado',
                        stock > 0 ? AppTheme.successColor : AppTheme.errorColor,
                      )),
                      // Featured toggle
                      DataCell(
                        IconButton(
                          icon: Icon(
                            isFeatured ? Icons.star_rounded : Icons.star_border_rounded,
                            color: isFeatured ? Colors.amber : Colors.grey,
                          ),
                          onPressed: () => _bloc.add(ToggleFeatured(
                            productId: (product['_id'] ?? product['id'] ?? '').toString(),
                          )),
                          tooltip: isFeatured ? 'Quitar destacado' : 'Destacar',
                        ),
                      ),
                      // Actions
                      DataCell(Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            tooltip: 'Editar',
                            onPressed: () => _showProductForm(context, product: product),
                            splashRadius: 20,
                          ),
                          IconButton(
                            icon: const Icon(Icons.inventory_outlined, size: 20),
                            tooltip: 'Stock',
                            onPressed: () => _showStockDialog(product),
                            splashRadius: 20,
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline, size: 20, color: AppTheme.errorColor),
                            tooltip: 'Eliminar',
                            onPressed: () => _confirmAndDelete(product),
                            splashRadius: 20,
                          ),
                        ],
                      )),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      );
    }

    // ── Mobile list ──
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: state.products.length,
      itemBuilder: (_, i) => _productCard(state.products[i]),
    );
  }

  Widget _productCard(Map<String, dynamic> product) {
    final pid = _id(product);
    final name = product['name'] as String? ?? 'Sin nombre';
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final stock = product['stock'] as int? ?? 0;
    final isFeatured =
        product['is_featured'] == true || product['is_featured'] == 1;
    final img = _extractFirstImage(product);
    final isSelected = _selectMode && _selectedProductIds.contains(pid);

    return Dismissible(
      key: ValueKey(product['_id'] ?? product['id'] ?? name),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppTheme.errorColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) => _confirmDelete(name),
      onDismissed: (_) {
        _bloc.add(DeleteProduct(
          productId: (product['_id'] ?? product['id'] ?? '').toString(),
        ));
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade200),
        ),
        color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.05) : null,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _selectMode
              ? () => _toggleProductSelection(pid)
              : () => _showProductForm(context, product: product),
          onLongPress: !_selectMode
              ? () {
                  setState(() => _selectMode = true);
                  _toggleProductSelection(pid);
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                if (_selectMode) ...[
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleProductSelection(pid),
                  ),
                  const SizedBox(width: 4),
                ],
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: img.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: img,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => _imgPlaceholder(60),
                          errorWidget: (_, __, ___) => _imgPlaceholder(60),
                        )
                      : _imgPlaceholder(60),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(_currencyFmt.format(price),
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.primary)),
                      const SizedBox(height: 4),
                      Row(children: [
                        _badge(
                          'Stock: $stock',
                          stock > 0
                              ? AppTheme.successColor
                              : AppTheme.errorColor,
                        ),
                        if (stock == 0) ...[
                          const SizedBox(width: 6),
                          _badge('Agotado', AppTheme.errorColor),
                        ],
                      ]),
                    ],
                  ),
                ),
                Column(children: [
                  IconButton(
                    icon: Icon(
                      isFeatured ? Icons.star : Icons.star_border,
                      color: isFeatured ? Colors.amber : Colors.grey,
                    ),
                    tooltip: 'Destacado',
                    onPressed: () => _bloc.add(ToggleFeatured(
                      productId:
                          (product['_id'] ?? product['id'] ?? '').toString(),
                    )),
                  ),
                  IconButton(
                    icon: const Icon(Icons.inventory, size: 20),
                    tooltip: 'Stock',
                    onPressed: () => _showStockDialog(product),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Web-optimized product card for grid layout.
  Widget _webProductCard(Map<String, dynamic> product) {
    final pid = _id(product);
    final name = product['name'] as String? ?? 'Sin nombre';
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final stock = product['stock'] as int? ?? 0;
    final isFeatured = product['is_featured'] == true || product['is_featured'] == 1;
    final img = _extractFirstImage(product);
    final isSelected = _selectMode && _selectedProductIds.contains(pid);
    final primary = Theme.of(context).colorScheme.primary;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isSelected ? primary : Colors.grey.shade200,
          width: isSelected ? 2 : 1,
        ),
      ),
      color: isSelected ? primary.withOpacity(0.04) : Colors.white,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _selectMode
            ? () => _toggleProductSelection(pid)
            : () => _showProductForm(context, product: product),
        onLongPress: !_selectMode
            ? () {
                setState(() => _selectMode = true);
                _toggleProductSelection(pid);
              }
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image area ──
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  img.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: img,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: Colors.grey.shade100,
                            child: const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: Colors.grey.shade100,
                            child: Icon(Icons.image_outlined, size: 48, color: Colors.grey.shade400),
                          ),
                        )
                      : Container(
                          color: Colors.grey.shade100,
                          child: Icon(Icons.image_outlined, size: 48, color: Colors.grey.shade400),
                        ),
                  // Featured star badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => _bloc.add(ToggleFeatured(
                        productId: (product['_id'] ?? product['id'] ?? '').toString(),
                      )),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4),
                          ],
                        ),
                        child: Icon(
                          isFeatured ? Icons.star_rounded : Icons.star_border_rounded,
                          color: isFeatured ? Colors.amber : Colors.grey,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  // Select checkbox
                  if (_selectMode)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: Checkbox(
                          value: isSelected,
                          onChanged: (_) => _toggleProductSelection(pid),
                          shape: const CircleBorder(),
                        ),
                      ),
                    ),
                  // Stock badge
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: _badge(
                      stock > 0 ? 'Stock: $stock' : 'Agotado',
                      stock > 0 ? AppTheme.successColor : AppTheme.errorColor,
                    ),
                  ),
                ],
              ),
            ),
            // ── Info area ──
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, height: 1.3),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currencyFmt.format(price),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: primary,
                      ),
                    ),
                    const Spacer(),
                    // Action buttons row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _miniAction(Icons.edit_outlined, 'Editar', () => _showProductForm(context, product: product)),
                        const SizedBox(width: 4),
                        _miniAction(Icons.inventory_outlined, 'Stock', () => _showStockDialog(product)),
                        const SizedBox(width: 4),
                        _miniAction(Icons.delete_outline, 'Eliminar', () => _confirmAndDelete(product), color: AppTheme.errorColor),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniAction(IconData icon, String tooltip, VoidCallback onTap, {Color? color}) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: (color ?? Colors.grey).withOpacity(0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 18, color: color ?? Colors.grey.shade700),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // ── CATEGORIES TAB ────────────────────────────────────────
  // ══════════════════════════════════════════════════════════

  Widget _buildCategoriesSelectionBar() {
    if (!_selectMode) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            TextButton.icon(
              onPressed: () => setState(() => _selectMode = true),
              icon: const Icon(Icons.checklist, size: 20),
              label: const Text('Seleccionar'),
            ),
          ],
        ),
      );
    }
    return BlocBuilder<ProductsBloc, ProductsState>(
      builder: (context, state) {
        List<Map<String, dynamic>> categories = [];
        if (state is ProductsLoaded) categories = state.categories;
        else if (state is CategoriesLoaded) categories = state.categories;
        final allIds = categories.map(_id).toSet();
        final allSelected = allIds.isNotEmpty && allIds.every(_selectedCategoryIds.contains);

        return Container(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Checkbox(
                value: allSelected,
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _selectedCategoryIds.addAll(allIds);
                    } else {
                      _selectedCategoryIds.clear();
                    }
                  });
                },
              ),
              Text(
                '${_selectedCategoryIds.length} seleccionados',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (_selectedCategoryIds.isNotEmpty)
                TextButton.icon(
                  onPressed: _deleteSelected,
                  icon: Icon(Icons.delete_sweep, color: AppTheme.errorColor),
                  label: Text('Eliminar', style: TextStyle(color: AppTheme.errorColor)),
                ),
              TextButton.icon(
                onPressed: () => setState(() {
                  _selectMode = false;
                  _selectedCategoryIds.clear();
                }),
                icon: const Icon(Icons.close),
                label: const Text('Cancelar'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCategoriesTab() {
    return Column(
      children: [
        _buildCategoriesSelectionBar(),
        Expanded(
          child: BlocConsumer<ProductsBloc, ProductsState>(
      listener: (context, state) {
        if (state is CategoriesLoaded) {
          // Categories loaded/refreshed – nothing else needed
        }
      },
      builder: (context, state) {
        List<Map<String, dynamic>> categories = [];
        if (state is ProductsLoaded) {
          categories = state.categories;
        } else if (state is CategoriesLoaded) {
          categories = state.categories;
        }

        if (state is ProductsLoading) return _shimmer();

        if (categories.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.category_outlined,
                    size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text('No hay categorías',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Text('Usa el botón + para agregar tu primera categoría',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
              ],
            ),
          );
        }

        // Separate parents and children
        final parents =
            categories.where((c) => c['parent_id'] == null).toList();
        final children =
            categories.where((c) => c['parent_id'] != null).toList();

        return RefreshIndicator(
          onRefresh: () async => _bloc.add(const LoadCategories()),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: parents.map((parent) {
              final parentId =
                  (parent['_id'] ?? parent['id'] ?? '').toString();
              final subs = children
                  .where(
                      (c) => (c['parent_id'] ?? '').toString() == parentId)
                  .toList();

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: _selectMode && _selectedCategoryIds.contains(parentId)
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade200,
                  ),
                ),
                color: _selectMode && _selectedCategoryIds.contains(parentId)
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.05)
                    : null,
                child: ExpansionTile(
                  leading: _selectMode
                      ? Checkbox(
                          value: _selectedCategoryIds.contains(parentId),
                          onChanged: (_) => _toggleCategorySelection(parentId),
                        )
                      : null,
                  title: Text(
                    parent['name'] as String? ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    parent['description'] as String? ?? '',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.add, size: 20),
                        tooltip: 'Agregar subcategoría',
                        onPressed: () => _showCategoryForm(context,
                            parentId: parentId),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        tooltip: 'Editar',
                        onPressed: () =>
                            _showCategoryForm(context, category: parent),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                            size: 20, color: AppTheme.errorColor),
                        tooltip: 'Eliminar',
                        onPressed: () => _confirmDeleteCategory(parent),
                      ),
                    ],
                  ),
                  children: subs.map((sub) {
                    final subId = _id(sub);
                    return ListTile(
                      contentPadding:
                          const EdgeInsets.only(left: 32, right: 16),
                      leading: _selectMode
                          ? Checkbox(
                              value: _selectedCategoryIds.contains(subId),
                              onChanged: (_) => _toggleCategorySelection(subId),
                            )
                          : null,
                      title: Text(sub['name'] as String? ?? ''),
                      subtitle: Text(
                        sub['description'] as String? ?? '',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () =>
                                _showCategoryForm(context, category: sub),
                          ),
                          IconButton(
                            icon: Icon(Icons.delete_outline,
                                size: 18, color: AppTheme.errorColor),
                            onPressed: () => _confirmDeleteCategory(sub),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              );
            }).toList(),
          ),
        );
      },
    ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════
  // ── DIALOGS ───────────────────────────────────────────────
  // ══════════════════════════════════════════════════════════

  void _showStockDialog(Map<String, dynamic> product) {
    final ctrl = TextEditingController(
        text: (product['stock'] ?? 0).toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Stock: ${product['name'] ?? ''}'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Nuevo stock',
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final newStock = int.tryParse(ctrl.text) ?? 0;
              _bloc.add(UpdateProductStock(
                productId:
                    (product['_id'] ?? product['id'] ?? '').toString(),
                stock: newStock,
              ));
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndDelete(Map<String, dynamic> product) async {
    final name = product['name'] as String? ?? '';
    final ok = await _confirmDelete(name);
    if (ok == true) {
      _bloc.add(DeleteProduct(
          productId: (product['_id'] ?? product['id'] ?? '').toString()));
    }
  }

  Future<bool?> _confirmDelete(String name) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Eliminar "$name"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  // ── Category form ──────────────────────────────────────────

  void _showCategoryForm(
    BuildContext context, {
    Map<String, dynamic>? category,
    String? parentId,
  }) {
    final isEditing = category != null;
    final nameCtrl =
        TextEditingController(text: category?['name'] as String? ?? '');
    final descCtrl = TextEditingController(
        text: category?['description'] as String? ?? '');
    // If editing a subcategory, use its parent_id; if creating a sub, use the passed parentId
    final effectiveParentId = isEditing
        ? (category?['parent_id']?.toString())
        : parentId;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEditing
            ? 'Editar Categoría'
            : parentId != null
                ? 'Nueva Subcategoría'
                : 'Nueva Categoría'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Nombre',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Descripción',
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
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              final payload = <String, dynamic>{
                'name': nameCtrl.text.trim(),
                'description': descCtrl.text.trim(),
                if (effectiveParentId != null) 'parent_id': effectiveParentId,
              };
              if (isEditing) {
                _bloc.add(UpdateCategory(
                  categoryId:
                      (category!['_id'] ?? category['id'] ?? '').toString(),
                  payload: payload,
                ));
              } else {
                _bloc.add(CreateCategory(payload: payload));
              }
            },
            child: Text(isEditing ? 'Guardar' : 'Crear'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteCategory(Map<String, dynamic> cat) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: Text('¿Eliminar "${cat['name']}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _bloc.add(DeleteCategory(
                  categoryId:
                      (cat['_id'] ?? cat['id'] ?? '').toString()));
            },
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  // ── Product form ───────────────────────────────────────────

  void _showProductForm(
    BuildContext context, {
    Map<String, dynamic>? product,
  }) {
    final isEditing = product != null;

    final nameCtrl =
        TextEditingController(text: product?['name'] as String? ?? '');
    final descCtrl =
        TextEditingController(text: product?['description'] as String? ?? '');
    final shortDescCtrl = TextEditingController(
        text: product?['short_description'] as String? ?? '');
    final priceCtrl = TextEditingController(
        text: (product?['original_price'] as num?)?.toString() ??
            (product?['price'] as num?)?.toString() ?? '');
    final discountCtrl = TextEditingController(
        text: (product?['discount_percent'] as num?)?.toStringAsFixed(0) ?? '');
    final skuCtrl =
        TextEditingController(text: product?['sku'] as String? ?? '');
    final stockCtrl = TextEditingController(
        text: (product?['stock'] as int?)?.toString() ?? '0');

    // Multiple images support
    final existingImages = <String>[];
    if (product != null) {
      final imgs = product['images'];
      if (imgs is List) {
        for (final img in imgs) {
          if (img is String && img.isNotEmpty) {
            existingImages.add(img);
          } else if (img is Map && img['url'] != null) {
            existingImages.add(img['url'].toString());
          }
        }
      }
      if (existingImages.isEmpty) {
        final single = (product['image_url'] ?? '').toString();
        if (single.isNotEmpty) existingImages.add(single);
      }
    }
    final images = List<String>.from(existingImages);
    final imageUrlCtrl = TextEditingController();

    final tagsCtrl = TextEditingController(
      text: (product?['tags'] is List)
          ? (product!['tags'] as List).join(', ')
          : (product?['tags'] as String? ?? ''),
    );
    bool isFeatured =
        product?['is_featured'] == true || product?['is_featured'] == 1;
    String? selectedCategory = product?['category_id']?.toString();

    // ── Variants state ──
    bool hasVariants = product?['has_variants'] == true || product?['has_variants'] == 1;
    // variants: List of { 'name': String, 'options': List<{ 'name': String, 'price_adjustment': double, 'image': String }> }
    final List<Map<String, dynamic>> variants = [];
    if (product != null && product['variants'] is List) {
      for (final v in product['variants'] as List) {
        final options = <Map<String, dynamic>>[];
        if (v['options'] is List) {
          for (final opt in v['options'] as List) {
            options.add({
              'name': opt['name'] ?? '',
              'price_adjustment': (opt['price_adjustment'] as num?)?.toDouble() ?? 0.0,
              'image': opt['image'] ?? '',
            });
          }
        }
        variants.add({
          'name': v['name'] ?? '',
          'options': options,
        });
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, ss) {
            // Compute final price preview
            final basePrice = double.tryParse(priceCtrl.text) ?? 0;
            final discount = double.tryParse(discountCtrl.text) ?? 0;
            final finalPrice = discount > 0
                ? (basePrice * (1 - discount / 100))
                : basePrice;

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.92,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              builder: (ctx, scrollCtrl) {
                return Padding(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 16,
                    bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                  ),
                  child: ListView(
                    controller: scrollCtrl,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isEditing ? 'Editar Producto' : 'Nuevo Producto',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 20),
                      _field(nameCtrl, 'Nombre', Icons.label_outline),
                      const SizedBox(height: 12),
                      _field(descCtrl, 'Descripción',
                          Icons.description_outlined,
                          maxLines: 3),
                      const SizedBox(height: 12),
                      _field(
                          shortDescCtrl, 'Descripción corta', Icons.short_text),
                      const SizedBox(height: 12),
                      // ── Price + Discount ──
                      Row(children: [
                        Expanded(
                          flex: 2,
                          child: _field(priceCtrl, 'Precio',
                              Icons.attach_money,
                              keyboardType: TextInputType.number),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _field(discountCtrl,
                              'Desc. %', Icons.percent,
                              keyboardType: TextInputType.number),
                        ),
                      ]),
                      if (discount > 0 && basePrice > 0) ...[
                        const SizedBox(height: 6),
                        Row(children: [
                          Text(
                            'Precio original: ${_currencyFmt.format(basePrice)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Precio final: ${_currencyFmt.format(finalPrice)}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ]),
                      ],
                      const SizedBox(height: 12),
                      _field(skuCtrl, 'SKU', Icons.qr_code),
                      const SizedBox(height: 12),
                      _field(stockCtrl, 'Stock',
                          Icons.inventory_2_outlined,
                          keyboardType: TextInputType.number),
                      const SizedBox(height: 12),
                      // Category dropdown
                      BlocBuilder<ProductsBloc, ProductsState>(
                        bloc: _bloc,
                        builder: (context, state) {
                          List<Map<String, dynamic>> cats = [];
                          if (state is ProductsLoaded) {
                            cats = state.categories;
                          }
                          return DropdownButtonFormField<String>(
                            value: selectedCategory,
                            decoration: InputDecoration(
                              labelText: 'Categoría',
                              prefixIcon:
                                  const Icon(Icons.category_outlined),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            items: cats.map((c) {
                              final id =
                                  (c['_id'] ?? c['id'] ?? '').toString();
                              final n = c['name'] as String? ?? '';
                              final isChild = c['parent_id'] != null;
                              return DropdownMenuItem(
                                value: id,
                                child: Text(isChild ? '  └ $n' : n),
                              );
                            }).toList(),
                            onChanged: (v) =>
                                ss(() => selectedCategory = v),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      // ── Images section ──
                      const Text('Imágenes',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ...images.asMap().entries.map((entry) {
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    entry.value,
                                    width: 72,
                                    height: 72,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        _imgPlaceholder(72),
                                  ),
                                ),
                                Positioned(
                                  top: -4,
                                  right: -4,
                                  child: GestureDetector(
                                    onTap: () =>
                                        ss(() => images.removeAt(entry.key)),
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close,
                                          size: 14, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: imageUrlCtrl,
                            decoration: InputDecoration(
                              hintText: 'URL de imagen',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            final url = imageUrlCtrl.text.trim();
                            if (url.isNotEmpty) {
                              ss(() => images.add(url));
                              imageUrlCtrl.clear();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Agregar URL'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final url = await _pickAndUploadImage();
                            if (url != null) {
                              ss(() => images.add(url));
                            }
                          },
                          icon: const Icon(Icons.upload_file, size: 18),
                          label: const Text('Subir'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      _field(tagsCtrl, 'Tags (separados por coma)', Icons.tag),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: const Text('Producto destacado'),
                        secondary: Icon(
                          Icons.star,
                          color: isFeatured
                              ? Colors.amber
                              : Colors.grey.shade400,
                        ),
                        value: isFeatured,
                        activeColor: Theme.of(context).colorScheme.primary,
                        onChanged: (v) => ss(() => isFeatured = v),
                      ),
                      const SizedBox(height: 8),

                      // ══════════════════════════════════════════
                      // ── VARIANTS SECTION ──────────────────────
                      // ══════════════════════════════════════════
                      SwitchListTile(
                        title: const Text('Este producto tiene variantes'),
                        subtitle: Text(
                          'Tallas, colores, memoria, etc.',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        secondary: Icon(
                          Icons.tune,
                          color: hasVariants
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey.shade400,
                        ),
                        value: hasVariants,
                        activeColor: Theme.of(context).colorScheme.primary,
                        onChanged: (v) => ss(() => hasVariants = v),
                      ),

                      if (hasVariants) ...[
                        const SizedBox(height: 8),
                        _buildVariantsBuilder(ss, variants),
                      ],

                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            if (nameCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('El nombre es obligatorio')),
                              );
                              return;
                            }
                            final payload = <String, dynamic>{
                              'name': nameCtrl.text.trim(),
                              'description': descCtrl.text.trim(),
                              'short_description':
                                  shortDescCtrl.text.trim(),
                              'price':
                                  double.tryParse(priceCtrl.text) ?? 0,
                              'discount_percent':
                                  double.tryParse(discountCtrl.text) ?? 0,
                              'sku': skuCtrl.text.trim().isEmpty
                                  ? null
                                  : skuCtrl.text.trim(),
                              'stock': int.tryParse(stockCtrl.text) ?? 0,
                              'category_id': selectedCategory,
                              'images': images,
                              'is_featured': isFeatured,
                              'tags': tagsCtrl.text
                                  .split(',')
                                  .map((t) => t.trim())
                                  .where((t) => t.isNotEmpty)
                                  .toList(),
                            };

                            // Add variants if enabled
                            if (hasVariants && variants.isNotEmpty) {
                              payload['variants'] = variants.map((v) => {
                                'name': v['name'],
                                'options': (v['options'] as List).map((o) => {
                                  'name': o['name'],
                                  'price_adjustment': o['price_adjustment'] ?? 0,
                                  'image': o['image'] ?? '',
                                }).toList(),
                              }).toList();
                            } else if (!hasVariants) {
                              payload['variants'] = [];
                            }

                            if (isEditing) {
                              _bloc.add(UpdateProduct(
                                productId: (product!['_id'] ??
                                        product['id'] ??
                                        '')
                                    .toString(),
                                payload: payload,
                              ));
                            } else {
                              _bloc.add(CreateProduct(payload: payload));
                            }
                            Navigator.pop(ctx);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            isEditing
                                ? 'Guardar Cambios'
                                : 'Crear Producto',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ── Variants builder widget ──
  Widget _buildVariantsBuilder(
    StateSetter ss,
    List<Map<String, dynamic>> variants,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Existing variant types
        ...variants.asMap().entries.map((entry) {
          final idx = entry.key;
          final variant = entry.value;
          final typeName = variant['name'] as String? ?? '';
          final options = variant['options'] as List<Map<String, dynamic>>? ?? [];

          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Variant type header
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          typeName.isEmpty ? 'Tipo de variante' : typeName,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () => _editVariantTypeName(ss, variants, idx),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                            size: 18, color: AppTheme.errorColor),
                        onPressed: () => ss(() => variants.removeAt(idx)),
                      ),
                    ],
                  ),

                  // Options list
                  ...options.asMap().entries.map((optEntry) {
                    final optIdx = optEntry.key;
                    final opt = optEntry.value;
                    return Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          // Option image thumbnail if exists
                          if ((opt['image'] as String? ?? '').isNotEmpty) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Image.network(
                                opt['image']!,
                                width: 32,
                                height: 32,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    _imgPlaceholder(32),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  opt['name'] as String? ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w500, fontSize: 13),
                                ),
                                if ((opt['price_adjustment'] as num?) != null &&
                                    (opt['price_adjustment'] as num) != 0)
                                  Text(
                                    (opt['price_adjustment'] as num) > 0
                                        ? '+${_currencyFmt.format(opt['price_adjustment'])}'
                                        : _currencyFmt.format(opt['price_adjustment']),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: (opt['price_adjustment'] as num) > 0
                                          ? AppTheme.successColor
                                          : AppTheme.errorColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 16),
                            onPressed: () =>
                                _editVariantOption(ss, variants, idx, optIdx),
                          ),
                          IconButton(
                            icon: Icon(Icons.close,
                                size: 16, color: AppTheme.errorColor),
                            onPressed: () => ss(() => options.removeAt(optIdx)),
                          ),
                        ],
                      ),
                    );
                  }),

                  // Add option button
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _addVariantOption(ss, variants, idx),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Agregar opción',
                          style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),

        // Add variant type button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _addVariantType(ss, variants),
            icon: const Icon(Icons.add),
            label: const Text('Agregar tipo de variante'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
              side: BorderSide(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),

        // Quick-add templates
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _variantTemplate(ss, variants, 'Talla', ['XS', 'S', 'M', 'L', 'XL']),
            _variantTemplate(ss, variants, 'Color', ['Negro', 'Blanco', 'Azul', 'Rojo']),
            _variantTemplate(ss, variants, 'Talla Calzado', ['36', '37', '38', '39', '40', '41', '42']),
            _variantTemplate(ss, variants, 'Memoria', ['64GB', '128GB', '256GB', '512GB']),
          ],
        ),
      ],
    );
  }

  Widget _variantTemplate(
    StateSetter ss,
    List<Map<String, dynamic>> variants,
    String label,
    List<String> options,
  ) {
    return ActionChip(
      avatar: const Icon(Icons.auto_awesome, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onPressed: () {
        // Don't add if type already exists
        final exists = variants.any(
            (v) => (v['name'] as String).toLowerCase() == label.toLowerCase());
        if (exists) return;
        ss(() {
          variants.add({
            'name': label,
            'options': options
                .map((o) => {
                      'name': o,
                      'price_adjustment': 0.0,
                      'image': '',
                    })
                .toList(),
          });
        });
      },
    );
  }

  void _addVariantType(
    StateSetter ss,
    List<Map<String, dynamic>> variants,
  ) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo tipo de variante'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Nombre (ej: Color, Talla, Memoria)',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              ss(() {
                variants.add({
                  'name': nameCtrl.text.trim(),
                  'options': <Map<String, dynamic>>[],
                });
              });
            },
            child: const Text('Crear'),
          ),
        ],
      ),
    );
  }

  void _editVariantTypeName(
    StateSetter ss,
    List<Map<String, dynamic>> variants,
    int idx,
  ) {
    final nameCtrl = TextEditingController(text: variants[idx]['name'] as String);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar tipo de variante'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Nombre',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              ss(() => variants[idx]['name'] = nameCtrl.text.trim());
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _addVariantOption(
    StateSetter ss,
    List<Map<String, dynamic>> variants,
    int typeIdx,
  ) {
    final nameCtrl = TextEditingController();
    final priceCtrl = TextEditingController(text: '0');
    String variantImageUrl = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Nueva opción de ${variants[typeIdx]['name']}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Nombre (ej: Rojo, XL, 256GB)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Ajuste de precio (+/-)',
                    helperText: 'Ej: 50000 agrega al precio base, -10000 resta',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                // Image upload section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Imagen (opcional)',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600)),
                      const SizedBox(height: 8),
                      if (variantImageUrl.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(variantImageUrl,
                              width: 80, height: 80, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _imgPlaceholder(80)),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Row(children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            final url = await _pickAndUploadImage();
                            if (url != null) {
                              setDialogState(() => variantImageUrl = url);
                            }
                          },
                          icon: const Icon(Icons.upload_file, size: 16),
                          label: Text(variantImageUrl.isEmpty
                              ? 'Subir imagen'
                              : 'Cambiar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        if (variantImageUrl.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () =>
                                setDialogState(() => variantImageUrl = ''),
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red, size: 20),
                          ),
                        ],
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                ss(() {
                  final options =
                      variants[typeIdx]['options'] as List<Map<String, dynamic>>;
                  options.add({
                    'name': nameCtrl.text.trim(),
                    'price_adjustment':
                        double.tryParse(priceCtrl.text) ?? 0.0,
                    'image': variantImageUrl,
                  });
                });
              },
              child: const Text('Agregar'),
            ),
          ],
        ),
      ),
    );
  }

  void _editVariantOption(
    StateSetter ss,
    List<Map<String, dynamic>> variants,
    int typeIdx,
    int optIdx,
  ) {
    final opt =
        (variants[typeIdx]['options'] as List<Map<String, dynamic>>)[optIdx];
    final nameCtrl = TextEditingController(text: opt['name'] as String);
    final priceCtrl = TextEditingController(
        text: (opt['price_adjustment'] as num?)?.toString() ?? '0');
    String variantImageUrl = opt['image'] as String? ?? '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Editar opción'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Nombre',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Ajuste de precio (+/-)',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                // Image upload section
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Imagen (opcional)',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600)),
                      const SizedBox(height: 8),
                      if (variantImageUrl.isNotEmpty) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(variantImageUrl,
                              width: 80, height: 80, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _imgPlaceholder(80)),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Row(children: [
                        ElevatedButton.icon(
                          onPressed: () async {
                            final url = await _pickAndUploadImage();
                            if (url != null) {
                              setDialogState(() => variantImageUrl = url);
                            }
                          },
                          icon: const Icon(Icons.upload_file, size: 16),
                          label: Text(variantImageUrl.isEmpty
                              ? 'Subir imagen'
                              : 'Cambiar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                        if (variantImageUrl.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () =>
                                setDialogState(() => variantImageUrl = ''),
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.red, size: 20),
                          ),
                        ],
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                ss(() {
                  final options =
                      variants[typeIdx]['options'] as List<Map<String, dynamic>>;
                  options[optIdx] = {
                    'name': nameCtrl.text.trim(),
                    'price_adjustment':
                        double.tryParse(priceCtrl.text) ?? 0.0,
                    'image': variantImageUrl,
                  };
                });
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // ── HELPERS ───────────────────────────────────────────────
  // ══════════════════════════════════════════════════════════

  /// Pick an image from device and upload it to the backend.
  /// Returns the URL of the uploaded image, or null if cancelled/failed.
  Future<String?> _pickAndUploadImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        // On web, skip resize params to avoid blob revocation issues
        maxWidth: kIsWeb ? null : 1200,
        maxHeight: kIsWeb ? null : 1200,
        imageQuality: kIsWeb ? null : 80,
      );
      if (picked == null) return null;

      // Read bytes immediately before the blob URL can be revoked
      var bytes = await picked.readAsBytes();
      if (bytes.isEmpty) return null;

      // Compress image on web (canvas resize + JPEG quality)
      bytes = await compressImageBytes(bytes, maxWidth: 1200, maxHeight: 1200, quality: 80);

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(children: [
              SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
              SizedBox(width: 12),
              Text('Subiendo imagen...'),
            ]),
            duration: Duration(seconds: 30),
          ),
        );
      }

      final apiClient = getIt<ApiClient>();

      final multipartFile = dio_pkg.MultipartFile.fromBytes(
        bytes,
        filename: picked.name.isNotEmpty ? picked.name : 'image.jpg',
      );

      final formData = dio_pkg.FormData.fromMap({
        'image': multipartFile,
      });

      final response = await apiClient.dio.post('/products/upload', data: formData);

      if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();

      if (response.statusCode == 200 && response.data['url'] != null) {
        String url = response.data['url'].toString();
        // Gateway origin without /api (uploads are served at /uploads, not /api/uploads)
        final gatewayOrigin = apiClient.dio.options.baseUrl.replaceAll(RegExp(r'/api/?$'), '');
        // If the URL points to the internal products-service, rewrite to gateway
        if (url.contains(':3003')) {
          url = url.replaceFirst(RegExp(r'http://[^:]+:3003'), gatewayOrigin);
        }
        return url;
      }
      return null;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir imagen: $e'), backgroundColor: AppTheme.errorColor),
        );
      }
      if (kDebugMode) debugPrint('Upload error: $e');
      return null;
    }
  }

  String _extractFirstImage(Map<String, dynamic> product) {
    final images = product['images'];
    if (images is List && images.isNotEmpty) {
      final first = images.first;
      if (first is String) return first;
      if (first is Map) return (first['url'] ?? '').toString();
    }
    return (product['image_url'] ?? '').toString();
  }

  Widget _imgPlaceholder(double size) {
    return Container(
      width: size,
      height: size,
      color: Colors.grey.shade200,
      child: const Icon(Icons.inventory_2, color: Colors.grey),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _shimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: 6,
        itemBuilder: (_, __) => Container(
          height: 90,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _errorWidget(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppTheme.errorColor),
            const SizedBox(height: 16),
            Text(msg,
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

  Widget _emptyProducts() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text('No hay productos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('Usa el botón + para agregar tu primer producto',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}
