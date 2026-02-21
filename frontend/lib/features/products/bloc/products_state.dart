import 'package:equatable/equatable.dart';

abstract class ProductsState extends Equatable {
  const ProductsState();

  @override
  List<Object?> get props => [];
}

class ProductsInitial extends ProductsState {
  const ProductsInitial();
}

class ProductsLoading extends ProductsState {
  const ProductsLoading();
}

class ProductsLoaded extends ProductsState {
  final List<Map<String, dynamic>> products;
  final int total;
  final int page;
  final List<Map<String, dynamic>> categories;

  const ProductsLoaded({
    required this.products,
    required this.total,
    required this.page,
    this.categories = const [],
  });

  @override
  List<Object?> get props => [products, total, page, categories];
}

class ProductDetailLoaded extends ProductsState {
  final Map<String, dynamic> product;

  const ProductDetailLoaded({required this.product});

  @override
  List<Object?> get props => [product];
}

class CategoriesLoaded extends ProductsState {
  final List<Map<String, dynamic>> categories;

  const CategoriesLoaded({required this.categories});

  @override
  List<Object?> get props => [categories];
}

class ProductsError extends ProductsState {
  final String message;

  const ProductsError({required this.message});

  @override
  List<Object?> get props => [message];
}

class ProductActionSuccess extends ProductsState {
  final String message;
  final Map<String, dynamic>? product;

  const ProductActionSuccess({required this.message, this.product});

  @override
  List<Object?> get props => [message, product];
}
