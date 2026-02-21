import 'dart:convert';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../network/api_client.dart';
import '../constants/api_constants.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[FCM] Background message: ${message.messageId}');
}

class PushNotificationService {
  final ApiClient _apiClient;
  FirebaseMessaging? _messaging;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  String? _currentToken;

  PushNotificationService(this._apiClient);

  Future<void> initialize() async {
    if (kIsWeb) return;

    _messaging = FirebaseMessaging.instance;

    final settings = await _messaging!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) return;

    await _initLocalNotifications();
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    final initialMessage = await _messaging!.getInitialMessage();
    if (initialMessage != null) _handleNotificationTap(initialMessage);

    _messaging!.onTokenRefresh.listen((newToken) {
      _currentToken = newToken;
      _registerTokenWithBackend(newToken);
    });
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint('[FCM] Local notification tapped: ${response.payload}');
      },
    );

    if (defaultTargetPlatform == TargetPlatform.android) {
      const channel = AndroidNotificationChannel(
        'baseshop_notifications',
        'BaseShop Notificaciones',
        description: 'Notificaciones de BaseShop',
        importance: Importance.high,
        enableVibration: true,
        playSound: true,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  Future<void> registerToken() async {
    try {
      final token = await _messaging?.getToken();
      if (token != null) {
        _currentToken = token;
        await _registerTokenWithBackend(token);
      }
    } catch (e) {
      debugPrint('[FCM] Error getting token: $e');
    }
  }

  Future<void> unregisterToken() async {
    try {
      if (_currentToken != null) {
        await _apiClient.dio.delete(
          ApiConstants.deviceTokens,
          data: {'token': _currentToken},
        );
      }
    } catch (e) {
      debugPrint('[FCM] Error unregistering: $e');
    }
  }

  Future<void> _registerTokenWithBackend(String token) async {
    try {
      final authToken = await _apiClient.getToken();
      if (authToken == null) return;
      await _apiClient.dio.post(
        ApiConstants.deviceTokens,
        data: {
          'token': token,
          'platform':
              defaultTargetPlatform == TargetPlatform.android
                  ? 'android'
                  : 'ios',
        },
      );
    } catch (e) {
      debugPrint('[FCM] Error registering token: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification != null) {
      _localNotifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'baseshop_notifications',
            'BaseShop Notificaciones',
            channelDescription: 'Notificaciones de BaseShop',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            color: const Color(0xFF1565C0),
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('[FCM] Notification tapped: ${message.data}');
    // TODO: Navigate to specific screen based on message.data
  }
}
