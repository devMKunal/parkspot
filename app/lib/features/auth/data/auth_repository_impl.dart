import 'package:dio/dio.dart';
import 'package:parkspot/core/network/api_exception.dart';
import 'package:parkspot/core/network/session_refresher.dart';
import 'package:parkspot/core/storage/token_store.dart';
import 'package:parkspot/features/auth/domain/auth_repository.dart';
import 'package:parkspot/features/auth/domain/user.dart';

/// docs/auth-api.md
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required this._dio,
    required this._tokens,
    required this._refresher,
  });

  final Dio _dio;
  final TokenStore _tokens;
  final SessionRefresher _refresher;

  @override
  Future<User> register({
    required String name,
    required String email,
    required String password,
  }) => _signIn('/auth/register', {
    'name': name.trim(),
    'email': email.trim(),
    'password': password,
  });

  @override
  Future<User> login({required String email, required String password}) =>
      _signIn('/auth/login', {'email': email.trim(), 'password': password});

  Future<User> _signIn(String path, Map<String, String> body) async {
    final res = await guardApi(
      () => _dio.post<Map<String, dynamic>>(path, data: body),
    );
    final data = res.data!;
    await _tokens.save(data['tokens'] as Map<String, dynamic>);
    return User.fromJson(data['user'] as Map<String, dynamic>);
  }

  @override
  Future<User?> restoreSession() async {
    try {
      await _refresher.refresh();
      final res = await guardApi(() => _dio.get<Map<String, dynamic>>('/me'));
      return User.fromJson(res.data!['user'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.code == ApiErrorCode.network) rethrow;
      // Revoked, expired or a deleted user: start over at login.
      await _tokens.clear();
      return null;
    }
  }

  @override
  Future<void> logout() async {
    try {
      final refreshToken = await _tokens.readRefreshToken();
      if (refreshToken != null) {
        await _dio.post<void>(
          '/auth/logout',
          data: {'refreshToken': refreshToken},
        );
      }
    } on DioException {
      // Offline or already revoked: the device forgets it either way.
    } finally {
      await _tokens.clear();
    }
  }
}
