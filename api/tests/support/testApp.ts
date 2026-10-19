import { createApp } from '../../src/app.js';
import { AuthService } from '../../src/modules/auth/auth.service.js';
import { TokenService } from '../../src/modules/auth/token.service.js';
import { BookingService } from '../../src/modules/bookings/booking.service.js';
import { ExtensionService } from '../../src/modules/bookings/extension.service.js';
import { PaymentService } from '../../src/modules/payments/payment.service.js';
import {
  FakePasswordHasher,
  FakePaymentGateway,
  InMemoryBookingRepository,
  InMemoryExtensionRepository,
  InMemoryLotRepository,
  InMemoryPaymentRepository,
  InMemoryRefreshTokenRepository,
  InMemorySlotHoldRepository,
  InMemorySlotRepository,
  InMemoryUserRepository,
  TEST_TOKEN_CONFIG,
} from './fakes.js';

export interface TestAppOptions {
  now?: () => Date;
  /** Pass null to simulate a server without Razorpay keys. */
  payments?: FakePaymentGateway | null;
}

export function buildTestApp(opts: TestAppOptions = {}) {
  const users = new InMemoryUserRepository();
  const refreshTokens = new InMemoryRefreshTokenRepository();
  const lots = new InMemoryLotRepository();
  const slots = new InMemorySlotRepository();
  const holds = new InMemorySlotHoldRepository();
  const bookingRepo = new InMemoryBookingRepository();
  const extensionRepo = new InMemoryExtensionRepository();
  const payments = opts.payments === undefined ? new FakePaymentGateway() : opts.payments;
  const hasher = new FakePasswordHasher();
  const tokens = new TokenService(TEST_TOKEN_CONFIG, opts.now);
  const auth = new AuthService({ users, refreshTokens, hasher, tokens, now: opts.now });
  const bookings = new BookingService({
    bookings: bookingRepo,
    extensions: extensionRepo,
    lots,
    slots,
    holds,
    payments,
    lockMinutes: 10,
    now: opts.now,
  });
  const extensions = new ExtensionService({
    bookings: bookingRepo,
    extensions: extensionRepo,
    lots,
    holds,
    payments,
    lockMinutes: 10,
    now: opts.now,
  });
  const paymentRepo = new InMemoryPaymentRepository();
  const paymentService = new PaymentService({
    gateway: payments,
    bookingService: bookings,
    extensionService: extensions,
    payments: paymentRepo,
  });
  const app = createApp({
    auth,
    tokens,
    users,
    lots,
    bookings,
    extensions,
    payments: paymentService,
    rateLimit: false,
  });
  return {
    app,
    users,
    lots,
    slots,
    holds,
    bookingRepo,
    extensionRepo,
    payments,
    paymentRepo,
    refreshTokens,
    hasher,
    tokens,
    auth,
  };
}
