import 'package:dio/dio.dart';
import 'package:parkspot/core/network/api_exception.dart';
import 'package:parkspot/core/network/session_refresher.dart';
import 'package:parkspot/core/storage/token_store.dart';

/// Adds the access token to every request. On `401 TOKEN_EXPIRED` it
/// refreshes once and retries the request; if the session is gone it calls
/// `onSessionExpired` (AuthBloc signs the user out) and fails the request.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this._dio,
    required this._tokens,
    required this._refresher,
    required this._onSessionExpired,
  });

  final Dio _dio;
  final TokenStore _tokens;
  final SessionRefresher _refresher;
  final void Function() _onSessionExpired;

  static const _retried = 'auth.retried';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = _tokens.accessToken;
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final request = err.requestOptions;
    final expired =
        err.response?.statusCode == 401 &&
        ApiException.fromDio(err).code == ApiErrorCode.tokenExpired;
    if (!expired || request.extra[_retried] == true) return handler.next(err);

    // Another request may have refreshed while this one was in flight.
    final sentWith = request.headers['Authorization'];
    if (sentWith == 'Bearer ${_tokens.accessToken}') {
      try {
        await _refresher.refresh();
      } on ApiException catch (e) {
        if (e.isSessionGone) _onSessionExpired();
        return handler.next(err.copyWith(error: e));
      }
    }

    request.extra[_retried] = true;
    try {
      // fetch() runs onRequest again, which attaches the new token.
      handler.resolve(await _dio.fetch<dynamic>(request));
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
