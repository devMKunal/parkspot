import cors from 'cors';
import express, { type Express } from 'express';
import helmet from 'helmet';
import { pinoHttp } from 'pino-http';
import { errorHandler, notFoundHandler } from './core/errors/errorHandler.js';
import { logger } from './core/logger.js';
import type { BookingService } from './modules/bookings/booking.service.js';
import type { ExtensionService } from './modules/bookings/extension.service.js';
import { bookingsRouter } from './modules/bookings/bookings.routes.js';
import type { PaymentService } from './modules/payments/payment.service.js';
import { paymentsRouter, webhooksRouter } from './modules/payments/payments.routes.js';
import type { LotRepository } from './modules/lots/lot.repository.js';
import { lotsRouter } from './modules/lots/lots.routes.js';
import { authRouter } from './modules/auth/auth.routes.js';
import type { AuthService } from './modules/auth/auth.service.js';
import type { TokenService } from './modules/auth/token.service.js';
import type { UserRepository } from './modules/users/user.repository.js';
import { usersRouter } from './modules/users/users.routes.js';

export interface AppDeps {
  auth: AuthService;
  tokens: TokenService;
  users: UserRepository;
  lots: LotRepository;
  bookings: BookingService;
  extensions: ExtensionService;
  payments: PaymentService;
  corsOrigins?: string[];
  /** Off in tests so suites can hammer /login. */
  rateLimit?: boolean;
}

/** Builds the Express app from its dependencies. No I/O here, so tests can inject fakes. */
export function createApp(deps: AppDeps): Express {
  const app = express();

  app.disable('x-powered-by');
  app.use(helmet());
  app.use(cors({ origin: deps.corsOrigins ?? [] }));
  // Webhooks first: they need the raw body for signature checks, before JSON parsing.
  app.use('/v1/webhooks', webhooksRouter({ payments: deps.payments }));
  app.use(express.json({ limit: '100kb' }));
  app.use(pinoHttp({ logger }));

  app.get('/health', (_req, res) => {
    res.json({ status: 'ok' });
  });

  app.use('/v1/auth', authRouter(deps.auth, { rateLimit: deps.rateLimit }));
  app.use('/v1/lots', lotsRouter({ lots: deps.lots }));
  app.use(
    '/v1',
    bookingsRouter({ bookings: deps.bookings, extensions: deps.extensions, tokens: deps.tokens }),
  );
  app.use('/v1', paymentsRouter({ payments: deps.payments, tokens: deps.tokens }));
  app.use('/v1', usersRouter({ users: deps.users, tokens: deps.tokens }));

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}
