import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:baseshop/core/theme/app_theme.dart';

/// Admin Store Configuration screen.
///
/// Allows the admin to tweak home-page section titles, toggle header/footer
/// visibility, and manage promotional banners. All settings are persisted
/// locally with SharedPreferences until a backend config endpoint is added.
class AdminStoreConfigScreen extends StatefulWidget {
  const AdminStoreConfigScreen({super.key});

  @override
  State<AdminStoreConfigScreen> createState() => _AdminStoreConfigScreenState();
}

class _AdminStoreConfigScreenState extends State<AdminStoreConfigScreen> {
  // ── Keys ────────────────────────────────────────────────
  static const _kFeaturedTitle = 'store_featured_title';
  static const _kFeaturedDesc = 'store_featured_desc';
  static const _kShowHeader = 'store_show_header';
  static const _kShowFooter = 'store_show_footer';
  static const _kStoreName = 'store_name';
  static const _kStoreLogo = 'store_logo_url';
  static const _kBanners = 'store_banners'; // comma-separated URLs

  // ── Controllers ─────────────────────────────────────────────
  final _featuredTitleCtrl = TextEditingController();
  final _featuredDescCtrl = TextEditingController();
  final _storeNameCtrl = TextEditingController();
  final _storeLogoCtrl = TextEditingController();
  bool _showHeader = true;
  bool _showFooter = true;
  List<String> _banners = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _featuredTitleCtrl.dispose();
    _featuredDescCtrl.dispose();
    _storeNameCtrl.dispose();
    _storeLogoCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _featuredTitleCtrl.text =
          prefs.getString(_kFeaturedTitle) ?? 'Colección destacada';
      _featuredDescCtrl.text = prefs.getString(_kFeaturedDesc) ??
          'Los productos más elegidos por nuestros clientes';
      _showHeader = prefs.getBool(_kShowHeader) ?? true;
      _showFooter = prefs.getBool(_kShowFooter) ?? true;
      _storeNameCtrl.text = prefs.getString(_kStoreName) ?? 'BaseShop';
      _storeLogoCtrl.text = prefs.getString(_kStoreLogo) ?? '';
      final bannersRaw = prefs.getString(_kBanners) ?? '';
      _banners = bannersRaw.isNotEmpty
          ? bannersRaw.split('|||').where((b) => b.isNotEmpty).toList()
          : [];
      _loading = false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kFeaturedTitle, _featuredTitleCtrl.text.trim());
    await prefs.setString(_kFeaturedDesc, _featuredDescCtrl.text.trim());
    await prefs.setBool(_kShowHeader, _showHeader);
    await prefs.setBool(_kShowFooter, _showFooter);
    await prefs.setString(_kStoreName, _storeNameCtrl.text.trim());
    await prefs.setString(_kStoreLogo, _storeLogoCtrl.text.trim());
    await prefs.setString(_kBanners, _banners.join('|||'));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuración guardada')),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración de la Tienda'),
        actions: [
          TextButton.icon(
            onPressed: _saveSettings,
            icon: const Icon(Icons.save, color: Colors.white),
            label:
                const Text('Guardar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 80 : 16, vertical: 20),
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              _buildStoreIdentityCard(),
                              const SizedBox(height: 16),
                              _buildLayoutTogglesCard(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            children: [
                              _buildHomeSectionCard(),
                              const SizedBox(height: 16),
                              _buildBannersCard(),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        _buildStoreIdentityCard(),
                        const SizedBox(height: 16),
                        _buildLayoutTogglesCard(),
                        const SizedBox(height: 16),
                        _buildHomeSectionCard(),
                        const SizedBox(height: 16),
                        _buildBannersCard(),
                        const SizedBox(height: 80),
                      ],
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.save),
        label: const Text('Guardar cambios'),
        onPressed: _saveSettings,
      ),
    );
  }

  // ── Cards ──────────────────────────────────────────────────

  Widget _card({required String title, required IconData icon, required List<Widget> children}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: AppTheme.primaryColor, size: 22),
              const SizedBox(width: 8),
              Text(title,
                  style:
                      const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ]),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildStoreIdentityCard() {
    return _card(
      title: 'Identidad de la Tienda',
      icon: Icons.store,
      children: [
        _field(_storeNameCtrl, 'Nombre de la tienda', Icons.badge_outlined),
        const SizedBox(height: 12),
        _field(_storeLogoCtrl, 'URL del logo', Icons.image_outlined),
        if (_storeLogoCtrl.text.isNotEmpty) ...[
          const SizedBox(height: 12),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                _storeLogoCtrl.text,
                height: 60,
                errorBuilder: (_, __, ___) => Container(
                  height: 60,
                  width: 60,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.broken_image),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildLayoutTogglesCard() {
    return _card(
      title: 'Layout',
      icon: Icons.view_quilt_outlined,
      children: [
        SwitchListTile(
          title: const Text('Mostrar Header'),
          subtitle: const Text('Logo y nombre en la parte superior'),
          value: _showHeader,
          activeColor: AppTheme.primaryColor,
          onChanged: (v) => setState(() => _showHeader = v),
        ),
        SwitchListTile(
          title: const Text('Mostrar Footer'),
          subtitle: const Text('Información de contacto en la parte inferior'),
          value: _showFooter,
          activeColor: AppTheme.primaryColor,
          onChanged: (v) => setState(() => _showFooter = v),
        ),
      ],
    );
  }

  Widget _buildHomeSectionCard() {
    return _card(
      title: 'Sección Destacada (Home)',
      icon: Icons.star_outline,
      children: [
        _field(_featuredTitleCtrl, 'Título de la sección', Icons.title),
        const SizedBox(height: 12),
        _field(_featuredDescCtrl, 'Descripción', Icons.notes, maxLines: 2),
        const SizedBox(height: 8),
        Text(
          'Este texto aparece encima de la grilla de productos destacados en la página de inicio.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildBannersCard() {
    return _card(
      title: 'Banners Promocionales',
      icon: Icons.photo_library_outlined,
      children: [
        if (_banners.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: Text('No hay banners configurados',
                  style: TextStyle(color: Colors.grey.shade500)),
            ),
          ),
        ..._banners.asMap().entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    entry.value,
                    width: 80,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 80,
                      height: 44,
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.broken_image, size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    entry.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      size: 20, color: AppTheme.errorColor),
                  onPressed: () {
                    setState(() => _banners.removeAt(entry.key));
                  },
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _addBannerDialog,
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: const Text('Agregar banner'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  void _addBannerDialog() {
    final urlCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agregar Banner'),
        content: TextField(
          controller: urlCtrl,
          decoration: InputDecoration(
            labelText: 'URL de la imagen',
            hintText: 'https://...',
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              final url = urlCtrl.text.trim();
              if (url.isNotEmpty) {
                setState(() => _banners.add(url));
              }
              Navigator.pop(ctx);
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    int maxLines = 1,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
