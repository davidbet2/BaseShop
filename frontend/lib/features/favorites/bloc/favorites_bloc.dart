import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:baseshop/features/favorites/bloc/favorites_event.dart';
import 'package:baseshop/features/favorites/bloc/favorites_state.dart';
import 'package:baseshop/features/favorites/repository/favorites_repository.dart';

class FavoritesBloc extends Bloc<FavoritesEvent, FavoritesState> {
  final FavoritesRepository _repository;

  /// In-memory set for quick lookup (shared across screens).
  Set<String> _favoriteIds = {};

  FavoritesBloc(this._repository) : super(const FavoritesInitial()) {
    on<LoadFavorites>(_onLoadFavorites);
    on<AddFavorite>(_onAddFavorite);
    on<RemoveFavorite>(_onRemoveFavorite);
    on<CheckFavorite>(_onCheckFavorite);
  }

  /// Expose current favorite IDs for quick checks.
  bool isFavorite(String productId) => _favoriteIds.contains(productId);

  Future<void> _onLoadFavorites(
    LoadFavorites event,
    Emitter<FavoritesState> emit,
  ) async {
    emit(const FavoritesLoading());
    try {
      final result = await _repository.getFavorites(page: event.page);
      final favorites =
          List<Map<String, dynamic>>.from(result['data'] ?? result['favorites'] ?? []);

      _favoriteIds = favorites
          .map((f) =>
              (f['productId'] ?? f['product_id'] ?? f['_id'] ?? '').toString())
          .where((id) => id.isNotEmpty)
          .toSet();

      emit(FavoritesLoaded(
        favorites: favorites,
        favoriteIds: Set<String>.from(_favoriteIds),
      ));
    } catch (e) {
      if (kDebugMode) debugPrint('[FavoritesBloc] LoadFavorites error: $e');
      emit(FavoritesError(message: _extractError(e)));
    }
  }

  Future<void> _onAddFavorite(
    AddFavorite event,
    Emitter<FavoritesState> emit,
  ) async {
    // Optimistic update
    _favoriteIds.add(event.productId);
    _emitCurrentState(emit);

    try {
      await _repository.addFavorite(
        event.productId,
        event.productName,
        event.productPrice,
        event.productImage,
      );
      // Reload full list to stay in sync
      add(const LoadFavorites());
    } catch (e) {
      if (kDebugMode) debugPrint('[FavoritesBloc] AddFavorite error: $e');
      _favoriteIds.remove(event.productId);
      emit(FavoritesError(message: _extractError(e)));
    }
  }

  Future<void> _onRemoveFavorite(
    RemoveFavorite event,
    Emitter<FavoritesState> emit,
  ) async {
    // Optimistic update
    _favoriteIds.remove(event.productId);
    _emitCurrentState(emit);

    try {
      await _repository.removeFavorite(event.productId);
      add(const LoadFavorites());
    } catch (e) {
      if (kDebugMode) debugPrint('[FavoritesBloc] RemoveFavorite error: $e');
      _favoriteIds.add(event.productId);
      emit(FavoritesError(message: _extractError(e)));
    }
  }

  Future<void> _onCheckFavorite(
    CheckFavorite event,
    Emitter<FavoritesState> emit,
  ) async {
    try {
      final isFav = await _repository.checkFavorite(event.productId);
      if (isFav) {
        _favoriteIds.add(event.productId);
      } else {
        _favoriteIds.remove(event.productId);
      }
      _emitCurrentState(emit);
    } catch (e) {
      if (kDebugMode) debugPrint('[FavoritesBloc] CheckFavorite error: $e');
    }
  }

  void _emitCurrentState(Emitter<FavoritesState> emit) {
    final current = state;
    if (current is FavoritesLoaded) {
      emit(FavoritesLoaded(
        favorites: current.favorites,
        favoriteIds: Set<String>.from(_favoriteIds),
      ));
    } else {
      emit(FavoritesLoaded(
        favorites: const [],
        favoriteIds: Set<String>.from(_favoriteIds),
      ));
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
