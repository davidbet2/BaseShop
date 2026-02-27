import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:baseshop/features/cart/bloc/cart_bloc.dart';
import 'package:baseshop/features/cart/bloc/cart_event.dart';
import 'package:baseshop/features/cart/bloc/cart_state.dart';
import 'package:baseshop/features/cart/repository/cart_repository.dart';

class MockCartRepository extends Mock implements CartRepository {}

void main() {
  late MockCartRepository mockRepo;

  setUp(() {
    mockRepo = MockCartRepository();
  });

  group('CartBloc', () {
    // ── LoadCart ──
    group('LoadCart', () {
      blocTest<CartBloc, CartState>(
        'emits [CartLoading, CartLoaded] on successful load',
        build: () {
          when(() => mockRepo.getCart()).thenAnswer((_) async => {
                'items': [
                  {'id': '1', 'product_name': 'Laptop', 'quantity': 2, 'product_price': 5000.0}
                ],
                'subtotal': 10000.0,
                'itemCount': 2,
              });
          return CartBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const LoadCart()),
        expect: () => [
          isA<CartLoading>(),
          isA<CartLoaded>()
              .having((s) => s.items.length, 'items.length', 1)
              .having((s) => s.subtotal, 'subtotal', 10000.0)
              .having((s) => s.itemCount, 'itemCount', 2),
        ],
      );

      blocTest<CartBloc, CartState>(
        'emits [CartLoading, CartLoaded] with empty cart',
        build: () {
          when(() => mockRepo.getCart()).thenAnswer((_) async => {
                'items': <Map<String, dynamic>>[],
                'subtotal': 0,
                'itemCount': 0,
              });
          return CartBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const LoadCart()),
        expect: () => [
          isA<CartLoading>(),
          isA<CartLoaded>()
              .having((s) => s.items, 'items', isEmpty)
              .having((s) => s.subtotal, 'subtotal', 0.0)
              .having((s) => s.itemCount, 'itemCount', 0),
        ],
      );

      blocTest<CartBloc, CartState>(
        'emits [CartLoading, CartError] on failure',
        build: () {
          when(() => mockRepo.getCart()).thenThrow(Exception('Network error'));
          return CartBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const LoadCart()),
        expect: () => [
          isA<CartLoading>(),
          isA<CartError>(),
        ],
      );
    });

    // ── AddToCart ──
    group('AddToCart', () {
      blocTest<CartBloc, CartState>(
        'calls addItem and then triggers LoadCart on success',
        build: () {
          when(() => mockRepo.addItem(
                any(), any(), any(), any(), any(),
                selectedVariants: any(named: 'selectedVariants'),
              )).thenAnswer((_) async => {'id': '1'});
          when(() => mockRepo.getCart()).thenAnswer((_) async => {
                'items': [
                  {'id': '1', 'product_name': 'Phone', 'quantity': 1, 'product_price': 500.0}
                ],
                'subtotal': 500.0,
                'itemCount': 1,
              });
          return CartBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const AddToCart(
          productId: 'p1',
          productName: 'Phone',
          productPrice: 500.0,
          productImage: 'phone.jpg',
          quantity: 1,
        )),
        expect: () => [
          // After AddToCart, it dispatches LoadCart internally
          isA<CartLoading>(),
          isA<CartLoaded>(),
        ],
        verify: (_) {
          verify(() => mockRepo.addItem(
                'p1', 'Phone', 500.0, 'phone.jpg', 1,
                selectedVariants: null,
              )).called(1);
        },
      );

      blocTest<CartBloc, CartState>(
        'emits [CartError] on addItem failure',
        build: () {
          when(() => mockRepo.addItem(
                any(), any(), any(), any(), any(),
                selectedVariants: any(named: 'selectedVariants'),
              )).thenThrow(Exception('Producto agotado'));
          return CartBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const AddToCart(
          productId: 'p1',
          productName: 'Phone',
          productPrice: 500.0,
          productImage: 'phone.jpg',
        )),
        expect: () => [
          isA<CartError>(),
        ],
      );
    });

    // ── UpdateCartItem ──
    group('UpdateCartItem', () {
      blocTest<CartBloc, CartState>(
        'calls updateItem and then reloads cart',
        build: () {
          when(() => mockRepo.updateItem(any(), any()))
              .thenAnswer((_) async => {});
          when(() => mockRepo.getCart()).thenAnswer((_) async => {
                'items': [
                  {'id': '1', 'product_name': 'Phone', 'quantity': 3, 'product_price': 500.0}
                ],
                'subtotal': 1500.0,
                'itemCount': 3,
              });
          return CartBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const UpdateCartItem(itemId: '1', quantity: 3)),
        expect: () => [
          isA<CartLoading>(),
          isA<CartLoaded>().having((s) => s.itemCount, 'itemCount', 3),
        ],
        verify: (_) {
          verify(() => mockRepo.updateItem('1', 3)).called(1);
        },
      );
    });

    // ── RemoveCartItem ──
    group('RemoveCartItem', () {
      blocTest<CartBloc, CartState>(
        'calls removeItem and reloads cart',
        build: () {
          when(() => mockRepo.removeItem(any()))
              .thenAnswer((_) async => {});
          when(() => mockRepo.getCart()).thenAnswer((_) async => {
                'items': <Map<String, dynamic>>[],
                'subtotal': 0.0,
                'itemCount': 0,
              });
          return CartBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const RemoveCartItem(itemId: '1')),
        expect: () => [
          isA<CartLoading>(),
          isA<CartLoaded>().having((s) => s.items, 'items', isEmpty),
        ],
        verify: (_) {
          verify(() => mockRepo.removeItem('1')).called(1);
        },
      );
    });

    // ── ClearCart ──
    group('ClearCart', () {
      blocTest<CartBloc, CartState>(
        'clears cart and emits CartLoaded with empty data',
        build: () {
          when(() => mockRepo.clearCart()).thenAnswer((_) async {});
          return CartBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const ClearCart()),
        expect: () => [
          isA<CartLoaded>()
              .having((s) => s.items, 'items', isEmpty)
              .having((s) => s.subtotal, 'subtotal', 0.0)
              .having((s) => s.itemCount, 'itemCount', 0),
        ],
      );

      blocTest<CartBloc, CartState>(
        'emits CartError on clearCart failure',
        build: () {
          when(() => mockRepo.clearCart()).thenThrow(Exception('Error'));
          return CartBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const ClearCart()),
        expect: () => [
          isA<CartError>(),
        ],
      );
    });

    // ── LoadCartCount ──
    group('LoadCartCount', () {
      blocTest<CartBloc, CartState>(
        'updates itemCount when state is CartLoaded',
        build: () {
          when(() => mockRepo.getCount()).thenAnswer((_) async => 5);
          return CartBloc(mockRepo);
        },
        seed: () => const CartLoaded(items: [], subtotal: 0.0, itemCount: 0),
        act: (bloc) => bloc.add(const LoadCartCount()),
        expect: () => [
          isA<CartLoaded>().having((s) => s.itemCount, 'itemCount', 5),
        ],
      );

      blocTest<CartBloc, CartState>(
        'does nothing when state is not CartLoaded',
        build: () {
          when(() => mockRepo.getCount()).thenAnswer((_) async => 5);
          return CartBloc(mockRepo);
        },
        // initial state is CartInitial
        act: (bloc) => bloc.add(const LoadCartCount()),
        expect: () => <CartState>[],
      );
    });
  });
}
