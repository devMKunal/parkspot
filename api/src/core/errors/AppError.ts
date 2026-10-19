export type ErrorCode =
  | 'BAD_REQUEST'
  | 'VALIDATION_ERROR'
  | 'INVALID_CREDENTIALS'
  | 'EMAIL_TAKEN'
  | 'REFRESH_INVALID'
  | 'REFRESH_REUSED'
  | 'TOKEN_EXPIRED'
  | 'TOKEN_INVALID'
  | 'NOT_FOUND'
  | 'LOT_FULL'
  | 'BOOKING_NOT_CANCELLABLE'
  | 'PASS_CODE_INVALID'
  | 'CHECKIN_NOT_ALLOWED'
  | 'EXTENSION_NOT_ALLOWED'
  | 'EXTENSION_UNAVAILABLE'
  | 'END_NOT_ALLOWED'
  | 'RATE_LIMITED'
  | 'PAYMENT_PROVIDER_ERROR'
  | 'PAYMENT_SIGNATURE_INVALID'
  | 'PAYMENT_REFUNDED'
  | 'WEBHOOK_SIGNATURE_INVALID'
  | 'PAYMENTS_UNAVAILABLE'
  | 'INTERNAL_ERROR';

/** An error that is safe to show to the client. Anything else becomes a 500. */
export class AppError extends Error {
  constructor(
    readonly status: number,
    readonly code: ErrorCode,
    message: string,
    readonly details?: unknown,
  ) {
    super(message);
    this.name = 'AppError';
  }
}

export const Errors = {
  validation: (details: unknown) =>
    new AppError(422, 'VALIDATION_ERROR', 'Request validation failed', details),
  invalidCredentials: () =>
    new AppError(401, 'INVALID_CREDENTIALS', 'Email or password is incorrect'),
  emailTaken: () => new AppError(409, 'EMAIL_TAKEN', 'An account with this email already exists'),
  refreshInvalid: () => new AppError(401, 'REFRESH_INVALID', 'Refresh token is invalid or expired'),
  refreshReused: () =>
    new AppError(401, 'REFRESH_REUSED', 'Refresh token was already used; session revoked'),
  tokenExpired: () => new AppError(401, 'TOKEN_EXPIRED', 'Access token has expired'),
  tokenInvalid: () => new AppError(401, 'TOKEN_INVALID', 'Access token is missing or invalid'),
  notFound: (what = 'Resource') => new AppError(404, 'NOT_FOUND', `${what} not found`),
  lotFull: () => new AppError(409, 'LOT_FULL', 'No free slot in this lot for that time'),
  bookingNotCancellable: (status: string) =>
    new AppError(409, 'BOOKING_NOT_CANCELLABLE', `A ${status} booking can't be cancelled`),
  passCodeInvalid: () => new AppError(400, 'PASS_CODE_INVALID', 'Pass code does not match'),
  checkinNotAllowed: (why: string) => new AppError(409, 'CHECKIN_NOT_ALLOWED', why),
  extensionNotAllowed: (why: string) => new AppError(409, 'EXTENSION_NOT_ALLOWED', why),
  extensionUnavailable: () =>
    new AppError(409, 'EXTENSION_UNAVAILABLE', 'The slot is booked right after your time'),
  endNotAllowed: (status: string) =>
    new AppError(409, 'END_NOT_ALLOWED', `A ${status} booking can't be ended`),
  paymentsUnavailable: () =>
    new AppError(503, 'PAYMENTS_UNAVAILABLE', 'Payments are not configured on this server'),
  paymentSignatureInvalid: () =>
    new AppError(400, 'PAYMENT_SIGNATURE_INVALID', 'Payment signature does not match'),
  paymentRefunded: () =>
    new AppError(
      409,
      'PAYMENT_REFUNDED',
      'The slot is no longer available, so the payment is being refunded',
    ),
  webhookSignatureInvalid: () =>
    new AppError(400, 'WEBHOOK_SIGNATURE_INVALID', 'Webhook signature does not match'),
  paymentProvider: () =>
    new AppError(502, 'PAYMENT_PROVIDER_ERROR', 'Could not create the payment, try again'),
} as const;
