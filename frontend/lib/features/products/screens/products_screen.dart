import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';

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
  final _scrollController = ScrollController();
  final _searchCtrl = TextEditingController();
  final _currency = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  String? _selectedCategoryId;
  String _sortBy = 'newest';
  double? _minPrice;
  double? _maxPrice;
  int _currentPage = 1;
  bool _hasMore = true;

  List<Map<String, dynamic>> _allProducts = [];
  List<Map<String, dynamic>> _categories = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    context.read<ProductsBloc>().add(const LoadCategories());
    _loadProducts(reset: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 && _hasMore) {
      _loadProducts();
    }
  }

  void _loadProducts({bool reset = false}) {
    if (reset) {
      _currentPage = 1;
      _allProducts = [];
      _hasMore = true;
    }
    context.read<ProductsBloc>().add(LoadProducts(
      categoryId: _selectedCategoryId,
      search: _searchCtrl.text.isNotEmpty ? _searchCtrl.text : null,
      sortBy: _sortBy,
      minPrice: _minPrice,
      maxPrice: _maxPrice,
      page: _currentPage,
    ));
  }

  void _onCategoryTap(String? id) {
    setState(() => _selectedCategoryId = id);
    _loadProducts(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 768;
            return Column(
              children: [
                // ── Header ──
                _buildHeader(isWide),
                // ── Category chips (mobile only — sidebar handles this on wide) ──
                if (!isWide) _buildCategoryChips(),
                if (!isWide) const SizedBox(height: 4),
                // ── Body ──
                Expanded(
                  child: isWide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Sidebar filters
                            SizedBox(
                              width: 240,
                              child: _buildSidebar(),
                            ),
                            Container(width: 1, color: AppTheme.dividerColor.withValues(alpha: 0.3)),
                            // Product grid
                            Expanded(child: _buildProductGrid(isWide)),
                          ],
                        )
                      : _buildProductGrid(isWide),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  HEADER
  // ═══════════════════════════════════════════════════════════
  Widget _buildHeader(bool isWide) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(20, 12, 20, isWide ? 12 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Tienda', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                    SizedBox(height: 2),
                    Text('Encuentra lo que necesitas', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  ],
                ),
              ),
              if (!isWide)
                GestureDetector(
                  onTap: _showFilterSheet,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
                      ),
                      if (_activeFilterCount > 0)
                        Positioned(
                          top: -4, right: -4,
                          child: Container(
                            width: 20, height: 20,
                            decoration: const BoxDecoration(color: AppTheme.errorColor, shape: BoxShape.circle),
                            child: Center(child: Text('$_activeFilterCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700))),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Search bar
          Container(
            height: 44,
            decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
            child: TextField(
              controller: _searchCtrl,
              onSubmitted: (_) => _loadProducts(reset: true),
              decoration: InputDecoration(
                hintText: 'Buscar productos...',
                hintStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppTheme.textSecondary),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: () { _searchCtrl.clear(); _loadProducts(reset: true); })
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          if (!isWide) const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  CATEGORY CHIPS (mobile horizontal scroll)
  // ═══════════════════════════════════════════════════════════
  Widget _buildCategoryChips() {
    return BlocListener<ProductsBloc, ProductsState>(
      listener: (context, state) {
        if (state is CategoriesLoaded) setState(() => _categories = state.categories);
      },
      child: Container(
        color: Colors.white,
        height: 46,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            _buildChip(null, 'Todos'),
            ..._categories.map((c) => _buildChip(c['id']?.toString() ?? '', c['name']?.toString() ?? '')),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  SIDEBAR (web/wide screens)
  // ═══════════════════════════════════════════════════════════
  Widget _buildSidebar() {
    return BlocListener<ProductsBloc, ProductsState>(
      listener: (context, state) {
        if (state is CategoriesLoaded) setState(() => _categories = state.categories);
      },
      child: Container(
        color: Colors.white,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Results count
            if (_allProducts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text('${_allProducts.length} productos',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
              ),
            // Categories
            const Text('CATEGORÍA', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 0.8)),
            const SizedBox(height: 8),
            _buildSidebarCategory(null, 'Todos'),
            ..._categories.map((c) => _buildSidebarCategory(c['id']?.toString() ?? '', c['name']?.toString() ?? '')),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),
            // Sort
            const Text('ORDENAR POR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 0.8)),
            const SizedBox(height: 8),
            _buildSidebarSort('newest', 'Más nuevos'),
            _buildSidebarSort('price_asc', 'Menor precio'),
            _buildSidebarSort('price_desc', 'Mayor precio'),
            _buildSidebarSort('name_asc', 'A - Z'),
            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),
            // Price range
            const Text('RANGO DE PRECIO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 0.8)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Min',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.dividerColor)),
                    ),
                    onChanged: (v) { _minPrice = double.tryParse(v); },
                  ),
                ),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('–')),
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Max',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.dividerColor)),
                    ),
                    onChanged: (v) { _maxPrice = double.tryParse(v); },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _loadProducts(reset: true),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Aplicar filtros', style: TextStyle(fontSize: 13)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  setState(() { _sortBy = 'newest'; _minPrice = null; _maxPrice = null; _selectedCategoryId = null; });
                  _loadProducts(reset: true);
                },
                child: const Text('Limpiar todo', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarCategory(String? id, String label) {
    final selected = _selectedCategoryId == id;
    return InkWell(
      onTap: () => _onCategoryTap(id),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08) : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            if (selected) Icon(Icons.check_rounded, size: 16, color: Theme.of(context).colorScheme.primary) else const SizedBox(width: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: TextStyle(
              fontSize: 13, fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? Theme.of(context).colorScheme.primary : AppTheme.textPrimary,
            ))),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebarSort(String value, String label) {
    final selected = _sortBy == value;
    return InkWell(
      onTap: () { setState(() => _sortBy = value); _loadProducts(reset: true); },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
        child: Row(
          children: [
            Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                size: 18, color: selected ? Theme.of(context).colorScheme.primary : AppTheme.textSecondary),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 13, color: selected ? Theme.of(context).colorScheme.primary : AppTheme.textPrimary,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  PRODUCT GRID
  // ═══════════════════════════════════════════════════════════
  Widget _buildProductGrid(bool isWide) {
    return BlocConsumer<ProductsBloc, ProductsState>(
      listener: (context, state) {
        if (state is ProductsLoaded) {
          setState(() {
            if (state.page == 1) _allProducts = [];
            _allProducts = [..._allProducts, ...state.products];
            _hasMore = _allProducts.length < state.total;
            _currentPage = state.page + 1;
            if (state.categories.isNotEmpty) _categories = state.categories;
          });
        }
      },
      buildWhen: (prev, curr) => curr is ProductsLoaded || curr is ProductsLoading || curr is ProductsError,
      builder: (context, state) {
        if (state is ProductsLoading && _allProducts.isEmpty) return _buildShimmerGrid();
        if (state is ProductsError && _allProducts.isEmpty) return _buildError(state.message);
        if (_allProducts.isEmpty) return _buildEmpty();

        return GridView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 220,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: 0.62,
          ),
          itemCount: _allProducts.length + (_hasMore ? 2 : 0),
          itemBuilder: (context, i) {
            if (i >= _allProducts.length) {
              return Shimmer.fromColors(
                baseColor: Colors.grey.shade200, highlightColor: Colors.grey.shade50,
                child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14))),
              );
            }
            return _buildProductCard(_allProducts[i]);
          },
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  PRODUCT CARD
  // ═══════════════════════════════════════════════════════════
  Widget _buildProductCard(Map<String, dynamic> p) {
    final images = p['images'] as List? ?? [];
    final imageUrl = images.isNotEmpty ? images.first.toString() : '';
    final name = (p['name'] ?? '').toString();
    final price = (p['price'] as num?)?.toDouble() ?? 0;
    final comparePrice = (p['compare_price'] as num?)?.toDouble() ?? 0;
    final id = (p['_id'] ?? p['id'] ?? '').toString();
    final hasDiscount = comparePrice > price && comparePrice > 0;
    final discountPct = hasDiscount ? ((comparePrice - price) / comparePrice * 100).round() : 0;

    return GestureDetector(
      onTap: () => context.push('/products/$id'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    child: SizedBox(
                      width: double.infinity,
                      child: CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Shimmer.fromColors(
                          baseColor: Colors.grey.shade200, highlightColor: Colors.grey.shade50,
                          child: Container(color: Colors.white),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: const Color(0xFFF3F4F6),
                          child: const Icon(Icons.image_outlined, size: 32, color: AppTheme.textSecondary),
                        ),
                      ),
                    ),
                  ),
                  if (hasDiscount)
                    Positioned(
                      top: 8, left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(color: AppTheme.errorColor, borderRadius: BorderRadius.circular(6)),
                        child: Text('-$discountPct%', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      width: 30, height: 30,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), shape: BoxShape.circle),
                      child: const Icon(Icons.favorite_border_rounded, size: 15, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary, height: 1.3)),
                  const SizedBox(height: 6),
                  if (hasDiscount)
                    Text(_currency.format(comparePrice),
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, decoration: TextDecoration.lineThrough)),
                  Text(_currency.format(price),
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════════════════════════
  Widget _buildChip(String? id, String label) {
    final selected = _selectedCategoryId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: Theme.of(context).colorScheme.primary,
        backgroundColor: const Color(0xFFF3F4F6),
        labelStyle: TextStyle(color: selected ? Colors.white : AppTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 13),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onSelected: (_) => _onCategoryTap(id),
      ),
    );
  }

  Widget _buildShimmerGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 0.62,
      ),
      itemCount: 8,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey.shade200, highlightColor: Colors.grey.shade50,
        child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14))),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('No se encontraron productos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () { _searchCtrl.clear(); _selectedCategoryId = null; _loadProducts(reset: true); },
            child: const Text('Limpiar filtros'),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String msg) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 56, color: AppTheme.errorColor),
          const SizedBox(height: 12),
          Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: () => _loadProducts(reset: true), child: const Text('Reintentar')),
        ],
      ),
    );
  }

  int get _activeFilterCount {
    int count = 0;
    if (_selectedCategoryId != null) count++;
    if (_sortBy != 'newest') count++;
    if (_minPrice != null) count++;
    if (_maxPrice != null) count++;
    return count;
  }

  void _showFilterSheet() {
    String tempSort = _sortBy;
    String? tempCategory = _selectedCategoryId;
    final minCtrl = TextEditingController(text: _minPrice?.toStringAsFixed(0) ?? '');
    final maxCtrl = TextEditingController(text: _maxPrice?.toStringAsFixed(0) ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheetState) {
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            builder: (_, scrollCtrl) {
              return Column(
                children: [
                  // Handle + header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                    child: Column(
                      children: [
                        Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Expanded(child: Text('Filtros', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary))),
                            TextButton(
                              onPressed: () {
                                setSheetState(() { tempSort = 'newest'; tempCategory = null; minCtrl.clear(); maxCtrl.clear(); });
                              },
                              child: const Text('Limpiar todo', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  // Scrollable filter content
                  Expanded(
                    child: ListView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                      children: [
                        // ── Categories ──
                        const Text('Categor\u00eda', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: [
                            _filterCategoryChip(null, 'Todos', tempCategory, (v) => setSheetState(() => tempCategory = v)),
                            ..._categories.map((c) => _filterCategoryChip(
                              c['id']?.toString() ?? '', c['name']?.toString() ?? '',
                              tempCategory, (v) => setSheetState(() => tempCategory = v),
                            )),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // ── Sort ──
                        const Text('Ordenar por', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                        const SizedBox(height: 12),
                        _sheetSortOption('newest', 'M\u00e1s nuevos', Icons.schedule_rounded, tempSort, (v) => setSheetState(() => tempSort = v)),
                        _sheetSortOption('price_asc', 'Menor precio', Icons.arrow_downward_rounded, tempSort, (v) => setSheetState(() => tempSort = v)),
                        _sheetSortOption('price_desc', 'Mayor precio', Icons.arrow_upward_rounded, tempSort, (v) => setSheetState(() => tempSort = v)),
                        _sheetSortOption('name_asc', 'A - Z', Icons.sort_by_alpha_rounded, tempSort, (v) => setSheetState(() => tempSort = v)),
                        const SizedBox(height: 24),
                        // ── Price Range ──
                        const Text('Rango de precio', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                        const SizedBox(height: 12),
                        Row(children: [
                          Expanded(
                            child: TextField(
                              controller: minCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: 'M\u00ednimo',
                                prefixText: '\$ ',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.dividerColor)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.dividerColor)),
                              ),
                            ),
                          ),
                          const Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('\u2013', style: TextStyle(fontSize: 18, color: AppTheme.textSecondary))),
                          Expanded(
                            child: TextField(
                              controller: maxCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: 'M\u00e1ximo',
                                prefixText: '\$ ',
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.dividerColor)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppTheme.dividerColor)),
                              ),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                  // ── Apply button ──
                  Container(
                    padding: EdgeInsets.fromLTRB(24, 12, 24, MediaQuery.of(ctx).padding.bottom + 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: AppTheme.dividerColor.withValues(alpha: 0.5))),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          setState(() {
                            _sortBy = tempSort;
                            _selectedCategoryId = tempCategory;
                            _minPrice = double.tryParse(minCtrl.text);
                            _maxPrice = double.tryParse(maxCtrl.text);
                          });
                          _loadProducts(reset: true);
                        },
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                        child: const Text('Aplicar filtros', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        });
      },
    );
  }

  Widget _filterCategoryChip(String? id, String label, String? current, ValueChanged<String?> onTap) {
    final selected = current == id;
    return GestureDetector(
      onTap: () => onTap(id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).colorScheme.primary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? Theme.of(context).colorScheme.primary : AppTheme.dividerColor),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: selected ? Colors.white : AppTheme.textPrimary,
        )),
      ),
    );
  }

  Widget _sheetSortOption(String value, String label, IconData icon, String current, ValueChanged<String> onTap) {
    final selected = current == value;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: selected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08) : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: selected ? Theme.of(context).colorScheme.primary : AppTheme.textSecondary),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(
              fontSize: 14, fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? Theme.of(context).colorScheme.primary : AppTheme.textPrimary,
            ))),
            if (selected) Icon(Icons.check_rounded, size: 20, color: Theme.of(context).colorScheme.primary),
          ],
        ),
      ),
    );
  }

}
