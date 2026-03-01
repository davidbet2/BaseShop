import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:baseshop/features/auth/bloc/auth_event.dart';
import 'package:baseshop/features/auth/bloc/auth_state.dart';
import 'package:baseshop/features/auth/repository/auth_repository.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _repository;

  AuthBloc(this._repository) : super(const AuthInitial()) {
    on<AuthCheckRequested>(_onCheckRequested);
    on<AuthLoginRequested>(_onLoginRequested);
    on<AuthRegisterRequested>(_onRegisterRequested);
    on<AuthGoogleSignInRequested>(_onGoogleSignInRequested);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthVerifyEmailRequested>(_onVerifyEmail);
    on<AuthResendVerificationRequested>(_onResendVerification);
    on<AuthForgotPasswordRequested>(_onForgotPassword);
    on<AuthResetPasswordRequested>(_onResetPassword);
  }

  Future<void> _onCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      final isLogged = await _repository.isLoggedIn();
      if (!isLogged) {
        emit(const AuthUnauthenticated());
        return;
      }
      final user = await _repository.getMe();
      emit(AuthAuthenticated(user: user));
    } catch (e) {
      if (kDebugMode) debugPrint('[AuthBloc] Check failed: $e');
      emit(const AuthUnauthenticated());
    }
  }

  Future<void> _onLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final user = await _repository.login(event.email, event.password);
      emit(AuthAuthenticated(user: user));
    } catch (e) {
      // Check if login failed because email is not verified
      if (e is DioException && e.response?.statusCode == 403) {
        final data = e.response?.data;
        if (data is Map<String, dynamic> && data['requiresVerification'] == true) {
          emit(AuthVerificationRequired(
            email: data['email']?.toString() ?? event.email,
            message: data['error']?.toString() ?? 'Verifica tu correo electrónico',
          ));
          return;
        }
      }
      emit(AuthError(message: _extractError(e)));
    }
  }

  Future<void> _onRegisterRequested(
    AuthRegisterRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final result = await _repository.register(
        email: event.email,
        password: event.password,
        firstName: event.firstName,
        lastName: event.lastName,
        phone: event.phone,
      );

      // Check if registration requires email verification
      if (result['requiresVerification'] == true) {
        emit(AuthVerificationRequired(
          email: result['email']?.toString() ?? event.email,
          message: result['message']?.toString() ?? 'Revisa tu correo para verificar tu cuenta.',
        ));
      } else {
        emit(AuthAuthenticated(user: result));
      }
    } catch (e) {
      emit(AuthError(message: _extractError(e)));
    }
  }

  Future<void> _onGoogleSignInRequested(
    AuthGoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final user = await _repository.googleSignIn();
      if (user != null) {
        emit(AuthAuthenticated(user: user));
      } else {
        emit(const AuthUnauthenticated());
      }
    } catch (e) {
      emit(AuthError(message: _extractError(e)));
    }
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await _repository.logout();
    } catch (e) {
      if (kDebugMode) debugPrint('[AuthBloc] Logout error: $e');
    }
    emit(const AuthUnauthenticated());
  }

  Future<void> _onVerifyEmail(
    AuthVerifyEmailRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final user = await _repository.verifyEmail(event.email, event.code);
      emit(AuthAuthenticated(user: user));
    } catch (e) {
      emit(AuthError(message: _extractError(e)));
    }
  }

  Future<void> _onResendVerification(
    AuthResendVerificationRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await _repository.resendVerification(event.email);
      emit(AuthVerificationResent(email: event.email));
    } catch (e) {
      emit(AuthError(message: _extractError(e)));
    }
  }

  Future<void> _onForgotPassword(
    AuthForgotPasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final result = await _repository.forgotPassword(event.email);
      final sent = result['sent'] == true;
      final message = result['message'] as String? ?? '';
      if (sent) {
        emit(AuthResetCodeSent(
          email: event.email,
          message: message,
        ));
      } else {
        emit(AuthError(message: message.isNotEmpty ? message : 'No se pudo enviar el código'));
      }
    } catch (e) {
      emit(AuthError(message: _extractError(e)));
    }
  }

  Future<void> _onResetPassword(
    AuthResetPasswordRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      await _repository.resetPassword(event.email, event.code, event.newPassword);
      emit(const AuthPasswordReset());
    } catch (e) {
      emit(AuthError(message: _extractError(e)));
    }
  }

  String _extractError(dynamic e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        return data['message']?.toString() ??
            data['error']?.toString() ??
            'Error de conexión';
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return 'Tiempo de espera agotado. Verifica tu conexión.';
      }
      return 'Error de conexión con el servidor';
    }
    return e.toString();
  }
}
