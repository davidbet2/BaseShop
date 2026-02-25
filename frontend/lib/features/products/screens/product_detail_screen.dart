import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import 'package:baseshop/core/theme/app_theme.dart';
import 'package:baseshop/features/products/bloc/products_bloc.dart';
import 'package:baseshop/features/products/bloc/products_event.dart';
import 'package:baseshop/features/products/bloc/products_state.dart';
import 'package:baseshop/features/cart/bloc/cart_bloc.dart';
import 'package:baseshop/features/cart/bloc/cart_event.dart';
import 'package:baseshop/features/favorites/bloc/favorites_bloc.dart';
import 'package:baseshop/features/favorites/bloc/favorites_event.dart';
import 'package:baseshop/features/favorites/bloc/favorites_state.dart';
import 'package:baseshop/features/auth/bloc/auth_bloc.dart';
import 'package:baseshop/features/auth/bloc/auth_state.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});
  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;
  final _currency = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
  final PageController _imageCtrl = PageController();
  int _currentImagePage = 0;
  int _selectedThumbIndex = 0;

  // Dynamic variant selections: variantTypeName -> selected option map
  final Map<String, Map<String, dynamic>> _selectedVariants = {};
  bool _variantsInitialized = false;

  @override
  void initState() {
    super.initState();
    context.read<ProductsBloc>().add(LoadProductDetail(widget.productId));
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      context.read<FavoritesBloc>().add(CheckFavorite(productId: widget.productId));
    }
  }

  @override
  void dispose() {
    _imageCtrl.dispose();
    super.dispose();
  }

  // Initialize variant selections with first option of each type
  void _initVariants(List<dynamic> variants) {
    if (_variantsInitialized || variants.isEmpty) return;
    _variantsInitialized = true;
    for (final v in variants) {
      final typeName = v['name'] as String? ?? '';
      final options = v['options'] as List? ?? [];
      if (options.isNotEmpty && !_selectedVariants.containsKey(typeName)) {
        _selectedVariants[typeName] = Map<String, dynamic>.from(options.first as Map);
      }
    }
  }

  // Compute total price adjustment from all selected variants
  double _computePriceAdjustment() {
    double adj = 0;
    for (final opt in _selectedVariants.values) {
      adj += (opt['price_adjustment'] as num?)?.toDouble() ?? 0;
    }
    return adj;
  }

  // Get variant override image (returns first non-empty image from selected variants)
  String? _getVariantImage() {
    for (final opt in _selectedVariants.values) {
      final img = opt['image'] as String? ?? '';
      if (img.isNotEmpty) return img;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: BlocBuilder<ProductsBloc, ProductsState>(
        buildWhen: (_, curr) => curr is ProductDetailLoaded || curr is ProductsLoading || curr is ProductsError,
        builder: (context, state) {
          if (state is ProductsLoading) return _buildLoading();
          if (state is ProductsError) return _buildError(state.message);
          if (state is! ProductDetailLoaded) return _buildLoading();

          final p = state.product;
          final images = (p['images'] is List) ? (p['images'] as List).map((e) => e.toString()).toList() : <String>[];
          final imageUrl = images.isNotEmpty ? images.first : '';
          final name = (p['name'] ?? '').toString();
          final shortDesc = (p['short_description'] ?? '').toString();
          final description = (p['description'] ?? '').toString();
          final originalPrice = (p['original_price'] as num?)?.toDouble() ?? (p['price'] as num?)?.toDouble() ?? 0;
          final discountPercent = (p['discount_percent'] as num?)?.toDouble() ?? 0;
          final stock = (p['stock'] as num?)?.toInt() ?? 0;
          final tags = (p['tags'] is List) ? (p['tags'] as List).map((e) => e.toString()).toList() : <String>[];
          final hasVariants = p['has_variants'] == true || p['has_variants'] == 1;
          final variants = (p['variants'] is List) ? p['variants'] as List : [];

          // Initialize variant selections
          if (hasVariants) _initVariants(variants);

          // Compute effective price with variant adjustments on original price
          final priceAdj = _computePriceAdjustment();
          final adjustedOriginal = originalPrice + priceAdj;
          final hasDiscount = discountPercent > 0;
          final price = hasDiscount
              ? (adjustedOriginal * (1 - discountPercent / 100))
              : adjustedOriginal;
          final comparePrice = hasDiscount ? adjustedOriginal : 0.0;
          final discountPct = hasDiscount ? discountPercent.round() : 0;

          // Override image from variant selection
          final variantImage = _getVariantImage();
          final displayImageUrl = variantImage ?? imageUrl;

          return LayoutBuilder(builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            if (isWide) {
              return _buildWideLayout(
                images: images, imageUrl: displayImageUrl, name: name, shortDesc: shortDesc,
                description: description, price: price, comparePrice: comparePrice,
                stock: stock, tags: tags, hasDiscount: hasDiscount, discountPct: discountPct,
                variants: variants, hasVariantData: hasVariants, maxWidth: constraints.maxWidth,
              );
            }
            return _buildMobileLayout(
              images: images, imageUrl: displayImageUrl, name: name, shortDesc: shortDesc,
              description: description, price: price, comparePrice: comparePrice,
              stock: stock, tags: tags, hasDiscount: hasDiscount, discountPct: discountPct,
              variants: variants, hasVariantData: hasVariants,
            );
          });
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  WIDE / WEB LAYOUT
  // ═══════════════════════════════════════════════════════════
  Widget _buildWideLayout({
    required List<String> images, required String imageUrl, required String name,
    required String shortDesc, required String description, required double price,
    required double comparePrice, required int stock, required List<String> tags,
    required bool hasDiscount, required int discountPct, required List<dynamic> variants,
    required bool hasVariantData, required double maxWidth,
  }) {
    return Column(
      children: [
        // Top bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              _buildCircleBtn(Icons.arrow_back_rounded, () => context.pop()),
              const SizedBox(width: 12),
              Expanded(
                child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              ),
              _buildCircleBtn(Icons.share_outlined, () => _shareProduct(name, price)),
              const SizedBox(width: 8),
              BlocBuilder<FavoritesBloc, FavoritesState>(
                builder: (context, favState) {
                  final isFav = favState is FavoritesLoaded && favState.favoriteIds.contains(widget.productId);
                  return _buildCircleBtn(
                    isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    () => _toggleFavorite(isFav, name, price, imageUrl),
                    color: isFav ? AppTheme.errorColor : null,
                  );
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppTheme.dividerColor),
        // Content
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Left: Image Gallery ──
                  Expanded(
                    flex: 5,
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          // Main image
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Container(
                                    color: const Color(0xFFF8F8F8),
                                    child: images.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: _getVariantImage() ?? images[_selectedThumbIndex],
                                            fit: BoxFit.contain,
                                            placeholder: (_, __) => Shimmer.fromColors(
                                              baseColor: Colors.grey.shade200, highlightColor: Colors.grey.shade50,
                                              child: Container(color: Colors.white),
                                            ),
                                            errorWidget: (_, __, ___) => const Icon(Icons.image_outlined, size: 64, color: AppTheme.textSecondary),
                                          )
                                        : const Icon(Icons.image_outlined, size: 64, color: AppTheme.textSecondary),
                                  ),
                                  if (hasDiscount)
                                    Positioned(
                                      top: 16, left: 16,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(color: AppTheme.errorColor, borderRadius: BorderRadius.circular(10)),
                                        child: Text('-$discountPct%', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          // Thumbnails
                          if (images.length > 1) ...[
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 72,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(images.length, (i) {
                                  final selected = i == _selectedThumbIndex;
                                  return GestureDetector(
                                    onTap: () => setState(() => _selectedThumbIndex = i),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      width: 72, height: 72,
                                      margin: const EdgeInsets.symmetric(horizontal: 4),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: selected ? Theme.of(context).colorScheme.primary : AppTheme.dividerColor,
                                          width: selected ? 2.5 : 1,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: CachedNetworkImage(imageUrl: images[i], fit: BoxFit.cover),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // ── Right: Product info ──
                  Expanded(
                    flex: 4,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(0, 32, 40, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                          if (shortDesc.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(shortDesc, style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                          ],
                          const SizedBox(height: 16),
                          // Price
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(_currency.format(price),
                                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary)),
                              if (hasDiscount) ...[
                                const SizedBox(width: 12),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(_currency.format(comparePrice),
                                    style: const TextStyle(fontSize: 16, color: AppTheme.textSecondary, decoration: TextDecoration.lineThrough)),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(6)),
                                  child: Text('-$discountPct%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.errorColor)),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 14),
                          // Stock
                          _buildStockIndicator(stock),
                          const SizedBox(height: 24),
                          const Divider(color: AppTheme.dividerColor),
                          const SizedBox(height: 20),
                          // Variant selectors (data-driven)
                          if (hasVariantData && variants.isNotEmpty)
                            ...variants.map((v) => _buildVariantSelector(v, images)),
                          // Tags
                          if (tags.isNotEmpty) _buildTags(tags),
                          // Description
                          const Divider(color: AppTheme.dividerColor),
                          const SizedBox(height: 16),
                          const Text('Descripci\u00f3n', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                          const SizedBox(height: 10),
                          Text(description, style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.7)),
                          const SizedBox(height: 32),
                          // Add to cart (inline for web)
                          _buildAddToCartBar(name, price, stock, imageUrl, compact: false),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  MOBILE LAYOUT (original SliverAppBar style)
  // ═══════════════════════════════════════════════════════════
  Widget _buildMobileLayout({
    required List<String> images, required String imageUrl, required String name,
    required String shortDesc, required String description, required double price,
    required double comparePrice, required int stock, required List<String> tags,
    required bool hasDiscount, required int discountPct, required List<dynamic> variants,
    required bool hasVariantData,
  }) {
    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 380,
              pinned: true,
              backgroundColor: Colors.white,
              leading: Padding(
                padding: const EdgeInsets.all(8),
                child: GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8)],
                    ),
                    child: const Icon(Icons.arrow_back_rounded, size: 22, color: AppTheme.textPrimary),
                  ),
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: GestureDetector(
                    onTap: () => _shareProduct(name, price),
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8)],
                      ),
                      child: const Icon(Icons.share_outlined, size: 20, color: AppTheme.textPrimary),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: BlocBuilder<FavoritesBloc, FavoritesState>(
                    builder: (context, favState) {
                      final isFav = favState is FavoritesLoaded && favState.favoriteIds.contains(widget.productId);
                      return GestureDetector(
                        onTap: () => _toggleFavorite(isFav, name, price, imageUrl),
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8)],
                          ),
                          child: Icon(
                            isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            size: 22,
                            color: isFav ? AppTheme.errorColor : AppTheme.textSecondary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (images.length > 1)
                      PageView.builder(
                        controller: _imageCtrl,
                        onPageChanged: (i) => setState(() => _currentImagePage = i),
                        itemCount: images.length,
                        itemBuilder: (_, i) => CachedNetworkImage(
                          imageUrl: images[i], fit: BoxFit.cover,
                          placeholder: (_, __) => Shimmer.fromColors(
                            baseColor: Colors.grey.shade200, highlightColor: Colors.grey.shade50,
                            child: Container(color: Colors.white),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: const Color(0xFFF3F4F6),
                            child: const Icon(Icons.image_outlined, size: 64, color: AppTheme.textSecondary),
                          ),
                        ),
                      )
                    else
                      CachedNetworkImage(
                        imageUrl: imageUrl, fit: BoxFit.cover,
                        placeholder: (_, __) => Shimmer.fromColors(
                          baseColor: Colors.grey.shade200, highlightColor: Colors.grey.shade50,
                          child: Container(color: Colors.white),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: const Color(0xFFF3F4F6),
                          child: const Icon(Icons.image_outlined, size: 64, color: AppTheme.textSecondary),
                        ),
                      ),
                    if (hasDiscount)
                      Positioned(
                        top: 100, left: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: AppTheme.errorColor, borderRadius: BorderRadius.circular(10)),
                          child: Text('-$discountPct%', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    if (images.length > 1)
                      Positioned(
                        bottom: 16, left: 0, right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(images.length, (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: i == _currentImagePage ? 20 : 8, height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: i == _currentImagePage ? Colors.white : Colors.white.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          )),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                    if (shortDesc.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(shortDesc, style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(_currency.format(price),
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.primary)),
                        if (hasDiscount) ...[
                          const SizedBox(width: 10),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text(_currency.format(comparePrice),
                              style: const TextStyle(fontSize: 16, color: AppTheme.textSecondary, decoration: TextDecoration.lineThrough)),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(6)),
                            child: Text('-$discountPct%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.errorColor)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildStockIndicator(stock),
                    const SizedBox(height: 24),
                    const Divider(color: AppTheme.dividerColor),
                    const SizedBox(height: 16),
                    if (hasVariantData && variants.isNotEmpty)
                      ...variants.map((v) => _buildVariantSelector(v, images)),
                    if (tags.isNotEmpty) _buildTags(tags),
                    const Divider(color: AppTheme.dividerColor),
                    const SizedBox(height: 16),
                    const Text('Descripci\u00f3n', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                    const SizedBox(height: 10),
                    Text(description, style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.7)),
                  ],
                ),
              ),
            ),
          ],
        ),
        // Bottom bar (mobile only)
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: _buildAddToCartBar(name, price, stock, imageUrl, compact: true),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  //  SHARED WIDGETS
  // ═══════════════════════════════════════════════════════════
  Widget _buildCircleBtn(IconData icon, VoidCallback onTap, {Color? color}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: color ?? AppTheme.textPrimary),
      ),
    );
  }

  Widget _buildStockIndicator(int stock) {
    return Row(
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: stock > 0 ? const Color(0xFF22C55E) : AppTheme.errorColor),
        ),
        const SizedBox(width: 8),
        Text(
          stock > 10 ? 'En stock' : stock > 0 ? '\u00daltimas $stock unidades' : 'Agotado',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: stock > 0 ? const Color(0xFF16A34A) : AppTheme.errorColor),
        ),
      ],
    );
  }

  // ── Dynamic variant selector (data-driven) ──
  Widget _buildVariantSelector(dynamic variant, List<String> productImages) {
    final typeName = (variant['name'] ?? '').toString();
    final options = (variant['options'] as List?) ?? [];
    if (options.isEmpty) return const SizedBox.shrink();

    final selectedOpt = _selectedVariants[typeName];
    final selectedName = selectedOpt?['name'] ?? '';
    final isColorType = typeName.toLowerCase().contains('color');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(typeName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            if (selectedName.isNotEmpty) ...[
              const SizedBox(width: 10),
              Text(selectedName, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10, runSpacing: 10,
          children: options.map<Widget>((opt) {
            final optName = (opt['name'] ?? '').toString();
            final priceAdj = (opt['price_adjustment'] as num?)?.toDouble() ?? 0;
            final optImage = (opt['image'] ?? '').toString();
            final isSelected = selectedName == optName;

            // If it's a color type with image, show as image swatch
            if (isColorType && optImage.isNotEmpty) {
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedVariants[typeName] = Map<String, dynamic>.from(opt as Map);
                }),
                child: Tooltip(
                  message: optName,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Theme.of(context).colorScheme.primary : AppTheme.dividerColor,
                        width: isSelected ? 3 : 1,
                      ),
                      boxShadow: isSelected ? [BoxShadow(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3), blurRadius: 8)] : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: CachedNetworkImage(
                        imageUrl: optImage,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: Colors.grey.shade200,
                          child: Center(child: Text(optName[0], style: const TextStyle(fontWeight: FontWeight.w600))),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }

            // Default: pill-style button
            return GestureDetector(
              onTap: () => setState(() {
                _selectedVariants[typeName] = Map<String, dynamic>.from(opt as Map);
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(horizontal: optName.length > 4 ? 18 : 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? Theme.of(context).colorScheme.primary : AppTheme.dividerColor,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected ? [BoxShadow(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2), blurRadius: 8)] : null,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(optName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppTheme.textPrimary)),
                    if (priceAdj != 0) ...[
                      const SizedBox(height: 2),
                      Text(
                        priceAdj > 0 ? '+${_currency.format(priceAdj)}' : _currency.format(priceAdj),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white70 : AppTheme.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildTags(List<String> tags) {
    return Column(
      children: [
        const Divider(color: AppTheme.dividerColor),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: tags.map((t) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(20)),
            child: Text('#$t', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          )).toList(),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildAddToCartBar(String name, double price, int stock, String imageUrl, {required bool compact}) {
    // Build variant selection label for snackbar
    final variantLabel = _selectedVariants.entries
        .map((e) => '${e.key}: ${e.value['name']}')
        .join(' | ');
    final variantMap = _selectedVariants.map((key, val) => MapEntry(key, (val['name'] ?? '').toString()));

    return Container(
      padding: compact
          ? EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16)
          : const EdgeInsets.all(0),
      decoration: compact
          ? BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppTheme.dividerColor.withValues(alpha: 0.5))),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))],
            )
          : null,
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                IconButton(
                  onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                  icon: const Icon(Icons.remove_rounded, size: 20),
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                ),
                SizedBox(
                  width: 32,
                  child: Text('$_quantity', textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  onPressed: _quantity < stock ? () => setState(() => _quantity++) : null,
                  icon: const Icon(Icons.add_rounded, size: 20),
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: stock > 0 ? () {
                  final authState = context.read<AuthBloc>().state;
                  if (authState is! AuthAuthenticated) {
                    _showAuthPrompt();
                    return;
                  }
                  context.read<CartBloc>().add(AddToCart(
                    productId: widget.productId,
                    productName: name,
                    productPrice: price,
                    productImage: _getVariantImage() ?? imageUrl,
                    quantity: _quantity,
                    selectedVariants: variantMap.isNotEmpty ? variantMap : null,
                  ));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(children: [
                        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                        Expanded(child: Text(variantLabel.isNotEmpty
                            ? '$name ($variantLabel) agregado al carrito'
                            : '$name agregado al carrito')),
                      ]),
                      backgroundColor: AppTheme.successColor,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                    ),
                  );
                } : null,
                icon: const Icon(Icons.shopping_cart_rounded, size: 20),
                label: Text('Agregar \u2022 ${_currency.format(price * _quantity)}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAuthPrompt() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(28),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.shopping_bag_outlined, color: Theme.of(context).colorScheme.primary, size: 24),
            ),
            const SizedBox(height: 16),
            const Text('Inicia sesión para comprar', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            const SizedBox(height: 8),
            const Text('Crea una cuenta o inicia sesión para agregar productos a tu carrito y completar tu compra.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.4)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: () { Navigator.pop(ctx); context.push('/login'); },
                child: const Text('Iniciar sesión', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity, height: 52,
              child: OutlinedButton(
                onPressed: () { Navigator.pop(ctx); context.push('/register'); },
                style: OutlinedButton.styleFrom(side: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: Text('Crear cuenta', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary)),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _toggleFavorite(bool isFav, String name, double price, String imageUrl) {
    final authState = context.read<AuthBloc>().state;
    if (authState is! AuthAuthenticated) { _showAuthPrompt(); return; }
    if (isFav) {
      context.read<FavoritesBloc>().add(RemoveFavorite(productId: widget.productId));
    } else {
      context.read<FavoritesBloc>().add(AddFavorite(
        productId: widget.productId, productName: name, productPrice: price, productImage: imageUrl,
      ));
    }
  }

  void _shareProduct(String name, double price) {
    final url = 'https://baseshop.app/products/${widget.productId}';
    final text = '¡Mira esto en BaseShop!\n\n$name\n${_currency.format(price)}\n\n$url';
    Share.share(text, subject: name);
  }

  Widget _buildLoading() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 380,
          backgroundColor: Colors.white,
          leading: Padding(
            padding: const EdgeInsets.all(8),
            child: GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.arrow_back_rounded, size: 22, color: AppTheme.textPrimary),
              ),
            ),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Shimmer.fromColors(
              baseColor: Colors.grey.shade200, highlightColor: Colors.grey.shade50,
              child: Container(color: Colors.white),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Shimmer.fromColors(
              baseColor: Colors.grey.shade200, highlightColor: Colors.grey.shade50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(width: 220, height: 24, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
                  const SizedBox(height: 12),
                  Container(width: 140, height: 30, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
                  const SizedBox(height: 24),
                  Row(children: List.generate(4, (_) => Container(
                    width: 40, height: 40, margin: const EdgeInsets.only(right: 12),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  ))),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 10, runSpacing: 10,
                    children: List.generate(5, (_) => Container(
                      width: 52, height: 44, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    )),
                  ),
                  const SizedBox(height: 24),
                  Container(width: double.infinity, height: 80, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
                ],
              ),
            ),
          ),
        ),
      ],
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
          ElevatedButton(onPressed: () => context.pop(), child: const Text('Volver')),
        ],
      ),
    );
  }
}
