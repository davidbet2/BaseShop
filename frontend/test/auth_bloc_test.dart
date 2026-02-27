import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:baseshop/features/auth/bloc/auth_bloc.dart';
import 'package:baseshop/features/auth/bloc/auth_event.dart';
import 'package:baseshop/features/auth/bloc/auth_state.dart';
import 'package:baseshop/features/auth/repository/auth_repository.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  late MockAuthRepository mockRepo;

  setUp(() {
    mockRepo = MockAuthRepository();
  });

  group('AuthBloc', () {
    // ── Login ──
    group('AuthLoginRequested', () {
      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoading, AuthAuthenticated] on successful login',
        build: () {
          when(() => mockRepo.login('test@test.com', 'pass123'))
              .thenAnswer((_) async => {'id': '1', 'email': 'test@test.com', 'role': 'client'});
          return AuthBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const AuthLoginRequested(email: 'test@test.com', password: 'pass123')),
        expect: () => [
          isA<AuthLoading>(),
          isA<AuthAuthenticated>()
              .having((s) => s.user['email'], 'email', 'test@test.com'),
        ],
      );

      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoading, AuthError] on login failure',
        build: () {
          when(() => mockRepo.login(any(), any()))
              .thenThrow(Exception('Credenciales inválidas'));
          return AuthBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const AuthLoginRequested(email: 'bad@test.com', password: 'wrong')),
        expect: () => [
          isA<AuthLoading>(),
          isA<AuthError>(),
        ],
      );
    });

    // ── Register ──
    group('AuthRegisterRequested', () {
      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoading, AuthAuthenticated] on successful register',
        build: () {
          when(() => mockRepo.register(
                email: any(named: 'email'),
                password: any(named: 'password'),
                firstName: any(named: 'firstName'),
                lastName: any(named: 'lastName'),
                phone: any(named: 'phone'),
              )).thenAnswer((_) async => {'id': '1', 'email': 'new@test.com', 'role': 'client'});
          return AuthBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const AuthRegisterRequested(
          email: 'new@test.com',
          password: 'pass123',
          firstName: 'New',
          lastName: 'User',
        )),
        expect: () => [
          isA<AuthLoading>(),
          isA<AuthAuthenticated>(),
        ],
      );

      blocTest<AuthBloc, AuthState>(
        'emits [AuthLoading, AuthError] on register failure',
        build: () {
          when(() => mockRepo.register(
                email: any(named: 'email'),
                password: any(named: 'password'),
                firstName: any(named: 'firstName'),
                lastName: any(named: 'lastName'),
                phone: any(named: 'phone'),
              )).thenThrow(Exception('Email ya registrado'));
          return AuthBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const AuthRegisterRequested(
          email: 'dup@test.com',
          password: 'pass123',
          firstName: 'Dup',
          lastName: 'User',
        )),
        expect: () => [
          isA<AuthLoading>(),
          isA<AuthError>(),
        ],
      );
    });

    // ── Check Auth ──
    group('AuthCheckRequested', () {
      blocTest<AuthBloc, AuthState>(
        'emits [AuthAuthenticated] when logged in',
        build: () {
          when(() => mockRepo.isLoggedIn()).thenAnswer((_) async => true);
          when(() => mockRepo.getMe()).thenAnswer((_) async => {'id': '1', 'email': 'test@test.com'});
          return AuthBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const AuthCheckRequested()),
        expect: () => [isA<AuthAuthenticated>()],
      );

      blocTest<AuthBloc, AuthState>(
        'emits [AuthUnauthenticated] when not logged in',
        build: () {
          when(() => mockRepo.isLoggedIn()).thenAnswer((_) async => false);
          return AuthBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const AuthCheckRequested()),
        expect: () => [isA<AuthUnauthenticated>()],
      );

      blocTest<AuthBloc, AuthState>(
        'emits [AuthUnauthenticated] when check fails',
        build: () {
          when(() => mockRepo.isLoggedIn()).thenThrow(Exception('Network error'));
          return AuthBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const AuthCheckRequested()),
        expect: () => [isA<AuthUnauthenticated>()],
      );
    });

    // ── Logout ──
    group('AuthLogoutRequested', () {
      blocTest<AuthBloc, AuthState>(
        'emits [AuthUnauthenticated] on logout',
        build: () {
          when(() => mockRepo.logout()).thenAnswer((_) async {});
          return AuthBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const AuthLogoutRequested()),
        expect: () => [isA<AuthUnauthenticated>()],
      );

      blocTest<AuthBloc, AuthState>(
        'emits [AuthUnauthenticated] even if logout API fails',
        build: () {
          when(() => mockRepo.logout()).thenThrow(Exception('API error'));
          return AuthBloc(mockRepo);
        },
        act: (bloc) => bloc.add(const AuthLogoutRequested()),
        expect: () => [isA<AuthUnauthenticated>()],
      );
    });
  });
}
