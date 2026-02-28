import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:baseshop/features/orders/bloc/orders_bloc.dart';
import 'package:baseshop/features/orders/bloc/orders_event.dart';
import 'package:baseshop/features/orders/bloc/orders_state.dart';
import 'package:baseshop/features/orders/repository/orders_repository.dart';

class MockOrdersRepository extends Mock implements OrdersRepository {}

void main() {
  late MockOrdersRepository mockRepo;

  setUp(() {
    mockRepo = MockOrdersRepository();
  });

  group('OrdersBloc', () {
    // ── LoadMyOrders ──
    group('LoadMyOrders', () {
      blocTest<OrdersBloc, OrdersState>(
        'emits [OrdersLoading, OrdersLoaded] on success',
        build: () {
          when(() => mockRepo.getMyOrders(status: any(named: 'status'), page: any(named: 'page')))
              .thenAnswer((_) async => {
                    'data': [
                      {'id': 'order-1', 'order_number': 'ORD-001'}
                    ],
                    'total': 1,
                    'page': 1,
                  });
          return OrdersBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const LoadMyOrders()),
        expect: () => [
          isA<OrdersLoading>(),
          isA<OrdersLoaded>()
              .having((s) => s.orders.length, 'orders count', 1)
              .having((s) => s.total, 'total', 1),
        ],
      );

      blocTest<OrdersBloc, OrdersState>(
        'emits [OrdersLoading, OrdersError] on failure',
        build: () {
          when(() => mockRepo.getMyOrders(status: any(named: 'status'), page: any(named: 'page')))
              .thenThrow(Exception('Network error'));
          return OrdersBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const LoadMyOrders()),
        expect: () => [
          isA<OrdersLoading>(),
          isA<OrdersError>(),
        ],
      );
    });

    // ── LoadOrderDetail ──
    group('LoadOrderDetail', () {
      blocTest<OrdersBloc, OrdersState>(
        'emits [OrdersLoading, OrderDetailLoaded] on success',
        build: () {
          when(() => mockRepo.getOrderDetail('order-1'))
              .thenAnswer((_) async => {'id': 'order-1', 'status': 'pending'});
          return OrdersBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const LoadOrderDetail('order-1')),
        expect: () => [
          isA<OrdersLoading>(),
          isA<OrderDetailLoaded>()
              .having((s) => s.order['id'], 'order id', 'order-1'),
        ],
      );

      blocTest<OrdersBloc, OrdersState>(
        'emits [OrdersLoading, OrdersError] on failure',
        build: () {
          when(() => mockRepo.getOrderDetail(any()))
              .thenThrow(Exception('Not found'));
          return OrdersBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const LoadOrderDetail('bad-id')),
        expect: () => [
          isA<OrdersLoading>(),
          isA<OrdersError>(),
        ],
      );
    });

    // ── CreateOrder ──
    group('CreateOrder', () {
      blocTest<OrdersBloc, OrdersState>(
        'emits [OrdersLoading, OrderCreated] on success',
        build: () {
          when(() => mockRepo.createOrder(
                items: any(named: 'items'),
                shippingAddress: any(named: 'shippingAddress'),
                paymentMethod: any(named: 'paymentMethod'),
                notes: any(named: 'notes'),
              )).thenAnswer((_) async => {'id': 'new-order', 'order_number': 'ORD-100'});
          return OrdersBloc(mockRepo);
        },
        act: (bloc) => bloc.add(CreateOrder(
          items: [
            {'product_id': 'p1', 'quantity': 2, 'price': 10000}
          ],
          shippingAddress: {'address': 'Calle 1', 'city': 'Bogotá'},
          paymentMethod: 'payu',
        )),
        expect: () => [
          isA<OrdersLoading>(),
          isA<OrderCreated>()
              .having((s) => s.order['id'], 'id', 'new-order'),
        ],
      );

      blocTest<OrdersBloc, OrdersState>(
        'emits [OrdersLoading, OrdersError] on failure',
        build: () {
          when(() => mockRepo.createOrder(
                items: any(named: 'items'),
                shippingAddress: any(named: 'shippingAddress'),
                paymentMethod: any(named: 'paymentMethod'),
                notes: any(named: 'notes'),
              )).thenThrow(Exception('Error creating'));
          return OrdersBloc(mockRepo);
        },
        act: (bloc) => bloc.add(CreateOrder(
          items: [
            {'product_id': 'p1', 'quantity': 1, 'price': 5000}
          ],
          shippingAddress: {'address': 'Test'},
          paymentMethod: 'payu',
        )),
        expect: () => [
          isA<OrdersLoading>(),
          isA<OrdersError>(),
        ],
      );
    });

    // ── Admin: LoadAllOrders ──
    group('LoadAllOrders', () {
      blocTest<OrdersBloc, OrdersState>(
        'emits [OrdersLoading, OrdersLoaded] on success',
        build: () {
          when(() => mockRepo.getAllOrders(
                status: any(named: 'status'),
                search: any(named: 'search'),
                page: any(named: 'page'),
              )).thenAnswer((_) async => {
                    'data': [
                      {'id': 'o1'},
                      {'id': 'o2'}
                    ],
                    'total': 2,
                    'page': 1,
                  });
          return OrdersBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const LoadAllOrders()),
        expect: () => [
          isA<OrdersLoading>(),
          isA<OrdersLoaded>().having((s) => s.orders.length, 'count', 2),
        ],
      );
    });

    // ── Admin: LoadOrderStats ──
    group('LoadOrderStats', () {
      blocTest<OrdersBloc, OrdersState>(
        'emits [OrderStatsLoaded] on success',
        build: () {
          when(() => mockRepo.getOrderStats())
              .thenAnswer((_) async => {'total_orders': 50, 'pending': 10});
          return OrdersBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const LoadOrderStats()),
        expect: () => [
          isA<OrderStatsLoaded>()
              .having((s) => s.stats['total_orders'], 'total', 50),
        ],
      );

      blocTest<OrdersBloc, OrdersState>(
        'emits [OrdersError] on failure',
        build: () {
          when(() => mockRepo.getOrderStats())
              .thenThrow(Exception('Stats error'));
          return OrdersBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const LoadOrderStats()),
        expect: () => [isA<OrdersError>()],
      );
    });

    // ── Admin: UpdateOrderStatus ──
    group('UpdateOrderStatus', () {
      blocTest<OrdersBloc, OrdersState>(
        'emits [OrdersLoading, OrderStatusUpdated] on success',
        build: () {
          when(() => mockRepo.updateOrderStatus(any(), any(), note: any(named: 'note')))
              .thenAnswer((_) async => {'id': 'o1', 'status': 'shipped'});
          return OrdersBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const UpdateOrderStatus(
          orderId: 'o1',
          status: 'shipped',
          note: 'Enviado hoy',
        )),
        expect: () => [
          isA<OrdersLoading>(),
          isA<OrderStatusUpdated>()
              .having((s) => s.order['status'], 'status', 'shipped'),
        ],
      );
    });
  });
}
