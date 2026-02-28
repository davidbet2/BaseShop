import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:baseshop/features/payments/bloc/payments_bloc.dart';
import 'package:baseshop/features/payments/bloc/payments_event.dart';
import 'package:baseshop/features/payments/bloc/payments_state.dart';
import 'package:baseshop/features/payments/repository/payments_repository.dart';

class MockPaymentsRepository extends Mock implements PaymentsRepository {}

void main() {
  late MockPaymentsRepository mockRepo;

  setUp(() {
    mockRepo = MockPaymentsRepository();
  });

  group('PaymentsBloc', () {
    // ── CreatePayment ──
    group('CreatePayment', () {
      blocTest<PaymentsBloc, PaymentsState>(
        'emits [PaymentsLoading, PaymentCreated] on success',
        build: () {
          when(() => mockRepo.createPayment(
                orderId: any(named: 'orderId'),
                amount: any(named: 'amount'),
                buyerEmail: any(named: 'buyerEmail'),
                buyerName: any(named: 'buyerName'),
                paymentMethod: any(named: 'paymentMethod'),
                description: any(named: 'description'),
              )).thenAnswer((_) async => {
                    'id': 'pay-1',
                    'status': 'pending',
                    'payu_form_data': {
                      'merchantId': '12345',
                      'accountId': '67890',
                      'referenceCode': 'REF-001',
                    },
                  });
          return PaymentsBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const CreatePayment(
          orderId: 'order-1',
          amount: 150000,
          buyerEmail: 'buyer@test.com',
          buyerName: 'Test Buyer',
          paymentMethod: 'credit_card',
        )),
        expect: () => [
          isA<PaymentsLoading>(),
          isA<PaymentCreated>()
              .having((s) => s.paymentData['id'], 'id', 'pay-1')
              .having((s) => s.payuFormData['merchantId'], 'merchant', '12345'),
        ],
      );

      blocTest<PaymentsBloc, PaymentsState>(
        'emits [PaymentsLoading, PaymentsError] on failure',
        build: () {
          when(() => mockRepo.createPayment(
                orderId: any(named: 'orderId'),
                amount: any(named: 'amount'),
                buyerEmail: any(named: 'buyerEmail'),
                buyerName: any(named: 'buyerName'),
                paymentMethod: any(named: 'paymentMethod'),
                description: any(named: 'description'),
              )).thenThrow(Exception('Error al crear el pago'));
          return PaymentsBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const CreatePayment(
          orderId: 'order-1',
          amount: 150000,
          buyerEmail: 'buyer@test.com',
          buyerName: 'Test Buyer',
        )),
        expect: () => [
          isA<PaymentsLoading>(),
          isA<PaymentsError>(),
        ],
      );
    });

    // ── CheckPaymentStatus ──
    group('CheckPaymentStatus', () {
      blocTest<PaymentsBloc, PaymentsState>(
        'emits [PaymentsLoading, PaymentStatusLoaded] on success',
        build: () {
          when(() => mockRepo.getPaymentByOrder('order-1'))
              .thenAnswer((_) async => {
                    'id': 'pay-1',
                    'status': 'approved',
                    'amount': 150000,
                  });
          return PaymentsBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const CheckPaymentStatus('order-1')),
        expect: () => [
          isA<PaymentsLoading>(),
          isA<PaymentStatusLoaded>()
              .having((s) => s.status, 'status', 'approved')
              .having((s) => s.payment['amount'], 'amount', 150000),
        ],
      );

      blocTest<PaymentsBloc, PaymentsState>(
        'emits [PaymentsLoading, PaymentsError] on failure',
        build: () {
          when(() => mockRepo.getPaymentByOrder(any()))
              .thenThrow(Exception('No se encontró pago'));
          return PaymentsBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const CheckPaymentStatus('bad-order')),
        expect: () => [
          isA<PaymentsLoading>(),
          isA<PaymentsError>(),
        ],
      );
    });

    // ── ValidatePayUResponse ──
    group('ValidatePayUResponse', () {
      blocTest<PaymentsBloc, PaymentsState>(
        'emits [PaymentsLoading, PaymentStatusLoaded] on success',
        build: () {
          when(() => mockRepo.validatePayUResponse(any()))
              .thenAnswer((_) async => {
                    'id': 'pay-1',
                    'status': 'approved',
                  });
          return PaymentsBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const ValidatePayUResponse({
          'referenceCode': 'REF-001',
          'transactionState': '4',
          'TX_VALUE': '150000',
        })),
        expect: () => [
          isA<PaymentsLoading>(),
          isA<PaymentStatusLoaded>()
              .having((s) => s.status, 'status', 'approved'),
        ],
      );

      blocTest<PaymentsBloc, PaymentsState>(
        'emits [PaymentsLoading, PaymentsError] on failure',
        build: () {
          when(() => mockRepo.validatePayUResponse(any()))
              .thenThrow(Exception('Validation failed'));
          return PaymentsBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const ValidatePayUResponse({'bad': 'data'})),
        expect: () => [
          isA<PaymentsLoading>(),
          isA<PaymentsError>(),
        ],
      );
    });

    // ── ResetPayments ──
    group('ResetPayments', () {
      blocTest<PaymentsBloc, PaymentsState>(
        'emits [PaymentsInitial] on reset',
        build: () => PaymentsBloc(mockRepo),
        seed: () => const PaymentsError('Some error'),
        act: (bloc) => bloc.add(const ResetPayments()),
        expect: () => [isA<PaymentsInitial>()],
      );
    });
  });
}
