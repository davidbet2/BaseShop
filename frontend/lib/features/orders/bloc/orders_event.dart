import 'package:equatable/equatable.dart';

abstract class OrdersEvent extends Equatable {
  const OrdersEvent();

  @override
  List<Object?> get props => [];
}

// ── Client events ──

class LoadMyOrders extends OrdersEvent {
  final String? status;
  final int page;

  const LoadMyOrders({this.status, this.page = 1});

  @override
  List<Object?> get props => [status, page];
}

class LoadOrderDetail extends OrdersEvent {
  final String orderId;

  const LoadOrderDetail(this.orderId);

  @override
  List<Object?> get props => [orderId];
}

class CreateOrder extends OrdersEvent {
  final List<Map<String, dynamic>> items;
  final Map<String, dynamic> shippingAddress;
  final String paymentMethod;
  final String? notes;

  const CreateOrder({
    required this.items,
    required this.shippingAddress,
    required this.paymentMethod,
    this.notes,
  });

  @override
  List<Object?> get props => [items, shippingAddress, paymentMethod, notes];
}

// ── Admin events ──

class LoadAllOrders extends OrdersEvent {
  final String? status;
  final String? search;
  final int page;

  const LoadAllOrders({this.status, this.search, this.page = 1});

  @override
  List<Object?> get props => [status, search, page];
}

class LoadOrderStats extends OrdersEvent {
  const LoadOrderStats();
}

class LoadAdminOrderDetail extends OrdersEvent {
  final String orderId;

  const LoadAdminOrderDetail(this.orderId);

  @override
  List<Object?> get props => [orderId];
}

class UpdateOrderStatus extends OrdersEvent {
  final String orderId;
  final String status;
  final String? note;

  const UpdateOrderStatus({
    required this.orderId,
    required this.status,
    this.note,
  });

  @override
  List<Object?> get props => [orderId, status, note];
}
