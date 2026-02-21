import 'package:baseshop/core/constants/api_constants.dart';
import 'package:baseshop/core/network/api_client.dart';

class ProductsRepository {
  final ApiClient _apiClient;

  ProductsRepository(this._apiClient);

  /// Fetch paginated products with optional filters.
  /// Backend returns: { products: [...], pagination: { page, limit, total, pages } }
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
      queryParams['category_id'] = categoryId;
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    if (sortBy != null && sortBy.isNotEmpty) {
      queryParams['sort_by'] = sortBy;
    }
    if (minPrice != null) {
      queryParams['min_price'] = minPrice;
    }
    if (maxPrice != null) {
      queryParams['max_price'] = maxPrice;
    }

    final response = await _apiClient.dio.get(
      ApiConstants.products,
      queryParameters: queryParams,
    );

    final data = response.data;
    final pagination = data['pagination'];
    return {
      'data': data['products'] ?? data['data'] ?? [],
      'total': pagination?['total'] ?? data['total'] ?? 0,
      'page': pagination?['page'] ?? data['page'] ?? page,
    };
  }

  /// Fetch a single product by its ID.
  /// Backend returns: { product: { ... } }
  Future<Map<String, dynamic>> getProduct(String id) async {
    final response = await _apiClient.dio.get(
      '${ApiConstants.products}/$id',
    );
    final data = response.data;
    if (data is Map<String, dynamic>) {
      if (data.containsKey('product')) {
        return Map<String, dynamic>.from(data['product']);
      }
      if (data.containsKey('data')) {
        return Map<String, dynamic>.from(data['data']);
      }
    }
    return Map<String, dynamic>.from(data);
  }

  /// Fetch the category tree.
  /// Backend returns: { categories: [...] }
  Future<List<Map<String, dynamic>>> getCategories() async {
    final response = await _apiClient.dio.get(
      '${ApiConstants.categories}?flat=true',
    );
    final data = response.data;
    final list = data is List
        ? data
        : (data is Map ? (data['categories'] ?? data['data'] ?? []) : []);
    return List<Map<String, dynamic>>.from(list);
  }

  /// Create a new product (admin).
  Future<Map<String, dynamic>> createProduct(
      Map<String, dynamic> payload) async {
    final response = await _apiClient.dio.post(
      ApiConstants.products,
      data: payload,
    );
    final data = response.data;
    return Map<String, dynamic>.from(data['product'] ?? data['data'] ?? data);
  }

  /// Update a product (admin).
  Future<Map<String, dynamic>> updateProduct(
      String id, Map<String, dynamic> payload) async {
    final response = await _apiClient.dio.put(
      '${ApiConstants.products}/$id',
      data: payload,
    );
    final data = response.data;
    return Map<String, dynamic>.from(data['product'] ?? data['data'] ?? data);
  }

  /// Delete a product (admin, soft delete).
  Future<void> deleteProduct(String id) async {
    await _apiClient.dio.delete('${ApiConstants.products}/$id');
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
