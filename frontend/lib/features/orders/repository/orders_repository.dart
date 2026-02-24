import 'package:baseshop/core/constants/api_constants.dart';
import 'package:baseshop/core/network/api_client.dart';

class OrdersRepository {
  final ApiClient _apiClient;

  OrdersRepository(this._apiClient);

  /// Fetch the current user's orders with optional filters.
  Future<Map<String, dynamic>> getMyOrders({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
    };
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }

    final response = await _apiClient.dio.get(
      ApiConstants.myOrders,
      queryParameters: queryParams,
    );

    final data = response.data;
    return {
      'data': data['data'] ?? data['orders'] ?? [],
      'total': data['pagination']?['total'] ?? data['total'] ?? 0,
      'page': data['pagination']?['page'] ?? data['page'] ?? page,
    };
  }

  /// Fetch ALL orders (admin).
  Future<Map<String, dynamic>> getAllOrders({
    String? status,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
    };
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }

    final response = await _apiClient.dio.get(
      ApiConstants.orders,
      queryParameters: queryParams,
    );

    final data = response.data;
    return {
      'data': data['data'] ?? data['orders'] ?? [],
      'total': data['pagination']?['total'] ?? data['total'] ?? 0,
      'page': data['pagination']?['page'] ?? data['page'] ?? page,
    };
  }

  /// Fetch admin order stats summary.
  Future<Map<String, dynamic>> getOrderStats() async {
    final response = await _apiClient.dio.get(ApiConstants.orderStats);
    final data = response.data;
    return Map<String, dynamic>.from(data['data'] ?? data);
  }

  /// Fetch a single order by ID (current user's order).
  Future<Map<String, dynamic>> getOrderDetail(String orderId) async {
    final response = await _apiClient.dio.get(
      '${ApiConstants.myOrders}/$orderId',
    );
    final data = response.data;
    if (data is Map<String, dynamic> && data.containsKey('data')) {
      return Map<String, dynamic>.from(data['data']);
    }
    return Map<String, dynamic>.from(data);
  }

  /// Fetch any order detail (admin).
  Future<Map<String, dynamic>> getAdminOrderDetail(String orderId) async {
    final response = await _apiClient.dio.get(
      '${ApiConstants.orders}/$orderId',
    );
    final data = response.data;
    if (data is Map<String, dynamic> && data.containsKey('data')) {
      return Map<String, dynamic>.from(data['data']);
    }
    return Map<String, dynamic>.from(data);
  }

  /// Update order status (admin).
  Future<Map<String, dynamic>> updateOrderStatus(
    String orderId,
    String status, {
    String? note,
  }) async {
    final body = <String, dynamic>{'status': status};
    if (note != null && note.isNotEmpty) body['note'] = note;

    final response = await _apiClient.dio.patch(
      '${ApiConstants.orders}/$orderId/status',
      data: body,
    );
    final data = response.data;
    return Map<String, dynamic>.from(data['data'] ?? data);
  }

  /// Create a new order.
  Future<Map<String, dynamic>> createOrder({
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> shippingAddress,
    Map<String, dynamic>? billingAddress,
    required String paymentMethod,
    String? notes,
  }) async {
    final body = <String, dynamic>{
      'items': items,
      'shipping_address': shippingAddress,
      'payment_method': paymentMethod,
    };
    if (billingAddress != null) body['billing_address'] = billingAddress;
    if (notes != null && notes.isNotEmpty) body['notes'] = notes;

    final response = await _apiClient.dio.post(
      ApiConstants.orders,
      data: body,
    );
    final data = response.data;
    if (data is Map<String, dynamic> && data.containsKey('data')) {
      return Map<String, dynamic>.from(data['data']);
    }
    return Map<String, dynamic>.from(data);
  }
}
