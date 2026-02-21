import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:baseshop/features/products/bloc/products_event.dart';
import 'package:baseshop/features/products/bloc/products_state.dart';
import 'package:baseshop/features/products/repository/products_repository.dart';

class ProductsBloc extends Bloc<ProductsEvent, ProductsState> {
  final ProductsRepository _repository;

  ProductsBloc(this._repository) : super(const ProductsInitial()) {
    on<LoadProducts>(_onLoadProducts);
    on<LoadProductDetail>(_onLoadProductDetail);
    on<LoadCategories>(_onLoadCategories);
  }

  Future<void> _onLoadProducts(
    LoadProducts event,
    Emitter<ProductsState> emit,
  ) async {
    emit(const ProductsLoading());
    try {
      final result = await _repository.getProducts(
        categoryId: event.categoryId,
        search: event.search,
        sortBy: event.sortBy,
        minPrice: event.minPrice,
        maxPrice: event.maxPrice,
        page: event.page,
      );

      final products =
          List<Map<String, dynamic>>.from(result['data'] ?? []);
      final total = result['total'] as int? ?? 0;
      final page = result['page'] as int? ?? event.page;

      // Try loading categories alongside products
      List<Map<String, dynamic>> categories = [];
      try {
        categories = await _repository.getCategories();
      } catch (_) {
        debugPrint('[ProductsBloc] Categories load skipped');
      }

      emit(ProductsLoaded(
        products: products,
        total: total,
        page: page,
        categories: categories,
      ));
    } catch (e) {
      debugPrint('[ProductsBloc] LoadProducts error: $e');
      emit(ProductsError(message: _extractError(e)));
    }
  }

  Future<void> _onLoadProductDetail(
    LoadProductDetail event,
    Emitter<ProductsState> emit,
  ) async {
    emit(const ProductsLoading());
    try {
      final product = await _repository.getProduct(event.productId);
      emit(ProductDetailLoaded(product: product));
    } catch (e) {
      debugPrint('[ProductsBloc] LoadProductDetail error: $e');
      emit(ProductsError(message: _extractError(e)));
    }
  }

  Future<void> _onLoadCategories(
    LoadCategories event,
    Emitter<ProductsState> emit,
  ) async {
    try {
      final categories = await _repository.getCategories();
      emit(CategoriesLoaded(categories: categories));
    } catch (e) {
      debugPrint('[ProductsBloc] LoadCategories error: $e');
      emit(ProductsError(message: _extractError(e)));
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
