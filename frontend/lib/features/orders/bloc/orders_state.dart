import 'package:equatable/equatable.dart';

abstract class OrdersState extends Equatable {
  const OrdersState();

  @override
  List<Object?> get props => [];
}

class OrdersInitial extends OrdersState {
  const OrdersInitial();
}

class OrdersLoading extends OrdersState {
  const OrdersLoading();
}

class OrdersLoaded extends OrdersState {
  final List<Map<String, dynamic>> orders;
  final int total;
  final int page;

  const OrdersLoaded({
    required this.orders,
    required this.total,
    required this.page,
  });

  @override
  List<Object?> get props => [orders, total, page];
}

class OrderDetailLoaded extends OrdersState {
  final Map<String, dynamic> order;

  const OrderDetailLoaded({required this.order});

  @override
  List<Object?> get props => [order];
}

class OrderCreated extends OrdersState {
  final Map<String, dynamic> order;

  const OrderCreated({required this.order});

  @override
  List<Object?> get props => [order];
}

class OrdersError extends OrdersState {
  final String message;

  const OrdersError({required this.message});

  @override
  List<Object?> get props => [message];
}
