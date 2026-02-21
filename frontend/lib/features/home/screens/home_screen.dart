import 'dart:async';
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
  final PageController _bannerCtrl = PageController();
  int _bannerPage = 0;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    _bloc = getIt<ProductsBloc>()..add(const LoadProducts());
    _bannerTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_bannerCtrl.hasClients) {
        final next = (_bannerPage + 1) % 3;
        _bannerCtrl.animateToPage(next, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
      }
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _bannerCtrl.dispose();
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        backgroundColor: const Color(0xFFFAFAFA),
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
    final featured = state.products.where((p) {
      final f = p['is_featured'];
      return f == true || f == 1 || f == '1';
    }).toList();
    final discounted = state.products.where((p) {
      final cp = (p['compare_price'] as num?)?.toDouble() ?? 0;
      final pr = (p['price'] as num?)?.toDouble() ?? 0;
      return cp > pr && cp > 0;
    }).toList();
    final newest = state.products.take(10).toList();
    final authState = context.watch<AuthBloc>().state;
    final firstName = authState is AuthAuthenticated
        ? (authState.user['firstName'] ?? authState.user['first_name'] ?? '').toString()
        : '';

    return CustomScrollView(
      slivers: [
        // ── Header ──
        SliverToBoxAdapter(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        firstName.isNotEmpty ? 'Hola, $firstName \u{1F44B}' : 'Descubre',
                        style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 2),
                      const Text('BaseShop', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                    ],
                  ),
                ),
                BlocBuilder<CartBloc, CartState>(
                  builder: (_, cartState) {
                    final count = cartState is CartLoaded ? cartState.items.length : 0;
                    return _HeaderButton(icon: Icons.shopping_bag_outlined, badgeCount: count, onTap: () => context.go('/cart'));
                  },
                ),
                const SizedBox(width: 10),
                _HeaderButton(icon: Icons.notifications_outlined, badgeCount: 0, onTap: () {}),
              ],
            ),
          ),
        ),

        // ── Search bar ──
        SliverToBoxAdapter(
          child: GestureDetector(
            onTap: () => context.go('/products'),
            child: Container(
              margin: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(16)),
              child: const Row(
                children: [
                  Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 22),
                  SizedBox(width: 10),
                  Text('Buscar productos, marcas...', style: TextStyle(color: AppTheme.textSecondary, fontSize: 15)),
                ],
              ),
            ),
          ),
        ),

        // ── Hero Banner Carousel (featured products with images) ──
        if (featured.isNotEmpty)
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 14),
                SizedBox(
                  height: 200,
                  child: PageView.builder(
                    controller: _bannerCtrl,
                    onPageChanged: (i) => setState(() => _bannerPage = i),
                    itemCount: featured.length > 3 ? 3 : featured.length,
                    itemBuilder: (context, i) {
                      final p = featured[i];
                      final name = p['name']?.toString() ?? '';
                      final shortDesc = (p['short_description'] ?? '').toString();
                      final price = (p['price'] as num?)?.toDouble() ?? 0;
                      final comparePrice = (p['compare_price'] as num?)?.toDouble() ?? 0;
                      final images = p['images'] as List? ?? [];
                      final imageUrl = images.isNotEmpty ? images.first.toString() : '';
                      final hasDiscount = comparePrice > price && comparePrice > 0;
                      final discountPct = hasDiscount ? ((comparePrice - price) / comparePrice * 100).round() : 0;
                      final id = (p['_id'] ?? p['id'] ?? '').toString();
                      final bannerColors = [
                        [const Color(0xFFF97316), const Color(0xFFFB923C)],
                        [const Color(0xFF6366F1), const Color(0xFF818CF8)],
                        [const Color(0xFF059669), const Color(0xFF34D399)],
                      ];
                      final colors = bannerColors[i % bannerColors.length];

                      return GestureDetector(
                        onTap: () => context.push('/products/$id'),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Stack(
                            children: [
                              // Decorative circles
                              Positioned(right: -20, top: -20, child: Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.1)))),
                              Positioned(right: 40, bottom: -30, child: Container(width: 80, height: 80, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08)))),

                              Padding(
                                padding: const EdgeInsets.all(20),
                                child: Row(
                                  children: [
                                    // Text side
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          if (hasDiscount)
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(20)),
                                              child: Text('-$discountPct% OFF', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                                            ),
                                          if (hasDiscount) const SizedBox(height: 8),
                                          Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2)),
                                          const SizedBox(height: 4),
                                          if (shortDesc.isNotEmpty)
                                            Text(shortDesc, maxLines: 1, overflow: TextOverflow.ellipsis,
                                              style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85))),
                                          const SizedBox(height: 10),
                                          Text(_currency.format(price), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Product image
                                    Expanded(
                                      flex: 2,
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: imageUrl.isNotEmpty
                                          ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover, height: 140,
                                              placeholder: (_, __) => Container(color: Colors.white.withValues(alpha: 0.2)),
                                              errorWidget: (_, __, ___) => Container(
                                                color: Colors.white.withValues(alpha: 0.2),
                                                child: const Icon(Icons.shopping_bag_outlined, size: 40, color: Colors.white),
                                              ))
                                          : Container(
                                              height: 140,
                                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
                                              child: const Icon(Icons.shopping_bag_outlined, size: 40, color: Colors.white),
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Page indicators
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    featured.length > 3 ? 3 : featured.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: i == _bannerPage ? 24 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: i == _bannerPage ? AppTheme.primaryColor : const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

        // ── Categories ──
        if (state.categories.isNotEmpty) ...[
          _sectionHeader('Categor\u00edas', onSeeAll: () => context.go('/products')),
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
                  final catId = cat['id']?.toString() ?? '';
                  final icons = [Icons.devices_rounded, Icons.checkroom_rounded, Icons.home_rounded, Icons.sports_soccer_rounded, Icons.spa_rounded];
                  final colors = [const Color(0xFFEEF2FF), const Color(0xFFFEF2F2), const Color(0xFFF0FDF4), const Color(0xFFFFF7ED), const Color(0xFFFDF2F8)];
                  final iconColors = [const Color(0xFF6366F1), const Color(0xFFEF4444), const Color(0xFF22C55E), const Color(0xFFF97316), const Color(0xFFEC4899)];
                  return GestureDetector(
                    onTap: () => context.go('/products'),
                    child: Column(
                      children: [
                        Container(
                          width: 60, height: 60,
                          decoration: BoxDecoration(color: colors[index % colors.length], borderRadius: BorderRadius.circular(18)),
                          child: Icon(icons[index % icons.length], color: iconColors[index % iconColors.length], size: 26),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: 68,
                          child: Text(catName, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],

        // ── Flash Deals (discounted products) ──
        if (discounted.isNotEmpty) ...[
          _sectionHeader('\u{26A1} Ofertas del d\u00eda', onSeeAll: () => context.go('/products')),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 260,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: discounted.length > 10 ? 10 : discounted.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (_, i) => _ProductCard(product: discounted[i], currency: _currency, showBadge: true),
              ),
            ),
          ),
        ],

        // ── Featured ──
        if (featured.isNotEmpty) ...[
          _sectionHeader('Productos estrella', onSeeAll: () => context.go('/products')),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 260,
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

        // ── New products grid ──
        if (newest.isNotEmpty) ...[
          _sectionHeader('Reci\u00e9n llegados', onSeeAll: () => context.go('/products')),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.63,
              ),
              delegate: SliverChildBuilderDelegate(
                (_, i) => _ProductCard(product: newest[i], currency: _currency, isGrid: true),
                childCount: newest.length > 6 ? 6 : newest.length,
              ),
            ),
          ),
        ],

        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  SliverToBoxAdapter _sectionHeader(String title, {VoidCallback? onSeeAll}) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
            if (onSeeAll != null)
              GestureDetector(
                onTap: onSeeAll,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                  child: const Text('Ver todo', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w600, fontSize: 13)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200, highlightColor: Colors.grey.shade50,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(height: 40, width: 180, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8))),
          const SizedBox(height: 16),
          Container(height: 48, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16))),
          const SizedBox(height: 16),
          Container(height: 200, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20))),
          const SizedBox(height: 20),
          Row(children: List.generate(4, (_) => Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Column(children: [
              Container(width: 60, height: 60, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18))),
              const SizedBox(height: 8), Container(width: 50, height: 12, color: Colors.white),
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
            ElevatedButton.icon(onPressed: () => _bloc.add(const LoadProducts()), icon: const Icon(Icons.refresh_rounded), label: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

// ── Header Button ──
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
        decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(14)),
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

// ── Product Card ──
class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final NumberFormat currency;
  final bool showBadge;
  final bool isGrid;
  const _ProductCard({required this.product, required this.currency, this.showBadge = false, this.isGrid = false});

  @override
  Widget build(BuildContext context) {
    final id = (product['_id'] ?? product['id'] ?? '').toString();
    final name = product['name']?.toString() ?? '';
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final comparePrice = (product['compare_price'] as num?)?.toDouble() ?? 0;
    final images = product['images'] as List? ?? [];
    final imageUrl = images.isNotEmpty ? images.first.toString() : '';
    final hasDiscount = comparePrice > price && comparePrice > 0;
    final discountPct = hasDiscount ? ((comparePrice - price) / comparePrice * 100).round() : 0;

    return GestureDetector(
      onTap: () => context.push('/products/$id'),
      child: Container(
        width: isGrid ? null : 168,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
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
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: SizedBox(
                      width: double.infinity,
                      child: imageUrl.isNotEmpty
                        ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover,
                            placeholder: (_, __) => Container(color: const Color(0xFFF3F4F6)),
                            errorWidget: (_, __, ___) => Container(color: const Color(0xFFF3F4F6), child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey)))
                        : Container(color: const Color(0xFFF3F4F6), child: const Icon(Icons.shopping_bag_outlined, size: 40, color: Colors.grey)),
                    ),
                  ),
                  if (hasDiscount && showBadge)
                    Positioned(
                      top: 8, left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: AppTheme.errorColor, borderRadius: BorderRadius.circular(8)),
                        child: Text('-$discountPct%', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.favorite_border_rounded, size: 16, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            // Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary, height: 1.3)),
                    const Spacer(),
                    if (hasDiscount)
                      Text(currency.format(comparePrice),
                        style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, decoration: TextDecoration.lineThrough)),
                    Text(currency.format(price), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primaryColor)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
