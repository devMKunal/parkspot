part of 'login_bloc.dart';

@immutable
final class LoginState extends Equatable {
  const LoginState({
    this.status = SubmitStatus.idle,
    this.user,
    this.error,
    this.wrongPassword = false,
  });

  final SubmitStatus status;

  /// Set on success; the page hands it to AuthBloc.
  final User? user;

  /// Shown in the banner above the form.
  final String? error;

  /// Outlines the password field in the error colour.
  final bool wrongPassword;

  @override
  List<Object?> get props => [status, user, error, wrongPassword];
}
