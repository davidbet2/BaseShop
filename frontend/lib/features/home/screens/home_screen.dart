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
import 'package:baseshop/features/auth/bloc/auth_bloc.dart';
import 'package:baseshop/features/auth/bloc/auth_state.dart';
import 'package:baseshop/features/cart/bloc/cart_bloc.dart';
import 'package:baseshop/features/cart/bloc/cart_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ProductsBloc _bloc;
  final _currency = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _bloc = getIt<ProductsBloc>()..add(const LoadProducts());
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
      child: Scaffold(
        body: SafeArea(
          child: RefreshIndicator(
            color: AppTheme.primaryColor,
            onRefresh: () async => _bloc.add(const LoadProducts()),
            child: BlocBuilder<ProductsBloc, ProductsState>(
              builder: (context, state) {
                if (state is ProductsLoading) return _buildShimmer();
                if (state is ProductsError) return _buildError(state.message);
                if (state is ProductsLoaded) return _buildContent(context, state);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ProductsLoaded state) {
    final featured = state.products.where((p) => p['is_featured'] == true).toList();
    final newest = state.products.take(10).toList();
    final authState = context.watch<AuthBloc>().state;
    final firstName = authState is AuthAuthenticated
        ? (authState.user['firstName'] ?? authState.user['first_name'] ?? '').toString()
        : '';

    return CustomScrollView(
      slivers: [
        // ── Header ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        firstName.isNotEmpty ? 'Hola, $firstName' : 'Bienvenido',
                        style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'BaseShop',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                ),
                // Cart button
                BlocBuilder<CartBloc, CartState>(
                  builder: (_, cartState) {
                    final count = cartState is CartLoaded ? cartState.items.length : 0;
                    return _HeaderButton(
                      icon: Icons.shopping_bag_outlined,
                      badgeCount: count,
                      onTap: () => context.go('/cart'),
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        // ── Search bar ──
        SliverToBoxAdapter(
          child: GestureDetector(
            onTap: () => context.go('/products'),
            child: Container(
              margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                children: [
                  Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 22),
                  SizedBox(width: 10),
                  Text('Buscar productos...', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
                ],
              ),
            ),
          ),
        ),

        // ── Promo banner ──
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF97316), Color(0xFFFB923C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('Ofertas', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Compra inteligente,\nahorra m\u00e1s',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => context.go('/products'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.primaryColor,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        child: const Text('Ver todo'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.local_offer_rounded, color: Colors.white, size: 40),
                ),
              ],
            ),
          ),
        ),

        // ── Categories ──
        if (state.categories.isNotEmpty) ...[
          _sectionHeader(context, 'Categor\u00edas', onSeeAll: () => context.go('/products')),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: state.categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final cat = state.categories[index];
                  final catName = cat['name']?.toString() ?? '';
                  final icons = [Icons.devices, Icons.checkroom, Icons.home_work, Icons.sports_soccer, Icons.spa];
                  final colors = [const Color(0xFFEEF2FF), const Color(0xFFFEF2F2), const Color(0xFFF0FDF4), const Color(0xFFFFF7ED), const Color(0xFFFDF2F8)];
                  final iconColors = [const Color(0xFF6366F1), const Color(0xFFEF4444), const Color(0xFF22C55E), const Color(0xFFF97316), const Color(0xFFEC4899)];
                  return GestureDetector(
                    onTap: () => context.go('/products'),
                    child: Column(
                      children: [
                        Container(
                          width: 60, height: 60,
                          decoration: BoxDecoration(
                            color: colors[index % colors.length],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(icons[index % icons.length], color: iconColors[index % iconColors.length], size: 28),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: 68,
                          child: Text(catName, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],

        // ── Featured products ──
        if (featured.isNotEmpty) ...[
          _sectionHeader(context, 'Destacados', onSeeAll: () => context.go('/products')),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 248,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: featured.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (_, i) => _ProductCard(product: featured[i], currency: _currency),
              ),
            ),
          ),
        ],

        // ── New products ──
        if (newest.isNotEmpty) ...[
          _sectionHeader(context, 'Nuevos productos', onSeeAll: () => context.go('/products')),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 248,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: newest.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (_, i) => _ProductCard(product: newest[i], currency: _currency),
              ),
            ),
          ),
        ],

        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  SliverToBoxAdapter _sectionHeader(BuildContext context, String title, {VoidCallback? onSeeAll}) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            if (onSeeAll != null)
              GestureDetector(
                onTap: onSeeAll,
                child: const Text('Ver todo', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w600, fontSize: 14)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade50,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(height: 40, width: 180, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
          const SizedBox(height: 16),
          Container(height: 48, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
          const SizedBox(height: 16),
          Container(height: 160, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20))),
          const SizedBox(height: 20),
          Row(children: List.generate(4, (_) => Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Column(children: [
              Container(width: 60, height: 60, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
              const SizedBox(height: 8),
              Container(width: 50, height: 12, color: Colors.white),
            ]),
          ))),
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _bloc.add(const LoadProducts()),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header icon button ──
class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final int badgeCount;
  final VoidCallback onTap;
  const _HeaderButton({required this.icon, this.badgeCount = 0, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Badge(
          isLabelVisible: badgeCount > 0,
          label: Text('$badgeCount', style: const TextStyle(fontSize: 10)),
          backgroundColor: AppTheme.primaryColor,
          child: Icon(icon, size: 22, color: AppTheme.textPrimary),
        ),
      ),
    );
  }
}

// ── Product card ──
class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final NumberFormat currency;
  const _ProductCard({required this.product, required this.currency});

  @override
  Widget build(BuildContext context) {
    final id = (product['_id'] ?? product['id'] ?? '').toString();
    final name = product['name']?.toString() ?? '';
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final comparePrice = (product['compare_price'] as num?)?.toDouble() ?? 0;
    final images = product['images'] as List? ?? [];
    final imageUrl = images.isNotEmpty ? images.first.toString() : '';
    final hasDiscount = comparePrice > price && comparePrice > 0;
    final discountPercent = hasDiscount ? ((comparePrice - price) / comparePrice * 100).round() : 0;

    return GestureDetector(
      onTap: () => context.push('/products/$id'),
      child: Container(
        width: 164,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: SizedBox(
                    height: 140, width: double.infinity,
                    child: imageUrl.isNotEmpty
                      ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: const Color(0xFFF3F4F6)),
                          errorWidget: (_, __, ___) => Container(color: const Color(0xFFF3F4F6), child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey)))
                      : Container(color: const Color(0xFFF3F4F6), child: const Icon(Icons.shopping_bag_outlined, size: 40, color: Colors.grey)),
                  ),
                ),
                if (hasDiscount)
                  Positioned(
                    top: 8, left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: AppTheme.errorColor, borderRadius: BorderRadius.circular(8)),
                      child: Text('-$discountPercent%', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ),
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.favorite_border_rounded, size: 18, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary, height: 1.3)),
                  const SizedBox(height: 6),
                  Text(currency.format(price), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primaryColor)),
                  if (hasDiscount)
                    Text(currency.format(comparePrice), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, decoration: TextDecoration.lineThrough)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
