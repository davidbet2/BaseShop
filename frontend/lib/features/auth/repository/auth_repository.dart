import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:baseshop/core/network/api_client.dart';
import 'package:baseshop/core/constants/api_constants.dart';
import 'package:baseshop/core/services/recaptcha_service.dart';

class AuthRepository {
  final ApiClient _apiClient;

  AuthRepository(this._apiClient);

  // ── Login ──────────────────────────────────────────────────
  Future<Map<String, dynamic>> login(String email, String password) async {
    final recaptchaToken = await RecaptchaService.execute('login');

    final response = await _apiClient.dio.post(
      ApiConstants.login,
      data: {
        'email': email,
        'password': password,
        'recaptchaToken': recaptchaToken,
      },
    );

    final data = response.data as Map<String, dynamic>;
    await _apiClient.setToken(
      data['token']?.toString() ?? '',
      data['refreshToken']?.toString() ?? '',
    );
    return data['user'] as Map<String, dynamic>;
  }

  // ── Register ───────────────────────────────────────────────
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
  }) async {
    final recaptchaToken = await RecaptchaService.execute('register');

    final response = await _apiClient.dio.post(
      ApiConstants.register,
      data: {
        'email': email,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        'recaptchaToken': recaptchaToken,
      },
    );

    final data = response.data as Map<String, dynamic>;
    await _apiClient.setToken(
      data['token']?.toString() ?? '',
      data['refreshToken']?.toString() ?? '',
    );
    return data['user'] as Map<String, dynamic>;
  }

  // ── Google Sign-In ─────────────────────────────────────────
  Future<Map<String, dynamic>?> googleSignIn() async {
    final googleUser = await GoogleSignIn(
      clientId: '523139154121-19e2a8br6ce22mabnn1h2jk1jrg38srs.apps.googleusercontent.com',
      scopes: ['email'],
    ).signIn();
    if (googleUser == null) return null; // user cancelled

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;
    if (idToken == null && accessToken == null) {
      throw Exception('No se obtuvo el token de Google');
    }

    final recaptchaToken = await RecaptchaService.execute('google_signin');

    final response = await _apiClient.dio.post(
      ApiConstants.googleSignIn,
      data: {
        if (idToken != null) 'id_token': idToken,
        if (accessToken != null) 'access_token': accessToken,
        'recaptchaToken': recaptchaToken,
      },
    );

    final data = response.data as Map<String, dynamic>;
    await _apiClient.setToken(
      data['token']?.toString() ?? '',
      data['refreshToken']?.toString() ?? '',
    );
    return data['user'] as Map<String, dynamic>;
  }

  // ── Get Me ─────────────────────────────────────────────────
  Future<Map<String, dynamic>> getMe() async {
    final response = await _apiClient.dio.get(ApiConstants.me);
    final data = response.data as Map<String, dynamic>;
    return data['user'] as Map<String, dynamic>? ?? data;
  }

  // ── Logout ─────────────────────────────────────────────────
  Future<void> logout() async {
    try {
      await _apiClient.dio.post(ApiConstants.logout);
    } catch (e) {
      debugPrint('[AuthRepository] Logout request failed: $e');
    } finally {
      await _apiClient.clearTokens();
    }
  }

  // ── Is Logged In ───────────────────────────────────────────
  Future<bool> isLoggedIn() async {
    final token = await _apiClient.getToken();
    return token != null && token.isNotEmpty;
  }

  // ── Change Password ────────────────────────────────────────
  Future<void> changePassword(
      String currentPassword, String newPassword) async {
    await _apiClient.dio.post(
      ApiConstants.changePassword,
      data: {
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
  }

  // ── Forgot Password ───────────────────────────────────────
  Future<void> forgotPassword(String email) async {
    final recaptchaToken = await RecaptchaService.execute('forgot_password');
    await _apiClient.dio.post(
      ApiConstants.forgotPassword,
      data: {
        'email': email,
        'recaptchaToken': recaptchaToken,
      },
    );
  }

  // ── Reset Password ────────────────────────────────────────
  Future<void> resetPassword(
      String email, String code, String newPassword) async {
    await _apiClient.dio.post(
      ApiConstants.resetPassword,
      data: {
        'email': email,
        'code': code,
        'newPassword': newPassword,
      },
    );
  }
}
