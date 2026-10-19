import { Router } from 'express';
import { validateBody, parseOrThrow } from '../../core/http/validate.js';
import { authenticate } from '../../core/middleware/authenticate.js';
import type { TokenService } from '../auth/token.service.js';
import type { BookingService } from './booking.service.js';
import { toBookingDto } from './booking.types.js';
import {
  CreateBookingBody,
  ListBookingsQuery,
  type CreateBookingInput,
} from './bookings.schemas.js';

/** Mounted at /v1. Every route needs a logged-in driver. */
export function bookingsRouter(deps: { bookings: BookingService; tokens: TokenService }): Router {
  const router = Router();
  const auth = authenticate(deps.tokens);

  router.post('/bookings', auth, validateBody(CreateBookingBody), async (req, res) => {
    const { booking, payment } = await deps.bookings.create(
      req.auth!.userId,
      req.body as CreateBookingInput,
    );
    res.status(201).json({ booking: toBookingDto(booking), payment });
  });

  router.get('/bookings/:id', auth, async (req, res) => {
    const booking = await deps.bookings.getForUser(req.auth!.userId, req.params.id as string);
    res.json({ booking: toBookingDto(booking) });
  });

  router.post('/bookings/:id/cancel', auth, async (req, res) => {
    const booking = await deps.bookings.cancel(req.auth!.userId, req.params.id as string);
    res.json({ booking: toBookingDto(booking) });
  });

  router.get('/me/bookings', auth, async (req, res) => {
    const { status } = parseOrThrow(ListBookingsQuery, req.query);
    const bookings = await deps.bookings.listForUser(req.auth!.userId, status);
    res.json({ bookings: bookings.map(toBookingDto) });
  });

  return router;
}
