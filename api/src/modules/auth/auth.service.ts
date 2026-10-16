import type { UserRepository } from '../users/user.repository.js';
import type { UserDto } from '../users/user.types.js';
import type { PasswordHasher } from './password.hasher.js';
import type { RefreshTokenRepository } from './refreshToken.repository.js';
import type { TokenPair, TokenService } from './token.service.js';
import type { LoginInput, RegisterInput } from './auth.schemas.js';

export interface AuthResult {
  user: UserDto;
  tokens: TokenPair;
}

/** Request metadata stored on the refresh token for a future "your devices" screen. */
export interface ClientContext {
  userAgent?: string;
}

export interface AuthServiceDeps {
  users: UserRepository;
  refreshTokens: RefreshTokenRepository;
  hasher: PasswordHasher;
  tokens: TokenService;
  now?: () => Date;
}

/**
 * Auth use cases. The rules are specified in docs/auth-api.md, sections 1 and 4.
 *
 * TODO(Dev): implement the four methods below. Throw `Errors.*` from core/errors/AppError.ts;
 * the controller and error handler already turn those into the documented responses.
 * The integration tests in tests/auth.flow.test.ts are written against this contract.
 */
export class AuthService {
  constructor(private readonly deps: AuthServiceDeps) {}

  /**
   * Create a DRIVER, start a new token family, return user + token pair.
   * EMAIL_TAKEN when `users.create` throws DuplicateEmailError.
   */
  async register(_input: RegisterInput, _ctx: ClientContext = {}): Promise<AuthResult> {
    throw new Error('TODO(Dev): AuthService.register');
  }

  /**
   * Verify credentials and start a new token family.
   * INVALID_CREDENTIALS for both unknown email and wrong password, with similar timing
   * (hash a dummy password when the user is missing).
   */
  async login(_input: LoginInput, _ctx: ClientContext = {}): Promise<AuthResult> {
    throw new Error('TODO(Dev): AuthService.login');
  }

  /**
   * Rotate a refresh token within its family.
   * Unknown or expired → REFRESH_INVALID. Already revoked, or `markRotated` returns false
   * → revoke the family and throw REFRESH_REUSED.
   */
  async refresh(_refreshToken: string, _ctx: ClientContext = {}): Promise<TokenPair> {
    throw new Error('TODO(Dev): AuthService.refresh');
  }

  /** Revoke this refresh token. Idempotent: unknown or already-revoked tokens are fine. */
  async logout(_refreshToken: string): Promise<void> {
    throw new Error('TODO(Dev): AuthService.logout');
  }
}
