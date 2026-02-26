import 'package:flutter/material.dart';
import 'package:baseshop/core/network/api_client.dart';

/// Service that reads/writes store config via the backend API.
/// Falls back to sensible defaults on network errors.
class StoreConfigService {
  final ApiClient _api;

  StoreConfigService(this._api);

  /// GET /config — public, no auth required
  Future<StoreConfig> getConfig() async {
    try {
      final response = await _api.dio.get('/config');
      final data = response.data as Map<String, dynamic>;
      return StoreConfig.fromJson(data);
    } catch (e) {
      debugPrint('[StoreConfigService] getConfig error: $e');
      // Return defaults on network error so the app still works offline
      return const StoreConfig(
        showHeader: true,
        showFooter: true,
        storeName: 'BaseShop',
        storeLogo: '',
        featuredTitle: 'Colección destacada',
        featuredDesc: 'Los productos más elegidos por nuestros clientes',
        banners: [],
        primaryColorHex: 'F97316',
        policiesContent: '',
      );
    }
  }

  /// PUT /config — admin only
  Future<StoreConfig> updateConfig({
    bool? showHeader,
    bool? showFooter,
    String? storeName,
    String? storeLogo,
    String? featuredTitle,
    String? featuredDesc,
    String? primaryColorHex,
    String? policiesContent,
    List<BannerConfig>? banners,
  }) async {
    final body = <String, dynamic>{};
    if (showHeader != null) body['show_header'] = showHeader;
    if (showFooter != null) body['show_footer'] = showFooter;
    if (storeName != null) body['store_name'] = storeName;
    if (storeLogo != null) body['store_logo'] = storeLogo;
    if (featuredTitle != null) body['featured_title'] = featuredTitle;
    if (featuredDesc != null) body['featured_desc'] = featuredDesc;
    if (primaryColorHex != null) body['primary_color_hex'] = primaryColorHex;
    if (policiesContent != null) body['policies_content'] = policiesContent;
    if (banners != null) {
      body['banners'] = banners.map((b) => b.toJson()).toList();
    }

    final response = await _api.dio.put('/config', data: body);
    final data = response.data as Map<String, dynamic>;
    return StoreConfig.fromJson(data);
  }
}

class StoreConfig {
  final bool showHeader;
  final bool showFooter;
  final String storeName;
  final String storeLogo;
  final String featuredTitle;
  final String featuredDesc;
  final List<BannerConfig> banners;
  final String primaryColorHex;
  final String policiesContent;

  const StoreConfig({
    required this.showHeader,
    required this.showFooter,
    required this.storeName,
    required this.storeLogo,
    required this.featuredTitle,
    required this.featuredDesc,
    required this.banners,
    this.primaryColorHex = 'F97316',
    this.policiesContent = '',
  });

  factory StoreConfig.fromJson(Map<String, dynamic> json) {
    final bannersRaw = json['banners'] as List? ?? [];
    return StoreConfig(
      showHeader: json['show_header'] == true,
      showFooter: json['show_footer'] == true,
      storeName: json['store_name']?.toString() ?? 'BaseShop',
      storeLogo: json['store_logo']?.toString() ?? '',
      featuredTitle: json['featured_title']?.toString() ?? 'Colección destacada',
      featuredDesc: json['featured_desc']?.toString() ?? 'Los productos más elegidos por nuestros clientes',
      primaryColorHex: json['primary_color_hex']?.toString() ?? 'F97316',      policiesContent: json['policies_content']?.toString() ?? '',      banners: bannersRaw.map((b) => BannerConfig.fromJson(b as Map<String, dynamic>)).toList(),
    );
  }

  /// Returns the primary color as a Flutter Color.
  Color get primaryColor => Color(int.parse('FF$primaryColorHex', radix: 16));
}

class BannerConfig {
  final String imagePath;
  final String? productId;
  final double? customPrice;

  const BannerConfig({
    required this.imagePath,
    this.productId,
    this.customPrice,
  });

  factory BannerConfig.fromJson(Map<String, dynamic> json) {
    return BannerConfig(
      imagePath: json['image_path']?.toString() ?? '',
      productId: json['product_id']?.toString(),
      customPrice: (json['custom_price'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'image_path': imagePath,
    'product_id': productId,
    'custom_price': customPrice,
  };

  BannerConfig copyWith({
    String? imagePath,
    String? productId,
    double? customPrice,
  }) {
    return BannerConfig(
      imagePath: imagePath ?? this.imagePath,
      productId: productId ?? this.productId,
      customPrice: customPrice ?? this.customPrice,
    );
  }
}
