import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';

import 'package:baseshop/core/di/injection.dart';
import 'package:baseshop/core/theme/app_theme.dart';
import 'package:baseshop/core/services/store_config_service.dart';
import 'package:baseshop/core/cubits/store_config_cubit.dart';
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
  final PageController _heroCtrl = PageController();
  int _heroPage = 0;
  Timer? _heroTimer;

  @override
  void initState() {
    super.initState();
    _bloc = getIt<ProductsBloc>()..add(const LoadProducts());
    // Reload config on each mount so admin changes are always reflected
    getIt<StoreConfigCubit>().loadConfig();
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
        body: BlocBuilder<StoreConfigCubit, StoreConfigState>(
          bloc: getIt<StoreConfigCubit>(),
          builder: (context, configState) {
            final config = configState is StoreConfigLoaded ? configState.config : null;
            final primary = config?.primaryColor ?? AppTheme.defaultPrimary;
            return BlocBuilder<ProductsBloc, ProductsState>(
              builder: (context, state) {
                if (state is ProductsLoading) return Center(child: CircularProgressIndicator(color: primary));
                if (state is ProductsError) return _buildError(state.message);
                if (state is ProductsLoaded) return _buildLanding(context, state, config, primary);
                return const SizedBox.shrink();
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildLanding(BuildContext context, ProductsLoaded state, StoreConfig? config, Color primary) {
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

    // Use config banners if available, otherwise fall back to Unsplash
    final configBanners = config?.banners ?? [];
    final storeName = config?.storeName ?? 'BaseShop';
    final featuredTitle = config?.featuredTitle ?? 'Colección destacada';
    final featuredDesc = config?.featuredDesc ?? 'Los productos más elegidos por nuestros clientes';

    return CustomScrollView(
      slivers: [
        // 0. HEADER — store identity bar (always visible)
        SliverToBoxAdapter(child: _buildHeader(config, isWide, primary)),

        // 1. HERO — Full-width cinematic banner
        SliverToBoxAdapter(child: _buildHeroSection(featured, isWide, configBanners, primary)),

        // 2. FEATURED — Curated picks grid
        if (popular.isNotEmpty) ...[
          _sectionTitle(featuredTitle, featuredDesc),
          SliverToBoxAdapter(child: _buildFeaturedGrid(popular, isWide)),
        ],

        // 3. FOOTER (always visible)
        SliverToBoxAdapter(child: _buildFooter(isWide, storeName, config?.storeLogo, primary)),
      ],
    );
  }

  // ── HEADER ─────────────────────────────────────────────────
  Widget _buildHeader(StoreConfig? config, bool isWide, Color primary) {
    final storeName = config?.storeName ?? 'BaseShop';
    final logoPath = config?.storeLogo ?? '';
    final authState = context.watch<AuthBloc>().state;
    final isAuthenticated = authState is AuthAuthenticated;
    final isAdmin = isAuthenticated &&
        (authState as AuthAuthenticated).user['role']?.toString().toLowerCase() == 'admin';

    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: isWide ? 48 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          // Logo — click navigates to home (user) or dashboard (admin)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => context.go(isAdmin ? '/admin/dashboard' : '/home'),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (logoPath.isNotEmpty) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildLogoImage(logoPath, 36, primary),
                    ),
                    const SizedBox(width: 10),
                  ] else ...[
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Text(storeName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                ],
              ),
            ),
          ),

          // Web navigation links (only on wide/web screens)
          if (isWide) ...[
            const Spacer(),
            if (!isAdmin) ...[
              _headerNavLink('Inicio', Icons.home_outlined, '/home', primary),
              const SizedBox(width: 6),
              _headerNavLink('Tienda', Icons.storefront_outlined, '/products', primary),
            ],
            if (isAuthenticated && !isAdmin) ...[
              const SizedBox(width: 6),
              _headerNavLink('Carrito', Icons.shopping_bag_outlined, '/cart', primary, showCartBadge: true),
              const SizedBox(width: 6),
              _headerNavLink('Pedidos', Icons.receipt_outlined, '/orders', primary),
            ],
            if (isAdmin) ...[
              const SizedBox(width: 6),
              _headerNavLink('Panel', Icons.dashboard_outlined, '/admin/dashboard', primary),
              const SizedBox(width: 6),
              _headerNavLink('Productos', Icons.inventory_2_outlined, '/admin/products', primary),
              const SizedBox(width: 6),
              _headerNavLink('Pedidos', Icons.receipt_outlined, '/admin/orders', primary),
              const SizedBox(width: 6),
              _headerNavLink('Config', Icons.settings_outlined, '/admin/config', primary),
              const SizedBox(width: 6),
              _headerNavLink('Políticas', Icons.policy_outlined, '/admin/policies', primary),
            ],
            if (!isAdmin) ...[
              const SizedBox(width: 6),
              _headerNavLink('Políticas', Icons.policy_outlined, '/policies', primary),
            ],

            const SizedBox(width: 6),
            if (isAuthenticated)
              _headerNavLink('Perfil', Icons.person_outline_rounded, '/profile', primary)
            else
              _headerNavLink('Ingresar', Icons.login_rounded, '/login', primary),
          ],
        ],
      ),
    );
  }

  Widget _headerNavLink(String label, IconData icon, String path, Color primary, {bool showCartBadge = false}) {
    final location = GoRouterState.of(context).matchedLocation;
    final isActive = location.startsWith(path);

    Widget child = Text(
      label,
      style: TextStyle(
        fontSize: 15,
        fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
        color: isActive ? primary : AppTheme.textSecondary,
        letterSpacing: 0.2,
      ),
    );

    if (showCartBadge) {
      child = BlocBuilder<CartBloc, CartState>(
        builder: (_, cartState) {
          final count = cartState is CartLoaded ? cartState.items.length : 0;
          return Badge(
            isLabelVisible: count > 0,
            label: Text('$count', style: const TextStyle(fontSize: 10)),
            backgroundColor: primary,
            child: child,
          );
        },
      );
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: () => context.go(path),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? primary.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: child,
        ),
      ),
    );
  }

  // High-quality Unsplash banner images (1920px+)
  static const _heroBanners = [
    'https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=1920&q=90&auto=format',
    'https://images.unsplash.com/photo-1607082349566-187342175e2f?w=1920&q=90&auto=format',
    'https://images.unsplash.com/photo-1483985988355-763728e1935b?w=1920&q=90&auto=format',
  ];

  // ── HERO ───────────────────────────────────────────────────
  Widget _buildHeroSection(List<Map<String, dynamic>> featured, bool isWide, List<BannerConfig> configBanners, Color primary) {
    final heroH = isWide ? 520.0 : 420.0;
    final items = featured.take(3).toList();
    if (items.isEmpty) return _buildStaticHero(heroH, isWide, primary);

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
              // Use config banners if available, else fallback to Unsplash
              final bannerUrl = (configBanners.isNotEmpty && i < configBanners.length)
                  ? configBanners[i].imagePath
                  : _heroBanners[i % _heroBanners.length];

              return Stack(
                fit: StackFit.expand,
                children: [
                  // High-res background image (config or Unsplash)
                  _buildBannerImage(
                    bannerUrl, fit: BoxFit.cover,
                    width: double.infinity, height: double.infinity,
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
                          decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(20)),
                          child: const Text('DESTACADO', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
                        ),
                        const SizedBox(height: 14),
                        Text(name, maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: isWide ? 40 : 28, fontWeight: FontWeight.w900, color: Colors.white, height: 1.15, letterSpacing: -0.5)),
                        const SizedBox(height: 10),
                        Text(_currency.format(price),
                          style: TextStyle(fontSize: isWide ? 26 : 22, fontWeight: FontWeight.w800, color: primary)),
                        const SizedBox(height: 20),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () => context.push('/products/$id'),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                              decoration: BoxDecoration(
                                color: primary, borderRadius: BorderRadius.circular(30),
                                boxShadow: [BoxShadow(color: primary.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8))],
                              ),
                              child: const Text('Comprar ahora', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                            ),
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
                  color: i == _heroPage ? primary : Colors.white.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaticHero(double h, bool isWide, Color primary) {
    final configCubit = getIt<StoreConfigCubit>();
    final cubitState = configCubit.state;
    final storeName = cubitState is StoreConfigLoaded ? cubitState.config.storeName : 'BaseShop';
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
              Text(storeName, style: TextStyle(fontSize: isWide ? 52 : 36, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1)),
              const SizedBox(height: 12),
              Text('Descubre productos increíbles con la mejor calidad y los mejores precios',
                textAlign: TextAlign.center, style: TextStyle(fontSize: isWide ? 18 : 15, color: Colors.white70, height: 1.5)),
              const SizedBox(height: 28),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => context.go('/products'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(30)),
                    child: const Text('Explorar tienda', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
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
  Widget _buildFooter(bool isWide, String storeName, String? logoPath, Color primary) {
    return Container(
      margin: const EdgeInsets.only(top: 56),
      padding: EdgeInsets.symmetric(vertical: 40, horizontal: isWide ? 64 : 24),
      color: const Color(0xFF111111),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (logoPath != null && logoPath.isNotEmpty) ...[               
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildLogoImage(logoPath, 40, primary),
                ),
              ] else ...[              
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 20),
                ),
              ],
              const SizedBox(width: 12),
              Text(storeName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Tu tienda online de confianza', style: TextStyle(fontSize: 14, color: Colors.white54)),
          const SizedBox(height: 24),
          const SizedBox(height: 24),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.1)),
          const SizedBox(height: 16),
          Text('© ${DateTime.now().year} $storeName. Todos los derechos reservados.',
            style: const TextStyle(fontSize: 12, color: Colors.white38)),
        ],
      ),
    );
  }

  Widget _footerLink(String label, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Text(label, style: const TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500)),
      ),
    );
  }

  /// Renders a logo image – supports local file paths and network URLs.
  Widget _buildLogoImage(String path, double size, Color primary) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(path, width: size, height: size, fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _defaultLogoIcon(size, primary));
    }
    if (!kIsWeb) {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(file, width: size, height: size, fit: BoxFit.contain);
      }
    }
    return _defaultLogoIcon(size, primary);
  }

  Widget _defaultLogoIcon(double size, Color primary) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(size * 0.3)),
      child: Icon(Icons.shopping_bag_rounded, color: Colors.white, size: size * 0.5),
    );
  }

  /// Renders a banner image – supports local file paths and network URLs.
  Widget _buildBannerImage(String url, {BoxFit fit = BoxFit.cover, double? width, double? height}) {
    if (!kIsWeb && !url.startsWith('http://') && !url.startsWith('https://')) {
      final file = File(url);
      if (file.existsSync()) {
        return Image.file(file, fit: fit, width: width, height: height);
      }
    }
    return Image.network(
      url, fit: fit, width: width, height: height,
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

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
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
      ),
    );
  }
}

