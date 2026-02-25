import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:baseshop/features/cart/bloc/cart_event.dart';
import 'package:baseshop/features/cart/bloc/cart_state.dart';
import 'package:baseshop/features/cart/repository/cart_repository.dart';

class CartBloc extends Bloc<CartEvent, CartState> {
  final CartRepository _repository;

  CartBloc(this._repository) : super(const CartInitial()) {
    on<LoadCart>(_onLoadCart);
    on<AddToCart>(_onAddToCart);
    on<UpdateCartItem>(_onUpdateCartItem);
    on<RemoveCartItem>(_onRemoveCartItem);
    on<ClearCart>(_onClearCart);
    on<LoadCartCount>(_onLoadCartCount);
  }

  Future<void> _onLoadCart(
    LoadCart event,
    Emitter<CartState> emit,
  ) async {
    emit(const CartLoading());
    try {
      final result = await _repository.getCart();
      final items = List<Map<String, dynamic>>.from(result['items'] ?? []);
      final subtotal = (result['subtotal'] as num?)?.toDouble() ?? 0.0;
      final itemCount = result['itemCount'] as int? ?? items.length;

      emit(CartLoaded(
        items: items,
        subtotal: subtotal,
        itemCount: itemCount,
      ));
    } catch (e) {
      debugPrint('[CartBloc] LoadCart error: $e');
      emit(CartError(message: _extractError(e)));
    }
  }

  Future<void> _onAddToCart(
    AddToCart event,
    Emitter<CartState> emit,
  ) async {
    try {
      await _repository.addItem(
        event.productId,
        event.productName,
        event.productPrice,
        event.productImage,
        event.quantity,
        selectedVariants: event.selectedVariants,
      );
      add(const LoadCart());
    } catch (e) {
      debugPrint('[CartBloc] AddToCart error: $e');
      emit(CartError(message: _extractError(e)));
    }
  }

  Future<void> _onUpdateCartItem(
    UpdateCartItem event,
    Emitter<CartState> emit,
  ) async {
    try {
      await _repository.updateItem(event.itemId, event.quantity);
      add(const LoadCart());
    } catch (e) {
      debugPrint('[CartBloc] UpdateCartItem error: $e');
      emit(CartError(message: _extractError(e)));
    }
  }

  Future<void> _onRemoveCartItem(
    RemoveCartItem event,
    Emitter<CartState> emit,
  ) async {
    try {
      await _repository.removeItem(event.itemId);
      add(const LoadCart());
    } catch (e) {
      debugPrint('[CartBloc] RemoveCartItem error: $e');
      emit(CartError(message: _extractError(e)));
    }
  }

  Future<void> _onClearCart(
    ClearCart event,
    Emitter<CartState> emit,
  ) async {
    try {
      await _repository.clearCart();
      emit(const CartLoaded(items: [], subtotal: 0.0, itemCount: 0));
    } catch (e) {
      debugPrint('[CartBloc] ClearCart error: $e');
      emit(CartError(message: _extractError(e)));
    }
  }

  Future<void> _onLoadCartCount(
    LoadCartCount event,
    Emitter<CartState> emit,
  ) async {
    try {
      final count = await _repository.getCount();
      final current = state;
      if (current is CartLoaded) {
        emit(CartLoaded(
          items: current.items,
          subtotal: current.subtotal,
          itemCount: count,
        ));
      }
    } catch (e) {
      debugPrint('[CartBloc] LoadCartCount error: $e');
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
