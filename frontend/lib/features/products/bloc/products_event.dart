import 'package:equatable/equatable.dart';

abstract class ProductsEvent extends Equatable {
  const ProductsEvent();

  @override
  List<Object?> get props => [];
}

class LoadProducts extends ProductsEvent {
  final String? categoryId;
  final String? search;
  final String? sortBy;
  final double? minPrice;
  final double? maxPrice;
  final int page;

  const LoadProducts({
    this.categoryId,
    this.search,
    this.sortBy,
    this.minPrice,
    this.maxPrice,
    this.page = 1,
  });

  @override
  List<Object?> get props => [categoryId, search, sortBy, minPrice, maxPrice, page];
}

class LoadProductDetail extends ProductsEvent {
  final String productId;

  const LoadProductDetail(this.productId);

  @override
  List<Object?> get props => [productId];
}

class LoadCategories extends ProductsEvent {
  const LoadCategories();
}
