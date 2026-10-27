part of 'auth_bloc.dart';

@immutable
final class AuthState extends Equatable {
  const AuthState.unknown({this.restoreError})
    : status = AuthStatus.unknown,
      user = null;

  const AuthState.authenticated(User this.user)
    : status = AuthStatus.authenticated,
      restoreError = null;

  const AuthState.unauthenticated()
    : status = AuthStatus.unauthenticated,
      user = null,
      restoreError = null;

  final AuthStatus status;

  /// Set only while [status] is authenticated.
  final User? user;

  /// Why the cold-start check couldn't finish (offline); the splash shows it
  /// with a retry.
  final String? restoreError;

  @override
  List<Object?> get props => [status, user, restoreError];
}
