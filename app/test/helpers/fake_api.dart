import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

typedef FakeHandler = FutureOr<ResponseBody> Function(RequestOptions request);

/// A dio adapter that answers from [routes] instead of the network, and
/// records every request it saw. Unrouted calls fail like being offline.
class FakeApi implements HttpClientAdapter {
  final Map<String, FakeHandler> routes = {};
  final List<RequestOptions> requests = [];

  /// `api.on('POST', '/auth/login', (_) => json(200, {...}))`
  void on(String method, String path, FakeHandler handler) =>
      routes['$method $path'] = handler;

  int count(String method, String path) =>
      requests.where((r) => r.method == method && r.path == path).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final handler = routes['${options.method} ${options.path}'];
    if (handler == null) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    return await handler(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody json(int status, Object? body) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

ResponseBody apiError(int status, String code, [String message = 'nope']) =>
    json(status, {
      'error': {'code': code, 'message': message, 'details': null},
    });

Map<String, dynamic> tokensJson(String suffix) => {
  'accessToken': 'access-$suffix',
  'accessTokenExpiresIn': 900,
  'refreshToken': 'refresh-$suffix',
  'refreshTokenExpiresAt': '2026-12-01T00:00:00Z',
};

const userJson = {
  'id': 'u1',
  'name': 'Asha',
  'email': 'asha@mail.com',
  'role': 'DRIVER',
  'createdAt': '2026-10-01T10:00:00.000Z',
};
