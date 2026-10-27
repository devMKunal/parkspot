part of 'signup_bloc.dart';

@immutable
final class SignupState extends Equatable {
  const SignupState({
    this.status = SubmitStatus.idle,
    this.user,
    this.emailError,
    this.error,
  });

  final SubmitStatus status;

  /// Set on success; the page hands it to AuthBloc.
  final User? user;

  /// Shown under the email field (email already taken).
  final String? emailError;

  /// Shown in a banner above the form (offline, rate limited, server).
  final String? error;

  @override
  List<Object?> get props => [status, user, emailError, error];
}
