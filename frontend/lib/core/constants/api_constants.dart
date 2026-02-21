import 'package:flutter/foundation.dart';

class ApiConstants {
  static const String _prodUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');
  static const String _devUrl = 'http://localhost:3000/api';

  static String get baseUrl {
    if (kReleaseMode) {
      assert(_prodUrl.isNotEmpty, 'API_BASE_URL must be set via --dart-define');
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

  // ── Payments ──
  static const String payments = '/payments';
  static const String createPayment = '/payments/create';
  static const String paymentStats = '/payments/stats/summary';

  // ── Reviews ──
  static const String reviews = '/reviews';
  static const String myReviews = '/reviews/me';

  // ── Favorites ──
  static const String favorites = '/favorites';
}
