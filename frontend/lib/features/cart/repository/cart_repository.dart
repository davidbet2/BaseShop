import 'package:baseshop/core/constants/api_constants.dart';
import 'package:baseshop/core/network/api_client.dart';

class CartRepository {
  final ApiClient _apiClient;

  CartRepository(this._apiClient);

  /// Fetch the current user's cart.
  /// Backend returns: { data: { items: [...], subtotal, itemCount } }
  Future<Map<String, dynamic>> getCart() async {
    final response = await _apiClient.dio.get(ApiConstants.cart);
    final data = response.data;
    if (data is Map<String, dynamic>) {
      // Backend wraps response in { data: { ... } }
      final inner = data['data'];
      if (inner is Map<String, dynamic>) {
        return {
          'items': List<Map<String, dynamic>>.from(inner['items'] ?? []),
          'subtotal': inner['subtotal'] ?? 0,
          'itemCount': inner['itemCount'] ?? inner['item_count'] ?? 0,
        };
      }
      // Fallback: direct structure
      return {
        'items': List<Map<String, dynamic>>.from(data['items'] ?? []),
        'subtotal': data['subtotal'] ?? 0,
        'itemCount': data['itemCount'] ?? data['item_count'] ?? 0,
      };
    }
    return {'items': <Map<String, dynamic>>[], 'subtotal': 0, 'itemCount': 0};
  }

  /// Add a product to the cart.
  /// Backend expects snake_case: product_id, product_name, product_price, product_image
  Future<Map<String, dynamic>> addItem(
    String productId,
    String productName,
    double productPrice,
    String productImage,
    int quantity,
  ) async {
    final response = await _apiClient.dio.post(
      ApiConstants.cartItems,
      data: {
        'product_id': productId,
        'product_name': productName,
        'product_price': productPrice,
        'product_image': productImage,
        'quantity': quantity,
      },
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
