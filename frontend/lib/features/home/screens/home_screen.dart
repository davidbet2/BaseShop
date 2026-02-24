import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import 'package:baseshop/core/di/injection.dart';
import 'package:baseshop/core/theme/app_theme.dart';
import 'package:baseshop/features/products/bloc/products_bloc.dart';
import 'package:baseshop/features/products/bloc/products_event.dart';
import 'package:baseshop/features/products/bloc/products_state.dart';
import 'package:baseshop/features/auth/bloc/auth_bloc.dart';
import 'package:baseshop/features/auth/bloc/auth_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final ProductsBloc _bloc;
  final _currency = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
  final PageController _heroCtrl = PageController();
  int _heroPage = 0;
  Timer? _heroTimer;

  @override
  void initState() {
    super.initState();
    _bloc = getIt<ProductsBloc>()..add(const LoadProducts());
    _heroTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (_heroCtrl.hasClients) {
        final next = (_heroPage + 1) % 3;
        _heroCtrl.animateToPage(next, duration: const Duration(milliseconds: 800), curve: Curves.easeInOut);
      }
    });
  }

  @override
  void dispose() {
    _heroTimer?.cancel();
    _heroCtrl.dispose();
    _bloc.close();
    super.dispose();
  }

  bool get _isAuthenticated => context.read<AuthBloc>().state is AuthAuthenticated;

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: BlocBuilder<ProductsBloc, ProductsState>(
          builder: (context, state) {
            if (state is ProductsLoading) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
            if (state is ProductsError) return _buildError(state.message);
            if (state is ProductsLoaded) return _buildLanding(context, state);
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildLanding(BuildContext context, ProductsLoaded state) {
    final w = MediaQuery.of(context).size.width;
    final isWide = w > 800;

    final featured = state.products.where((p) {
      final f = p['is_featured'];
      return f == true || f == 1 || f == '1';
    }).toList();

    final popular = <Map<String, dynamic>>[];
    final seen = <String>{};
    for (final p in [...featured, ...state.products]) {
      final id = (p['_id'] ?? p['id'] ?? '').toString();
      if (seen.add(id)) popular.add(p);
      if (popular.length >= 8) break;
    }

    return CustomScrollView(
      slivers: [
        // 1. HERO — Full-width cinematic banner
        SliverToBoxAdapter(child: _buildHeroSection(featured, isWide)),

        // 2. FEATURED — Curated picks grid
        if (popular.isNotEmpty) ...[
          _sectionTitle('Colección destacada', 'Los productos más elegidos por nuestros clientes'),
          SliverToBoxAdapter(child: _buildFeaturedGrid(popular, isWide)),
        ],

        // 3. FOOTER
        SliverToBoxAdapter(child: _buildFooter(isWide)),
      ],
    );
  }

  // High-quality Unsplash banner images (1920px+)
  static const _heroBanners = [
    'https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=1920&q=90&auto=format',
    'https://images.unsplash.com/photo-1607082349566-187342175e2f?w=1920&q=90&auto=format',
    'https://images.unsplash.com/photo-1483985988355-763728e1935b?w=1920&q=90&auto=format',
  ];

  // ── HERO ───────────────────────────────────────────────────
  Widget _buildHeroSection(List<Map<String, dynamic>> featured, bool isWide) {
    final heroH = isWide ? 520.0 : 420.0;
    final items = featured.take(3).toList();
    if (items.isEmpty) return _buildStaticHero(heroH, isWide);

    return SizedBox(
      height: heroH,
      child: Stack(
        children: [
          PageView.builder(
            controller: _heroCtrl,
            onPageChanged: (i) => setState(() => _heroPage = i),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final p = items[i];
              final name = p['name']?.toString() ?? '';
              final price = (p['price'] as num?)?.toDouble() ?? 0;
              final id = (p['_id'] ?? p['id'] ?? '').toString();
              final bannerUrl = _heroBanners[i % _heroBanners.length];

              return Stack(
                fit: StackFit.expand,
                children: [
                  // High-res background image from Unsplash
                  Image.network(
                    bannerUrl, fit: BoxFit.cover,
                    width: double.infinity, height: double.infinity,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)]),
                      ),
                    ),
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                            colors: [Color(0xFF1A1A2E), Color(0xFF16213E)]),
                        ),
                      );
                    },
                  ),

                  // Dark overlay for text readability
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft, end: Alignment.centerRight,
                        colors: [
                          Colors.black.withValues(alpha: 0.75),
                          Colors.black.withValues(alpha: 0.35),
                          Colors.black.withValues(alpha: 0.15),
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),

                  Positioned(
                    left: isWide ? 64 : 24, right: isWide ? 64 : 24,
                    bottom: isWide ? 80 : 60,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(20)),
                          child: const Text('DESTACADO', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
                        ),
                        const SizedBox(height: 14),
                        Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: isWide ? 40 : 28, fontWeight: FontWeight.w900, color: Colors.white, height: 1.15, letterSpacing: -0.5)),
                        const SizedBox(height: 10),
                        Text(_currency.format(price),
                          style: TextStyle(fontSize: isWide ? 26 : 22, fontWeight: FontWeight.w800, color: AppTheme.primaryColor)),
                        const SizedBox(height: 20),
                        GestureDetector(
                          onTap: () => context.push('/products/$id'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(30),
                              boxShadow: [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8))],
                            ),
                            child: const Text('Comprar ahora', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          Positioned(
            bottom: 20, left: 0, right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(items.length, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: i == _heroPage ? 28 : 8, height: 4,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  color: i == _heroPage ? AppTheme.primaryColor : Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaticHero(double h, bool isWide) {
    return Container(
      height: h,
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1A1A2E), Color(0xFF16213E)]),
      ),
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: isWide ? 64 : 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('BaseShop', style: TextStyle(fontSize: isWide ? 52 : 36, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1)),
              const SizedBox(height: 12),
              Text('Descubre productos increíbles con la mejor calidad y los mejores precios',
                textAlign: TextAlign.center, style: TextStyle(fontSize: isWide ? 18 : 15, color: Colors.white70, height: 1.5)),
              const SizedBox(height: 28),
              GestureDetector(
                onTap: () => context.go('/products'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(30)),
                  child: const Text('Explorar tienda', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── SECTION TITLE ──────────────────────────────────────────
  SliverToBoxAdapter _sectionTitle(String title, String subtitle) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 48, 24, 20),
        child: Column(
          children: [
            Text(title, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppTheme.textPrimary, letterSpacing: -0.5)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.4)),
          ],
        ),
      ),
    );
  }

  // ── FEATURED GRID ──────────────────────────────────────────
  Widget _buildFeaturedGrid(List<Map<String, dynamic>> products, bool isWide) {
    final maxItems = isWide ? 8 : 4;
    final items = products.take(maxItems).toList();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isWide ? 48 : 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cols = constraints.maxWidth > 900 ? 4 : constraints.maxWidth > 600 ? 3 : 2;
          final spacing = 14.0;
          final itemW = (constraints.maxWidth - (spacing * (cols - 1))) / cols;
          final itemH = itemW * 1.35;

          return Wrap(
            spacing: spacing, runSpacing: spacing,
            children: items.map((p) => SizedBox(
              width: itemW, height: itemH,
              child: _FeaturedProductCard(product: p, currency: _currency),
            )).toList(),
          );
        },
      ),
    );
  }

  // ── FOOTER ─────────────────────────────────────────────────
  Widget _buildFooter(bool isWide) {
    return Container(
      margin: const EdgeInsets.only(top: 56),
      padding: EdgeInsets.symmetric(vertical: 40, horizontal: isWide ? 64 : 24),
      color: const Color(0xFF111111),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: AppTheme.primaryColor, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('BaseShop', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Tu tienda online de confianza', style: TextStyle(fontSize: 14, color: Colors.white54)),
          const SizedBox(height: 24),
          const SizedBox(height: 24),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          Text('© ${DateTime.now().year} BaseShop. Todos los derechos reservados.',
            style: const TextStyle(fontSize: 12, color: Colors.white38)),
        ],
      ),
    );
  }

  Widget _footerLink(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Text(label, style: const TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500)),
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

// ═════════════════════════════════════════════════════════════
//  FEATURED PRODUCT CARD
// ═════════════════════════════════════════════════════════════
class _FeaturedProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final NumberFormat currency;
  const _FeaturedProductCard({required this.product, required this.currency});

  @override
  Widget build(BuildContext context) {
    final id = (product['_id'] ?? product['id'] ?? '').toString();
    final name = product['name']?.toString() ?? '';
    final price = (product['price'] as num?)?.toDouble() ?? 0;
    final images = product['images'] as List? ?? [];
    final img = images.isNotEmpty ? images.first.toString() : '';

    return GestureDetector(
      onTap: () => context.push('/products/$id'),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: SizedBox(
                  width: double.infinity,
                  child: img.isNotEmpty
                    ? CachedNetworkImage(imageUrl: img, fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: const Color(0xFFF5F5F5)),
                        errorWidget: (_, __, ___) => Container(color: const Color(0xFFF5F5F5), child: const Icon(Icons.image_outlined, color: Colors.grey)))
                    : Container(color: const Color(0xFFF5F5F5), child: const Icon(Icons.shopping_bag_outlined, size: 40, color: Colors.grey)),
                ),
              ),
            ),
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary, height: 1.3)),
                    const Spacer(),
                    Text(currency.format(price), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
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

