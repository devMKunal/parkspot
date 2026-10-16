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
  | 'RATE_LIMITED'
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
} as const;
