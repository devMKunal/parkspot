import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'package:parkspot/core/network/api_exception.dart';
import 'package:parkspot/core/utils/submit_status.dart';
import 'package:parkspot/features/auth/domain/auth_repository.dart';
import 'package:parkspot/features/auth/domain/user.dart';

part 'login_event.dart';
part 'login_state.dart';

class LoginBloc extends Bloc<LoginEvent, LoginState> {
  LoginBloc(this._repository) : super(const LoginState()) {
    on<LoginSubmitted>(_submit);
  }

  final AuthRepository _repository;

  static const wrongCredentials =
      "That email and password don't match. Check them and try again.";
  static const rateLimited = 'Too many tries. Wait a minute and try again.';

  Future<void> _submit(LoginSubmitted event, Emitter<LoginState> emit) async {
    if (state.status.isSubmitting) return;
    emit(const LoginState(status: SubmitStatus.submitting));
    try {
      final user = await _repository.login(
        email: event.email,
        password: event.password,
      );
      emit(LoginState(status: SubmitStatus.success, user: user));
    } on ApiException catch (e) {
      emit(
        LoginState(
          status: SubmitStatus.failure,
          wrongPassword: e.code == ApiErrorCode.invalidCredentials,
          error: switch (e.code) {
            ApiErrorCode.invalidCredentials => wrongCredentials,
            ApiErrorCode.rateLimited => rateLimited,
            _ => e.message,
          },
        ),
      );
    }
  }
}
