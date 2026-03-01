import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/api_constants.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late final Dio dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  bool _isRefreshing = false;

  // Cache de tokens en memoria
  String? _cachedToken;
  String? _cachedRefreshToken;

  ApiClient._internal() {
    dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        if (!kIsWeb) 'X-Platform': 'mobile',
      },
    ));

    // Log interceptor solo en debug (skip en web)
    if (kDebugMode && !kIsWeb) {
      dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
      ));
    }

    dio.interceptors.add(InterceptorsWrapper(
      // Auto-attach Bearer token
      onRequest: (options, handler) {
        if (_cachedToken != null && _cachedToken!.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $_cachedToken';
        }
        handler.next(options);
      },
      // 401: refresh token + retry
      onError: (error, handler) async {
        try {
          if (error.response?.statusCode == 401) {
            final path = error.requestOptions.path;
            final isAuthRoute = path.contains('/auth/login') ||
                path.contains('/auth/register') ||
                path.contains('/auth/google') ||
                path.contains('/auth/refresh') ||
                path.contains('/auth/forgot-password') ||
                path.contains('/auth/reset-password');

            if (!isAuthRoute && !_isRefreshing) {
              _isRefreshing = true;
              try {
                final refreshToken = _cachedRefreshToken;
                if (refreshToken != null && refreshToken.isNotEmpty) {
                  final refreshDio = Dio(BaseOptions(
                    connectTimeout: const Duration(seconds: 10),
                    receiveTimeout: const Duration(seconds: 10),
                    headers: {
                      'Content-Type': 'application/json',
                      if (!kIsWeb) 'X-Platform': 'mobile',
                    },
                  ));
                  final response = await refreshDio.post(
                    '${dio.options.baseUrl}/auth/refresh',
                    data: {'refreshToken': refreshToken},
                  );
                  final newToken = response.data['token'];
                  final newRefreshToken = response.data['refreshToken'];
                  await setToken(
                    newToken?.toString() ?? '',
                    newRefreshToken?.toString() ?? '',
                  );

                  // Retry request original
                  error.requestOptions.headers['Authorization'] =
                      'Bearer $newToken';
                  final retryResponse = await dio.fetch(error.requestOptions);
                  _isRefreshing = false;
                  return handler.resolve(retryResponse);
                }
              } catch (e) {
              if (kDebugMode) debugPrint('[ApiClient] Refresh failed: $e');
                await clearTokens();
              } finally {
                _isRefreshing = false;
              }
            }
          }
        } catch (e) {
          if (kDebugMode) debugPrint('[ApiClient] Interceptor error: $e');
        }
        handler.next(error);
      },
    ));
  }

  Future<void> setToken(String token, String refreshToken) async {
    _cachedToken = token;
    _cachedRefreshToken = refreshToken;
    try {
      await _storage.write(key: 'access_token', value: token);
      await _storage.write(key: 'refresh_token', value: refreshToken);
    } catch (e) {
      if (kDebugMode) debugPrint('[ApiClient] Storage write error: $e');
    }
  }

  Future<void> clearTokens() async {
    _cachedToken = null;
    _cachedRefreshToken = null;
    try {
      await _storage.deleteAll();
    } catch (e) {
      if (kDebugMode) debugPrint('[ApiClient] Storage clear error: $e');
    }
  }

  Future<String?> getToken() async {
    if (_cachedToken != null) return _cachedToken;
    try {
      _cachedToken = await _storage.read(key: 'access_token');
      _cachedRefreshToken = await _storage.read(key: 'refresh_token');
    } catch (e) {
      if (kDebugMode) debugPrint('[ApiClient] Storage read error: $e');
    }
    return _cachedToken;
  }

  // Bump this version to force a one-time token reset on all clients
  static const String _storageVersion = '2';

  Future<void> loadTokensFromStorage() async {
    try {
      // Check storage version — clear stale tokens from previous builds
      final version = await _storage.read(key: 'storage_version');
      if (version != _storageVersion) {
        if (kDebugMode) debugPrint('[ApiClient] Storage version mismatch ($version != $_storageVersion) — clearing tokens');
        await clearTokens();
        await _storage.write(key: 'storage_version', value: _storageVersion);
        return;
      }

      _cachedToken = await _storage.read(key: 'access_token');
      _cachedRefreshToken = await _storage.read(key: 'refresh_token');

      // Validate JWT expiry client-side
      if (_cachedToken != null && _isTokenExpired(_cachedToken!)) {
        if (kDebugMode) debugPrint('[ApiClient] Stored token is expired — clearing');
        await clearTokens();
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[ApiClient] loadTokensFromStorage error: $e');
    }
  }

  /// Decode JWT payload and check if `exp` claim is in the past.
  bool _isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      // Base64-decode the payload (part[1])
      String payload = parts[1];
      // Pad to multiple of 4
      switch (payload.length % 4) {
        case 2: payload += '=='; break;
        case 3: payload += '=';  break;
      }
      final decoded = utf8.decode(base64Url.decode(payload));
      final data = jsonDecode(decoded) as Map<String, dynamic>;
      final exp = data['exp'] as int?;
      if (exp == null) return false; // No expiry claim → assume valid
      final expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
      return DateTime.now().isAfter(expiryDate);
    } catch (e) {
      if (kDebugMode) debugPrint('[ApiClient] JWT decode error: $e');
      return true; // Can't decode → treat as invalid
    }
  }
}
