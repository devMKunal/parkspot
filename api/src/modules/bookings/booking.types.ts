import type { Money } from '../lots/lot.types.js';
import type { BookingStatus } from './booking.model.js';

export interface BookingRecord {
  id: string;
  userId: string;
  lotId: string;
  slotId: string;
  slotLabel: string;
  start: Date;
  end: Date;
  amountPaise: number;
  currency: 'INR';
  status: BookingStatus;
  lockExpiresAt: Date | null;
  provider: string | null;
  orderId: string | null;
  paymentId: string | null;
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
  createdAt: string;
}

export const toBookingDto = (b: BookingRecord): BookingDto => ({
  id: b.id,
  lotId: b.lotId,
  slotLabel: b.slotLabel,
  start: b.start.toISOString(),
  end: b.end.toISOString(),
  amount: { amount: b.amountPaise, currency: b.currency },
  status: b.status,
  lockExpiresAt: b.lockExpiresAt?.toISOString() ?? null,
  createdAt: b.createdAt.toISOString(),
});
