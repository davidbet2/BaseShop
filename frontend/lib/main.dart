import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

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

    // ── Firebase ──────────────────────────────────────────
    try {
      await Firebase.initializeApp();
      FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint('[Main] Firebase init error: $e');
    }

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
    await getIt<ApiClient>().loadTokensFromStorage();

    // ── Push notifications ───────────────────────────────
    try {
      await getIt<PushNotificationService>().initialize();
    } catch (e) {
      debugPrint('[Main] Push notifications init error: $e');
    }

    // ── Check auth state ─────────────────────────────────
    getIt<AuthBloc>().add(const AuthCheckRequested());

    runApp(const MyApp());
  }, (error, stackTrace) {
    debugPrint('[Main] Unhandled error: $error');
    debugPrint('[Main] Stack trace: $stackTrace');
  });
}

/// Background message handler — must be top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[FCM] Background message: ${message.messageId}');
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
        supportedLocales: const [
          Locale('es', 'CO'),
          Locale('es'),
          Locale('en'),
        ],
      ),
    );
  }
}
