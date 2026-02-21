import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';

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
          final imageUrl = (p['image_url'] ?? p['imageUrl'] ?? '').toString();
          final name = (p['name'] ?? '').toString();
          final description = (p['description'] ?? '').toString();
          final price = double.tryParse(p['price']?.toString() ?? '0') ?? 0;
          final discount = double.tryParse(p['discount']?.toString() ?? '0') ?? 0;
          final stock = int.tryParse(p['stock']?.toString() ?? '0') ?? 0;
          final tags = (p['tags'] is List) ? (p['tags'] as List).map((e) => e.toString()).toList() : <String>[];
          final hasDiscount = discount > 0;
          final discountedPrice = hasDiscount ? price * (1 - discount / 100) : price;

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  // Image header
                  SliverAppBar(
                    expandedHeight: 340,
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
                          ),
                          child: const Icon(Icons.arrow_back_rounded, size: 22, color: AppTheme.textPrimary),
                        ),
                      ),
                    ),
                    actions: [
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
                          if (hasDiscount)
                            Positioned(
                              top: 100, left: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(color: AppTheme.errorColor, borderRadius: BorderRadius.circular(10)),
                                child: Text('-${discount.toInt()}%', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Body content
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Name
                          Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                          const SizedBox(height: 10),

                          // Price
                          Row(
                            children: [
                              Text('\$${discountedPrice.toStringAsFixed(0)}',
                                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.primaryColor)),
                              if (hasDiscount) ...[
                                const SizedBox(width: 10),
                                Text('\$${price.toStringAsFixed(0)}',
                                  style: const TextStyle(fontSize: 16, color: AppTheme.textSecondary, decoration: TextDecoration.lineThrough)),
                              ],
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Stock indicator
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: stock > 0 ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              stock > 0 ? '$stock disponibles' : 'Agotado',
                              style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600,
                                color: stock > 0 ? const Color(0xFF16A34A) : AppTheme.errorColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Tags
                          if (tags.isNotEmpty) ...[
                            Wrap(
                              spacing: 8, runSpacing: 8,
                              children: tags.map((t) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(t, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                              )).toList(),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Description
                          const Text('Descripci\u00f3n', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                          const SizedBox(height: 8),
                          Text(description, style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.6)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              // Bottom bar
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
                                productPrice: discountedPrice,
                                productImage: imageUrl,
                                quantity: _quantity,
                              ));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('$name agregado al carrito'),
                                  backgroundColor: AppTheme.successColor,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              );
                            } : null,
                            icon: const Icon(Icons.shopping_cart_rounded, size: 20),
                            label: const Text('Agregar al carrito', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
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
    );
  }

  Widget _buildLoading() {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 340,
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
                  Container(width: 200, height: 24, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
                  const SizedBox(height: 12),
                  Container(width: 120, height: 28, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
                  const SizedBox(height: 20),
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
