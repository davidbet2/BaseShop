import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:baseshop/features/reviews/bloc/reviews_event.dart';
import 'package:baseshop/features/reviews/bloc/reviews_state.dart';
import 'package:baseshop/features/reviews/repository/reviews_repository.dart';

class ReviewsBloc extends Bloc<ReviewsEvent, ReviewsState> {
  final ReviewsRepository _repository;

  ReviewsBloc(this._repository) : super(const ReviewsInitial()) {
    on<LoadProductReviews>(_onLoadProductReviews);
    on<CreateReview>(_onCreateReview);
    on<LoadMyReviews>(_onLoadMyReviews);
  }

  Future<void> _onLoadProductReviews(
    LoadProductReviews event,
    Emitter<ReviewsState> emit,
  ) async {
    emit(const ReviewsLoading());
    try {
      final results = await Future.wait([
        _repository.getProductReviews(event.productId, page: event.page),
        _repository.getReviewSummary(event.productId),
      ]);

      final reviewsResult = results[0] as Map<String, dynamic>;
      final summary = results[1] as Map<String, dynamic>;

      final reviews = List<Map<String, dynamic>>.from(
        reviewsResult['data'] ?? reviewsResult['reviews'] ?? [],
      );

      emit(ReviewsLoaded(reviews: reviews, summary: summary));
    } catch (e) {
      if (kDebugMode) debugPrint('[ReviewsBloc] LoadProductReviews error: $e');
      emit(ReviewsError(message: _extractError(e)));
    }
  }

  Future<void> _onCreateReview(
    CreateReview event,
    Emitter<ReviewsState> emit,
  ) async {
    emit(const ReviewsLoading());
    try {
      await _repository.createReview(
        event.productId,
        event.rating,
        event.title,
        event.comment,
      );
      emit(const ReviewCreated());
    } catch (e) {
      if (kDebugMode) debugPrint('[ReviewsBloc] CreateReview error: $e');
      emit(ReviewsError(message: _extractError(e)));
    }
  }

  Future<void> _onLoadMyReviews(
    LoadMyReviews event,
    Emitter<ReviewsState> emit,
  ) async {
    emit(const ReviewsLoading());
    try {
      final result = await _repository.getMyReviews();
      final reviews = List<Map<String, dynamic>>.from(
        result['data'] ?? result['reviews'] ?? [],
      );

      emit(ReviewsLoaded(reviews: reviews, summary: const {}));
    } catch (e) {
      if (kDebugMode) debugPrint('[ReviewsBloc] LoadMyReviews error: $e');
      emit(ReviewsError(message: _extractError(e)));
    }
  }

  String _extractError(dynamic e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        return data['message']?.toString() ??
            data['error']?.toString() ??
            'Error de conexión';
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return 'Tiempo de espera agotado. Verifica tu conexión.';
      }
      return 'Error de conexión con el servidor';
    }
    return e.toString();
  }
}
