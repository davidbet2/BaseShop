import 'package:equatable/equatable.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  final Map<String, dynamic> user;

  const AuthAuthenticated({required this.user});

  @override
  List<Object?> get props => [user];
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthError extends AuthState {
  final String message;

  const AuthError({required this.message});

  @override
  List<Object?> get props => [message];
}

/// Emitted after registration — user needs to verify email
class AuthVerificationRequired extends AuthState {
  final String email;
  final String message;

  const AuthVerificationRequired({required this.email, required this.message});

  @override
  List<Object?> get props => [email, message];
}

/// Emitted after verification code resent
class AuthVerificationResent extends AuthState {
  final String email;

  const AuthVerificationResent({required this.email});

  @override
  List<Object?> get props => [email];
}

/// Emitted after forgot-password request sent
class AuthResetCodeSent extends AuthState {
  final String email;
  final String message;

  const AuthResetCodeSent({required this.email, required this.message});

  @override
  List<Object?> get props => [email, message];
}

/// Emitted after password successfully reset
class AuthPasswordReset extends AuthState {
  const AuthPasswordReset();
}
