import 'package:baseshop/core/constants/api_constants.dart';
import 'package:baseshop/core/network/api_client.dart';

class ProductsRepository {
  final ApiClient _apiClient;

  ProductsRepository(this._apiClient);

  /// Fetch paginated products with optional filters.
  Future<Map<String, dynamic>> getProducts({
    String? categoryId,
    String? search,
    String? sortBy,
    double? minPrice,
    double? maxPrice,
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
    };

    if (categoryId != null && categoryId.isNotEmpty) {
      queryParams['category'] = categoryId;
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    if (sortBy != null && sortBy.isNotEmpty) {
      queryParams['sort'] = sortBy;
    }
    if (minPrice != null) {
      queryParams['minPrice'] = minPrice;
    }
    if (maxPrice != null) {
      queryParams['maxPrice'] = maxPrice;
    }

    final response = await _apiClient.dio.get(
      ApiConstants.products,
      queryParameters: queryParams,
    );

    final data = response.data;
    return {
      'data': data['data'] ?? data['products'] ?? [],
      'total': data['total'] ?? 0,
      'page': data['page'] ?? page,
    };
  }

  /// Fetch a single product by its ID.
  Future<Map<String, dynamic>> getProduct(String id) async {
    final response = await _apiClient.dio.get(
      '${ApiConstants.products}/$id',
    );
    final data = response.data;
    // The API may wrap it in { data: ... } or return it directly.
    if (data is Map<String, dynamic> && data.containsKey('data')) {
      return Map<String, dynamic>.from(data['data']);
    }
    return Map<String, dynamic>.from(data);
  }

  /// Fetch the category tree.
  Future<List<Map<String, dynamic>>> getCategories() async {
    final response = await _apiClient.dio.get(ApiConstants.categories);
    final data = response.data;
    final list = data is List
        ? data
        : (data is Map ? (data['data'] ?? data['categories'] ?? []) : []);
    return List<Map<String, dynamic>>.from(list);
  }

  /// Fetch products filtered by category (convenience wrapper).
  Future<Map<String, dynamic>> getProductsByCategory(
    String categoryId, {
    int page = 1,
    int limit = 20,
  }) async {
    return getProducts(categoryId: categoryId, page: page, limit: limit);
  }
}
