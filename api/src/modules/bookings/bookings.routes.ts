import { Router } from 'express';
import { validateBody, parseOrThrow } from '../../core/http/validate.js';
import { authenticate } from '../../core/middleware/authenticate.js';
import type { TokenService } from '../auth/token.service.js';
import type { BookingService } from './booking.service.js';
import type { ExtensionService } from './extension.service.js';
import { toBookingDto, toExtensionDto } from './booking.types.js';
import {
  CheckInBody,
  CreateBookingBody,
  ExtendBody,
  ListBookingsQuery,
  type CreateBookingInput,
} from './bookings.schemas.js';

/** Mounted at /v1. Every route needs a logged-in driver. */
export function bookingsRouter(deps: {
  bookings: BookingService;
  extensions: ExtensionService;
  tokens: TokenService;
}): Router {
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

  router.post('/bookings/:id/checkin', auth, validateBody(CheckInBody), async (req, res) => {
    const { passCode } = req.body as { passCode: string };
    const booking = await deps.bookings.checkIn(
      req.auth!.userId,
      req.params.id as string,
      passCode,
    );
    res.json({ booking: toBookingDto(booking) });
  });

  router.post('/bookings/:id/extend', auth, validateBody(ExtendBody), async (req, res) => {
    const { minutes } = req.body as { minutes: number };
    const { extension, payment } = await deps.extensions.extend(
      req.auth!.userId,
      req.params.id as string,
      minutes,
    );
    res.status(201).json({ extension: toExtensionDto(extension), payment });
  });

  router.post('/bookings/:id/end', auth, async (req, res) => {
    const booking = await deps.bookings.end(req.auth!.userId, req.params.id as string);
    res.json({ booking: toBookingDto(booking) });
  });

  router.get('/me/bookings', auth, async (req, res) => {
    const { status } = parseOrThrow(ListBookingsQuery, req.query);
    const bookings = await deps.bookings.listForUser(req.auth!.userId, status);
    res.json({ bookings: bookings.map(toBookingDto) });
  });

  return router;
}
