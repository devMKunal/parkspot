import express, { Router } from 'express';
import { z } from 'zod';
import { validateBody } from '../../core/http/validate.js';
import { authenticate } from '../../core/middleware/authenticate.js';
import type { TokenService } from '../auth/token.service.js';
import { toBookingDto } from '../bookings/booking.types.js';
import type { PaymentService } from './payment.service.js';

const VerifyBody = z.object({
  orderId: z.string().min(1),
  paymentId: z.string().min(1),
  signature: z.string().min(1),
});

/** Mounted at /v1. */
export function paymentsRouter(deps: { payments: PaymentService; tokens: TokenService }): Router {
  const router = Router();

  router.post(
    '/payments/verify',
    authenticate(deps.tokens),
    validateBody(VerifyBody),
    async (req, res) => {
      const booking = await deps.payments.verifyCheckout(
        req.auth!.userId,
        req.body as z.infer<typeof VerifyBody>,
      );
      res.json({ booking: toBookingDto(booking) });
    },
  );

  return router;
}

/**
 * Mounted before express.json(): the signature covers the exact bytes Razorpay sent,
 * so the body must stay raw until it has been verified.
 */
export function webhooksRouter(deps: { payments: PaymentService }): Router {
  const router = Router();

  router.post(
    '/razorpay',
    express.raw({ type: 'application/json', limit: '1mb' }),
    async (req, res) => {
      const body = Buffer.isBuffer(req.body) ? req.body : Buffer.alloc(0);
      await deps.payments.handleWebhook(body, req.get('x-razorpay-signature'));
      res.json({ ok: true });
    },
  );

  return router;
}
