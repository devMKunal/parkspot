import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parkspot/core/network/api_exception.dart';
import 'package:parkspot/features/auth/presentation/bloc/auth_bloc.dart';

import '../../../helpers/mocks.dart';

void main() {
  late MockAuthRepository repository;
  late StreamController<void> expired;

  setUp(() {
    repository = MockAuthRepository();
    expired = StreamController<void>();
  });
  tearDown(() => expired.close());

  AuthBloc build() =>
      AuthBloc(repository: repository, sessionExpired: expired.stream);

  blocTest<AuthBloc, AuthState>(
    'restores a stored session',
    setUp: () => when(
      () => repository.restoreSession(),
    ).thenAnswer((_) async => testUser),
    build: build,
    act: (bloc) => bloc.add(const AuthSessionRestoreRequested()),
    expect: () => [
      const AuthState.unknown(),
      AuthState.authenticated(testUser),
    ],
  );

  blocTest<AuthBloc, AuthState>(
    'no session: unauthenticated',
    setUp: () =>
        when(() => repository.restoreSession()).thenAnswer((_) async => null),
    build: build,
    act: (bloc) => bloc.add(const AuthSessionRestoreRequested()),
    expect: () => [
      const AuthState.unknown(),
      const AuthState.unauthenticated(),
    ],
  );

  blocTest<AuthBloc, AuthState>(
    'offline at launch: stays unknown with an error to retry',
    setUp: () => when(
      () => repository.restoreSession(),
    ).thenThrow(const ApiException(ApiErrorCode.network, 'Offline')),
    build: build,
    act: (bloc) => bloc.add(const AuthSessionRestoreRequested()),
    expect: () => [
      const AuthState.unknown(),
      const AuthState.unknown(restoreError: 'Offline'),
    ],
  );

  blocTest<AuthBloc, AuthState>(
    'login and logout',
    setUp: () => when(() => repository.logout()).thenAnswer((_) async {}),
    build: build,
    act: (bloc) => bloc
      ..add(AuthLoggedIn(testUser))
      ..add(const AuthLogoutRequested()),
    expect: () => [
      AuthState.authenticated(testUser),
      const AuthState.unauthenticated(),
    ],
    verify: (_) => verify(() => repository.logout()).called(1),
  );

  blocTest<AuthBloc, AuthState>(
    'a dead session from the interceptor signs out',
    build: build,
    seed: () => AuthState.authenticated(testUser),
    act: (_) => expired.add(null),
    expect: () => [const AuthState.unauthenticated()],
  );
}
