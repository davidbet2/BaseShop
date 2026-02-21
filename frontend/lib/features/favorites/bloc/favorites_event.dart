import 'package:equatable/equatable.dart';

abstract class FavoritesEvent extends Equatable {
  const FavoritesEvent();

  @override
  List<Object?> get props => [];
}

class LoadFavorites extends FavoritesEvent {
  final int page;

  const LoadFavorites({this.page = 1});

  @override
  List<Object?> get props => [page];
}

class AddFavorite extends FavoritesEvent {
  final String productId;
  final String productName;
  final double productPrice;
  final String productImage;

  const AddFavorite({
    required this.productId,
    required this.productName,
    required this.productPrice,
    required this.productImage,
  });

  @override
  List<Object?> get props => [productId, productName, productPrice, productImage];
}

class RemoveFavorite extends FavoritesEvent {
  final String productId;

  const RemoveFavorite({required this.productId});

  @override
  List<Object?> get props => [productId];
}

class CheckFavorite extends FavoritesEvent {
  final String productId;

  const CheckFavorite({required this.productId});

  @override
  List<Object?> get props => [productId];
}
