import 'package:dio/dio.dart';
import 'package:parkspot/core/network/api_exception.dart';
import 'package:parkspot/core/storage/token_store.dart';

/// Swaps the stored refresh token for a new pair, at most one call at a time.
///
/// The server rotates refresh tokens and treats a second use of the old one
/// as theft (`REFRESH_REUSED` revokes the session), so parallel 401s must
/// share a single refresh. Callers that arrive while one is running await it.
class SessionRefresher {
  /// The dio must not carry the auth interceptor, or a failed refresh would
  /// try to refresh itself.
  SessionRefresher({required this._dio, required this._tokens});

  final Dio _dio;
  final TokenStore _tokens;
  Future<void>? _inFlight;

  /// Throws [ApiException]. On `REFRESH_INVALID` or `REFRESH_REUSED` the
  /// tokens are already wiped; a network error leaves them for a retry.
  Future<void> refresh() =>
      _inFlight ??= _refresh().whenComplete(() => _inFlight = null);

  Future<void> _refresh() async {
    final refreshToken = await _tokens.readRefreshToken();
    if (refreshToken == null) {
      throw const ApiException(ApiErrorCode.refreshInvalid, 'Not signed in');
    }
    try {
      final res = await guardApi(
        () => _dio.post<Map<String, dynamic>>(
          '/auth/refresh',
          data: {'refreshToken': refreshToken},
        ),
      );
      await _tokens.save(res.data!['tokens'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.isSessionGone) await _tokens.clear();
      rethrow;
    }
  }
}

extension SessionGoneX on ApiException {
  /// The session can't be recovered; the user has to log in again.
  bool get isSessionGone =>
      code == ApiErrorCode.refreshInvalid || code == ApiErrorCode.refreshReused;
}
