import 'package:equatable/equatable.dart';

abstract class OrdersEvent extends Equatable {
  const OrdersEvent();

  @override
  List<Object?> get props => [];
}

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
