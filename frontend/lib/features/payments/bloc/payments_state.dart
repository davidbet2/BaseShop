import 'package:equatable/equatable.dart';

abstract class PaymentsState extends Equatable {
  const PaymentsState();

  @override
  List<Object?> get props => [];
}

class PaymentsInitial extends PaymentsState {
  const PaymentsInitial();
}

class PaymentsLoading extends PaymentsState {
  const PaymentsLoading();
}

/// Payment intent created — contains PayU form data for redirect.
class PaymentCreated extends PaymentsState {
  final Map<String, dynamic> paymentData;
  final Map<String, dynamic> payuFormData;

  const PaymentCreated({
    required this.paymentData,
    required this.payuFormData,
  });

  @override
  List<Object?> get props => [paymentData, payuFormData];
}

/// Payment status retrieved.
class PaymentStatusLoaded extends PaymentsState {
  final Map<String, dynamic> payment;
  final String status;

  const PaymentStatusLoaded({
    required this.payment,
    required this.status,
  });

  @override
  List<Object?> get props => [payment, status];
}

class PaymentsError extends PaymentsState {
  final String message;

  const PaymentsError(this.message);

  @override
  List<Object?> get props => [message];
}
