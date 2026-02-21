import 'package:equatable/equatable.dart';

abstract class CartEvent extends Equatable {
  const CartEvent();

  @override
  List<Object?> get props => [];
}

class LoadCart extends CartEvent {
  const LoadCart();
}

class AddToCart extends CartEvent {
  final String productId;
  final String productName;
  final double productPrice;
  final String productImage;
  final int quantity;

  const AddToCart({
    required this.productId,
    required this.productName,
    required this.productPrice,
    required this.productImage,
    this.quantity = 1,
  });

  @override
  List<Object?> get props =>
      [productId, productName, productPrice, productImage, quantity];
}

class UpdateCartItem extends CartEvent {
  final String itemId;
  final int quantity;

  const UpdateCartItem({
    required this.itemId,
    required this.quantity,
  });

  @override
  List<Object?> get props => [itemId, quantity];
}

class RemoveCartItem extends CartEvent {
  final String itemId;

  const RemoveCartItem({required this.itemId});

  @override
  List<Object?> get props => [itemId];
}

class ClearCart extends CartEvent {
  const ClearCart();
}

class LoadCartCount extends CartEvent {
  const LoadCartCount();
}
