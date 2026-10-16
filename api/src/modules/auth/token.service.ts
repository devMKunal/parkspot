import jwt from 'jsonwebtoken';
import { createHash, randomBytes } from 'node:crypto';
import { Errors } from '../../core/errors/AppError.js';
import { USER_ROLES, type UserRole } from '../users/user.model.js';

const ISSUER = 'parkspot-api';
const AUDIENCE = 'parkspot-app';
const DAY_MS = 86_400_000;

export interface AccessTokenClaims {
  sub: string;
  role: UserRole;
}

export interface TokenPair {
  accessToken: string;
  accessTokenExpiresIn: number;
  refreshToken: string;
  refreshTokenExpiresAt: string;
}

export interface GeneratedRefreshToken {
  /** Raw value: returned to the client once, never stored. */
  token: string;
  /** SHA-256 of the raw value: the only thing persisted. */
  hash: string;
  expiresAt: Date;
}

export interface TokenServiceConfig {
  accessSecret: string;
  accessTtlSeconds: number;
  refreshTtlDays: number;
}

/** Pure token mechanics. Session rules (rotation, reuse detection) live in AuthService. */
export class TokenService {
  constructor(
    private readonly config: TokenServiceConfig,
    private readonly now: () => Date = () => new Date(),
  ) {}

  get accessTtlSeconds(): number {
    return this.config.accessTtlSeconds;
  }

  signAccessToken(claims: AccessTokenClaims): string {
    return jwt.sign({ role: claims.role }, this.config.accessSecret, {
      algorithm: 'HS256',
      subject: claims.sub,
      issuer: ISSUER,
      audience: AUDIENCE,
      expiresIn: this.config.accessTtlSeconds,
    });
  }

  /** Throws TOKEN_EXPIRED or TOKEN_INVALID so the client knows whether refreshing can help. */
  verifyAccessToken(token: string): AccessTokenClaims {
    let payload: string | jwt.JwtPayload;
    try {
      payload = jwt.verify(token, this.config.accessSecret, {
        algorithms: ['HS256'],
        issuer: ISSUER,
        audience: AUDIENCE,
      });
    } catch (err) {
      if (err instanceof jwt.TokenExpiredError) throw Errors.tokenExpired();
      throw Errors.tokenInvalid();
    }

    if (typeof payload === 'string' || !payload.sub || !isUserRole(payload.role)) {
      throw Errors.tokenInvalid();
    }
    return { sub: payload.sub, role: payload.role };
  }

  generateRefreshToken(): GeneratedRefreshToken {
    const token = `rt_${randomBytes(32).toString('base64url')}`;
    return {
      token,
      hash: this.hashRefreshToken(token),
      expiresAt: new Date(this.now().getTime() + this.config.refreshTtlDays * DAY_MS),
    };
  }

  hashRefreshToken(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }
}

const isUserRole = (value: unknown): value is UserRole =>
  typeof value === 'string' && (USER_ROLES as readonly string[]).includes(value);
