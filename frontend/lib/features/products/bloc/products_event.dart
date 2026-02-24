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

class CreateProduct extends ProductsEvent {
  final Map<String, dynamic> payload;

  const CreateProduct({required this.payload});

  @override
  List<Object?> get props => [payload];
}

class UpdateProduct extends ProductsEvent {
  final String productId;
  final Map<String, dynamic> payload;

  const UpdateProduct({required this.productId, required this.payload});

  @override
  List<Object?> get props => [productId, payload];
}

class DeleteProduct extends ProductsEvent {
  final String productId;

  const DeleteProduct({required this.productId});

  @override
  List<Object?> get props => [productId];
}

// ── Admin events ──

class ToggleFeatured extends ProductsEvent {
  final String productId;

  const ToggleFeatured({required this.productId});

  @override
  List<Object?> get props => [productId];
}

class UpdateProductStock extends ProductsEvent {
  final String productId;
  final int stock;

  const UpdateProductStock({required this.productId, required this.stock});

  @override
  List<Object?> get props => [productId, stock];
}

class CreateCategory extends ProductsEvent {
  final Map<String, dynamic> payload;

  const CreateCategory({required this.payload});

  @override
  List<Object?> get props => [payload];
}

class UpdateCategory extends ProductsEvent {
  final String categoryId;
  final Map<String, dynamic> payload;

  const UpdateCategory({required this.categoryId, required this.payload});

  @override
  List<Object?> get props => [categoryId, payload];
}

class DeleteCategory extends ProductsEvent {
  final String categoryId;

  const DeleteCategory({required this.categoryId});

  @override
  List<Object?> get props => [categoryId];
}
