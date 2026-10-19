import { randomBytes } from 'node:crypto';
import { Errors } from '../../core/errors/AppError.js';
import { logger } from '../../core/logger.js';
import {
  BUCKET_MINUTES,
  addMinutes,
  bucketsBetween,
  floorToBucket,
  isOnBucketBoundary,
} from '../../core/time.js';
import type { LotRepository } from '../lots/lot.repository.js';
import type { SlotHoldRepository, SlotRepository } from '../lots/slot.repository.js';
import type { PaymentGateway, PaymentProvider } from '../payments/payment.gateway.js';
import type { BookingStatus } from './booking.model.js';
import type { BookingRepository } from './booking.repository.js';
import type { ExtensionRepository } from './extension.repository.js';
import type { BookingRecord } from './booking.types.js';
import type { CreateBookingInput } from './bookings.schemas.js';

/** How far in the past a start may be (a driver booking "now" a few minutes late). */
const START_GRACE_MINUTES = 5;
const MAX_DAYS_AHEAD = 7;
/** Check-in opens this long before the booked start. */
const CHECKIN_EARLY_MINUTES = 15;

const newPassCode = () => randomBytes(4).toString('hex').toUpperCase();

export interface BookingServiceDeps {
  bookings: BookingRepository;
  lots: LotRepository;
  slots: SlotRepository;
  holds: SlotHoldRepository;
  extensions: ExtensionRepository;
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

export interface PaidPayment {
  orderId: string;
  paymentId: string;
  /** Known from webhooks; the checkout signature already binds the payment to our order. */
  amountPaise?: number;
}

/** `orderPaise` is what this order charged: the amount to record, and to refund if needed. */
export type ConfirmOutcome =
  | { kind: 'CONFIRMED'; booking: BookingRecord; orderPaise: number }
  | { kind: 'ALREADY_CONFIRMED'; booking: BookingRecord; orderPaise: number }
  /** The money arrived but nothing can honour it: the caller must refund. */
  | { kind: 'REFUND'; booking: BookingRecord; orderPaise: number; reason: string }
  | { kind: 'UNKNOWN_ORDER' };

const PAID_STATUSES: BookingStatus[] = ['CONFIRMED', 'ACTIVE', 'COMPLETED'];

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
    return this.refreshStatus(booking);
  }

  async listForUser(userId: string, statuses?: BookingStatus[]): Promise<BookingRecord[]> {
    const list = await this.deps.bookings.listByUser(userId);
    const fresh = await Promise.all(list.map((b) => this.refreshStatus(b)));
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

  /** The simulated gate scan: the pass code from the QR turns CONFIRMED into ACTIVE. */
  async checkIn(userId: string, bookingId: string, passCode: string): Promise<BookingRecord> {
    const booking = await this.getForUser(userId, bookingId);
    const now = this.now();

    if (booking.status !== 'CONFIRMED') {
      throw Errors.checkinNotAllowed(`A ${booking.status} booking can't be checked in`);
    }
    if (now < addMinutes(booking.start, -CHECKIN_EARLY_MINUTES)) {
      throw Errors.checkinNotAllowed(
        `Check-in opens ${CHECKIN_EARLY_MINUTES} minutes before the start`,
      );
    }
    if (passCode.trim().toUpperCase() !== booking.passCode) throw Errors.passCodeInvalid();

    const active = await this.deps.bookings.transition(booking.id, ['CONFIRMED'], 'ACTIVE');
    if (!active) throw Errors.checkinNotAllowed('The booking changed, refresh and try again');
    return active;
  }

  /** Leaving early: the slot frees from the next 15-minute bucket on. No partial refund (MVP). */
  async end(userId: string, bookingId: string): Promise<BookingRecord> {
    const booking = await this.getForUser(userId, bookingId);
    if (booking.status !== 'ACTIVE') throw Errors.endNotAllowed(booking.status);

    const now = this.now();
    const ended = await this.deps.bookings.transition(booking.id, ['ACTIVE'], 'COMPLETED', {
      endedAt: now,
    });
    if (!ended) throw Errors.endNotAllowed((await this.getForUser(userId, bookingId)).status);

    const extensions = await this.deps.extensions.listByBooking(booking.id, ['CONFIRMED']);
    await this.deps.holds.releaseFrom(
      [booking.id, ...extensions.map((e) => e.id)],
      addMinutes(floorToBucket(now), BUCKET_MINUTES),
    );
    return ended;
  }

  /** Who may verify a payment for this order, or null if it isn't a booking's order. */
  async ownerOfOrder(orderId: string): Promise<string | null> {
    return (await this.deps.bookings.findByOrderId(orderId))?.userId ?? null;
  }

  /**
   * Applies a verified payment. Safe to call any number of times, from the app's verify call and
   * the webhook alike: the PENDING/EXPIRED → CONFIRMED compare-and-set picks a single winner.
   */
  async confirmPaid(payment: PaidPayment): Promise<ConfirmOutcome> {
    const { bookings, holds } = this.deps;
    const booking = await bookings.findByOrderId(payment.orderId);
    if (!booking) return { kind: 'UNKNOWN_ORDER' };

    if (PAID_STATUSES.includes(booking.status)) {
      return booking.paymentId === payment.paymentId
        ? { kind: 'ALREADY_CONFIRMED', booking, orderPaise: booking.amountPaise }
        : {
            kind: 'REFUND',
            booking,
            orderPaise: booking.amountPaise,
            reason: 'Order already paid by another payment',
          };
    }
    if (payment.amountPaise !== undefined && payment.amountPaise !== booking.amountPaise) {
      return {
        kind: 'REFUND',
        booking,
        orderPaise: booking.amountPaise,
        reason: 'Paid amount does not match the booking',
      };
    }
    if (booking.status === 'CANCELLED' || booking.status === 'FAILED') {
      return {
        kind: 'REFUND',
        booking,
        orderPaise: booking.amountPaise,
        reason: `Payment arrived for a ${booking.status} booking`,
      };
    }

    const confirmed = await bookings.transition(booking.id, ['PENDING', 'EXPIRED'], 'CONFIRMED', {
      paymentId: payment.paymentId,
      lockExpiresAt: null,
      passCode: newPassCode(),
    });
    // Lost the race to the other path (verify vs webhook): report what it decided.
    if (!confirmed) return this.confirmPaid(payment);

    const buckets = bucketsBetween(confirmed.start, confirmed.end);
    if ((await holds.confirmBooking(confirmed.id)) === buckets.length) {
      return { kind: 'CONFIRMED', booking: confirmed, orderPaise: confirmed.amountPaise };
    }

    // The lock lapsed and part of the window was taken. Try the same slot, then any slot.
    await holds.releaseBooking(confirmed.id);
    const slot = await this.claimAnySlot(
      confirmed.lotId,
      confirmed.id,
      confirmed.start,
      confirmed.end,
      null,
      confirmed.slotId,
    );
    if (slot) {
      if (slot.id !== confirmed.slotId)
        await bookings.reassignSlot(confirmed.id, slot.id, slot.label);
      return {
        kind: 'CONFIRMED',
        booking: { ...confirmed, slotId: slot.id, slotLabel: slot.label },
        orderPaise: confirmed.amountPaise,
      };
    }

    const failed = await bookings.transition(confirmed.id, ['CONFIRMED'], 'FAILED');
    return {
      kind: 'REFUND',
      booking: failed ?? confirmed,
      orderPaise: confirmed.amountPaise,
      reason: 'Lock expired and the lot filled up before payment',
    };
  }

  private assertBookableWindow(start: Date, now: Date): void {
    const fieldError = (message: string) => Errors.validation({ start: [message] });
    if (!isOnBucketBoundary(start)) throw fieldError('Start must be on a 15-minute boundary');
    if (start < addMinutes(now, -START_GRACE_MINUTES)) throw fieldError('Start is in the past');
    if (start > addMinutes(now, MAX_DAYS_AHEAD * 24 * 60)) {
      throw fieldError(`Start must be within ${MAX_DAYS_AHEAD} days`);
    }
  }

  /**
   * Tries the slots that look free first (the preferred one ahead of the rest);
   * the unique index arbitrates any race. `expiresAt: null` claims permanently.
   */
  private async claimAnySlot(
    lotId: string,
    bookingId: string,
    start: Date,
    end: Date,
    expiresAt: Date | null,
    preferredSlotId?: string,
  ) {
    const { slots, holds } = this.deps;
    const now = this.now();
    const buckets = bucketsBetween(start, end);
    const busy = await holds.busySlotIds(lotId, buckets, now);
    const candidates = (await slots.listByLot(lotId))
      .filter((s) => !busy.has(s.id))
      .sort((a, b) => Number(b.id === preferredSlotId) - Number(a.id === preferredSlotId));

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

  /**
   * Applies time-based transitions lazily on read: PENDING past its lock is EXPIRED (its holds
   * lapse via TTL), and CONFIRMED or ACTIVE past its end is COMPLETED.
   */
  private async refreshStatus(booking: BookingRecord): Promise<BookingRecord> {
    const now = this.now();
    const { bookings } = this.deps;
    let next: BookingRecord | null;

    if (booking.status === 'PENDING' && booking.lockExpiresAt && booking.lockExpiresAt <= now) {
      next = await bookings.transition(booking.id, ['PENDING'], 'EXPIRED');
    } else if (
      (booking.status === 'CONFIRMED' || booking.status === 'ACTIVE') &&
      booking.end <= now
    ) {
      next = await bookings.transition(booking.id, ['CONFIRMED', 'ACTIVE'], 'COMPLETED', {
        endedAt: booking.end,
      });
    } else {
      return booking;
    }
    return next ?? (await bookings.findById(booking.id)) ?? booking;
  }

  private now(): Date {
    return this.deps.now?.() ?? new Date();
  }
}
