import 'package:equatable/equatable.dart';

abstract class PaymentsEvent extends Equatable {
  const PaymentsEvent();

  @override
  List<Object?> get props => [];
}

/// Create a payment intent for an order and get PayU form data.
class CreatePayment extends PaymentsEvent {
  final String orderId;
  final double amount;
  final String buyerEmail;
  final String buyerName;
  final String? paymentMethod;
  final String? description;

  const CreatePayment({
    required this.orderId,
    required this.amount,
    required this.buyerEmail,
    required this.buyerName,
    this.paymentMethod,
    this.description,
  });

  @override
  List<Object?> get props => [orderId, amount, buyerEmail, buyerName, paymentMethod, description];
}

/// Check current payment status for an order.
class CheckPaymentStatus extends PaymentsEvent {
  final String orderId;

  const CheckPaymentStatus(this.orderId);

  @override
  List<Object?> get props => [orderId];
}

/// Reset bloc to initial state.
class ResetPayments extends PaymentsEvent {
  const ResetPayments();
}
