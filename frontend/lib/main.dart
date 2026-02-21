import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:baseshop/core/di/injection.dart';
import 'package:baseshop/core/network/api_client.dart';
import 'package:baseshop/core/router/app_router.dart';
import 'package:baseshop/core/services/push_notification_service.dart';
import 'package:baseshop/core/theme/app_theme.dart';
import 'package:baseshop/features/auth/bloc/auth_bloc.dart';
import 'package:baseshop/features/auth/bloc/auth_event.dart';
import 'package:baseshop/features/cart/bloc/cart_bloc.dart';
import 'package:baseshop/features/favorites/bloc/favorites_bloc.dart';

void main() {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // ── Error widget for release mode ────────────────────
    if (kReleaseMode) {
      ErrorWidget.builder = (details) => const Material(
            child: Center(
              child: Text(
                'Ha ocurrido un error inesperado',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          );
    }

    // ── Dependency injection ─────────────────────────────
    configureDependencies();

    // ── Load tokens from secure storage ──────────────────
    try {
      await getIt<ApiClient>().loadTokensFromStorage();
    } catch (e) {
      debugPrint('[Main] Load tokens error: $e');
    }

    // ── Push notifications (mobile only) ─────────────────
    if (!kIsWeb) {
      try {
        await getIt<PushNotificationService>().initialize();
      } catch (e) {
        debugPrint('[Main] Push notifications init error: $e');
      }
    }

    // ── Check auth state ─────────────────────────────────
    getIt<AuthBloc>().add(const AuthCheckRequested());

    runApp(const MyApp());
  }, (error, stackTrace) {
    debugPrint('[Main] Unhandled error: $error');
    debugPrint('[Main] Stack trace: $stackTrace');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: getIt<AuthBloc>()),
        BlocProvider<CartBloc>.value(value: getIt<CartBloc>()),
        BlocProvider<FavoritesBloc>.value(value: getIt<FavoritesBloc>()),
      ],
      child: MaterialApp.router(
        title: 'BaseShop',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: appRouter,
        locale: const Locale('es', 'CO'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('es', 'CO'),
          Locale('es'),
          Locale('en'),
        ],
      ),
    );
  }
}
