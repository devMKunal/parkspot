import { Errors } from '../../core/errors/AppError.js';
import { logger } from '../../core/logger.js';
import { addMinutes, bucketsBetween } from '../../core/time.js';
import type { LotRepository } from '../lots/lot.repository.js';
import type { SlotHoldRepository } from '../lots/slot.repository.js';
import type { PaymentGateway } from '../payments/payment.gateway.js';
import type { BookingRepository } from './booking.repository.js';
import type { CheckoutPayload, ConfirmOutcome, PaidPayment } from './booking.service.js';
import type { BookingRecord, ExtensionRecord } from './booking.types.js';
import type { ExtensionRepository } from './extension.repository.js';

export interface ExtensionServiceDeps {
  bookings: BookingRepository;
  extensions: ExtensionRepository;
  lots: LotRepository;
  holds: SlotHoldRepository;
  payments: PaymentGateway | null;
  lockMinutes: number;
  now?: () => Date;
}

export interface CreatedExtension {
  extension: ExtensionRecord;
  payment: CheckoutPayload;
}

/**
 * Paid extra time on a live booking (docs/active-booking-api.md). The extension claims the same
 * slot from the booking's current end, with its own lock and its own order.
 */
export class ExtensionService {
  constructor(private readonly deps: ExtensionServiceDeps) {}

  async extend(userId: string, bookingId: string, minutes: number): Promise<CreatedExtension> {
    const { bookings, extensions, lots, holds, payments } = this.deps;
    if (!payments) throw Errors.paymentsUnavailable();

    const booking = await bookings.findById(bookingId);
    if (!booking || booking.userId !== userId) throw Errors.notFound('Booking');
    const now = this.now();
    if (booking.status !== 'CONFIRMED' && booking.status !== 'ACTIVE') {
      throw Errors.extensionNotAllowed(`A ${booking.status} booking can't be extended`);
    }
    if (booking.end <= now) throw Errors.extensionNotAllowed('The booking has already ended');

    const lot = await lots.findById(booking.lotId);
    if (!lot) throw Errors.notFound('Lot');

    // One pending extension per booking: asking again replaces it.
    for (const pending of await extensions.listByBooking(booking.id, ['PENDING'])) {
      if (
        await extensions.transition(pending.id, ['PENDING'], 'CANCELLED', { lockExpiresAt: null })
      ) {
        await holds.releaseBooking(pending.id);
      }
    }

    const id = extensions.newId();
    const start = booking.end;
    const end = addMinutes(start, minutes);
    const lockExpiresAt = addMinutes(now, this.deps.lockMinutes);
    const claimed = await holds.tryClaim(
      {
        slotId: booking.slotId,
        lotId: booking.lotId,
        bookingId: id,
        buckets: bucketsBetween(start, end),
        expiresAt: lockExpiresAt,
      },
      now,
    );
    if (!claimed) throw Errors.extensionUnavailable();

    const extension = await extensions.create({
      id,
      bookingId: booking.id,
      userId,
      start,
      end,
      minutes,
      amountPaise: Math.round((lot.pricePerHourPaise * minutes) / 60),
      status: 'PENDING',
      lockExpiresAt,
    });

    try {
      const order = await payments.createOrder({
        amountPaise: extension.amountPaise,
        currency: 'INR',
        receipt: extension.id,
        notes: { bookingId: booking.id, extensionId: extension.id },
      });
      await extensions.attachOrder(extension.id, order.orderId);
      return {
        extension: { ...extension, orderId: order.orderId },
        payment: {
          provider: order.provider,
          keyId: payments.publicKey,
          orderId: order.orderId,
          amount: order.amountPaise,
          currency: order.currency,
        },
      };
    } catch (err) {
      logger.error({ err, extensionId: extension.id }, 'Extension order failed; releasing time');
      await holds.releaseBooking(extension.id);
      await extensions.transition(extension.id, ['PENDING'], 'FAILED', { lockExpiresAt: null });
      throw Errors.paymentProvider();
    }
  }

  async ownerOfOrder(orderId: string): Promise<string | null> {
    return (await this.deps.extensions.findByOrderId(orderId))?.userId ?? null;
  }

  /** Same contract as BookingService.confirmPaid, for an extension's order. */
  async confirmPaid(payment: PaidPayment): Promise<ConfirmOutcome> {
    const { bookings, extensions, holds } = this.deps;
    const extension = await extensions.findByOrderId(payment.orderId);
    if (!extension) return { kind: 'UNKNOWN_ORDER' };
    const booking = await bookings.findById(extension.bookingId);
    if (!booking) return { kind: 'UNKNOWN_ORDER' };

    const orderPaise = extension.amountPaise;
    const refund = (reason: string): ConfirmOutcome => ({
      kind: 'REFUND',
      booking,
      orderPaise,
      reason,
    });

    if (extension.status === 'CONFIRMED') {
      return extension.paymentId === payment.paymentId
        ? { kind: 'ALREADY_CONFIRMED', booking, orderPaise }
        : refund('Extension already paid by another payment');
    }
    if (payment.amountPaise !== undefined && payment.amountPaise !== extension.amountPaise) {
      return refund('Paid amount does not match the extension');
    }
    if (extension.status === 'CANCELLED' || extension.status === 'FAILED') {
      return refund(`Payment arrived for a ${extension.status} extension`);
    }
    if (booking.end <= this.now()) return this.fail(extension, booking, 'Booking already ended');

    const won = await extensions.transition(extension.id, ['PENDING', 'EXPIRED'], 'CONFIRMED', {
      paymentId: payment.paymentId,
      lockExpiresAt: null,
    });
    if (!won) return this.confirmPaid(payment);

    const buckets = bucketsBetween(extension.start, extension.end);
    if ((await holds.confirmBooking(extension.id)) !== buckets.length) {
      // The lock lapsed: the car is in this slot, so only this slot will do.
      await holds.releaseBooking(extension.id);
      const reclaimed = await holds.tryClaim(
        {
          slotId: booking.slotId,
          lotId: booking.lotId,
          bookingId: extension.id,
          buckets,
          expiresAt: null,
        },
        this.now(),
      );
      if (!reclaimed) return this.fail(won, booking, 'Slot was booked after the lock expired');
    }

    const extended = await bookings.applyExtension(
      booking.id,
      extension.start,
      extension.end,
      extension.amountPaise,
    );
    if (!extended) return this.fail(won, booking, 'Booking changed before the extension applied');
    return { kind: 'CONFIRMED', booking: extended, orderPaise };
  }

  private async fail(
    extension: ExtensionRecord,
    booking: BookingRecord,
    reason: string,
  ): Promise<ConfirmOutcome> {
    await this.deps.holds.releaseBooking(extension.id);
    await this.deps.extensions.transition(
      extension.id,
      ['PENDING', 'EXPIRED', 'CONFIRMED'],
      'FAILED',
    );
    return { kind: 'REFUND', booking, orderPaise: extension.amountPaise, reason };
  }

  private now(): Date {
    return this.deps.now?.() ?? new Date();
  }
}
