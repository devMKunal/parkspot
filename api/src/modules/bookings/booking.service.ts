import { Errors } from '../../core/errors/AppError.js';
import { logger } from '../../core/logger.js';
import { addMinutes, bucketsBetween, isOnBucketBoundary } from '../../core/time.js';
import type { LotRepository } from '../lots/lot.repository.js';
import type { SlotHoldRepository, SlotRepository } from '../lots/slot.repository.js';
import type { PaymentGateway, PaymentProvider } from '../payments/payment.gateway.js';
import type { BookingStatus } from './booking.model.js';
import type { BookingRepository } from './booking.repository.js';
import type { BookingRecord } from './booking.types.js';
import type { CreateBookingInput } from './bookings.schemas.js';

/** How far in the past a start may be (a driver booking "now" a few minutes late). */
const START_GRACE_MINUTES = 5;
const MAX_DAYS_AHEAD = 7;

export interface BookingServiceDeps {
  bookings: BookingRepository;
  lots: LotRepository;
  slots: SlotRepository;
  holds: SlotHoldRepository;
  /** null when Razorpay keys are not configured. */
  payments: PaymentGateway | null;
  lockMinutes: number;
  now?: () => Date;
}

export interface CheckoutPayload {
  provider: PaymentProvider;
  keyId: string;
  orderId: string;
  amount: number;
  currency: 'INR';
}

export interface CreatedBooking {
  booking: BookingRecord;
  payment: CheckoutPayload;
}

/**
 * Booking use cases. The slot-locking design is in docs/bookings-api.md: a booking claims
 * 15-minute holds on one slot, and a unique index makes overlapping claims impossible.
 */
export class BookingService {
  constructor(private readonly deps: BookingServiceDeps) {}

  async create(userId: string, input: CreateBookingInput): Promise<CreatedBooking> {
    const { bookings, lots, payments, holds } = this.deps;
    const now = this.now();

    // Fail before touching any slot when payments can't work anyway.
    if (!payments) throw Errors.paymentsUnavailable();

    this.assertBookableWindow(input.start, now);
    const lot = await lots.findById(input.lotId);
    if (!lot) throw Errors.notFound('Lot');

    // One unpaid checkout per driver: starting a new one abandons the previous one.
    await this.cancelPendingOf(userId);

    const end = addMinutes(input.start, input.durationMinutes);
    const bookingId = bookings.newId();
    const lockExpiresAt = addMinutes(now, this.deps.lockMinutes);
    const slot = await this.claimAnySlot(lot.id, bookingId, input.start, end, lockExpiresAt);
    if (!slot) throw Errors.lotFull();

    const booking = await bookings.create({
      id: bookingId,
      userId,
      lotId: lot.id,
      slotId: slot.id,
      slotLabel: slot.label,
      start: input.start,
      end,
      amountPaise: Math.round((lot.pricePerHourPaise * input.durationMinutes) / 60),
      currency: 'INR',
      status: 'PENDING',
      lockExpiresAt,
    });

    try {
      const order = await payments.createOrder({
        amountPaise: booking.amountPaise,
        currency: booking.currency,
        receipt: booking.id,
        notes: { bookingId: booking.id, lotId: lot.id },
      });
      await bookings.attachOrder(booking.id, order.provider, order.orderId);
      return {
        booking: { ...booking, provider: order.provider, orderId: order.orderId },
        payment: {
          provider: order.provider,
          keyId: payments.publicKey,
          orderId: order.orderId,
          amount: order.amountPaise,
          currency: order.currency,
        },
      };
    } catch (err) {
      logger.error({ err, bookingId: booking.id }, 'Order creation failed; releasing slot');
      await holds.releaseBooking(booking.id);
      await bookings.transition(booking.id, ['PENDING'], 'FAILED', { lockExpiresAt: null });
      throw Errors.paymentProvider();
    }
  }

  /** Returns the caller's booking, or 404 for anyone else's (don't leak that it exists). */
  async getForUser(userId: string, bookingId: string): Promise<BookingRecord> {
    const booking = await this.deps.bookings.findById(bookingId);
    if (!booking || booking.userId !== userId) throw Errors.notFound('Booking');
    return this.expireIfLapsed(booking);
  }

  async listForUser(userId: string, statuses?: BookingStatus[]): Promise<BookingRecord[]> {
    const list = await this.deps.bookings.listByUser(userId);
    const fresh = await Promise.all(list.map((b) => this.expireIfLapsed(b)));
    return statuses ? fresh.filter((b) => statuses.includes(b.status)) : fresh;
  }

  /** MVP: only an unpaid booking can be cancelled. Confirmed ones need refunds (Stretch). */
  async cancel(userId: string, bookingId: string): Promise<BookingRecord> {
    const booking = await this.getForUser(userId, bookingId);
    const cancelled = await this.deps.bookings.transition(booking.id, ['PENDING'], 'CANCELLED', {
      lockExpiresAt: null,
    });
    if (!cancelled) {
      const current = await this.getForUser(userId, bookingId);
      throw Errors.bookingNotCancellable(current.status);
    }
    await this.deps.holds.releaseBooking(booking.id);
    return cancelled;
  }

  private assertBookableWindow(start: Date, now: Date): void {
    const fieldError = (message: string) => Errors.validation({ start: [message] });
    if (!isOnBucketBoundary(start)) throw fieldError('Start must be on a 15-minute boundary');
    if (start < addMinutes(now, -START_GRACE_MINUTES)) throw fieldError('Start is in the past');
    if (start > addMinutes(now, MAX_DAYS_AHEAD * 24 * 60)) {
      throw fieldError(`Start must be within ${MAX_DAYS_AHEAD} days`);
    }
  }

  /** Tries the slots that look free first; the unique index arbitrates any race. */
  private async claimAnySlot(
    lotId: string,
    bookingId: string,
    start: Date,
    end: Date,
    expiresAt: Date,
  ) {
    const { slots, holds } = this.deps;
    const now = this.now();
    const buckets = bucketsBetween(start, end);
    const busy = await holds.busySlotIds(lotId, buckets, now);
    const candidates = (await slots.listByLot(lotId)).filter((s) => !busy.has(s.id));

    for (const slot of candidates) {
      const claimed = await holds.tryClaim(
        { slotId: slot.id, lotId, bookingId, buckets, expiresAt },
        now,
      );
      if (claimed) return slot;
    }
    return null;
  }

  private async cancelPendingOf(userId: string): Promise<void> {
    const pending = await this.deps.bookings.listByUser(userId, ['PENDING']);
    for (const booking of pending) {
      const cancelled = await this.deps.bookings.transition(booking.id, ['PENDING'], 'CANCELLED', {
        lockExpiresAt: null,
      });
      if (cancelled) await this.deps.holds.releaseBooking(booking.id);
    }
  }

  /** PENDING past its lock is EXPIRED; persisted lazily on read. Its holds lapse via TTL. */
  private async expireIfLapsed(booking: BookingRecord): Promise<BookingRecord> {
    if (booking.status !== 'PENDING' || !booking.lockExpiresAt) return booking;
    if (booking.lockExpiresAt > this.now()) return booking;
    const expired = await this.deps.bookings.transition(booking.id, ['PENDING'], 'EXPIRED');
    return expired ?? (await this.deps.bookings.findById(booking.id)) ?? booking;
  }

  private now(): Date {
    return this.deps.now?.() ?? new Date();
  }
}
