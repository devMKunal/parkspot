import { createApp } from './app.js';
import { loadEnv } from './config/env.js';
import { logger } from './core/logger.js';
import { connectMongo, disconnectMongo } from './infra/db/mongo.js';
import { AuthService } from './modules/auth/auth.service.js';
import { Argon2PasswordHasher } from './modules/auth/password.hasher.js';
import { MongoRefreshTokenRepository } from './modules/auth/refreshToken.repository.js';
import { TokenService } from './modules/auth/token.service.js';
import { MongoBookingRepository } from './modules/bookings/booking.repository.js';
import { BookingService } from './modules/bookings/booking.service.js';
import { MongoExtensionRepository } from './modules/bookings/extension.repository.js';
import { ExtensionService } from './modules/bookings/extension.service.js';
import { MongoLotRepository } from './modules/lots/lot.repository.js';
import { MongoSlotHoldRepository, MongoSlotRepository } from './modules/lots/slot.repository.js';
import { MongoPaymentRepository } from './modules/payments/payment.repository.js';
import { PaymentService } from './modules/payments/payment.service.js';
import { RazorpayGateway } from './modules/payments/razorpay.gateway.js';
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

  const lots = new MongoLotRepository();
  const gateway =
    env.RAZORPAY_KEY_ID && env.RAZORPAY_KEY_SECRET
      ? new RazorpayGateway({
          keyId: env.RAZORPAY_KEY_ID,
          keySecret: env.RAZORPAY_KEY_SECRET,
          webhookSecret: env.RAZORPAY_WEBHOOK_SECRET,
        })
      : null;
  if (!gateway) logger.warn('Razorpay keys not set: POST /v1/bookings will return 503');

  if (gateway && !env.RAZORPAY_WEBHOOK_SECRET) {
    logger.warn('RAZORPAY_WEBHOOK_SECRET not set: webhooks will be rejected');
  }

  const bookingRepo = new MongoBookingRepository();
  const extensionRepo = new MongoExtensionRepository();
  const holds = new MongoSlotHoldRepository();
  const bookings = new BookingService({
    bookings: bookingRepo,
    extensions: extensionRepo,
    lots,
    slots: new MongoSlotRepository(),
    holds,
    payments: gateway,
    lockMinutes: env.BOOKING_LOCK_MINUTES,
  });
  const extensions = new ExtensionService({
    bookings: bookingRepo,
    extensions: extensionRepo,
    lots,
    holds,
    payments: gateway,
    lockMinutes: env.BOOKING_LOCK_MINUTES,
  });
  const paymentService = new PaymentService({
    gateway,
    bookingService: bookings,
    extensionService: extensions,
    payments: new MongoPaymentRepository(),
  });

  const app = createApp({
    auth,
    tokens,
    users,
    lots,
    bookings,
    extensions,
    payments: paymentService,
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
