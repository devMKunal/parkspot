import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parkspot/core/network/api_exception.dart';
import 'package:parkspot/core/utils/submit_status.dart';
import 'package:parkspot/features/login/presentation/bloc/login_bloc.dart';

import '../../helpers/mocks.dart';

void main() {
  late MockAuthRepository repository;

  setUp(() => repository = MockAuthRepository());

  const event = LoginSubmitted(email: 'asha@mail.com', password: 'secret12');

  void loginThrows(ApiErrorCode code) => when(
    () => repository.login(
      email: any(named: 'email'),
      password: any(named: 'password'),
    ),
  ).thenThrow(ApiException(code, 'server says'));

  blocTest<LoginBloc, LoginState>(
    'logs in',
    setUp: () => when(
      () => repository.login(email: 'asha@mail.com', password: 'secret12'),
    ).thenAnswer((_) async => testUser),
    build: () => LoginBloc(repository),
    act: (bloc) => bloc.add(event),
    expect: () => [
      const LoginState(status: SubmitStatus.submitting),
      LoginState(status: SubmitStatus.success, user: testUser),
    ],
  );

  blocTest<LoginBloc, LoginState>(
    'wrong password: the design copy and a marked field',
    setUp: () => loginThrows(ApiErrorCode.invalidCredentials),
    build: () => LoginBloc(repository),
    act: (bloc) => bloc.add(event),
    skip: 1,
    expect: () => [
      const LoginState(
        status: SubmitStatus.failure,
        error: LoginBloc.wrongCredentials,
        wrongPassword: true,
      ),
    ],
  );

  blocTest<LoginBloc, LoginState>(
    'rate limited',
    setUp: () => loginThrows(ApiErrorCode.rateLimited),
    build: () => LoginBloc(repository),
    act: (bloc) => bloc.add(event),
    skip: 1,
    expect: () => [
      const LoginState(
        status: SubmitStatus.failure,
        error: LoginBloc.rateLimited,
      ),
    ],
  );

  blocTest<LoginBloc, LoginState>(
    'other failures show the server message',
    setUp: () => loginThrows(ApiErrorCode.unknown),
    build: () => LoginBloc(repository),
    act: (bloc) => bloc.add(event),
    skip: 1,
    expect: () => [
      const LoginState(status: SubmitStatus.failure, error: 'server says'),
    ],
  );
}
