import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:baseshop/core/constants/api_constants.dart';
import 'package:baseshop/core/network/api_client.dart';

class CartRepository {
  final ApiClient _apiClient;

  CartRepository(this._apiClient);

  /// Fetch the current user's cart.
  /// Backend returns: { data: { items: [...], subtotal, itemCount } }
  /// Enriches items with product images when product_image is missing.
  Future<Map<String, dynamic>> getCart() async {
    final response = await _apiClient.dio.get(ApiConstants.cart);
    final data = response.data;
    List<Map<String, dynamic>> items = [];
    num subtotal = 0;
    int itemCount = 0;

    if (data is Map<String, dynamic>) {
      final inner = data['data'];
      if (inner is Map<String, dynamic>) {
        items = List<Map<String, dynamic>>.from(inner['items'] ?? []);
        subtotal = inner['subtotal'] ?? 0;
        itemCount = inner['itemCount'] ?? inner['item_count'] ?? 0;
      } else {
        items = List<Map<String, dynamic>>.from(data['items'] ?? []);
        subtotal = data['subtotal'] ?? 0;
        itemCount = data['itemCount'] ?? data['item_count'] ?? 0;
      }
    }

    // Enrich items that have empty product_image
    await _enrichItemImages(items);

    return {'items': items, 'subtotal': subtotal, 'itemCount': itemCount};
  }

  /// For cart items missing product_image, fetch the product detail to get the image.
  Future<void> _enrichItemImages(List<Map<String, dynamic>> items) async {
    final missingIds = <String>{};
    for (final item in items) {
      final img = (item['product_image'] ?? '').toString();
      if (img.isEmpty) {
        final pid = (item['product_id'] ?? '').toString();
        if (pid.isNotEmpty) missingIds.add(pid);
      }
    }
    if (missingIds.isEmpty) return;

    // Fetch each missing product's image
    final imageMap = <String, String>{};
    for (final pid in missingIds) {
      try {
        final resp = await _apiClient.dio.get('${ApiConstants.products}/$pid');
        final pData = resp.data;
        final product = pData is Map<String, dynamic>
            ? (pData['data'] is Map<String, dynamic> ? pData['data'] : pData)
            : null;
        if (product != null) {
          final images = product['images'];
          if (images is List && images.isNotEmpty) {
            imageMap[pid] = images.first.toString();
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('[CartRepo] Failed to fetch image for $pid: $e');
      }
    }

    // Apply found images
    for (final item in items) {
      final img = (item['product_image'] ?? '').toString();
      if (img.isEmpty) {
        final pid = (item['product_id'] ?? '').toString();
        if (imageMap.containsKey(pid)) {
          item['product_image'] = imageMap[pid];
        }
      }
    }
  }

  /// Add a product to the cart.
  /// Backend expects snake_case: product_id, product_name, product_price, product_image
  Future<Map<String, dynamic>> addItem(
    String productId,
    String productName,
    double productPrice,
    String productImage,
    int quantity, {
    Map<String, String>? selectedVariants,
  }) async {
    final data = <String, dynamic>{
      'product_id': productId,
      'product_name': productName,
      'product_price': productPrice,
      'product_image': productImage,
      'quantity': quantity,
    };
    if (selectedVariants != null && selectedVariants.isNotEmpty) {
      data['selected_variants'] = selectedVariants;
    }
    final response = await _apiClient.dio.post(
      ApiConstants.cartItems,
      data: data,
    );
    return Map<String, dynamic>.from(response.data ?? {});
  }

  /// Update cart item quantity.
  Future<Map<String, dynamic>> updateItem(String itemId, int quantity) async {
    final response = await _apiClient.dio.put(
      '${ApiConstants.cartItems}/$itemId',
      data: {'quantity': quantity},
    );
    return Map<String, dynamic>.from(response.data ?? {});
  }

  /// Remove a single item from the cart.
  Future<void> removeItem(String itemId) async {
    await _apiClient.dio.delete('${ApiConstants.cartItems}/$itemId');
  }

  /// Clear the entire cart.
  Future<void> clearCart() async {
    await _apiClient.dio.delete(ApiConstants.cart);
  }

  /// Get the cart item count (for badge).
  /// Backend returns: { data: { count: N } }
  Future<int> getCount() async {
    final response = await _apiClient.dio.get(ApiConstants.cartCount);
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final inner = data['data'];
      if (inner is Map<String, dynamic>) {
        return inner['count'] as int? ?? 0;
      }
      return data['count'] as int? ?? 0;
    }
    return 0;
  }
}
