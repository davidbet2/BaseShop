import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:baseshop/core/theme/app_theme.dart';
import 'package:baseshop/features/cart/bloc/cart_bloc.dart';
import 'package:baseshop/features/cart/bloc/cart_event.dart';
import 'package:baseshop/features/cart/bloc/cart_state.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  void initState() {
    super.initState();
    context.read<CartBloc>().add(const LoadCart());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: BlocBuilder<CartBloc, CartState>(
          builder: (context, state) {
            if (state is CartLoading) {
              return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
            }
            if (state is CartError) {
              return _buildError(state.message);
            }
            if (state is CartLoaded && state.items.isEmpty) {
              return _buildEmpty();
            }
            if (state is! CartLoaded) {
              return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
            }

            return Column(
              children: [
                // Header
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Mi carrito', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                            SizedBox(height: 4),
                            Text('Revisa tus productos', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                          ],
                        ),
                      ),
                      if (state.items.isNotEmpty)
                        TextButton.icon(
                          onPressed: () => _showClearDialog(),
                          icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.errorColor),
                          label: const Text('Vaciar', style: TextStyle(color: AppTheme.errorColor, fontSize: 13)),
                        ),
                    ],
                  ),
                ),

                // Items
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    itemCount: state.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _buildCartItem(state.items[i]),
                  ),
                ),

                // Bottom bar
                Container(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: AppTheme.dividerColor.withValues(alpha: 0.5))),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Summary
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${state.itemCount} art\u00edculos', style: const TextStyle(color: AppTheme.textSecondary)),
                          Text('Subtotal', style: const TextStyle(color: AppTheme.textSecondary)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                          Text('\$${state.subtotal.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.primaryColor)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity, height: 56,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Funci\u00f3n de pago pr\u00f3ximamente'),
                                backgroundColor: AppTheme.primaryColor,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          },
                          icon: const Icon(Icons.payment_rounded, size: 20),
                          label: const Text('Proceder al pago', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCartItem(Map<String, dynamic> item) {
    final itemId = (item['id'] ?? item['item_id'] ?? '').toString();
    final name = (item['product_name'] ?? item['productName'] ?? item['name'] ?? '').toString();
    final imageUrl = (item['product_image'] ?? item['productImage'] ?? item['image_url'] ?? '').toString();
    final price = double.tryParse(item['product_price']?.toString() ?? item['price']?.toString() ?? '0') ?? 0;
    final quantity = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;

    return Dismissible(
      key: Key(itemId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppTheme.errorColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white, size: 28),
      ),
      onDismissed: (_) => context.read<CartBloc>().add(RemoveCartItem(itemId: itemId)),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 80, height: 80,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    color: const Color(0xFFF3F4F6),
                    child: const Icon(Icons.image_outlined, size: 28, color: AppTheme.textSecondary),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                  const SizedBox(height: 6),
                  Text('\$${price.toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primaryColor)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Quantity controls
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: 36, height: 36,
                    child: IconButton(
                      onPressed: () {
                        context.read<CartBloc>().add(UpdateCartItem(itemId: itemId, quantity: quantity + 1));
                      },
                      icon: const Icon(Icons.add_rounded, size: 16),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  Text('$quantity', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  SizedBox(
                    width: 36, height: 36,
                    child: IconButton(
                      onPressed: () {
                        if (quantity > 1) {
                          context.read<CartBloc>().add(UpdateCartItem(itemId: itemId, quantity: quantity - 1));
                        } else {
                          context.read<CartBloc>().add(RemoveCartItem(itemId: itemId));
                        }
                      },
                      icon: const Icon(Icons.remove_rounded, size: 16),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.shopping_cart_outlined, size: 48, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 24),
          const Text('Tu carrito est\u00e1 vac\u00edo', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          const Text('Agrega productos para comenzar', style: TextStyle(fontSize: 15, color: AppTheme.textSecondary)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.go('/products'),
            icon: const Icon(Icons.shopping_bag_rounded, size: 18),
            label: const Text('Explorar productos'),
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
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
          ElevatedButton(
            onPressed: () => context.read<CartBloc>().add(const LoadCart()),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  void _showClearDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('\u00bfVaciar carrito?', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Se eliminar\u00e1n todos los productos de tu carrito.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<CartBloc>().add(const ClearCart());
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorColor),
            child: const Text('Vaciar'),
          ),
        ],
      ),
    );
  }
}
