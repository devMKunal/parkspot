import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'package:parkspot/core/network/api_exception.dart';
import 'package:parkspot/features/auth/domain/auth_repository.dart';
import 'package:parkspot/features/auth/domain/user.dart';
import 'package:parkspot/router/auth_status.dart';

part 'auth_event.dart';
part 'auth_state.dart';

/// The app-wide session. The router listens to `AuthState.status`; screens
/// never navigate after sign-in or sign-out, they tell this bloc.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  /// [sessionExpired] fires when the API rejects the refresh token
  /// mid-session (from the auth interceptor).
  AuthBloc({required this._repository, required Stream<void> sessionExpired})
    : super(const AuthState.unknown()) {
    on<AuthSessionRestoreRequested>(_restore);
    on<AuthLoggedIn>(
      (event, emit) => emit(AuthState.authenticated(event.user)),
    );
    on<AuthLogoutRequested>(_logout);
    on<AuthSessionExpired>(
      (event, emit) => emit(const AuthState.unauthenticated()),
    );
    _expired = sessionExpired.listen((_) => add(const AuthSessionExpired()));
  }

  final AuthRepository _repository;
  late final StreamSubscription<void> _expired;

  Future<void> _restore(
    AuthSessionRestoreRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthState.unknown());
    try {
      final user = await _repository.restoreSession();
      emit(
        user == null
            ? const AuthState.unauthenticated()
            : AuthState.authenticated(user),
      );
    } on ApiException catch (e) {
      // Offline at launch: stay on the splash with a retry, keep the token.
      emit(AuthState.unknown(restoreError: e.message));
    }
  }

  Future<void> _logout(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    await _repository.logout();
    emit(const AuthState.unauthenticated());
  }

  @override
  Future<void> close() async {
    await _expired.cancel();
    await super.close();
  }
}
