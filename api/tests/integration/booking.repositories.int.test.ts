import { MongoMemoryServer } from 'mongodb-memory-server';
import mongoose, { Types } from 'mongoose';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { addMinutes, bucketsBetween } from '../../src/core/time.js';
import { BookingModel } from '../../src/modules/bookings/booking.model.js';
import { MongoBookingRepository } from '../../src/modules/bookings/booking.repository.js';
import { SlotHoldModel } from '../../src/modules/lots/lot.model.js';
import { MongoSlotHoldRepository } from '../../src/modules/lots/slot.repository.js';

/** Proves the slot lock against real MongoDB indexes. Run with `npm run test:int`. */
describe('slot holds and bookings on MongoDB', () => {
  let mongod: MongoMemoryServer;
  const holds = new MongoSlotHoldRepository();
  const bookings = new MongoBookingRepository();
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
    await Promise.all([SlotHoldModel.syncIndexes(), BookingModel.syncIndexes()]);
  });

  afterAll(async () => {
    await mongoose.disconnect();
    await mongod.stop();
  });

  beforeEach(async () => {
    await Promise.all([SlotHoldModel.deleteMany({}), BookingModel.deleteMany({})]);
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
});
