import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'package:parkspot/core/network/api_exception.dart';
import 'package:parkspot/core/utils/submit_status.dart';
import 'package:parkspot/features/auth/domain/auth_repository.dart';
import 'package:parkspot/features/auth/domain/user.dart';

part 'signup_event.dart';
part 'signup_state.dart';

class SignupBloc extends Bloc<SignupEvent, SignupState> {
  SignupBloc(this._repository) : super(const SignupState()) {
    on<CreateAccountEvent>(_createAccount);
  }

  final AuthRepository _repository;

  Future<void> _createAccount(
    CreateAccountEvent event,
    Emitter<SignupState> emit,
  ) async {
    if (state.status.isSubmitting) return;
    emit(const SignupState(status: SubmitStatus.submitting));
    try {
      final user = await _repository.register(
        name: event.name,
        email: event.email,
        password: event.password,
      );
      emit(SignupState(status: SubmitStatus.success, user: user));
    } on ApiException catch (e) {
      emit(
        e.code == ApiErrorCode.emailTaken
            ? const SignupState(
                status: SubmitStatus.failure,
                emailError: 'An account with this email already exists',
              )
            : SignupState(status: SubmitStatus.failure, error: e.message),
      );
    }
  }
}
