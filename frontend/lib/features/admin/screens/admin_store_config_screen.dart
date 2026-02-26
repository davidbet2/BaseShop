import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart' as dio_pkg;

import 'package:baseshop/core/network/api_client.dart';

import 'package:baseshop/core/di/injection.dart';
import 'package:baseshop/core/theme/app_theme.dart';
import 'package:baseshop/core/services/store_config_service.dart';
import 'package:baseshop/core/cubits/store_config_cubit.dart';
import 'package:baseshop/features/products/bloc/products_bloc.dart';
import 'package:baseshop/features/products/bloc/products_event.dart';
import 'package:baseshop/features/products/bloc/products_state.dart';

/// Admin Store Configuration screen.
///
/// Uses [StoreConfigCubit] for state management. Supports image upload
/// from device for logo and banners (via image_picker).
class AdminStoreConfigScreen extends StatefulWidget {
  const AdminStoreConfigScreen({super.key});

  @override
  State<AdminStoreConfigScreen> createState() => _AdminStoreConfigScreenState();
}

class _AdminStoreConfigScreenState extends State<AdminStoreConfigScreen> {
  late final StoreConfigCubit _cubit;
  late final ProductsBloc _productsBloc;
  final _picker = ImagePicker();

  // ── Controllers ─────────────────────────────────────────────
  final _featuredTitleCtrl = TextEditingController();
  final _featuredDescCtrl = TextEditingController();
  final _storeNameCtrl = TextEditingController();
  String _logoPath = '';
  bool _showHeader = true;
  bool _showFooter = true;
  List<BannerConfig> _banners = [];
  String _primaryColorHex = 'F97316';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cubit = getIt<StoreConfigCubit>();
    _productsBloc = getIt<ProductsBloc>()..add(const LoadProducts());
    _loadFromCubit();
  }

  @override
  void dispose() {
    _featuredTitleCtrl.dispose();
    _featuredDescCtrl.dispose();
    _storeNameCtrl.dispose();
    _productsBloc.close();
    super.dispose();
  }

  Future<void> _loadFromCubit() async {
    // If cubit already has data (from cache or prior load), populate immediately
    final currentState = _cubit.state;
    if (currentState is StoreConfigLoaded) {
      _applyConfig(currentState.config);
    }
    // Still refresh from API in background
    await _cubit.loadConfig();
    final state = _cubit.state;
    if (state is StoreConfigLoaded) {
      _applyConfig(state.config);
    } else if (_loading) {
      setState(() => _loading = false);
    }
  }

  void _applyConfig(StoreConfig c) {
    if (!mounted) return;
    setState(() {
      _storeNameCtrl.text = c.storeName;
      _logoPath = c.storeLogo;
      _featuredTitleCtrl.text = c.featuredTitle;
      _featuredDescCtrl.text = c.featuredDesc;
      _showHeader = c.showHeader;
      _showFooter = c.showFooter;
      _banners = List<BannerConfig>.from(c.banners);
      _primaryColorHex = c.primaryColorHex;
      _loading = false;
    });
  }

  Future<void> _save() async {
    await _cubit.updateConfig(
      storeName: _storeNameCtrl.text.trim(),
      storeLogo: _logoPath,
      featuredTitle: _featuredTitleCtrl.text.trim(),
      featuredDesc: _featuredDescCtrl.text.trim(),
      showHeader: _showHeader,
      showFooter: _showFooter,
      primaryColorHex: _primaryColorHex,
      banners: _banners,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuración guardada')),
      );
    }
  }

  /// Upload an image file to the backend and return its URL.
  Future<String?> _uploadImage(XFile xfile) async {
    try {
      final apiClient = getIt<ApiClient>();

      dio_pkg.MultipartFile multipartFile;
      if (kIsWeb) {
        final bytes = await xfile.readAsBytes();
        multipartFile = dio_pkg.MultipartFile.fromBytes(bytes, filename: xfile.name);
      } else {
        multipartFile = await dio_pkg.MultipartFile.fromFile(xfile.path, filename: xfile.name);
      }

      final formData = dio_pkg.FormData.fromMap({'image': multipartFile});
      final response = await apiClient.dio.post('/products/upload', data: formData);

      if (response.statusCode == 200 && response.data['url'] != null) {
        String url = response.data['url'].toString();
        // Gateway origin without /api (uploads are served at /uploads, not /api/uploads)
        final gatewayOrigin = apiClient.dio.options.baseUrl.replaceAll(RegExp(r'/api/?$'), '');
        if (url.contains(':3003')) {
          url = url.replaceFirst(RegExp(r'http://[^:]+:3003'), gatewayOrigin);
        }
        return url;
      }
      return null;
    } catch (e) {
      debugPrint('Upload error: $e');
      return null;
    }
  }

  Future<void> _pickLogo() async {
    final xfile = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 512, imageQuality: 85);
    if (xfile == null) return;
    final url = await _uploadImage(xfile);
    if (url != null) {
      setState(() => _logoPath = url);
    }
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 800;

    return BlocProvider.value(
      value: _productsBloc,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Configuración de la Tienda'),
          actions: [
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save, color: Colors.white),
              label: const Text('Guardar', style: TextStyle(color: Colors.white)),
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
                            child: Column(children: [
                              _buildStoreIdentityCard(),
                              const SizedBox(height: 16),
                              _buildPrimaryColorCard(),
                            ]),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(children: [
                              _buildHomeSectionCard(),
                              const SizedBox(height: 16),
                              _buildBannersCard(),
                            ]),
                          ),
                        ],
                      )
                    : Column(children: [
                        _buildStoreIdentityCard(),
                        const SizedBox(height: 16),
                        _buildPrimaryColorCard(),
                        const SizedBox(height: 16),
                        _buildHomeSectionCard(),
                        const SizedBox(height: 16),
                        _buildBannersCard(),
                        const SizedBox(height: 80),
                      ]),
              ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: _currentColor,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.save),
          label: const Text('Guardar cambios'),
          onPressed: _save,
        ),
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
              Icon(icon, color: _currentColor, size: 22),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
        const SizedBox(height: 16),
        const Text('Logo de la tienda', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: _buildLogoPreview(56),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickLogo,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Subir logo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _currentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  if (_logoPath.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => setState(() => _logoPath = ''),
                      child: Text('Quitar logo', style: TextStyle(fontSize: 12, color: AppTheme.errorColor)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLogoPreview(double size) {
    if (_logoPath.isEmpty) {
      return Container(
        width: size, height: size,
        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.store, color: Colors.grey),
      );
    }
    if (_logoPath.startsWith('http://') || _logoPath.startsWith('https://')) {
      return Image.network(_logoPath, width: size, height: size, fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Container(
          width: size, height: size, color: Colors.grey.shade200,
          child: const Icon(Icons.broken_image),
        ),
      );
    }
    if (!kIsWeb) {
      final file = File(_logoPath);
      if (file.existsSync()) {
        return Image.file(file, width: size, height: size, fit: BoxFit.contain);
      }
    }
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
      child: const Icon(Icons.broken_image, color: Colors.grey),
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
          activeColor: _currentColor,
          onChanged: (v) => setState(() => _showHeader = v),
        ),
        SwitchListTile(
          title: const Text('Mostrar Footer'),
          subtitle: const Text('Información de contacto en la parte inferior'),
          value: _showFooter,
          activeColor: _currentColor,
          onChanged: (v) => setState(() => _showFooter = v),
        ),
      ],
    );
  }

  Color get _currentColor => Color(int.parse('FF$_primaryColorHex', radix: 16));

  // ── Brand Color Preset palette ─────────────────────────────
  static const _brandPresets = <String, Color>{
    'Naranja': Color(0xFFF97316),
    'Azul': Color(0xFF3B82F6),
    'Verde': Color(0xFF22C55E),
    'Rojo': Color(0xFFEF4444),
    'Violeta': Color(0xFF8B5CF6),
    'Rosa': Color(0xFFEC4899),
    'Cyan': Color(0xFF06B6D4),
    'Ámbar': Color(0xFFF59E0B),
    'Esmeralda': Color(0xFF10B981),
    'Índigo': Color(0xFF6366F1),
    'Fucsia': Color(0xFFD946EF),
    'Lima': Color(0xFF84CC16),
    'Teal': Color(0xFF14B8A6),
    'Cielo': Color(0xFF0EA5E9),
    'Slate': Color(0xFF64748B),
    'Zinc': Color(0xFF71717A),
  };

  Widget _buildPrimaryColorCard() {
    final hexCtrl = TextEditingController(text: _primaryColorHex);
    return _card(
      title: 'Color Principal (Marca)',
      icon: Icons.palette_outlined,
      children: [
        // Current color preview
        Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: _currentColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Color actual', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('#$_primaryColorHex', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontFamily: 'monospace')),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Presets de marca', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8, runSpacing: 8,
          children: _brandPresets.entries.map((entry) {
            final hexStr = entry.value.value.toRadixString(16).substring(2).toUpperCase();
            final isSelected = hexStr == _primaryColorHex.toUpperCase();
            return Tooltip(
              message: entry.key,
              child: GestureDetector(
                onTap: () => setState(() => _primaryColorHex = hexStr),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: entry.value,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? Colors.black87 : Colors.grey.shade300,
                      width: isSelected ? 3 : 1,
                    ),
                    boxShadow: isSelected
                        ? [BoxShadow(color: entry.value.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 2))]
                        : null,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        // Custom hex input
        Row(
          children: [
            const Text('#', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(width: 4),
            SizedBox(
              width: 120,
              child: TextField(
                controller: hexCtrl,
                maxLength: 6,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'F97316',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onSubmitted: (v) {
                  final hex = v.trim().replaceAll('#', '');
                  if (hex.length == 6 && RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(hex)) {
                    setState(() => _primaryColorHex = hex.toUpperCase());
                  }
                },
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                final hex = hexCtrl.text.trim().replaceAll('#', '');
                if (hex.length == 6 && RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(hex)) {
                  setState(() => _primaryColorHex = hex.toUpperCase());
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _currentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Aplicar'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Este color se aplica a botones, enlaces y elementos de marca en toda la tienda.',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
          final banner = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: _buildBannerThumbnail(banner.imagePath, 80, 48),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        banner.imagePath.split('/').last,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      if (banner.productId != null)
                        Text('Producto: ${banner.productId}',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      if (banner.customPrice != null)
                        Text('Precio: \$${banner.customPrice!.toStringAsFixed(0)}',
                            style: TextStyle(fontSize: 11, color: _currentColor)),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit_outlined, size: 20, color: _currentColor),
                  onPressed: () => _editBannerDialog(entry.key),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 20, color: AppTheme.errorColor),
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
            backgroundColor: _currentColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildBannerThumbnail(String path, double w, double h) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(path, width: w, height: h, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: w, height: h, color: Colors.grey.shade200,
          child: const Icon(Icons.broken_image, size: 18),
        ),
      );
    }
    if (!kIsWeb) {
      final file = File(path);
      if (file.existsSync()) {
        return Image.file(file, width: w, height: h, fit: BoxFit.cover);
      }
    }
    return Container(
      width: w, height: h, color: Colors.grey.shade200,
      child: const Icon(Icons.broken_image, size: 18),
    );
  }

  // ── Banner dialog with image upload + product + price ──────

  void _addBannerDialog() {
    final urlCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    String? selectedProductId;
    String? pickedImagePath;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, ss) {
            return AlertDialog(
              title: const Text('Agregar Banner'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Image source
                    if (pickedImagePath != null)
                      SizedBox(
                        width: 300,
                        height: 120,
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: _buildBannerThumbnail(pickedImagePath!, 300, 120),
                            ),
                            Positioned(
                              top: 4, right: 4,
                              child: GestureDetector(
                                onTap: () => ss(() => pickedImagePath = null),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.upload_file, size: 18),
                            label: const Text('Subir imagen'),
                            onPressed: () async {
                              final xfile = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1920, imageQuality: 80);
                              if (xfile == null) return;
                              final url = await _uploadImage(xfile);
                              if (url != null) {
                                ss(() {
                                  pickedImagePath = url;
                                  urlCtrl.clear();
                                });
                              }
                            },
                          ),
                        ),
                      ]),
                    const SizedBox(height: 12),
                    if (pickedImagePath == null)
                      TextField(
                        controller: urlCtrl,
                        decoration: InputDecoration(
                          labelText: 'O pegar URL de imagen',
                          hintText: 'https://...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    const SizedBox(height: 12),
                    // Product selector
                    BlocBuilder<ProductsBloc, ProductsState>(
                      bloc: _productsBloc,
                      builder: (_, state) {
                        if (state is! ProductsLoaded) return const SizedBox.shrink();
                        return DropdownButtonFormField<String>(
                          value: selectedProductId,
                          decoration: InputDecoration(
                            labelText: 'Vincular producto (opcional)',
                            prefixIcon: const Icon(Icons.link),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: [
                            const DropdownMenuItem<String>(value: null, child: Text('Ninguno')),
                            ...state.products.map((p) {
                              final id = (p['_id'] ?? p['id'] ?? '').toString();
                              final name = p['name']?.toString() ?? '';
                              return DropdownMenuItem(value: id, child: Text(name, overflow: TextOverflow.ellipsis));
                            }),
                          ],
                          onChanged: (v) => ss(() => selectedProductId = v),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Precio personalizado (opcional)',
                        prefixIcon: const Icon(Icons.attach_money),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () {
                    final imagePath = pickedImagePath ?? urlCtrl.text.trim();
                    if (imagePath.isEmpty) return;
                    final banner = BannerConfig(
                      imagePath: imagePath,
                      productId: selectedProductId,
                      customPrice: double.tryParse(priceCtrl.text),
                    );
                    setState(() => _banners.add(banner));
                    Navigator.pop(ctx);
                  },
                  child: const Text('Agregar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Edit banner dialog ─────────────────────────────────────

  void _editBannerDialog(int index) {
    final banner = _banners[index];
    final urlCtrl = TextEditingController();
    final priceCtrl = TextEditingController(
        text: banner.customPrice?.toStringAsFixed(0) ?? '');
    String? selectedProductId = banner.productId;
    String? pickedImagePath = banner.imagePath;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, ss) {
            return AlertDialog(
              title: const Text('Editar Banner'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Current image preview
                    if (pickedImagePath != null && pickedImagePath!.isNotEmpty)
                      SizedBox(
                        width: 300,
                        height: 120,
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: _buildBannerThumbnail(pickedImagePath!, 300, 120),
                            ),
                            Positioned(
                              top: 4, right: 4,
                              child: GestureDetector(
                                onTap: () => ss(() => pickedImagePath = null),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Row(children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.upload_file, size: 18),
                            label: const Text('Subir imagen'),
                            onPressed: () async {
                              final xfile = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1920, imageQuality: 80);
                              if (xfile == null) return;
                              final url = await _uploadImage(xfile);
                              if (url != null) {
                                ss(() {
                                  pickedImagePath = url;
                                  urlCtrl.clear();
                                });
                              }
                            },
                          ),
                        ),
                      ]),
                    const SizedBox(height: 12),
                    if (pickedImagePath == null || pickedImagePath!.isEmpty)
                      TextField(
                        controller: urlCtrl,
                        decoration: InputDecoration(
                          labelText: 'O pegar URL de imagen',
                          hintText: 'https://...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    const SizedBox(height: 12),
                    // Product selector
                    BlocBuilder<ProductsBloc, ProductsState>(
                      bloc: _productsBloc,
                      builder: (_, state) {
                        if (state is! ProductsLoaded) return const SizedBox.shrink();
                        return DropdownButtonFormField<String>(
                          value: selectedProductId,
                          decoration: InputDecoration(
                            labelText: 'Vincular producto (opcional)',
                            prefixIcon: const Icon(Icons.link),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: [
                            const DropdownMenuItem<String>(value: null, child: Text('Ninguno')),
                            ...state.products.map((p) {
                              final id = (p['_id'] ?? p['id'] ?? '').toString();
                              final name = p['name']?.toString() ?? '';
                              return DropdownMenuItem(value: id, child: Text(name, overflow: TextOverflow.ellipsis));
                            }),
                          ],
                          onChanged: (v) => ss(() => selectedProductId = v),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Precio personalizado (opcional)',
                        prefixIcon: const Icon(Icons.attach_money),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () {
                    final imagePath = pickedImagePath ?? urlCtrl.text.trim();
                    if (imagePath.isEmpty) return;
                    final updated = BannerConfig(
                      imagePath: imagePath,
                      productId: selectedProductId,
                      customPrice: double.tryParse(priceCtrl.text),
                    );
                    setState(() => _banners[index] = updated);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
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
