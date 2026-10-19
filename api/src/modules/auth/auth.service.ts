import { randomUUID } from 'node:crypto';
import { Errors } from '../../core/errors/AppError.js';
import { DuplicateEmailError, type UserRepository } from '../users/user.repository.js';
import { toUserDto, type UserDto, type UserRecord } from '../users/user.types.js';
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
 * Every login starts a refresh-token *family*. Refreshing rotates the token inside its family;
 * presenting a token that was already rotated or revoked is treated as theft and revokes the
 * whole family, which logs out both the attacker and the real device.
 */
export class AuthService {
  /** Hash of a throwaway password, verified against when the email is unknown (see `login`). */
  private dummyHash?: Promise<string>;

  constructor(private readonly deps: AuthServiceDeps) {}

  async register(input: RegisterInput, ctx: ClientContext = {}): Promise<AuthResult> {
    const passwordHash = await this.deps.hasher.hash(input.password);

    let user: UserRecord;
    try {
      user = await this.deps.users.create({ name: input.name, email: input.email, passwordHash });
    } catch (err) {
      if (err instanceof DuplicateEmailError) throw Errors.emailTaken();
      throw err;
    }

    return { user: toUserDto(user), tokens: await this.startFamily(user, ctx) };
  }

  async login(input: LoginInput, ctx: ClientContext = {}): Promise<AuthResult> {
    const user = await this.deps.users.findByEmail(input.email);

    // Always run one verify, so an unknown email takes as long as a wrong password and
    // response timing can't be used to discover which emails are registered.
    const hash = user?.passwordHash ?? (await this.getDummyHash());
    const passwordOk = await this.deps.hasher.verify(hash, input.password);

    if (!user || !passwordOk) throw Errors.invalidCredentials();
    return { user: toUserDto(user), tokens: await this.startFamily(user, ctx) };
  }

  async refresh(refreshToken: string, ctx: ClientContext = {}): Promise<TokenPair> {
    const { refreshTokens, tokens, users } = this.deps;
    const current = await refreshTokens.findByHash(tokens.hashRefreshToken(refreshToken));

    if (!current || current.expiresAt <= this.now()) throw Errors.refreshInvalid();
    if (current.revokedAt) await this.revokeFamilyForReuse(current.familyId);

    // Claim the token atomically. Losing the race means another request already rotated it,
    // which is indistinguishable from a replayed stolen token, so it gets the same treatment.
    const nextId = refreshTokens.newId();
    const claimed = await refreshTokens.markRotated(current.id, nextId, this.now());
    if (!claimed) await this.revokeFamilyForReuse(current.familyId);

    const user = await users.findById(current.userId);
    if (!user) {
      await refreshTokens.revokeFamily(current.familyId, this.now());
      throw Errors.refreshInvalid();
    }

    return this.issueTokens(user, current.familyId, ctx, nextId);
  }

  async logout(refreshToken: string): Promise<void> {
    const hash = this.deps.tokens.hashRefreshToken(refreshToken);
    await this.deps.refreshTokens.revokeByHash(hash, this.now());
  }

  private startFamily(user: UserRecord, ctx: ClientContext): Promise<TokenPair> {
    return this.issueTokens(user, randomUUID(), ctx);
  }

  private async issueTokens(
    user: UserRecord,
    familyId: string,
    ctx: ClientContext,
    refreshTokenId?: string,
  ): Promise<TokenPair> {
    const { tokens, refreshTokens } = this.deps;
    const refresh = tokens.generateRefreshToken();

    await refreshTokens.create({
      id: refreshTokenId,
      userId: user.id,
      familyId,
      tokenHash: refresh.hash,
      expiresAt: refresh.expiresAt,
      userAgent: ctx.userAgent,
    });

    return {
      accessToken: tokens.signAccessToken({ sub: user.id, role: user.role }),
      accessTokenExpiresIn: tokens.accessTtlSeconds,
      refreshToken: refresh.token,
      refreshTokenExpiresAt: refresh.expiresAt.toISOString(),
    };
  }

  private async revokeFamilyForReuse(familyId: string): Promise<never> {
    await this.deps.refreshTokens.revokeFamily(familyId, this.now());
    throw Errors.refreshReused();
  }

  private getDummyHash(): Promise<string> {
    this.dummyHash ??= this.deps.hasher.hash(randomUUID());
    return this.dummyHash;
  }

  private now(): Date {
    return this.deps.now?.() ?? new Date();
  }
}
