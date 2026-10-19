import type { Money } from '../lots/lot.types.js';
import type { BookingStatus, ExtensionStatus } from './booking.model.js';

export interface BookingRecord {
  id: string;
  userId: string;
  lotId: string;
  slotId: string;
  slotLabel: string;
  start: Date;
  end: Date;
  /** Charged by the booking's own order. */
  amountPaise: number;
  /** Charged by paid extensions' orders. */
  extensionsPaise: number;
  currency: 'INR';
  status: BookingStatus;
  lockExpiresAt: Date | null;
  provider: string | null;
  orderId: string | null;
  paymentId: string | null;
  passCode: string | null;
  endedAt: Date | null;
  createdAt: Date;
}

export interface BookingDto {
  id: string;
  lotId: string;
  slotLabel: string;
  start: string;
  end: string;
  amount: Money;
  status: BookingStatus;
  lockExpiresAt: string | null;
  /** Present only while the pass is usable (CONFIRMED or ACTIVE). */
  passCode: string | null;
  endedAt: string | null;
  createdAt: string;
}

export const toBookingDto = (b: BookingRecord): BookingDto => ({
  id: b.id,
  lotId: b.lotId,
  slotLabel: b.slotLabel,
  start: b.start.toISOString(),
  end: b.end.toISOString(),
  /** Total paid for the booking, extensions included. */
  amount: { amount: b.amountPaise + b.extensionsPaise, currency: b.currency },
  status: b.status,
  lockExpiresAt: b.lockExpiresAt?.toISOString() ?? null,
  passCode: b.status === 'CONFIRMED' || b.status === 'ACTIVE' ? b.passCode : null,
  endedAt: b.endedAt?.toISOString() ?? null,
  createdAt: b.createdAt.toISOString(),
});

export interface ExtensionRecord {
  id: string;
  bookingId: string;
  userId: string;
  start: Date;
  end: Date;
  minutes: number;
  amountPaise: number;
  status: ExtensionStatus;
  lockExpiresAt: Date | null;
  orderId: string | null;
  paymentId: string | null;
}

export interface ExtensionDto {
  id: string;
  bookingId: string;
  start: string;
  end: string;
  amount: Money;
  status: ExtensionStatus;
  lockExpiresAt: string | null;
}

export const toExtensionDto = (e: ExtensionRecord): ExtensionDto => ({
  id: e.id,
  bookingId: e.bookingId,
  start: e.start.toISOString(),
  end: e.end.toISOString(),
  amount: { amount: e.amountPaise, currency: 'INR' },
  status: e.status,
  lockExpiresAt: e.lockExpiresAt?.toISOString() ?? null,
});
