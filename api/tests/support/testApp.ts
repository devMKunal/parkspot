import { createApp } from '../../src/app.js';
import { AuthService } from '../../src/modules/auth/auth.service.js';
import { TokenService } from '../../src/modules/auth/token.service.js';
import {
  FakePasswordHasher,
  InMemoryRefreshTokenRepository,
  InMemoryUserRepository,
  TEST_TOKEN_CONFIG,
} from './fakes.js';

export function buildTestApp(opts: { now?: () => Date } = {}) {
  const users = new InMemoryUserRepository();
  const refreshTokens = new InMemoryRefreshTokenRepository();
  const hasher = new FakePasswordHasher();
  const tokens = new TokenService(TEST_TOKEN_CONFIG, opts.now);
  const auth = new AuthService({ users, refreshTokens, hasher, tokens, now: opts.now });
  const app = createApp({ auth, tokens, users, rateLimit: false });
  return { app, users, refreshTokens, hasher, tokens, auth };
}
