import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:baseshop/features/payments/bloc/payments_event.dart';
import 'package:baseshop/features/payments/bloc/payments_state.dart';
import 'package:baseshop/features/payments/repository/payments_repository.dart';

class PaymentsBloc extends Bloc<PaymentsEvent, PaymentsState> {
  final PaymentsRepository repository;

  PaymentsBloc(this.repository) : super(const PaymentsInitial()) {
    on<CreatePayment>(_onCreatePayment);
    on<CheckPaymentStatus>(_onCheckPaymentStatus);
    on<ValidatePayUResponse>(_onValidatePayUResponse);
    on<ResetPayments>(_onReset);
  }

  Future<void> _onCreatePayment(
    CreatePayment event,
    Emitter<PaymentsState> emit,
  ) async {
    emit(const PaymentsLoading());
    try {
      final data = await repository.createPayment(
        orderId: event.orderId,
        amount: event.amount,
        buyerEmail: event.buyerEmail,
        buyerName: event.buyerName,
        paymentMethod: event.paymentMethod,
        description: event.description,
      );

      final payuFormData = Map<String, dynamic>.from(data['payu_form_data'] ?? {});

      emit(PaymentCreated(
        paymentData: data,
        payuFormData: payuFormData,
      ));
    } on Exception catch (e) {
      emit(PaymentsError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onCheckPaymentStatus(
    CheckPaymentStatus event,
    Emitter<PaymentsState> emit,
  ) async {
    emit(const PaymentsLoading());
    try {
      final data = await repository.getPaymentByOrder(event.orderId);
      final status = (data['status'] ?? 'pending').toString();

      emit(PaymentStatusLoaded(
        payment: data,
        status: status,
      ));
    } on Exception catch (e) {
      emit(PaymentsError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  Future<void> _onValidatePayUResponse(
    ValidatePayUResponse event,
    Emitter<PaymentsState> emit,
  ) async {
    emit(const PaymentsLoading());
    try {
      final data = await repository.validatePayUResponse(event.params);
      final status = (data['status'] ?? 'pending').toString();

      emit(PaymentStatusLoaded(
        payment: data,
        status: status,
      ));
    } on Exception catch (e) {
      emit(PaymentsError(e.toString().replaceFirst('Exception: ', '')));
    }
  }

  void _onReset(ResetPayments event, Emitter<PaymentsState> emit) {
    emit(const PaymentsInitial());
  }
}
