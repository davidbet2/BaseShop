import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:baseshop/features/products/bloc/products_bloc.dart';
import 'package:baseshop/features/products/bloc/products_event.dart';
import 'package:baseshop/features/products/bloc/products_state.dart';
import 'package:baseshop/features/products/repository/products_repository.dart';

class MockProductsRepository extends Mock implements ProductsRepository {}

void main() {
  late MockProductsRepository mockRepo;

  final sampleProducts = <Map<String, dynamic>>[
    {'id': '1', 'name': 'Laptop', 'price': 100000, 'stock': 10},
    {'id': '2', 'name': 'Mouse', 'price': 25000, 'stock': 50},
  ];

  final sampleCategories = <Map<String, dynamic>>[
    {'id': '1', 'name': 'Electronics'},
    {'id': '2', 'name': 'Accessories'},
  ];

  setUp(() {
    mockRepo = MockProductsRepository();
  });

  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  group('ProductsBloc', () {
    // ── LoadProducts ──
    group('LoadProducts', () {
      blocTest<ProductsBloc, ProductsState>(
        'emits [ProductsLoading, ProductsLoaded] on success',
        build: () {
          when(() => mockRepo.getProducts(
                categoryId: any(named: 'categoryId'),
                search: any(named: 'search'),
                sortBy: any(named: 'sortBy'),
                minPrice: any(named: 'minPrice'),
                maxPrice: any(named: 'maxPrice'),
                page: any(named: 'page'),
              )).thenAnswer((_) async => {
                'data': sampleProducts,
                'total': 2,
                'page': 1,
              });
          when(() => mockRepo.getCategories())
              .thenAnswer((_) async => sampleCategories);
          return ProductsBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const LoadProducts()),
        expect: () => [
          isA<ProductsLoading>(),
          isA<ProductsLoaded>()
              .having((s) => s.products.length, 'products.length', 2)
              .having((s) => s.total, 'total', 2)
              .having((s) => s.page, 'page', 1)
              .having((s) => s.categories.length, 'categories.length', 2),
        ],
      );

      blocTest<ProductsBloc, ProductsState>(
        'loads with filters (categoryId, search)',
        build: () {
          when(() => mockRepo.getProducts(
                categoryId: any(named: 'categoryId'),
                search: any(named: 'search'),
                sortBy: any(named: 'sortBy'),
                minPrice: any(named: 'minPrice'),
                maxPrice: any(named: 'maxPrice'),
                page: any(named: 'page'),
              )).thenAnswer((_) async => {
                'data': [sampleProducts[0]],
                'total': 1,
                'page': 1,
              });
          when(() => mockRepo.getCategories())
              .thenAnswer((_) async => sampleCategories);
          return ProductsBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const LoadProducts(
          categoryId: '1',
          search: 'Laptop',
        )),
        expect: () => [
          isA<ProductsLoading>(),
          isA<ProductsLoaded>()
              .having((s) => s.products.length, 'products.length', 1)
              .having((s) => s.total, 'total', 1),
        ],
      );

      blocTest<ProductsBloc, ProductsState>(
        'emits [ProductsLoading, ProductsError] on failure',
        build: () {
          when(() => mockRepo.getProducts(
                categoryId: any(named: 'categoryId'),
                search: any(named: 'search'),
                sortBy: any(named: 'sortBy'),
                minPrice: any(named: 'minPrice'),
                maxPrice: any(named: 'maxPrice'),
                page: any(named: 'page'),
              )).thenThrow(Exception('Server error'));
          return ProductsBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const LoadProducts()),
        expect: () => [
          isA<ProductsLoading>(),
          isA<ProductsError>(),
        ],
      );

      blocTest<ProductsBloc, ProductsState>(
        'still loads products even if categories fail',
        build: () {
          when(() => mockRepo.getProducts(
                categoryId: any(named: 'categoryId'),
                search: any(named: 'search'),
                sortBy: any(named: 'sortBy'),
                minPrice: any(named: 'minPrice'),
                maxPrice: any(named: 'maxPrice'),
                page: any(named: 'page'),
              )).thenAnswer((_) async => {
                'data': sampleProducts,
                'total': 2,
                'page': 1,
              });
          when(() => mockRepo.getCategories())
              .thenThrow(Exception('Categories fail'));
          return ProductsBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const LoadProducts()),
        expect: () => [
          isA<ProductsLoading>(),
          isA<ProductsLoaded>()
              .having((s) => s.products.length, 'products.length', 2)
              .having((s) => s.categories, 'categories', isEmpty),
        ],
      );
    });

    // ── LoadProductDetail ──
    group('LoadProductDetail', () {
      blocTest<ProductsBloc, ProductsState>(
        'emits [ProductsLoading, ProductDetailLoaded] on success',
        build: () {
          when(() => mockRepo.getProduct('1'))
              .thenAnswer((_) async => sampleProducts[0]);
          return ProductsBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const LoadProductDetail('1')),
        expect: () => [
          isA<ProductsLoading>(),
          isA<ProductDetailLoaded>()
              .having((s) => s.product['name'], 'name', 'Laptop'),
        ],
      );

      blocTest<ProductsBloc, ProductsState>(
        'emits [ProductsLoading, ProductsError] on failure',
        build: () {
          when(() => mockRepo.getProduct(any()))
              .thenThrow(Exception('Not found'));
          return ProductsBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const LoadProductDetail('999')),
        expect: () => [
          isA<ProductsLoading>(),
          isA<ProductsError>(),
        ],
      );
    });

    // ── LoadCategories (no ProductsLoading emitted) ──
    group('LoadCategories', () {
      blocTest<ProductsBloc, ProductsState>(
        'emits [CategoriesLoaded] on success',
        build: () {
          when(() => mockRepo.getCategories())
              .thenAnswer((_) async => sampleCategories);
          return ProductsBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const LoadCategories()),
        expect: () => [
          isA<CategoriesLoaded>()
              .having((s) => s.categories.length, 'length', 2),
        ],
      );
    });

    // ── CreateProduct ──
    group('CreateProduct', () {
      blocTest<ProductsBloc, ProductsState>(
        'emits [ProductsLoading, ProductActionSuccess] on success',
        build: () {
          when(() => mockRepo.createProduct(any()))
              .thenAnswer((_) async => {'id': '3', 'name': 'Keyboard'});
          return ProductsBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const CreateProduct(
          payload: {'name': 'Keyboard', 'price': 30000},
        )),
        expect: () => [
          isA<ProductsLoading>(),
          isA<ProductActionSuccess>()
              .having((s) => s.product?['name'], 'name', 'Keyboard'),
        ],
      );
    });

    // ── UpdateProduct ──
    group('UpdateProduct', () {
      blocTest<ProductsBloc, ProductsState>(
        'emits [ProductsLoading, ProductActionSuccess] on success',
        build: () {
          when(() => mockRepo.updateProduct(any(), any()))
              .thenAnswer((_) async => {'id': '1', 'name': 'Laptop Pro'});
          return ProductsBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const UpdateProduct(
          productId: '1',
          payload: {'name': 'Laptop Pro'},
        )),
        expect: () => [
          isA<ProductsLoading>(),
          isA<ProductActionSuccess>(),
        ],
      );
    });

    // ── DeleteProduct (no ProductsLoading) ──
    group('DeleteProduct', () {
      blocTest<ProductsBloc, ProductsState>(
        'emits [ProductActionSuccess] on success',
        build: () {
          when(() => mockRepo.deleteProduct(any()))
              .thenAnswer((_) async {});
          return ProductsBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const DeleteProduct(productId: '1')),
        expect: () => [
          isA<ProductActionSuccess>(),
        ],
      );
    });

    // ── ToggleFeatured (no ProductsLoading) ──
    group('ToggleFeatured', () {
      blocTest<ProductsBloc, ProductsState>(
        'emits [ProductActionSuccess] on success',
        build: () {
          when(() => mockRepo.toggleFeatured(any()))
              .thenAnswer((_) async => {'id': '1', 'is_featured': true});
          return ProductsBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const ToggleFeatured(productId: '1')),
        expect: () => [
          isA<ProductActionSuccess>(),
        ],
      );
    });

    // ── UpdateProductStock (no ProductsLoading) ──
    group('UpdateProductStock', () {
      blocTest<ProductsBloc, ProductsState>(
        'emits [ProductActionSuccess] on success',
        build: () {
          when(() => mockRepo.updateStock(any(), any()))
              .thenAnswer((_) async => {'id': '1', 'stock': 100});
          return ProductsBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const UpdateProductStock(productId: '1', stock: 100)),
        expect: () => [
          isA<ProductActionSuccess>(),
        ],
      );
    });

    // ── CreateCategory (emits Loading then CategoriesLoaded) ──
    group('CreateCategory', () {
      blocTest<ProductsBloc, ProductsState>(
        'emits [ProductsLoading, CategoriesLoaded] on success',
        build: () {
          when(() => mockRepo.createCategory(any()))
              .thenAnswer((_) async => {'id': '3', 'name': 'New Cat'});
          when(() => mockRepo.getCategories())
              .thenAnswer((_) async => [...sampleCategories, {'id': '3', 'name': 'New Cat'}]);
          return ProductsBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const CreateCategory(
          payload: {'name': 'New Cat'},
        )),
        expect: () => [
          isA<ProductsLoading>(),
          isA<CategoriesLoaded>()
              .having((s) => s.categories.length, 'length', 3),
        ],
      );
    });

    // ── UpdateCategory (emits Loading then CategoriesLoaded) ──
    group('UpdateCategory', () {
      blocTest<ProductsBloc, ProductsState>(
        'emits [ProductsLoading, CategoriesLoaded] on success',
        build: () {
          when(() => mockRepo.updateCategory(any(), any()))
              .thenAnswer((_) async => {'id': '1', 'name': 'Updated'});
          when(() => mockRepo.getCategories())
              .thenAnswer((_) async => [{'id': '1', 'name': 'Updated'}, sampleCategories[1]]);
          return ProductsBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const UpdateCategory(
          categoryId: '1',
          payload: {'name': 'Updated'},
        )),
        expect: () => [
          isA<ProductsLoading>(),
          isA<CategoriesLoaded>()
              .having((s) => s.categories.length, 'length', 2),
        ],
      );
    });

    // ── DeleteCategory (no ProductsLoading, emits CategoriesLoaded) ──
    group('DeleteCategory', () {
      blocTest<ProductsBloc, ProductsState>(
        'emits [CategoriesLoaded] on success',
        build: () {
          when(() => mockRepo.deleteCategory(any()))
              .thenAnswer((_) async {});
          when(() => mockRepo.getCategories())
              .thenAnswer((_) async => [sampleCategories[1]]);
          return ProductsBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const DeleteCategory(categoryId: '1')),
        expect: () => [
          isA<CategoriesLoaded>()
              .having((s) => s.categories.length, 'length', 1),
        ],
      );

      blocTest<ProductsBloc, ProductsState>(
        'emits [ProductsError] on failure',
        build: () {
          when(() => mockRepo.deleteCategory(any()))
              .thenThrow(Exception('Cannot delete'));
          return ProductsBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const DeleteCategory(categoryId: '1')),
        expect: () => [
          isA<ProductsError>(),
        ],
      );
    });
  });
}
