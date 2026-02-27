import 'package:flutter/foundation.dart';

class ApiConstants {
  static const String _prodUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');
  static const String _devUrl = 'http://localhost:3000/api';

  static String get baseUrl {
    // In release mode, use prod URL if defined; otherwise fall back to dev URL
    // so local `flutter build web` works without --dart-define.
    if (kReleaseMode && _prodUrl.isNotEmpty) {
      return _prodUrl;
    }
    return _devUrl;
  }

  // ── Auth ──
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String googleSignIn = '/auth/google';
  static const String refresh = '/auth/refresh';
  static const String me = '/auth/me';
  static const String logout = '/auth/logout';
  static const String changePassword = '/auth/change-password';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';

  // ── Users ──
  static const String profile = '/users/me/profile';
  static const String addresses = '/users/me/addresses';
  static const String deviceTokens = '/users/device-tokens';
  static const String adminUsers = '/users';

  // ── Products ──
  static const String products = '/products';
  static const String categories = '/categories';

  // ── Cart ──
  static const String cart = '/cart';
  static const String cartItems = '/cart/items';
  static const String cartCount = '/cart/count';

  // ── Orders ──
  static const String orders = '/orders';
  static const String myOrders = '/orders/me';
  static const String orderStats = '/orders/stats/summary';

  // ── Notifications ──
  static const String myNotifications = '/orders/notifications/me';
  static const String unreadNotificationsCount = '/orders/notifications/me/unread-count';
  static const String readAllNotifications = '/orders/notifications/me/read-all';

  // ── Payments ──
  static const String payments = '/payments';
  static const String createPayment = '/payments/create';
  static const String validatePaymentResponse = '/payments/validate-response';
  static const String paymentStats = '/payments/stats/summary';
  static const String paymentByOrder = '/payments/order';

  // ── Reviews ──
  static const String reviews = '/reviews';
  static const String myReviews = '/reviews/me';

  // ── Favorites ──
  static const String favorites = '/favorites';
}
