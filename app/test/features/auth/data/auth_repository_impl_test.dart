import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkspot/core/network/api_exception.dart';
import 'package:parkspot/core/network/session_refresher.dart';
import 'package:parkspot/core/storage/token_store.dart';
import 'package:parkspot/features/auth/data/auth_repository_impl.dart';

import '../../../helpers/fake_api.dart';
import '../../../helpers/mocks.dart';

void main() {
  late FakeApi api;
  late TokenStore tokens;
  late AuthRepositoryImpl repository;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    api = FakeApi();
    tokens = TokenStore();
    final dio = Dio()..httpClientAdapter = api;
    repository = AuthRepositoryImpl(
      dio: dio,
      tokens: tokens,
      refresher: SessionRefresher(dio: dio, tokens: tokens),
    );
  });

  void signInReturns(String path) => api.on(
    'POST',
    path,
    (_) => json(201, {'user': userJson, 'tokens': tokensJson('1')}),
  );

  test('register sends trimmed fields and stores the tokens', () async {
    signInReturns('/auth/register');

    final user = await repository.register(
      name: ' Asha ',
      email: ' asha@mail.com ',
      password: ' secret12 ',
    );

    expect(user, testUser);
    expect(api.requests.single.data, {
      'name': 'Asha',
      'email': 'asha@mail.com',
      'password': ' secret12 ',
    });
    expect(tokens.accessToken, 'access-1');
    expect(await tokens.readRefreshToken(), 'refresh-1');
  });

  test('login maps a wrong password to INVALID_CREDENTIALS', () async {
    api.on('POST', '/auth/login', (_) => apiError(401, 'INVALID_CREDENTIALS'));

    await expectLater(
      repository.login(email: 'asha@mail.com', password: 'nope'),
      throwsA(
        isA<ApiException>().having(
          (e) => e.code,
          'code',
          ApiErrorCode.invalidCredentials,
        ),
      ),
    );
    expect(await tokens.readRefreshToken(), isNull);
  });

  group('restoreSession', () {
    test('no stored token: null, without a call', () async {
      expect(await repository.restoreSession(), isNull);
      expect(api.requests, isEmpty);
    });

    test('refreshes, then loads the user', () async {
      await tokens.save(tokensJson('old'));
      api
        ..on(
          'POST',
          '/auth/refresh',
          (_) => json(200, {'tokens': tokensJson('new')}),
        )
        ..on('GET', '/me', (_) => json(200, {'user': userJson}));

      expect(await repository.restoreSession(), testUser);
      expect(await tokens.readRefreshToken(), 'refresh-new');
    });

    test('a revoked token: null and the device forgets it', () async {
      await tokens.save(tokensJson('old'));
      api.on('POST', '/auth/refresh', (_) => apiError(401, 'REFRESH_INVALID'));

      expect(await repository.restoreSession(), isNull);
      expect(await tokens.readRefreshToken(), isNull);
    });

    test('offline: throws and keeps the token for a retry', () async {
      await tokens.save(tokensJson('old'));

      await expectLater(
        repository.restoreSession(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            ApiErrorCode.network,
          ),
        ),
      );
      expect(await tokens.readRefreshToken(), 'refresh-old');
    });
  });

  test('logout forgets the session even when offline', () async {
    await tokens.save(tokensJson('old'));

    await repository.logout();

    expect(api.requests.single.data, {'refreshToken': 'refresh-old'});
    expect(tokens.accessToken, isNull);
    expect(await tokens.readRefreshToken(), isNull);
  });
}
