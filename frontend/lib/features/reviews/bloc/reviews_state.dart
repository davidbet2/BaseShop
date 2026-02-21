import 'package:equatable/equatable.dart';

abstract class ReviewsState extends Equatable {
  const ReviewsState();

  @override
  List<Object?> get props => [];
}

class ReviewsInitial extends ReviewsState {
  const ReviewsInitial();
}

class ReviewsLoading extends ReviewsState {
  const ReviewsLoading();
}

class ReviewsLoaded extends ReviewsState {
  final List<Map<String, dynamic>> reviews;
  final Map<String, dynamic> summary;

  const ReviewsLoaded({
    required this.reviews,
    required this.summary,
  });

  @override
  List<Object?> get props => [reviews, summary];
}

class ReviewCreated extends ReviewsState {
  const ReviewCreated();
}

class ReviewsError extends ReviewsState {
  final String message;

  const ReviewsError({required this.message});

  @override
  List<Object?> get props => [message];
}
