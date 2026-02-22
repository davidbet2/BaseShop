import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';

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
  String? _selectedSize;
  int _selectedColorIndex = 0;
  final _currency = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
  final PageController _imageCtrl = PageController();
  int _currentImagePage = 0;

  // Simulated variant data based on category/tags
  static const _clothingSizes = ['XS', 'S', 'M', 'L', 'XL'];
  static const _shoeSizes = ['36', '37', '38', '39', '40', '41', '42', '43', '44'];
  static const _electronicsStorage = ['128GB', '256GB', '512GB', '1TB'];
  static const _defaultColors = [
    {'name': 'Negro', 'color': Color(0xFF1F2937)},
    {'name': 'Blanco', 'color': Color(0xFFF9FAFB)},
    {'name': 'Azul', 'color': Color(0xFF3B82F6)},
    {'name': 'Rojo', 'color': Color(0xFFEF4444)},
  ];

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

  /// Determine variant type from tags/category
  _VariantType _getVariantType(List<String> tags) {
    final joined = tags.join(' ').toLowerCase();
    if (joined.contains('zapatillas') || joined.contains('running') || joined.contains('zapato')) {
      return _VariantType.shoes;
    }
    if (joined.contains('ropa') || joined.contains('camiseta') || joined.contains('vestido') ||
        joined.contains('jeans') || joined.contains('chaqueta') || joined.contains('deportiva')) {
      return _VariantType.clothing;
    }
    if (joined.contains('smartphone') || joined.contains('iphone') || joined.contains('galaxy') ||
        joined.contains('laptop') || joined.contains('macbook')) {
      return _VariantType.electronics;
    }
    return _VariantType.none;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kIsWeb ? const Color(0xFFF0F1F3) : Colors.white,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Container(
            color: Colors.white,
            child: BlocBuilder<ProductsBloc, ProductsState>(
              buildWhen: (_, curr) => curr is ProductDetailLoaded || curr is ProductsLoading || curr is ProductsError,
              builder: (context, state) {
                if (state is ProductsLoading) return _buildLoading();
                if (state is ProductsError) return _buildError(state.message);
                if (state is! ProductDetailLoaded) return _buildLoading();

          final p = state.product;
          // Fix field mapping: backend uses `images` (array) and `compare_price`
          final images = (p['images'] is List) ? (p['images'] as List).map((e) => e.toString()).toList() : <String>[];
          final imageUrl = images.isNotEmpty ? images.first : '';
          final name = (p['name'] ?? '').toString();
          final shortDesc = (p['short_description'] ?? '').toString();
          final description = (p['description'] ?? '').toString();
          final price = (p['price'] as num?)?.toDouble() ?? 0;
          final comparePrice = (p['compare_price'] as num?)?.toDouble() ?? 0;
          final stock = (p['stock'] as num?)?.toInt() ?? 0;
          final tags = (p['tags'] is List) ? (p['tags'] as List).map((e) => e.toString()).toList() : <String>[];
          final hasDiscount = comparePrice > price && comparePrice > 0;
          final discountPct = hasDiscount ? ((comparePrice - price) / comparePrice * 100).round() : 0;
          final variantType = _getVariantType(tags);

          // Set default selected size
          if (_selectedSize == null) {
            switch (variantType) {
              case _VariantType.clothing: _selectedSize = 'M'; break;
              case _VariantType.shoes: _selectedSize = '40'; break;
              case _VariantType.electronics: _selectedSize = '256GB'; break;
              case _VariantType.none: break;
            }
          }

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  // ── Image Gallery ──
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
                              onTap: () {
                                final authState = context.read<AuthBloc>().state;
                                if (authState is! AuthAuthenticated) {
                                  context.push('/login');
                                  return;
                                }
                                if (isFav) {
                                  context.read<FavoritesBloc>().add(RemoveFavorite(productId: widget.productId));
                                } else {
                                  context.read<FavoritesBloc>().add(AddFavorite(
                                    productId: widget.productId,
                                    productName: name,
                                    productPrice: price,
                                    productImage: imageUrl,
                                  ));
                                }
                              },
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
                                imageUrl: images[i],
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Shimmer.fromColors(
                                  baseColor: Colors.grey.shade200,
                                  highlightColor: Colors.grey.shade50,
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
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => Shimmer.fromColors(
                                baseColor: Colors.grey.shade200,
                                highlightColor: Colors.grey.shade50,
                                child: Container(color: Colors.white),
                              ),
                              errorWidget: (_, __, ___) => Container(
                                color: const Color(0xFFF3F4F6),
                                child: const Icon(Icons.image_outlined, size: 64, color: AppTheme.textSecondary),
                              ),
                            ),
                          // Discount badge
                          if (hasDiscount)
                            Positioned(
                              top: 100, left: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(color: AppTheme.errorColor, borderRadius: BorderRadius.circular(10)),
                                child: Text('-$discountPct%', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                              ),
                            ),
                          // Image page indicator
                          if (images.length > 1)
                            Positioned(
                              bottom: 16,
                              left: 0, right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(images.length, (i) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  width: i == _currentImagePage ? 20 : 8,
                                  height: 8,
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

                  // ── Body content ──
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name & short description
                          Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                          if (shortDesc.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(shortDesc, style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                          ],
                          const SizedBox(height: 12),

                          // Price row
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(_currency.format(price),
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppTheme.primaryColor)),
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

                          // Stock indicator
                          Row(
                            children: [
                              Container(
                                width: 8, height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: stock > 0 ? const Color(0xFF22C55E) : AppTheme.errorColor,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                stock > 10 ? 'En stock' : stock > 0 ? '\u00daltimas $stock unidades' : 'Agotado',
                                style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600,
                                  color: stock > 0 ? const Color(0xFF16A34A) : AppTheme.errorColor,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),
                          const Divider(color: AppTheme.dividerColor),
                          const SizedBox(height: 16),

                          // ── Color Selector ──
                          if (variantType == _VariantType.clothing || variantType == _VariantType.shoes) ...[
                            Row(
                              children: [
                                const Text('Color', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                                const SizedBox(width: 10),
                                Text((_defaultColors[_selectedColorIndex]['name'] as String?) ?? '',
                                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: List.generate(_defaultColors.length, (i) {
                                final color = _defaultColors[i]['color'] as Color;
                                final isSelected = i == _selectedColorIndex;
                                return GestureDetector(
                                  onTap: () => setState(() => _selectedColorIndex = i),
                                  child: Container(
                                    width: 40, height: 40,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: color,
                                      border: Border.all(
                                        color: isSelected ? AppTheme.primaryColor : AppTheme.dividerColor,
                                        width: isSelected ? 3 : 1,
                                      ),
                                      boxShadow: isSelected ? [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.3), blurRadius: 8)] : null,
                                    ),
                                    child: isSelected ? Icon(Icons.check_rounded, size: 18, color: color.computeLuminance() > 0.5 ? AppTheme.textPrimary : Colors.white) : null,
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // ── Size / Storage Selector ──
                          if (variantType != _VariantType.none) ...[
                            Text(
                              variantType == _VariantType.electronics ? 'Almacenamiento' : 'Talla',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10, runSpacing: 10,
                              children: _getSizeOptions(variantType).map((size) {
                                final isSelected = _selectedSize == size;
                                return GestureDetector(
                                  onTap: () => setState(() => _selectedSize = size),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: variantType == _VariantType.electronics ? 18 : 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected ? AppTheme.primaryColor : Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected ? AppTheme.primaryColor : AppTheme.dividerColor,
                                        width: isSelected ? 2 : 1,
                                      ),
                                      boxShadow: isSelected ? [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.2), blurRadius: 8)] : null,
                                    ),
                                    child: Text(size, style: TextStyle(
                                      fontSize: 14, fontWeight: FontWeight.w600,
                                      color: isSelected ? Colors.white : AppTheme.textPrimary,
                                    )),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Tags
                          if (tags.isNotEmpty) ...[
                            const Divider(color: AppTheme.dividerColor),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8, runSpacing: 8,
                              children: tags.map((t) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text('#$t', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                              )).toList(),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Description
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

              // ── Bottom bar ──
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: AppTheme.dividerColor.withValues(alpha: 0.5))),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))],
                  ),
                  child: Row(
                    children: [
                      // Quantity
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(14),
                        ),
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
                      // Add to cart
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: stock > 0 ? () {
                              final authState = context.read<AuthBloc>().state;
                              if (authState is! AuthAuthenticated) {
                                context.push('/login');
                                return;
                              }
                              context.read<CartBloc>().add(AddToCart(
                                productId: widget.productId,
                                productName: name,
                                productPrice: price,
                                productImage: imageUrl,
                                quantity: _quantity,
                              ));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(children: [
                                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text('$name agregado al carrito')),
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
                ),
              ),
            ],
          );
        },
      ),
          ),
        ),
      ),
    );
  }

  void _shareProduct(String name, double price) {
    final url = 'https://baseshop.app/products/${widget.productId}';
    final text = '$name - ${_currency.format(price)}\n$url';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text('Enlace copiado al portapapeles'),
        ]),
        backgroundColor: AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      ),
    );
  }

  List<String> _getSizeOptions(_VariantType type) {
    switch (type) {
      case _VariantType.clothing: return _clothingSizes;
      case _VariantType.shoes: return _shoeSizes;
      case _VariantType.electronics: return _electronicsStorage;
      case _VariantType.none: return [];
    }
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

enum _VariantType { clothing, shoes, electronics, none }
