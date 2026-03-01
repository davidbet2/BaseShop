import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;
import 'package:baseshop/core/constants/api_constants.dart';
import 'package:baseshop/core/network/api_client.dart';

class OrdersRepository {
  final ApiClient _apiClient;

  OrdersRepository(this._apiClient);

  /// Enrich order items that have empty product_image by fetching from products API.
  Future<void> _enrichOrderImages(List<dynamic> orders) async {
    // Collect all product IDs missing images across all orders
    final missingIds = <String>{};
    for (final order in orders) {
      if (order is! Map<String, dynamic>) continue;
      final items = order['items'];
      if (items is! List) continue;
      for (final item in items) {
        if (item is! Map<String, dynamic>) continue;
        final img = (item['product_image'] ?? item['productImage'] ?? '').toString();
        if (img.isEmpty) {
          final pid = (item['product_id'] ?? item['productId'] ?? '').toString();
          if (pid.isNotEmpty) missingIds.add(pid);
        }
      }
    }
    if (missingIds.isEmpty) return;

    // Fetch images
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
        if (kDebugMode) debugPrint('[OrdersRepo] Failed to fetch image for $pid: $e');
      }
    }

    // Apply found images
    for (final order in orders) {
      if (order is! Map<String, dynamic>) continue;
      final items = order['items'];
      if (items is! List) continue;
      for (final item in items) {
        if (item is! Map<String, dynamic>) continue;
        final img = (item['product_image'] ?? item['productImage'] ?? '').toString();
        if (img.isEmpty) {
          final pid = (item['product_id'] ?? item['productId'] ?? '').toString();
          if (imageMap.containsKey(pid)) {
            item['product_image'] = imageMap[pid];
          }
        }
      }
    }
  }

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
    final ordersList = data['data'] ?? data['orders'] ?? [];
    await _enrichOrderImages(ordersList is List ? ordersList : []);
    return {
      'data': ordersList,
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
    final ordersList = data['data'] ?? data['orders'] ?? [];
    await _enrichOrderImages(ordersList is List ? ordersList : []);
    return {
      'data': ordersList,
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
    final order = data is Map<String, dynamic> && data.containsKey('data')
        ? Map<String, dynamic>.from(data['data'])
        : Map<String, dynamic>.from(data);
    await _enrichOrderImages([order]);
    return order;
  }

  /// Fetch any order detail (admin).
  Future<Map<String, dynamic>> getAdminOrderDetail(String orderId) async {
    final response = await _apiClient.dio.get(
      '${ApiConstants.orders}/$orderId',
    );
    final data = response.data;
    final order = data is Map<String, dynamic> && data.containsKey('data')
        ? Map<String, dynamic>.from(data['data'])
        : Map<String, dynamic>.from(data);
    await _enrichOrderImages([order]);
    return order;
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
