import jwt from 'jsonwebtoken';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { AppError } from '../src/core/errors/AppError.js';
import { TokenService } from '../src/modules/auth/token.service.js';
import { TEST_TOKEN_CONFIG } from './support/fakes.js';

const codeOf = (fn: () => unknown) => {
  try {
    fn();
  } catch (err) {
    return err instanceof AppError ? err.code : 'NOT_APP_ERROR';
  }
  return 'NO_ERROR';
};

describe('TokenService', () => {
  const tokens = new TokenService(TEST_TOKEN_CONFIG);

  afterEach(() => {
    vi.useRealTimers();
  });

  it('round-trips access token claims', () => {
    const token = tokens.signAccessToken({ sub: 'user-1', role: 'DRIVER' });
    expect(tokens.verifyAccessToken(token)).toEqual({ sub: 'user-1', role: 'DRIVER' });
  });

  it('reports TOKEN_EXPIRED after the TTL', () => {
    vi.useFakeTimers();
    const token = tokens.signAccessToken({ sub: 'user-1', role: 'DRIVER' });
    vi.advanceTimersByTime((TEST_TOKEN_CONFIG.accessTtlSeconds + 1) * 1000);
    expect(codeOf(() => tokens.verifyAccessToken(token))).toBe('TOKEN_EXPIRED');
  });

  it('reports TOKEN_INVALID for a token signed with another secret', () => {
    const other = new TokenService({ ...TEST_TOKEN_CONFIG, accessSecret: 'x'.repeat(40) });
    const token = other.signAccessToken({ sub: 'user-1', role: 'DRIVER' });
    expect(codeOf(() => tokens.verifyAccessToken(token))).toBe('TOKEN_INVALID');
  });

  it('reports TOKEN_INVALID for the wrong audience or an unknown role', () => {
    const wrongAudience = jwt.sign({ role: 'DRIVER' }, TEST_TOKEN_CONFIG.accessSecret, {
      subject: 'user-1',
      issuer: 'parkspot-api',
      audience: 'someone-else',
    });
    const badRole = jwt.sign({ role: 'ADMIN' }, TEST_TOKEN_CONFIG.accessSecret, {
      subject: 'user-1',
      issuer: 'parkspot-api',
      audience: 'parkspot-app',
    });
    expect(codeOf(() => tokens.verifyAccessToken(wrongAudience))).toBe('TOKEN_INVALID');
    expect(codeOf(() => tokens.verifyAccessToken(badRole))).toBe('TOKEN_INVALID');
  });

  it('generates unique refresh tokens and stores only a hash', () => {
    const now = new Date('2026-10-16T00:00:00Z');
    const service = new TokenService(TEST_TOKEN_CONFIG, () => now);
    const a = service.generateRefreshToken();
    const b = service.generateRefreshToken();

    expect(a.token).not.toBe(b.token);
    expect(a.hash).toBe(service.hashRefreshToken(a.token));
    expect(a.hash).not.toContain(a.token);
    expect(a.expiresAt.toISOString()).toBe('2026-11-15T00:00:00.000Z');
  });
});
