import 'package:equatable/equatable.dart';

abstract class CartState extends Equatable {
  const CartState();

  @override
  List<Object?> get props => [];
}

class CartInitial extends CartState {
  const CartInitial();
}

class CartLoading extends CartState {
  const CartLoading();
}

class CartLoaded extends CartState {
  final List<Map<String, dynamic>> items;
  final double subtotal;
  final int itemCount;

  const CartLoaded({
    required this.items,
    required this.subtotal,
    required this.itemCount,
  });

  @override
  List<Object?> get props => [items, subtotal, itemCount];
}

class CartError extends CartState {
  final String message;

  const CartError({required this.message});

  @override
  List<Object?> get props => [message];
}
