import 'package:equatable/equatable.dart';

abstract class ReviewsEvent extends Equatable {
  const ReviewsEvent();

  @override
  List<Object?> get props => [];
}

class LoadProductReviews extends ReviewsEvent {
  final String productId;
  final int page;

  const LoadProductReviews(this.productId, {this.page = 1});

  @override
  List<Object?> get props => [productId, page];
}

class CreateReview extends ReviewsEvent {
  final String productId;
  final int rating;
  final String title;
  final String comment;

  const CreateReview({
    required this.productId,
    required this.rating,
    required this.title,
    required this.comment,
  });

  @override
  List<Object?> get props => [productId, rating, title, comment];
}

class LoadMyReviews extends ReviewsEvent {
  const LoadMyReviews();
}
