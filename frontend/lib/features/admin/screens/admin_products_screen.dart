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

/// Admin Products Management Screen.
///
/// Lists all products with search, add / edit / delete capabilities.
class AdminProductsScreen extends StatefulWidget {
  const AdminProductsScreen({super.key});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  late final ProductsBloc _bloc;
  final _searchController = TextEditingController();
  bool _isSearchVisible = false;

  final _currencyFormat = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _bloc = getIt<ProductsBloc>();
    _bloc.add(const LoadProducts());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _bloc.close();
    super.dispose();
  }

  void _search(String query) {
    _bloc.add(LoadProducts(search: query.isEmpty ? null : query));
  }

  void _refresh() {
    _bloc.add(LoadProducts(
      search: _searchController.text.isEmpty ? null : _searchController.text,
    ));
  }

  // ── Build ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        appBar: AppBar(
          title: _isSearchVisible
              ? _buildSearchField()
              : const Text('Gestionar Productos'),
          actions: [
            IconButton(
              icon: Icon(_isSearchVisible ? Icons.close : Icons.search),
              onPressed: () {
                setState(() {
                  _isSearchVisible = !_isSearchVisible;
                  if (!_isSearchVisible) {
                    _searchController.clear();
                    _search('');
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
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppTheme.primaryColor,
          foregroundColor: Colors.white,
          onPressed: () => _showProductForm(context),
          child: const Icon(Icons.add),
        ),
        body: RefreshIndicator(
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
              if (state is ProductsLoading) return _buildLoadingShimmer();
              if (state is ProductsLoaded) {
                if (state.products.isEmpty) return _buildEmptyState();
                return _buildProductsList(state);
              }
              if (state is ProductsError) return _buildErrorState(state.message);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }

  // ── Search field ────────────────────────────────────────────────────

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      autofocus: true,
      style: const TextStyle(color: Colors.white),
      decoration: const InputDecoration(
        hintText: 'Buscar producto…',
        hintStyle: TextStyle(color: Colors.white70),
        border: InputBorder.none,
        filled: false,
      ),
      onSubmitted: _search,
    );
  }

  // ── Products list ───────────────────────────────────────────────────

  Widget _buildProductsList(ProductsLoaded state) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: state.products.length,
      itemBuilder: (context, index) {
        final product = state.products[index];
        return _buildProductCard(product, state.categories);
      },
    );
  }

  Widget _buildProductCard(
    Map<String, dynamic> product,
    List<Map<String, dynamic>> categories,
  ) {
    final name = product['name'] as String? ?? 'Sin nombre';
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final stock = product['stock'] as int? ?? 0;
    final isActive = product['is_active'] as bool? ?? true;
    final isFeatured = product['is_featured'] as bool? ?? false;
    final imageUrl = _extractFirstImage(product);

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
        final productId = (product['_id'] ?? product['id'] ?? '').toString();
        _bloc.add(DeleteProduct(productId: productId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name eliminado')),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showProductForm(context, product: product),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Thumbnail
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.image, color: Colors.grey),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image,
                                color: Colors.grey),
                          ),
                        )
                      : Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.inventory_2,
                              color: Colors.grey),
                        ),
                ),
                const SizedBox(width: 12),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currencyFormat.format(price),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _buildSmallBadge(
                            'Stock: $stock',
                            stock > 0
                                ? AppTheme.successColor
                                : AppTheme.errorColor,
                          ),
                          const SizedBox(width: 6),
                          _buildSmallBadge(
                            isActive ? 'Activo' : 'Inactivo',
                            isActive ? AppTheme.successColor : Colors.grey,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Actions column
                Column(
                  children: [
                    // Featured toggle
                    IconButton(
                      icon: Icon(
                        isFeatured ? Icons.star : Icons.star_border,
                        color: isFeatured ? Colors.amber : Colors.grey,
                      ),
                      tooltip: 'Destacado',
                      onPressed: () {
                        // TODO: dispatch ToggleFeatured event
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isFeatured
                                ? 'Removido de destacados'
                                : 'Marcado como destacado'),
                            duration: const Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                    // Quick stock update
                    IconButton(
                      icon: const Icon(Icons.inventory, size: 20),
                      tooltip: 'Actualizar stock',
                      onPressed: () => _showQuickStockDialog(product),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSmallBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  // ── Confirm delete ──────────────────────────────────────────────────

  Future<bool?> _confirmDelete(String productName) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text('¿Estás seguro de eliminar "$productName"?'),
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
  }

  // ── Quick stock dialog ──────────────────────────────────────────────

  void _showQuickStockDialog(Map<String, dynamic> product) {
    final currentStock = product['stock'] as int? ?? 0;
    final controller = TextEditingController(text: currentStock.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Stock: ${product['name'] ?? ''}'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Nuevo stock',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: dispatch UpdateProductStock event
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Stock actualizado')),
              );
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  // ── Product form (add / edit) ───────────────────────────────────────

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
    final imageUrlCtrl =
        TextEditingController(text: product != null ? _extractFirstImage(product) : '');
    final tagsCtrl = TextEditingController(
      text: (product?['tags'] as List?)?.join(', ') ?? '',
    );
    bool isFeatured = product?['is_featured'] as bool? ?? false;
    String? selectedCategory = product?['category_id'] as String?;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.9,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              builder: (ctx, scrollController) {
                return Padding(
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 16,
                    bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                  ),
                  child: ListView(
                    controller: scrollController,
                    children: [
                      // Handle
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
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Name
                      _formField(nameCtrl, 'Nombre', Icons.label_outline),
                      const SizedBox(height: 12),
                      // Description
                      _formField(
                        descCtrl,
                        'Descripción',
                        Icons.description_outlined,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      // Short description
                      _formField(
                        shortDescCtrl,
                        'Descripción corta',
                        Icons.short_text,
                      ),
                      const SizedBox(height: 12),
                      // Price & Compare price row
                      Row(
                        children: [
                          Expanded(
                            child: _formField(
                              priceCtrl,
                              'Precio',
                              Icons.attach_money,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _formField(
                              comparePriceCtrl,
                              'Precio comparar',
                              Icons.money_off,
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // SKU
                      _formField(skuCtrl, 'SKU', Icons.qr_code),
                      const SizedBox(height: 12),
                      // Stock
                      _formField(
                        stockCtrl,
                        'Stock',
                        Icons.inventory_2_outlined,
                        keyboardType: TextInputType.number,
                      ),
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
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            items: cats.map((c) {
                              final id = (c['_id'] ?? c['id'] ?? '')
                                  .toString();
                              final catName =
                                  c['name'] as String? ?? 'Sin nombre';
                              return DropdownMenuItem(
                                value: id,
                                child: Text(catName),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setSheetState(() => selectedCategory = val);
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      // Image URL
                      _formField(
                        imageUrlCtrl,
                        'URL de imagen',
                        Icons.image_outlined,
                      ),
                      const SizedBox(height: 12),
                      // Tags
                      _formField(
                        tagsCtrl,
                        'Tags (separados por coma)',
                        Icons.tag,
                      ),
                      const SizedBox(height: 12),
                      // Featured toggle
                      SwitchListTile(
                        title: const Text('Producto destacado'),
                        secondary: Icon(
                          Icons.star,
                          color:
                              isFeatured ? Colors.amber : Colors.grey.shade400,
                        ),
                        value: isFeatured,
                        activeColor: AppTheme.primaryColor,
                        onChanged: (val) {
                          setSheetState(() => isFeatured = val);
                        },
                      ),
                      const SizedBox(height: 20),
                      // Save button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            if (nameCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('El nombre es obligatorio')),
                              );
                              return;
                            }
                            final imageUrl = imageUrlCtrl.text.trim();
                            final payload = <String, dynamic>{
                              'name': nameCtrl.text.trim(),
                              'description': descCtrl.text.trim(),
                              'short_description': shortDescCtrl.text.trim(),
                              'price': double.tryParse(priceCtrl.text) ?? 0,
                              'compare_price':
                                  double.tryParse(comparePriceCtrl.text) ?? 0,
                              'sku': skuCtrl.text.trim().isEmpty
                                  ? null
                                  : skuCtrl.text.trim(),
                              'stock': int.tryParse(stockCtrl.text) ?? 0,
                              'category_id': selectedCategory,
                              'images': imageUrl.isNotEmpty ? [imageUrl] : [],
                              'is_featured': isFeatured,
                              'tags': tagsCtrl.text
                                  .split(',')
                                  .map((t) => t.trim())
                                  .where((t) => t.isNotEmpty)
                                  .toList(),
                            };

                            if (isEditing) {
                              final productId = (product!['_id'] ??
                                      product['id'] ??
                                      '')
                                  .toString();
                              _bloc.add(UpdateProduct(
                                productId: productId,
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
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            isEditing ? 'Guardar Cambios' : 'Crear Producto',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
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

  /// Extract the first image URL from a product. Images may be a JSON array
  /// of strings, a list of maps with `url` keys, or a bare `image_url` field.
  String _extractFirstImage(Map<String, dynamic> product) {
    // Try images array first
    final images = product['images'];
    if (images is List && images.isNotEmpty) {
      final first = images.first;
      if (first is String) return first;
      if (first is Map) return (first['url'] ?? '').toString();
    }
    return (product['image_url'] ?? '').toString();
  }

  Widget _formField(
    TextEditingController controller,
    String label,
    IconData icon, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
            Icon(Icons.inventory_2_outlined,
                size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'No hay productos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Agrega tu primer producto con el botón +',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
