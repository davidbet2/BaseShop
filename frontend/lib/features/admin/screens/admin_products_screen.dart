import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';

import 'package:baseshop/core/di/injection.dart';
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
    ));
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
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Agregar producto',
              onPressed: () => _showProductForm(context),
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
          backgroundColor: AppTheme.primaryColor,
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
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: BlocConsumer<ProductsBloc, ProductsState>(
        listener: (context, state) {
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
            return _productsList(state);
          }
          if (state is ProductsError) return _errorWidget(state.message);
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _productsList(ProductsLoaded state) {
    final isWide = MediaQuery.of(context).size.width > 800;

    if (isWide) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
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
              columnSpacing: 16,
              columns: const [
                DataColumn(label: Text('Imagen', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Nombre', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Precio', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Stock', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Destacado', style: TextStyle(fontWeight: FontWeight.w600))),
                DataColumn(label: Text('Acciones', style: TextStyle(fontWeight: FontWeight.w600))),
              ],
              rows: state.products.map((p) {
                final name = p['name'] as String? ?? '';
                final price = (p['price'] as num?)?.toDouble() ?? 0;
                final stock = p['stock'] as int? ?? 0;
                final isFeatured = p['is_featured'] == true || p['is_featured'] == 1;
                final img = _extractFirstImage(p);

                return DataRow(
                  cells: [
                    DataCell(
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: img.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: img,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) =>
                                    _imgPlaceholder(44),
                              )
                            : _imgPlaceholder(44),
                      ),
                    ),
                    DataCell(
                      SizedBox(
                        width: 200,
                        child: Text(name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    DataCell(Text(_currencyFmt.format(price))),
                    DataCell(
                      _badge(
                        'Stock: $stock',
                        stock > 0
                            ? AppTheme.successColor
                            : AppTheme.errorColor,
                      ),
                    ),
                    DataCell(
                      IconButton(
                        icon: Icon(
                          isFeatured ? Icons.star : Icons.star_border,
                          color: isFeatured ? Colors.amber : Colors.grey,
                        ),
                        onPressed: () => _bloc.add(ToggleFeatured(
                          productId: (p['_id'] ?? p['id'] ?? '').toString(),
                        )),
                      ),
                    ),
                    DataCell(Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 20),
                          tooltip: 'Editar',
                          onPressed: () =>
                              _showProductForm(context, product: p),
                        ),
                        IconButton(
                          icon: const Icon(Icons.inventory, size: 20),
                          tooltip: 'Stock',
                          onPressed: () => _showStockDialog(p),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline,
                              size: 20, color: AppTheme.errorColor),
                          tooltip: 'Eliminar',
                          onPressed: () => _confirmAndDelete(p),
                        ),
                      ],
                    )),
                  ],
                );
              }).toList(),
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
    final name = product['name'] as String? ?? 'Sin nombre';
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final stock = product['stock'] as int? ?? 0;
    final isFeatured =
        product['is_featured'] == true || product['is_featured'] == 1;
    final img = _extractFirstImage(product);

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
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showProductForm(context, product: product),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: img.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: img,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
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
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppTheme.primaryColor)),
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

  // ══════════════════════════════════════════════════════════
  // ── CATEGORIES TAB ────────────────────────────────────────
  // ══════════════════════════════════════════════════════════

  Widget _buildCategoriesTab() {
    return BlocConsumer<ProductsBloc, ProductsState>(
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
                ElevatedButton.icon(
                  onPressed: () => _showCategoryForm(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Crear categoría'),
                ),
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
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: ExpansionTile(
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
                    return ListTile(
                      contentPadding:
                          const EdgeInsets.only(left: 32, right: 16),
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
        text: (product?['price'] as num?)?.toString() ?? '');
    final comparePriceCtrl = TextEditingController(
        text: (product?['compare_price'] as num?)?.toString() ?? '');
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, ss) {
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
                      Row(children: [
                        Expanded(
                          child: _field(priceCtrl, 'Precio',
                              Icons.attach_money,
                              keyboardType: TextInputType.number),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _field(comparePriceCtrl,
                              'Precio comparar', Icons.money_off,
                              keyboardType: TextInputType.number),
                        ),
                      ]),
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
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Agregar'),
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
                        activeColor: AppTheme.primaryColor,
                        onChanged: (v) => ss(() => isFeatured = v),
                      ),
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
                              'compare_price': double.tryParse(
                                      comparePriceCtrl.text) ??
                                  0,
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
                            backgroundColor: AppTheme.primaryColor,
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

  // ══════════════════════════════════════════════════════════
  // ── HELPERS ───────────────────────────────────────────────
  // ══════════════════════════════════════════════════════════

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
            Text('Agrega tu primer producto con el botón +',
                style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}
