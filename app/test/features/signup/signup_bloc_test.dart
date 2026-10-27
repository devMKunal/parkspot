import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parkspot/core/network/api_exception.dart';
import 'package:parkspot/core/utils/submit_status.dart';
import 'package:parkspot/features/auth/domain/user.dart';
import 'package:parkspot/features/signup/presentation/bloc/signup_bloc.dart';

import '../../helpers/mocks.dart';

void main() {
  late MockAuthRepository repository;

  setUp(() => repository = MockAuthRepository());

  const event = CreateAccountEvent(
    name: 'Asha',
    email: 'asha@mail.com',
    password: 'secret12',
  );

  void registerAnswers(Future<User> Function() answer) => when(
    () => repository.register(
      name: any(named: 'name'),
      email: any(named: 'email'),
      password: any(named: 'password'),
    ),
  ).thenAnswer((_) => answer());

  blocTest<SignupBloc, SignupState>(
    'creates the account',
    setUp: () => registerAnswers(() async => testUser),
    build: () => SignupBloc(repository),
    act: (bloc) => bloc.add(event),
    expect: () => [
      const SignupState(status: SubmitStatus.submitting),
      SignupState(status: SubmitStatus.success, user: testUser),
    ],
    verify: (_) => verify(
      () => repository.register(
        name: 'Asha',
        email: 'asha@mail.com',
        password: 'secret12',
      ),
    ).called(1),
  );

  blocTest<SignupBloc, SignupState>(
    'a taken email is a field error',
    setUp: () => registerAnswers(
      () => throw const ApiException(ApiErrorCode.emailTaken, 'taken'),
    ),
    build: () => SignupBloc(repository),
    act: (bloc) => bloc.add(event),
    expect: () => [
      const SignupState(status: SubmitStatus.submitting),
      const SignupState(
        status: SubmitStatus.failure,
        emailError: 'An account with this email already exists',
      ),
    ],
  );

  blocTest<SignupBloc, SignupState>(
    'anything else goes to the banner',
    setUp: () => registerAnswers(
      () => throw const ApiException(ApiErrorCode.network, 'Offline'),
    ),
    build: () => SignupBloc(repository),
    act: (bloc) => bloc.add(event),
    expect: () => [
      const SignupState(status: SubmitStatus.submitting),
      const SignupState(status: SubmitStatus.failure, error: 'Offline'),
    ],
  );

  blocTest<SignupBloc, SignupState>(
    'ignores a second tap while submitting',
    build: () => SignupBloc(repository),
    seed: () => const SignupState(status: SubmitStatus.submitting),
    act: (bloc) => bloc.add(event),
    expect: () => <SignupState>[],
  );
}
