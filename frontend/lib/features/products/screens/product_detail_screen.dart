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
import 'package:baseshop/features/cart/bloc/cart_bloc.dart';
import 'package:baseshop/features/cart/bloc/cart_event.dart';
import 'package:baseshop/features/favorites/bloc/favorites_bloc.dart';
import 'package:baseshop/features/favorites/bloc/favorites_event.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late final ProductsBloc _bloc;
  int _quantity = 1;

  final _currencyFormat = NumberFormat.currency(
    locale: 'es_CO',
    symbol: '\$',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _bloc = getIt<ProductsBloc>();
    _bloc.add(LoadProductDetail(widget.productId));
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: BlocBuilder<ProductsBloc, ProductsState>(
        builder: (context, state) {
          if (state is ProductsLoading) {
            return _buildLoadingState();
          }

          if (state is ProductsError) {
            return _buildErrorState(state.message);
          }

          if (state is ProductDetailLoaded) {
            return Scaffold(
              body: _buildDetailContent(context, state.product),
              bottomNavigationBar:
                  _buildBottomBar(context, state.product),
            );
          }

          return const Scaffold(body: SizedBox.shrink());
        },
      ),
    );
  }

  Widget _buildDetailContent(
      BuildContext context, Map<String, dynamic> product) {
    final name = product['name']?.toString() ?? '';
    final description = product['description']?.toString() ?? '';
    final shortDescription =
        product['short_description']?.toString() ?? '';
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final comparePrice =
        (product['compare_price'] as num?)?.toDouble() ?? 0;
    final hasDiscount = comparePrice > price && comparePrice > 0;
    final discountPercent = hasDiscount
        ? ((comparePrice - price) / comparePrice * 100).round()
        : 0;
    final stock = (product['stock'] as num?)?.toInt() ?? 0;
    final inStock = stock > 0;
    final sku = product['sku']?.toString() ?? '';
    final images = List<String>.from(
      (product['images'] as List?)?.map((e) => e.toString()) ?? [],
    );
    final category = product['category'] as Map<String, dynamic>?;
    final categoryName = category?['name']?.toString() ?? '';
    final tags = List<String>.from(
      (product['tags'] as List?)?.map((e) => e.toString()) ?? [],
    );
    final rating = (product['average_rating'] as num?)?.toDouble() ??
        (product['rating'] as num?)?.toDouble() ??
        0.0;
    final reviewCount =
        (product['review_count'] as num?)?.toInt() ?? 0;
    final productId =
        product['_id']?.toString() ?? product['id']?.toString() ?? '';

    return CustomScrollView(
      slivers: [
        // ── Image header ──
        SliverAppBar(
          expandedHeight: 350,
          pinned: true,
          leading: IconButton(
            icon: const CircleAvatar(
              backgroundColor: Colors.white70,
              child: Icon(Icons.arrow_back, color: Colors.black87),
            ),
            onPressed: () => context.pop(),
          ),
          actions: [
            IconButton(
              icon: const CircleAvatar(
                backgroundColor: Colors.white70,
                child:
                    Icon(Icons.favorite_border, color: Colors.redAccent),
              ),
              onPressed: () {
                context.read<FavoritesBloc>().add(
                      AddFavorite(productId),
                    );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Agregado a favoritos'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: images.isNotEmpty
                ? _buildImageCarousel(images)
                : Container(
                    color: Colors.grey[200],
                    child: const Icon(
                      Icons.shopping_bag_outlined,
                      size: 80,
                      color: Colors.grey,
                    ),
                  ),
          ),
        ),

        // ── Body ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Category chip ──
                if (categoryName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Chip(
                      label: Text(
                        categoryName,
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor:
                          AppTheme.primaryColor.withValues(alpha: 0.1),
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),

                // ── Name ──
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),

                // ── Rating ──
                if (rating > 0 || reviewCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        ...List.generate(5, (i) {
                          if (i < rating.floor()) {
                            return const Icon(Icons.star,
                                size: 20, color: Colors.amber);
                          } else if (i < rating) {
                            return const Icon(Icons.star_half,
                                size: 20, color: Colors.amber);
                          }
                          return const Icon(Icons.star_border,
                              size: 20, color: Colors.amber);
                        }),
                        const SizedBox(width: 8),
                        Text(
                          '${rating.toStringAsFixed(1)} ($reviewCount reseñas)',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── Price ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _currencyFormat.format(price),
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    if (hasDiscount) ...[
                      const SizedBox(width: 10),
                      Text(
                        _currencyFormat.format(comparePrice),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '-$discountPercent%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),

                // ── Stock indicator ──
                Row(
                  children: [
                    Icon(
                      inStock
                          ? Icons.check_circle_outline
                          : Icons.cancel_outlined,
                      color: inStock
                          ? AppTheme.successColor
                          : AppTheme.errorColor,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      inStock
                          ? 'En stock ($stock disponibles)'
                          : 'Agotado',
                      style: TextStyle(
                        color: inStock
                            ? AppTheme.successColor
                            : AppTheme.errorColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ── Short description ──
                if (shortDescription.isNotEmpty) ...[
                  Text(
                    shortDescription,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // ── Description ──
                if (description.isNotEmpty) ...[
                  const Text(
                    'Descripción',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[800],
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── SKU ──
                if (sku.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'SKU: $sku',
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey[500]),
                    ),
                  ),

                // ── Tags ──
                if (tags.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: tags
                        .map(
                          (tag) => Chip(
                            label: Text(tag, style: const TextStyle(fontSize: 12)),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                ],

                // ── Reviews link ──
                if (reviewCount > 0)
                  TextButton.icon(
                    onPressed: () {
                      // Navigate to reviews (could be a dedicated screen)
                    },
                    icon: const Icon(Icons.rate_review_outlined),
                    label: Text('Ver $reviewCount reseñas'),
                  ),

                // Bottom spacing for the fixed button
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImageCarousel(List<String> images) {
    if (images.length == 1) {
      return CachedNetworkImage(
        imageUrl: images.first,
        fit: BoxFit.cover,
        width: double.infinity,
        placeholder: (_, __) => Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(color: Colors.white),
        ),
        errorWidget: (_, __, ___) => const Icon(
          Icons.image_not_supported_outlined,
          size: 64,
          color: Colors.grey,
        ),
      );
    }

    return PageView.builder(
      itemCount: images.length,
      itemBuilder: (_, index) => CachedNetworkImage(
        imageUrl: images[index],
        fit: BoxFit.cover,
        width: double.infinity,
        placeholder: (_, __) => Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(color: Colors.white),
        ),
        errorWidget: (_, __, ___) => const Icon(
          Icons.image_not_supported_outlined,
          size: 64,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: CustomScrollView(
        slivers: [
          const SliverAppBar(expandedHeight: 350, pinned: true),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 150, height: 20, color: Colors.white),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity, height: 28, color: Colors.white),
                  const SizedBox(height: 12),
                  Container(
                    width: 120, height: 32, color: Colors.white),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity, height: 80, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () =>
                    _bloc.add(LoadProductDetail(widget.productId)),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Bottom bar (quantity + add to cart) ──
  Widget _buildBottomBar(BuildContext context, Map<String, dynamic> product) {
    final inStock = ((product['stock'] as num?)?.toInt() ?? 0) > 0;
    final productId =
        product['_id']?.toString() ?? product['id']?.toString() ?? '';

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            // ── Quantity selector ──
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove, size: 20),
                    onPressed: _quantity > 1
                        ? () => setState(() => _quantity--)
                        : null,
                    constraints: const BoxConstraints(
                        minWidth: 36, minHeight: 36),
                    padding: EdgeInsets.zero,
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '$_quantity',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, size: 20),
                    onPressed: () => setState(() => _quantity++),
                    constraints: const BoxConstraints(
                        minWidth: 36, minHeight: 36),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // ── Add to cart button ──
            Expanded(
              child: ElevatedButton.icon(
                onPressed: inStock
                    ? () {
                        context.read<CartBloc>().add(
                              AddToCart(
                                productId: productId,
                                quantity: _quantity,
                              ),
                            );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Producto agregado al carrito'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      }
                    : null,
                icon: const Icon(Icons.shopping_cart_outlined),
                label: const Text('Agregar al carrito'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
