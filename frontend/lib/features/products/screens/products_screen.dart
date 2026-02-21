import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';

import 'package:baseshop/core/di/injection.dart';
import 'package:baseshop/core/theme/app_theme.dart';
import 'package:baseshop/features/products/bloc/products_bloc.dart';
import 'package:baseshop/features/products/bloc/products_event.dart';
import 'package:baseshop/features/products/bloc/products_state.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  late final ProductsBloc _bloc;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();

  String? _selectedCategoryId;
  String? _sortBy;
  double? _minPrice;
  double? _maxPrice;
  int _currentPage = 1;
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
      if (state is ProductsLoaded) {
        final totalPages = (state.total / 20).ceil();
        if (_currentPage < totalPages) {
          _currentPage++;
          _bloc.add(LoadProducts(
            categoryId: _selectedCategoryId,
            search: _searchController.text.isEmpty
                ? null
                : _searchController.text,
            sortBy: _sortBy,
            minPrice: _minPrice,
            maxPrice: _maxPrice,
            page: _currentPage,
          ));
        }
      }
    }
  }

  void _applyFilters() {
    _currentPage = 1;
    _bloc.add(LoadProducts(
      categoryId: _selectedCategoryId,
      search:
          _searchController.text.isEmpty ? null : _searchController.text,
      sortBy: _sortBy,
      minPrice: _minPrice,
      maxPrice: _maxPrice,
      page: 1,
    ));
  }

  void _showFilterSheet() {
    double? tempMin = _minPrice;
    double? tempMax = _maxPrice;
    String? tempSort = _sortBy;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Filtros',
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 20),

                  // ── Sort ──
                  Text('Ordenar por',
                      style: Theme.of(ctx).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      _sortChip('Relevancia', null, tempSort, (v) {
                        setModalState(() => tempSort = v);
                      }),
                      _sortChip('Menor precio', 'price_asc', tempSort, (v) {
                        setModalState(() => tempSort = v);
                      }),
                      _sortChip('Mayor precio', 'price_desc', tempSort, (v) {
                        setModalState(() => tempSort = v);
                      }),
                      _sortChip('Más nuevos', 'newest', tempSort, (v) {
                        setModalState(() => tempSort = v);
                      }),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Price range ──
                  Text('Rango de precio',
                      style: Theme.of(ctx).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Mínimo',
                            prefixText: '\$ ',
                            border: OutlineInputBorder(),
                          ),
                          controller: TextEditingController(
                            text: tempMin?.toStringAsFixed(0) ?? '',
                          ),
                          onChanged: (v) =>
                              tempMin = double.tryParse(v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Máximo',
                            prefixText: '\$ ',
                            border: OutlineInputBorder(),
                          ),
                          controller: TextEditingController(
                            text: tempMax?.toStringAsFixed(0) ?? '',
                          ),
                          onChanged: (v) =>
                              tempMax = double.tryParse(v),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Apply / Clear ──
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _minPrice = null;
                              _maxPrice = null;
                              _sortBy = null;
                            });
                            _applyFilters();
                            Navigator.pop(ctx);
                          },
                          child: const Text('Limpiar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              _minPrice = tempMin;
                              _maxPrice = tempMax;
                              _sortBy = tempSort;
                            });
                            _applyFilters();
                            Navigator.pop(ctx);
                          },
                          child: const Text('Aplicar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _sortChip(
    String label,
    String? value,
    String? current,
    ValueChanged<String?> onSelected,
  ) {
    final selected = current == value;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(value),
      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        appBar: AppBar(
          title: _isSearchVisible
              ? TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Buscar productos...',
                    hintStyle: TextStyle(color: Colors.white70),
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => _applyFilters(),
                )
              : const Text('Productos'),
          actions: [
            IconButton(
              icon: Icon(_isSearchVisible ? Icons.close : Icons.search),
              onPressed: () {
                setState(() {
                  _isSearchVisible = !_isSearchVisible;
                  if (!_isSearchVisible) {
                    _searchController.clear();
                    _applyFilters();
                  }
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.tune),
              onPressed: _showFilterSheet,
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            _currentPage = 1;
            _bloc.add(LoadProducts(
              categoryId: _selectedCategoryId,
              search: _searchController.text.isEmpty
                  ? null
                  : _searchController.text,
              sortBy: _sortBy,
              minPrice: _minPrice,
              maxPrice: _maxPrice,
            ));
          },
          child: BlocBuilder<ProductsBloc, ProductsState>(
            builder: (context, state) {
              if (state is ProductsLoading) {
                return _buildShimmerGrid();
              }

              if (state is ProductsError) {
                return _buildError(state.message);
              }

              if (state is ProductsLoaded) {
                return _buildContent(state);
              }

              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ProductsLoaded state) {
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        // ── Category chips ──
        if (state.categories.isNotEmpty)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 8),
                itemCount: state.categories.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return ChoiceChip(
                      label: const Text('Todos'),
                      selected: _selectedCategoryId == null,
                      onSelected: (_) {
                        setState(() => _selectedCategoryId = null);
                        _applyFilters();
                      },
                      selectedColor:
                          AppTheme.primaryColor.withValues(alpha: 0.2),
                    );
                  }
                  final cat = state.categories[index - 1];
                  final catId = cat['_id']?.toString() ??
                      cat['id']?.toString() ??
                      '';
                  return ChoiceChip(
                    label: Text(cat['name']?.toString() ?? ''),
                    selected: _selectedCategoryId == catId,
                    onSelected: (_) {
                      setState(() => _selectedCategoryId = catId);
                      _applyFilters();
                    },
                    selectedColor:
                        AppTheme.primaryColor.withValues(alpha: 0.2),
                  );
                },
              ),
            ),
          ),

        // ── Product grid ──
        if (state.products.isEmpty)
          const SliverFillRemaining(
            child: Center(
              child: Text(
                'No se encontraron productos',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.62,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) =>
                    _buildProductCard(state.products[index]),
                childCount: state.products.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final id =
        product['_id']?.toString() ?? product['id']?.toString() ?? '';
    final name = product['name']?.toString() ?? '';
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final comparePrice =
        (product['compare_price'] as num?)?.toDouble() ?? 0;
    final images = product['images'] as List? ?? [];
    final imageUrl =
        images.isNotEmpty ? images.first.toString() : '';
    final hasDiscount = comparePrice > price && comparePrice > 0;

    return GestureDetector(
      onTap: () => context.push('/products/$id'),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Image ──
            Expanded(
              flex: 3,
              child: SizedBox(
                width: double.infinity,
                child: imageUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Shimmer.fromColors(
                          baseColor: Colors.grey[300]!,
                          highlightColor: Colors.grey[100]!,
                          child: Container(color: Colors.white),
                        ),
                        errorWidget: (_, __, ___) => const Icon(
                          Icons.image_not_supported_outlined,
                          size: 48,
                          color: Colors.grey,
                        ),
                      )
                    : Container(
                        color: Colors.grey[200],
                        child: const Icon(
                          Icons.shopping_bag_outlined,
                          size: 48,
                          color: Colors.grey,
                        ),
                      ),
              ),
            ),

            // ── Info ──
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _currencyFormat.format(price),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    if (hasDiscount)
                      Text(
                        _currencyFormat.format(comparePrice),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 30,
                      child: ElevatedButton(
                        onPressed: () => context.push('/products/$id'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                        child: const Text('Agregar'),
                      ),
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

  Widget _buildShimmerGrid() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: 6,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.62,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemBuilder: (_, __) => Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                _currentPage = 1;
                _bloc.add(const LoadProducts());
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
