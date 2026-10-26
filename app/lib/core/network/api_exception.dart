import 'package:dio/dio.dart';

/// Error codes the API sends in `{ error: { code } }`, plus two for failures
/// that never reached it. Mirrors api/src/core/errors/AppError.ts.
enum ApiErrorCode {
  validation('VALIDATION_ERROR'),
  invalidCredentials('INVALID_CREDENTIALS'),
  emailTaken('EMAIL_TAKEN'),
  refreshInvalid('REFRESH_INVALID'),
  refreshReused('REFRESH_REUSED'),
  tokenExpired('TOKEN_EXPIRED'),
  tokenInvalid('TOKEN_INVALID'),
  notFound('NOT_FOUND'),
  lotFull('LOT_FULL'),
  bookingNotCancellable('BOOKING_NOT_CANCELLABLE'),
  passCodeInvalid('PASS_CODE_INVALID'),
  checkinNotAllowed('CHECKIN_NOT_ALLOWED'),
  extensionNotAllowed('EXTENSION_NOT_ALLOWED'),
  extensionUnavailable('EXTENSION_UNAVAILABLE'),
  endNotAllowed('END_NOT_ALLOWED'),
  rateLimited('RATE_LIMITED'),
  paymentProvider('PAYMENT_PROVIDER_ERROR'),
  paymentSignatureInvalid('PAYMENT_SIGNATURE_INVALID'),
  paymentRefunded('PAYMENT_REFUNDED'),
  paymentsUnavailable('PAYMENTS_UNAVAILABLE'),

  /// No response: offline, DNS, timeout.
  network('NETWORK'),

  /// A response we can't read, or a code this build doesn't know.
  unknown('UNKNOWN');

  const ApiErrorCode(this.wire);

  final String wire;

  static ApiErrorCode parse(Object? wire) =>
      values.firstWhere((c) => c.wire == wire, orElse: () => unknown);
}

/// The one error type repositories throw. Blocs switch on [code]; [message]
/// is the server's wording, safe to show when there is no better copy.
class ApiException implements Exception {
  const ApiException(this.code, this.message, {this.statusCode});

  factory ApiException.fromDio(DioException e) {
    final response = e.response;
    if (response == null) {
      return const ApiException(
        ApiErrorCode.network,
        "Can't reach ParkSpot. Check your connection and try again.",
      );
    }
    final body = response.data;
    final error = body is Map ? body['error'] : null;
    if (error is! Map) {
      return ApiException(
        ApiErrorCode.unknown,
        'Something went wrong. Try again.',
        statusCode: response.statusCode,
      );
    }
    return ApiException(
      ApiErrorCode.parse(error['code']),
      error['message'] as String? ?? 'Something went wrong. Try again.',
      statusCode: response.statusCode,
    );
  }

  final ApiErrorCode code;
  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException(${code.wire}, $statusCode): $message';
}

/// Runs a dio call and rethrows its failure as an [ApiException].
Future<T> guardApi<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on DioException catch (e) {
    // The interceptor may already have turned it into one.
    if (e.error case final ApiException api) throw api;
    throw ApiException.fromDio(e);
  }
}
