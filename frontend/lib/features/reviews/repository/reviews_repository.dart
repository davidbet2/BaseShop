import 'package:baseshop/core/constants/api_constants.dart';
import 'package:baseshop/core/network/api_client.dart';

class ReviewsRepository {
  final ApiClient _apiClient;

  ReviewsRepository(this._apiClient);

  /// Fetch reviews for a specific product.
  Future<Map<String, dynamic>> getProductReviews(
    String productId, {
    int page = 1,
    int limit = 10,
  }) async {
    final response = await _apiClient.dio.get(
      '${ApiConstants.reviews}/product/$productId',
      queryParameters: {'page': page, 'limit': limit},
    );
    final data = response.data;
    return {
      'data': data['data'] ?? data['reviews'] ?? [],
      'total': data['total'] ?? 0,
      'page': data['page'] ?? page,
    };
  }

  /// Fetch review summary (average, total, star distribution) for a product.
  Future<Map<String, dynamic>> getReviewSummary(String productId) async {
    try {
      final response = await _apiClient.dio.get(
        '${ApiConstants.reviews}/product/$productId/summary',
      );
      final data = response.data;
      if (data is Map<String, dynamic>) {
        return {
          'average': (data['average'] as num?)?.toDouble() ?? 0.0,
          'total': data['total'] ?? 0,
          'stars': data['stars'] ?? data['distribution'] ?? {},
        };
      }
      return {'average': 0.0, 'total': 0, 'stars': {}};
    } catch (_) {
      return {'average': 0.0, 'total': 0, 'stars': {}};
    }
  }

  /// Create a review for a product.
  Future<Map<String, dynamic>> createReview(
    String productId,
    int rating,
    String title,
    String comment,
  ) async {
    final response = await _apiClient.dio.post(
      ApiConstants.reviews,
      data: {
        'productId': productId,
        'rating': rating,
        'title': title,
        'comment': comment,
      },
    );
    return Map<String, dynamic>.from(response.data ?? {});
  }

  /// Fetch the current user's reviews.
  Future<Map<String, dynamic>> getMyReviews() async {
    final response = await _apiClient.dio.get(ApiConstants.myReviews);
    final data = response.data;
    return {
      'data': data['data'] ?? data['reviews'] ?? [],
      'total': data['total'] ?? 0,
    };
  }
}
