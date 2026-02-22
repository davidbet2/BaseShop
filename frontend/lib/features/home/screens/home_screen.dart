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
  final PageController _bannerCtrl = PageController(viewportFraction: 0.92);
  int _bannerPage = 0;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    _bloc = getIt<ProductsBloc>()..add(const LoadProducts());
    _bannerTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_bannerCtrl.hasClients) {
        final next = (_bannerPage + 1) % 3;
        _bannerCtrl.animateToPage(next, duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
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
    // Popular = featured + discounted, deduplicated, then fill with top products
    final popularIds = <String>{};
    final popular = <Map<String, dynamic>>[];
    for (final p in [...featured, ...discounted]) {
      final id = (p['_id'] ?? p['id'] ?? '').toString();
      if (popularIds.add(id)) popular.add(p);
    }
    if (popular.length < 8) {
      for (final p in state.products) {
        final id = (p['_id'] ?? p['id'] ?? '').toString();
        if (popularIds.add(id)) popular.add(p);
        if (popular.length >= 12) break;
      }
    }

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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        firstName.isNotEmpty ? 'Hola, $firstName \u{1F44B}' : 'Bienvenido',
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

        // ── Hero Banner Carousel ──
        if (featured.isNotEmpty)
          SliverToBoxAdapter(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final screenW = constraints.maxWidth;
                final bannerH = screenW > 900 ? 240.0 : screenW > 600 ? 200.0 : 180.0;
                final count = featured.length > 3 ? 3 : featured.length;
                return Column(
                  children: [
                    const SizedBox(height: 8),
                    SizedBox(
                      height: bannerH,
                      child: PageView.builder(
                        controller: _bannerCtrl,
                        onPageChanged: (i) => setState(() => _bannerPage = i),
                        itemCount: count,
                        itemBuilder: (context, i) {
                          final p = featured[i];
                          final name = p['name']?.toString() ?? '';
                          final price = (p['price'] as num?)?.toDouble() ?? 0;
                          final comparePrice = (p['compare_price'] as num?)?.toDouble() ?? 0;
                          final images = p['images'] as List? ?? [];
                          final imageUrl = images.isNotEmpty ? images.first.toString() : '';
                          final hasDiscount = comparePrice > price && comparePrice > 0;
                          final discountPct = hasDiscount ? ((comparePrice - price) / comparePrice * 100).round() : 0;
                          final id = (p['_id'] ?? p['id'] ?? '').toString();
                          final gradients = [
                            [const Color(0xFFF97316), const Color(0xFFFB923C)],
                            [const Color(0xFF6366F1), const Color(0xFF818CF8)],
                            [const Color(0xFF059669), const Color(0xFF34D399)],
                          ];
                          final g = gradients[i % gradients.length];

                          return GestureDetector(
                            onTap: () => context.push('/products/$id'),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: g, begin: Alignment.topLeft, end: Alignment.bottomRight),
                                borderRadius: BorderRadius.circular(22),
                                boxShadow: [BoxShadow(color: g[0].withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
                              ),
                              child: Stack(
                                children: [
                                  Positioned(right: -20, top: -20, child: Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08)))),
                                  Positioned(left: -10, bottom: -30, child: Container(width: 70, height: 70, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.06)))),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          flex: 3,
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              if (hasDiscount)
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                                                  child: Text('-$discountPct% OFF', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                                                ),
                                              if (hasDiscount) const SizedBox(height: 6),
                                              Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2)),
                                              const SizedBox(height: 8),
                                              Text(_currency.format(price), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
                                              const SizedBox(height: 10),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                                                child: Text('Ver producto', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: g[0])),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          flex: 2,
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(16),
                                            child: imageUrl.isNotEmpty
                                              ? CachedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover, height: bannerH - 40,
                                                  placeholder: (_, __) => Container(color: Colors.white.withValues(alpha: 0.2)),
                                                  errorWidget: (_, __, ___) => Container(
                                                    color: Colors.white.withValues(alpha: 0.2),
                                                    child: const Icon(Icons.shopping_bag_outlined, size: 40, color: Colors.white),
                                                  ))
                                              : Container(
                                                  height: bannerH - 40,
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
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(count, (i) =>
                        AnimatedContainer(
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
                );
              },
            ),
          ),

        // ── Ofertas (horizontal scroll) ──
        if (discounted.isNotEmpty) ...[
          _sectionHeader('\u{1F525} Ofertas', onSeeAll: () => context.go('/products')),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 260,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: discounted.length > 8 ? 8 : discounted.length,
                separatorBuilder: (_, __) => const SizedBox(width: 14),
                itemBuilder: (_, i) => _ProductCard(product: discounted[i], currency: _currency, showBadge: true),
              ),
            ),
          ),
        ],

        // ── Popular products (responsive grid) ──
        _sectionHeader('Populares', onSeeAll: () => context.go('/products')),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 220, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.63,
            ),
            delegate: SliverChildBuilderDelegate(
              (_, i) => _ProductCard(product: popular[i], currency: _currency, isGrid: true),
              childCount: popular.length > 12 ? 12 : popular.length,
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 32)),
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
          Container(height: 180, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22))),
          const SizedBox(height: 24),
          Container(height: 20, width: 120, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6))),
          const SizedBox(height: 12),
          Row(children: List.generate(2, (_) => Expanded(
            child: Container(
              height: 200, margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
            ),
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
