import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:baseshop/features/orders/bloc/orders_event.dart';
import 'package:baseshop/features/orders/bloc/orders_state.dart';
import 'package:baseshop/features/orders/repository/orders_repository.dart';

class OrdersBloc extends Bloc<OrdersEvent, OrdersState> {
  final OrdersRepository _repository;

  OrdersBloc(this._repository) : super(const OrdersInitial()) {
    // Client events
    on<LoadMyOrders>(_onLoadMyOrders);
    on<LoadOrderDetail>(_onLoadOrderDetail);
    on<CreateOrder>(_onCreateOrder);
    // Admin events
    on<LoadAllOrders>(_onLoadAllOrders);
    on<LoadOrderStats>(_onLoadOrderStats);
    on<LoadAdminOrderDetail>(_onLoadAdminOrderDetail);
    on<UpdateOrderStatus>(_onUpdateOrderStatus);
  }

  // ── Client handlers ──

  Future<void> _onLoadMyOrders(
    LoadMyOrders event,
    Emitter<OrdersState> emit,
  ) async {
    emit(const OrdersLoading());
    try {
      final result = await _repository.getMyOrders(
        status: event.status,
        page: event.page,
      );

      final orders =
          List<Map<String, dynamic>>.from(result['data'] ?? result['orders'] ?? []);
      final total = result['total'] as int? ?? orders.length;
      final page = result['page'] as int? ?? event.page;

      emit(OrdersLoaded(orders: orders, total: total, page: page));
    } catch (e) {
      debugPrint('[OrdersBloc] LoadMyOrders error: $e');
      emit(OrdersError(message: _extractError(e)));
    }
  }

  Future<void> _onLoadOrderDetail(
    LoadOrderDetail event,
    Emitter<OrdersState> emit,
  ) async {
    emit(const OrdersLoading());
    try {
      final order = await _repository.getOrderDetail(event.orderId);
      emit(OrderDetailLoaded(order: order));
    } catch (e) {
      debugPrint('[OrdersBloc] LoadOrderDetail error: $e');
      emit(OrdersError(message: _extractError(e)));
    }
  }

  Future<void> _onCreateOrder(
    CreateOrder event,
    Emitter<OrdersState> emit,
  ) async {
    emit(const OrdersLoading());
    try {
      final order = await _repository.createOrder(
        items: event.items,
        shippingAddress: event.shippingAddress,
        paymentMethod: event.paymentMethod,
        notes: event.notes,
      );
      emit(OrderCreated(order: order));
    } catch (e) {
      debugPrint('[OrdersBloc] CreateOrder error: $e');
      emit(OrdersError(message: _extractError(e)));
    }
  }

  // ── Admin handlers ──

  Future<void> _onLoadAllOrders(
    LoadAllOrders event,
    Emitter<OrdersState> emit,
  ) async {
    emit(const OrdersLoading());
    try {
      final result = await _repository.getAllOrders(
        status: event.status,
        search: event.search,
        page: event.page,
      );

      final orders =
          List<Map<String, dynamic>>.from(result['data'] ?? result['orders'] ?? []);
      final total = result['total'] as int? ?? orders.length;
      final page = result['page'] as int? ?? event.page;

      emit(OrdersLoaded(orders: orders, total: total, page: page));
    } catch (e) {
      debugPrint('[OrdersBloc] LoadAllOrders error: $e');
      emit(OrdersError(message: _extractError(e)));
    }
  }

  Future<void> _onLoadOrderStats(
    LoadOrderStats event,
    Emitter<OrdersState> emit,
  ) async {
    try {
      final stats = await _repository.getOrderStats();
      emit(OrderStatsLoaded(stats: stats));
    } catch (e) {
      debugPrint('[OrdersBloc] LoadOrderStats error: $e');
      emit(OrdersError(message: _extractError(e)));
    }
  }

  Future<void> _onLoadAdminOrderDetail(
    LoadAdminOrderDetail event,
    Emitter<OrdersState> emit,
  ) async {
    emit(const OrdersLoading());
    try {
      final order = await _repository.getAdminOrderDetail(event.orderId);
      emit(OrderDetailLoaded(order: order));
    } catch (e) {
      debugPrint('[OrdersBloc] LoadAdminOrderDetail error: $e');
      emit(OrdersError(message: _extractError(e)));
    }
  }

  Future<void> _onUpdateOrderStatus(
    UpdateOrderStatus event,
    Emitter<OrdersState> emit,
  ) async {
    emit(const OrdersLoading());
    try {
      final order = await _repository.updateOrderStatus(
        event.orderId,
        event.status,
        note: event.note,
      );
      emit(OrderStatusUpdated(order: order));
    } catch (e) {
      debugPrint('[OrdersBloc] UpdateOrderStatus error: $e');
      emit(OrdersError(message: _extractError(e)));
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
