import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:baseshop/features/favorites/bloc/favorites_bloc.dart';
import 'package:baseshop/features/favorites/bloc/favorites_event.dart';
import 'package:baseshop/features/favorites/bloc/favorites_state.dart';
import 'package:baseshop/features/favorites/repository/favorites_repository.dart';

class MockFavoritesRepository extends Mock implements FavoritesRepository {}

void main() {
  late MockFavoritesRepository mockRepo;

  setUp(() {
    mockRepo = MockFavoritesRepository();
  });

  group('FavoritesBloc', () {
    // ── LoadFavorites ──
    group('LoadFavorites', () {
      blocTest<FavoritesBloc, FavoritesState>(
        'emits [FavoritesLoading, FavoritesLoaded] on success',
        build: () {
          when(() => mockRepo.getFavorites(page: any(named: 'page')))
              .thenAnswer((_) async => {
                    'data': [
                      {'product_id': 'p1', 'product_name': 'Producto 1'},
                      {'product_id': 'p2', 'product_name': 'Producto 2'},
                    ],
                    'total': 2,
                    'page': 1,
                  });
          return FavoritesBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const LoadFavorites()),
        expect: () => [
          isA<FavoritesLoading>(),
          isA<FavoritesLoaded>()
              .having((s) => s.favorites.length, 'count', 2)
              .having((s) => s.favoriteIds.contains('p1'), 'has p1', true)
              .having((s) => s.favoriteIds.contains('p2'), 'has p2', true),
        ],
      );

      blocTest<FavoritesBloc, FavoritesState>(
        'emits [FavoritesLoading, FavoritesError] on failure',
        build: () {
          when(() => mockRepo.getFavorites(page: any(named: 'page')))
              .thenThrow(Exception('Network error'));
          return FavoritesBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const LoadFavorites()),
        expect: () => [
          isA<FavoritesLoading>(),
          isA<FavoritesError>(),
        ],
      );

      blocTest<FavoritesBloc, FavoritesState>(
        'handles empty favorites',
        build: () {
          when(() => mockRepo.getFavorites(page: any(named: 'page')))
              .thenAnswer((_) async => {
                    'data': [],
                    'total': 0,
                    'page': 1,
                  });
          return FavoritesBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const LoadFavorites()),
        expect: () => [
          isA<FavoritesLoading>(),
          isA<FavoritesLoaded>()
              .having((s) => s.favorites.isEmpty, 'empty', true)
              .having((s) => s.favoriteIds.isEmpty, 'no ids', true),
        ],
      );
    });

    // ── AddFavorite ──
    group('AddFavorite', () {
      blocTest<FavoritesBloc, FavoritesState>(
        'optimistically adds and then reloads',
        build: () {
          when(() => mockRepo.addFavorite(any(), any(), any(), any()))
              .thenAnswer((_) async => {'id': 'fav-1'});
          when(() => mockRepo.getFavorites(page: any(named: 'page')))
              .thenAnswer((_) async => {
                    'data': [
                      {'product_id': 'p1'}
                    ],
                    'total': 1,
                    'page': 1,
                  });
          return FavoritesBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const AddFavorite(
          productId: 'p1',
          productName: 'Test',
          productPrice: 10000,
          productImage: 'img.jpg',
        )),
        wait: const Duration(milliseconds: 100),
        expect: () => [
          // Optimistic update first
          isA<FavoritesLoaded>()
              .having((s) => s.favoriteIds.contains('p1'), 'has p1', true),
          // Then reload triggers loading + loaded
          isA<FavoritesLoading>(),
          isA<FavoritesLoaded>(),
        ],
      );

      blocTest<FavoritesBloc, FavoritesState>(
        'reverts on error',
        build: () {
          when(() => mockRepo.addFavorite(any(), any(), any(), any()))
              .thenThrow(Exception('Failed'));
          return FavoritesBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const AddFavorite(
          productId: 'p1',
          productName: 'Test',
          productPrice: 10000,
          productImage: 'img.jpg',
        )),
        expect: () => [
          isA<FavoritesLoaded>(), // optimistic
          isA<FavoritesError>(), // error → revert
        ],
      );
    });

    // ── RemoveFavorite ──
    group('RemoveFavorite', () {
      blocTest<FavoritesBloc, FavoritesState>(
        'optimistically removes and reloads',
        build: () {
          when(() => mockRepo.removeFavorite(any()))
              .thenAnswer((_) async {});
          when(() => mockRepo.getFavorites(page: any(named: 'page')))
              .thenAnswer((_) async => {'data': [], 'total': 0, 'page': 1});
          return FavoritesBloc(mockRepo);
        },
        seed: () => const FavoritesLoaded(
          favorites: [
            {'product_id': 'p1'}
          ],
          favoriteIds: {'p1'},
        ),
        act: (bloc) => bloc.add(const RemoveFavorite(productId: 'p1')),
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<FavoritesLoaded>()
              .having((s) => s.favoriteIds.contains('p1'), 'removed p1', false),
          isA<FavoritesLoading>(),
          isA<FavoritesLoaded>(),
        ],
      );
    });

    // ── CheckFavorite ──
    group('CheckFavorite', () {
      blocTest<FavoritesBloc, FavoritesState>(
        'adds to favoriteIds when product is favorite',
        build: () {
          when(() => mockRepo.checkFavorite('p1'))
              .thenAnswer((_) async => true);
          return FavoritesBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const CheckFavorite(productId: 'p1')),
        expect: () => [
          isA<FavoritesLoaded>()
              .having((s) => s.favoriteIds.contains('p1'), 'p1 fav', true),
        ],
      );

      blocTest<FavoritesBloc, FavoritesState>(
        'removes from favoriteIds when product is not favorite',
        build: () {
          when(() => mockRepo.checkFavorite('p1'))
              .thenAnswer((_) async => false);
          return FavoritesBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const CheckFavorite(productId: 'p1')),
        expect: () => [
          isA<FavoritesLoaded>()
              .having((s) => s.favoriteIds.contains('p1'), 'p1 not fav', false),
        ],
      );
    });
  });
}
