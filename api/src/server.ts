import { createApp } from './app.js';
import { loadEnv } from './config/env.js';
import { logger } from './core/logger.js';
import { connectMongo, disconnectMongo } from './infra/db/mongo.js';
import { AuthService } from './modules/auth/auth.service.js';
import { Argon2PasswordHasher } from './modules/auth/password.hasher.js';
import { MongoRefreshTokenRepository } from './modules/auth/refreshToken.repository.js';
import { TokenService } from './modules/auth/token.service.js';
import { MongoLotRepository } from './modules/lots/lot.repository.js';
import { MongoUserRepository } from './modules/users/user.repository.js';

/** Composition root: the only file that knows about concrete implementations. */
async function main(): Promise<void> {
  const env = loadEnv();
  await connectMongo(env.MONGO_URI);

  const users = new MongoUserRepository();
  const tokens = new TokenService({
    accessSecret: env.JWT_ACCESS_SECRET,
    accessTtlSeconds: env.JWT_ACCESS_TTL_SECONDS,
    refreshTtlDays: env.REFRESH_TOKEN_TTL_DAYS,
  });
  const auth = new AuthService({
    users,
    tokens,
    refreshTokens: new MongoRefreshTokenRepository(),
    hasher: new Argon2PasswordHasher(),
  });

  const app = createApp({
    auth,
    tokens,
    users,
    lots: new MongoLotRepository(),
    corsOrigins: env.CORS_ORIGINS,
  });
  const server = app.listen(env.PORT, () => logger.info(`API listening on :${env.PORT}`));

  const shutdown = (signal: string) => {
    logger.info(`${signal} received, shutting down`);
    server.close(() => {
      void disconnectMongo().finally(() => process.exit(0));
    });
  };
  process.on('SIGTERM', () => shutdown('SIGTERM'));
  process.on('SIGINT', () => shutdown('SIGINT'));
}

main().catch((err: unknown) => {
  logger.fatal({ err }, 'Failed to start');
  process.exit(1);
});
