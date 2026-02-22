import 'package:baseshop/core/constants/api_constants.dart';
import 'package:baseshop/core/network/api_client.dart';

class FavoritesRepository {
  final ApiClient _apiClient;

  FavoritesRepository(this._apiClient);

  /// Fetch paginated favorites for the current user.
  Future<Map<String, dynamic>> getFavorites({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _apiClient.dio.get(
      ApiConstants.favorites,
      queryParameters: {'page': page, 'limit': limit},
    );
    final data = response.data;
    return {
      'data': data['data'] ?? data['favorites'] ?? [],
      'total': data['total'] ?? 0,
      'page': data['page'] ?? page,
    };
  }

  /// Add a product to favorites.
  Future<Map<String, dynamic>> addFavorite(
    String productId,
    String productName,
    double productPrice,
    String productImage,
  ) async {
    final response = await _apiClient.dio.post(
      ApiConstants.favorites,
      data: {
        'product_id': productId,
        'product_name': productName,
        'product_price': productPrice,
        'product_image': productImage,
      },
    );
    return Map<String, dynamic>.from(response.data ?? {});
  }

  /// Remove a product from favorites.
  Future<void> removeFavorite(String productId) async {
    await _apiClient.dio.delete('${ApiConstants.favorites}/$productId');
  }

  /// Check if a product is in favorites.
  Future<bool> checkFavorite(String productId) async {
    try {
      final response = await _apiClient.dio.get(
        '${ApiConstants.favorites}/check/$productId',
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return data['isFavorite'] == true || data['is_favorite'] == true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
