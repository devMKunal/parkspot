import { MongoMemoryServer } from 'mongodb-memory-server';
import mongoose, { Types } from 'mongoose';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { addMinutes, bucketsBetween } from '../../src/core/time.js';
import { BookingModel, ExtensionModel } from '../../src/modules/bookings/booking.model.js';
import { MongoExtensionRepository } from '../../src/modules/bookings/extension.repository.js';
import { MongoBookingRepository } from '../../src/modules/bookings/booking.repository.js';
import { SlotHoldModel } from '../../src/modules/lots/lot.model.js';
import { MongoSlotHoldRepository } from '../../src/modules/lots/slot.repository.js';
import { PaymentModel } from '../../src/modules/payments/payment.model.js';
import { MongoPaymentRepository } from '../../src/modules/payments/payment.repository.js';

/** Proves the slot lock against real MongoDB indexes. Run with `npm run test:int`. */
describe('slot holds and bookings on MongoDB', () => {
  let mongod: MongoMemoryServer;
  const holds = new MongoSlotHoldRepository();
  const bookings = new MongoBookingRepository();
  const paymentRepo = new MongoPaymentRepository();
  const extensions = new MongoExtensionRepository();
  const lotId = new Types.ObjectId().toString();
  const slotId = new Types.ObjectId().toString();
  const now = new Date('2026-10-19T09:42:00Z');
  const start = new Date('2026-10-19T10:00:00Z');
  const twoHours = bucketsBetween(start, addMinutes(start, 120));
  const newBooking = () => new Types.ObjectId().toString();
  const claim = (
    bookingId: string,
    buckets = twoHours,
    expiresAt: Date | null = addMinutes(now, 10),
  ) => holds.tryClaim({ slotId, lotId, bookingId, buckets, expiresAt }, now);

  beforeAll(async () => {
    mongod = await MongoMemoryServer.create();
    await mongoose.connect(mongod.getUri());
    await Promise.all([
      SlotHoldModel.syncIndexes(),
      BookingModel.syncIndexes(),
      PaymentModel.syncIndexes(),
      ExtensionModel.syncIndexes(),
    ]);
  });

  afterAll(async () => {
    await mongoose.disconnect();
    await mongod.stop();
  });

  beforeEach(async () => {
    await Promise.all([
      SlotHoldModel.deleteMany({}),
      BookingModel.deleteMany({}),
      PaymentModel.deleteMany({}),
      ExtensionModel.deleteMany({}),
    ]);
  });

  it('only one of many parallel claims on the same slot and window wins', async () => {
    const results = await Promise.all(Array.from({ length: 8 }, () => claim(newBooking())));
    expect(results.filter(Boolean)).toHaveLength(1);
    expect(await SlotHoldModel.countDocuments()).toBe(8);
  });

  it('a partly overlapping claim fails and leaves nothing behind', async () => {
    expect(await claim(newBooking())).toBe(true); // 10:00–12:00
    const later = newBooking();
    const overlap = bucketsBetween(addMinutes(start, 60), addMinutes(start, 180)); // 11:00–13:00
    expect(await claim(later, overlap)).toBe(false);
    expect(await SlotHoldModel.countDocuments({ bookingId: later })).toBe(0);
  });

  it('expired holds that TTL has not swept yet do not block a new claim', async () => {
    await claim(newBooking(), twoHours, addMinutes(now, -1));
    expect(await claim(newBooking())).toBe(true);
    expect(await holds.busySlotIds(lotId, twoHours, now)).toEqual(new Set([slotId]));
  });

  it('busySlotIds ignores expired holds and releaseBooking removes a claim', async () => {
    const id = newBooking();
    await claim(id, twoHours, addMinutes(now, -1));
    expect((await holds.busySlotIds(lotId, twoHours, now)).size).toBe(0);
    await holds.releaseBooking(id);
    expect(await SlotHoldModel.countDocuments()).toBe(0);
  });

  it('transition is compare-and-set on status', async () => {
    const booking = await bookings.create({
      id: newBooking(),
      userId: new Types.ObjectId().toString(),
      lotId,
      slotId,
      slotLabel: 'S001',
      start,
      end: addMinutes(start, 120),
      amountPaise: 8000,
      currency: 'INR',
      status: 'PENDING',
      lockExpiresAt: addMinutes(now, 10),
    });

    const [a, b] = await Promise.all([
      bookings.transition(booking.id, ['PENDING'], 'CANCELLED'),
      bookings.transition(booking.id, ['PENDING'], 'EXPIRED'),
    ]);
    expect([a, b].filter(Boolean)).toHaveLength(1);
  });

  it('confirmBooking makes holds permanent and reports how many are left', async () => {
    const id = newBooking();
    await claim(id);
    expect(await holds.confirmBooking(id)).toBe(8);
    expect(await SlotHoldModel.countDocuments({ bookingId: id, expiresAt: null })).toBe(8);
  });

  it('records a payment once and lets exactly one caller claim its refund', async () => {
    const input = {
      provider: 'razorpay',
      orderId: 'order_1',
      paymentId: 'pay_1',
      bookingId: null,
      amountPaise: 8000,
      source: 'client' as const,
    };
    await Promise.all([
      paymentRepo.recordCaptured(input),
      paymentRepo.recordCaptured({ ...input, source: 'webhook' }),
    ]);
    expect(await PaymentModel.countDocuments({ paymentId: 'pay_1' })).toBe(1);

    const claims = await Promise.all([
      paymentRepo.claimRefund('pay_1'),
      paymentRepo.claimRefund('pay_1'),
    ]);
    expect(claims.filter(Boolean)).toHaveLength(1);
  });

  const seedBooking = (status: 'PENDING' | 'CONFIRMED' = 'CONFIRMED') =>
    bookings.create({
      id: newBooking(),
      userId: new Types.ObjectId().toString(),
      lotId,
      slotId,
      slotLabel: 'S001',
      start,
      end: addMinutes(start, 120),
      amountPaise: 8000,
      currency: 'INR',
      status,
      lockExpiresAt: null,
    });

  it('applyExtension applies once per end time and only to live bookings', async () => {
    const booking = await seedBooking();
    const end = addMinutes(start, 120);
    const newEnd = addMinutes(end, 30);

    const [a, b] = await Promise.all([
      bookings.applyExtension(booking.id, end, newEnd, 2000),
      bookings.applyExtension(booking.id, end, newEnd, 2000),
    ]);
    expect([a, b].filter(Boolean)).toHaveLength(1);
    const stored = await bookings.findById(booking.id);
    expect(stored).toMatchObject({ end: newEnd, amountPaise: 8000, extensionsPaise: 2000 });

    const pending = await seedBooking('PENDING');
    expect(await bookings.applyExtension(pending.id, end, newEnd, 2000)).toBeNull();
  });

  it('extensions round-trip and transition by compare-and-set', async () => {
    const booking = await seedBooking();
    const ext = await extensions.create({
      id: extensions.newId(),
      bookingId: booking.id,
      userId: booking.userId,
      start: booking.end,
      end: addMinutes(booking.end, 30),
      minutes: 30,
      amountPaise: 2000,
      status: 'PENDING',
      lockExpiresAt: addMinutes(now, 10),
    });
    await extensions.attachOrder(ext.id, 'order_ext');
    expect((await extensions.findByOrderId('order_ext'))?.id).toBe(ext.id);
    expect(await extensions.listByBooking(booking.id, ['PENDING'])).toHaveLength(1);

    const [a, b] = await Promise.all([
      extensions.transition(ext.id, ['PENDING'], 'CONFIRMED'),
      extensions.transition(ext.id, ['PENDING'], 'CANCELLED'),
    ]);
    expect([a, b].filter(Boolean)).toHaveLength(1);
  });

  it('releaseFrom frees only buckets from the given time on', async () => {
    const id = newBooking();
    await claim(id, twoHours, null);
    await holds.releaseFrom([id], addMinutes(start, 60));
    const left = await SlotHoldModel.find({ bookingId: id }).sort({ bucketStart: 1 });
    expect(left.map((h) => h.bucketStart.toISOString())).toEqual([
      '2026-10-19T10:00:00.000Z',
      '2026-10-19T10:15:00.000Z',
      '2026-10-19T10:30:00.000Z',
      '2026-10-19T10:45:00.000Z',
    ]);
  });
});
