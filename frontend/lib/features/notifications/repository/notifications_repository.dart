import 'package:baseshop/core/constants/api_constants.dart';
import 'package:baseshop/core/network/api_client.dart';

class NotificationsRepository {
  final ApiClient _apiClient;

  NotificationsRepository(this._apiClient);

  /// Fetch user notifications with pagination.
  Future<Map<String, dynamic>> getMyNotifications({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _apiClient.dio.get(
      ApiConstants.myNotifications,
      queryParameters: {'page': page, 'limit': limit},
    );

    final data = response.data;
    return {
      'data': data['data'] ?? [],
      'unread': data['unread'] ?? 0,
      'total': data['pagination']?['total'] ?? 0,
      'page': data['pagination']?['page'] ?? page,
    };
  }

  /// Get unread notification count.
  Future<int> getUnreadCount() async {
    final response = await _apiClient.dio.get(
      ApiConstants.unreadNotificationsCount,
    );
    return response.data['unread'] ?? 0;
  }

  /// Mark all notifications as read.
  Future<void> markAllRead() async {
    await _apiClient.dio.patch(ApiConstants.readAllNotifications);
  }

  /// Delete a single notification.
  Future<void> deleteNotification(String id) async {
    await _apiClient.dio.delete('${ApiConstants.myNotifications}/$id');
  }

  /// Delete all notifications.
  Future<void> deleteAll() async {
    await _apiClient.dio.delete(ApiConstants.myNotifications);
  }
}
