import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkspot/core/network/api_exception.dart';
import 'package:parkspot/core/network/auth_interceptor.dart';
import 'package:parkspot/core/network/session_refresher.dart';
import 'package:parkspot/core/storage/token_store.dart';

import '../../helpers/fake_api.dart';

void main() {
  late FakeApi api;
  late TokenStore tokens;
  late Dio dio;
  late int expiredCalls;

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    api = FakeApi();
    tokens = TokenStore();
    await tokens.save(tokensJson('old'));
    expiredCalls = 0;

    final refreshDio = Dio()..httpClientAdapter = api;
    dio = Dio()..httpClientAdapter = api;
    dio.interceptors.add(
      AuthInterceptor(
        dio: dio,
        tokens: tokens,
        refresher: SessionRefresher(dio: refreshDio, tokens: tokens),
        onSessionExpired: () => expiredCalls++,
      ),
    );
  });

  /// `/me` accepts only the new token.
  void meNeedsNewToken() => api.on('GET', '/me', (r) {
    return r.headers['Authorization'] == 'Bearer access-new'
        ? json(200, {'ok': true})
        : apiError(401, 'TOKEN_EXPIRED');
  });

  test('attaches the access token', () async {
    api.on('GET', '/me', (_) => json(200, {}));
    await dio.get<void>('/me');
    expect(api.requests.single.headers['Authorization'], 'Bearer access-old');
  });

  test('refreshes once on TOKEN_EXPIRED and retries', () async {
    meNeedsNewToken();
    api.on('POST', '/auth/refresh', (r) {
      expect(r.data, {'refreshToken': 'refresh-old'});
      return json(200, {'tokens': tokensJson('new')});
    });

    final res = await dio.get<Map<String, dynamic>>('/me');

    expect(res.data, {'ok': true});
    expect(tokens.accessToken, 'access-new');
    expect(await tokens.readRefreshToken(), 'refresh-new');
  });

  test('parallel 401s share one refresh', () async {
    meNeedsNewToken();
    final gate = Completer<void>();
    api.on('POST', '/auth/refresh', (_) async {
      await gate.future;
      return json(200, {'tokens': tokensJson('new')});
    });

    final calls = [for (var i = 0; i < 3; i++) dio.get<void>('/me')];
    await Future<void>.delayed(Duration.zero);
    gate.complete();
    await Future.wait(calls);

    // The server treats a second use of a refresh token as theft.
    expect(api.count('POST', '/auth/refresh'), 1);
    expect(api.count('GET', '/me'), 6);
  });

  test('a dead refresh token signs out and fails the request', () async {
    meNeedsNewToken();
    api.on('POST', '/auth/refresh', (_) => apiError(401, 'REFRESH_REUSED'));

    await expectLater(
      dio.get<void>('/me'),
      throwsA(
        isA<DioException>().having(
          (e) => e.error,
          'error',
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            ApiErrorCode.refreshReused,
          ),
        ),
      ),
    );
    expect(expiredCalls, 1);
    expect(tokens.accessToken, isNull);
    expect(await tokens.readRefreshToken(), isNull);
  });

  test('offline during refresh keeps the session', () async {
    meNeedsNewToken(); // no refresh route: the fake fails like offline

    await expectLater(dio.get<void>('/me'), throwsA(isA<DioException>()));
    expect(expiredCalls, 0);
    expect(await tokens.readRefreshToken(), 'refresh-old');
  });

  test('other errors pass straight through', () async {
    api.on('GET', '/me', (_) => apiError(401, 'TOKEN_INVALID'));

    await expectLater(dio.get<void>('/me'), throwsA(isA<DioException>()));
    expect(api.count('POST', '/auth/refresh'), 0);
  });

  test('guardApi maps the error envelope and offline', () async {
    api.on('GET', '/lots/x', (_) => apiError(404, 'NOT_FOUND', 'Lot gone'));

    await expectLater(
      guardApi(() => dio.get<void>('/lots/x')),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', ApiErrorCode.notFound)
            .having((e) => e.message, 'message', 'Lot gone'),
      ),
    );
    await expectLater(
      guardApi(() => dio.get<void>('/unrouted')),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', ApiErrorCode.network),
      ),
    );
  });
}
