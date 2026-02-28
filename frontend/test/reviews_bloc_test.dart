import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:baseshop/features/reviews/bloc/reviews_bloc.dart';
import 'package:baseshop/features/reviews/bloc/reviews_event.dart';
import 'package:baseshop/features/reviews/bloc/reviews_state.dart';
import 'package:baseshop/features/reviews/repository/reviews_repository.dart';

class MockReviewsRepository extends Mock implements ReviewsRepository {}

void main() {
  late MockReviewsRepository mockRepo;

  setUp(() {
    mockRepo = MockReviewsRepository();
  });

  group('ReviewsBloc', () {
    // ── LoadProductReviews ──
    group('LoadProductReviews', () {
      blocTest<ReviewsBloc, ReviewsState>(
        'emits [ReviewsLoading, ReviewsLoaded] on success',
        build: () {
          when(() => mockRepo.getProductReviews('prod-1', page: any(named: 'page')))
              .thenAnswer((_) async => {
                    'data': [
                      {'id': 'r1', 'rating': 5, 'comment': 'Great'}
                    ],
                    'total': 1,
                    'page': 1,
                  });
          when(() => mockRepo.getReviewSummary('prod-1'))
              .thenAnswer((_) async => {
                    'average': 4.5,
                    'total': 10,
                    'stars': {'5': 6, '4': 3, '3': 1},
                  });
          return ReviewsBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const LoadProductReviews('prod-1')),
        expect: () => [
          isA<ReviewsLoading>(),
          isA<ReviewsLoaded>()
              .having((s) => s.reviews.length, 'reviews count', 1)
              .having((s) => s.summary['average'], 'avg', 4.5),
        ],
      );

      blocTest<ReviewsBloc, ReviewsState>(
        'emits [ReviewsLoading, ReviewsError] on failure',
        build: () {
          when(() => mockRepo.getProductReviews(any(), page: any(named: 'page')))
              .thenThrow(Exception('Network error'));
          when(() => mockRepo.getReviewSummary(any()))
              .thenThrow(Exception('Network error'));
          return ReviewsBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const LoadProductReviews('prod-1')),
        expect: () => [
          isA<ReviewsLoading>(),
          isA<ReviewsError>(),
        ],
      );
    });

    // ── CreateReview ──
    group('CreateReview', () {
      blocTest<ReviewsBloc, ReviewsState>(
        'emits [ReviewsLoading, ReviewCreated] on success',
        build: () {
          when(() => mockRepo.createReview(any(), any(), any(), any()))
              .thenAnswer((_) async => {'id': 'new-review', 'rating': 5});
          return ReviewsBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const CreateReview(
          productId: 'prod-1',
          rating: 5,
          title: 'Excelente',
          comment: 'Muy bueno',
        )),
        expect: () => [
          isA<ReviewsLoading>(),
          isA<ReviewCreated>(),
        ],
      );

      blocTest<ReviewsBloc, ReviewsState>(
        'emits [ReviewsLoading, ReviewsError] on failure',
        build: () {
          when(() => mockRepo.createReview(any(), any(), any(), any()))
              .thenThrow(Exception('Already reviewed'));
          return ReviewsBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const CreateReview(
          productId: 'prod-1',
          rating: 4,
          title: 'Duplicada',
          comment: 'Test',
        )),
        expect: () => [
          isA<ReviewsLoading>(),
          isA<ReviewsError>(),
        ],
      );
    });

    // ── LoadMyReviews ──
    group('LoadMyReviews', () {
      blocTest<ReviewsBloc, ReviewsState>(
        'emits [ReviewsLoading, ReviewsLoaded] on success',
        build: () {
          when(() => mockRepo.getMyReviews())
              .thenAnswer((_) async => {
                    'data': [
                      {'id': 'r1', 'product_id': 'p1', 'rating': 4},
                      {'id': 'r2', 'product_id': 'p2', 'rating': 5},
                    ],
                    'total': 2,
                  });
          return ReviewsBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const LoadMyReviews()),
        expect: () => [
          isA<ReviewsLoading>(),
          isA<ReviewsLoaded>()
              .having((s) => s.reviews.length, 'count', 2),
        ],
      );

      blocTest<ReviewsBloc, ReviewsState>(
        'emits [ReviewsLoading, ReviewsError] on failure',
        build: () {
          when(() => mockRepo.getMyReviews())
              .thenThrow(Exception('Error'));
          return ReviewsBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const LoadMyReviews()),
        expect: () => [
          isA<ReviewsLoading>(),
          isA<ReviewsError>(),
        ],
      );
    });
  });
}
