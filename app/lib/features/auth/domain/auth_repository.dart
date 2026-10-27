import 'package:parkspot/features/auth/domain/user.dart';

/// Sign-up, login and the stored session. Every method throws
/// `ApiException` on failure.
abstract interface class AuthRepository {
  Future<User> register({
    required String name,
    required String email,
    required String password,
  });

  Future<User> login({required String email, required String password});

  /// The signed-in user from the stored refresh token, or null when there
  /// is no session left to restore. Throws only when the server can't be
  /// reached, so the caller can offer a retry instead of logging out.
  Future<User?> restoreSession();

  /// Revokes the session on the server if it can, and always forgets it on
  /// the device. Never throws.
  Future<void> logout();
}
