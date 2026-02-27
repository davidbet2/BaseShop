import 'package:get_it/get_it.dart';

import 'package:baseshop/core/network/api_client.dart';
import 'package:baseshop/core/services/push_notification_service.dart';
import 'package:baseshop/core/services/store_config_service.dart';
import 'package:baseshop/core/cubits/store_config_cubit.dart';

import 'package:baseshop/features/auth/repository/auth_repository.dart';
import 'package:baseshop/features/auth/bloc/auth_bloc.dart';

import 'package:baseshop/features/products/repository/products_repository.dart';
import 'package:baseshop/features/products/bloc/products_bloc.dart';

import 'package:baseshop/features/cart/repository/cart_repository.dart';
import 'package:baseshop/features/cart/bloc/cart_bloc.dart';

import 'package:baseshop/features/orders/repository/orders_repository.dart';
import 'package:baseshop/features/orders/bloc/orders_bloc.dart';

import 'package:baseshop/features/payments/repository/payments_repository.dart';
import 'package:baseshop/features/payments/bloc/payments_bloc.dart';

import 'package:baseshop/features/reviews/repository/reviews_repository.dart';

import 'package:baseshop/features/favorites/repository/favorites_repository.dart';
import 'package:baseshop/features/favorites/bloc/favorites_bloc.dart';

import 'package:baseshop/features/profile/repository/address_repository.dart';

final GetIt getIt = GetIt.instance;

void configureDependencies() {
  // ── Core ─────────────────────────────────────────────────
  getIt.registerLazySingleton<ApiClient>(() => ApiClient());

  getIt.registerLazySingleton<PushNotificationService>(
    () => PushNotificationService(getIt<ApiClient>()),
  );

  getIt.registerLazySingleton<StoreConfigService>(
    () => StoreConfigService(getIt<ApiClient>()),
  );

  // ── Repositories ─────────────────────────────────────────
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepository(getIt<ApiClient>()),
  );

  getIt.registerLazySingleton<ProductsRepository>(
    () => ProductsRepository(getIt<ApiClient>()),
  );

  getIt.registerLazySingleton<CartRepository>(
    () => CartRepository(getIt<ApiClient>()),
  );

  getIt.registerLazySingleton<OrdersRepository>(
    () => OrdersRepository(getIt<ApiClient>()),
  );

  getIt.registerLazySingleton<PaymentsRepository>(
    () => PaymentsRepository(getIt<ApiClient>()),
  );

  getIt.registerLazySingleton<ReviewsRepository>(
    () => ReviewsRepository(getIt<ApiClient>()),
  );

  getIt.registerLazySingleton<FavoritesRepository>(
    () => FavoritesRepository(getIt<ApiClient>()),
  );

  getIt.registerLazySingleton<AddressRepository>(
    () => AddressRepository(getIt<ApiClient>()),
  );

  // ── BLoCs ────────────────────────────────────────────────
  // Singleton: shared by router guard
  getIt.registerLazySingleton<AuthBloc>(
    () => AuthBloc(getIt<AuthRepository>()),
  );

  // Factory: new instance per screen
  getIt.registerFactory<ProductsBloc>(
    () => ProductsBloc(getIt<ProductsRepository>()),
  );

  // Singleton: cart badge count shared across app
  getIt.registerLazySingleton<CartBloc>(
    () => CartBloc(getIt<CartRepository>()),
  );

  // Factory: new instance per screen
  getIt.registerFactory<OrdersBloc>(
    () => OrdersBloc(getIt<OrdersRepository>()),
  );

  // Factory: new instance per payment flow
  getIt.registerFactory<PaymentsBloc>(
    () => PaymentsBloc(getIt<PaymentsRepository>()),
  );

  // Singleton: heart icon state shared across app
  getIt.registerLazySingleton<FavoritesBloc>(
    () => FavoritesBloc(getIt<FavoritesRepository>()),
  );

  // Singleton: store config shared across app
  // cachedConfig is registered externally in main.dart before this runs
  getIt.registerLazySingleton<StoreConfigCubit>(
    () => StoreConfigCubit(
      getIt<StoreConfigService>(),
      cachedConfig: getIt.isRegistered<StoreConfig>()
          ? getIt<StoreConfig>()
          : null,
    ),
  );
}
