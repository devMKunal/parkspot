import { MongoMemoryServer } from 'mongodb-memory-server';
import mongoose from 'mongoose';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { LotModel, SlotModel } from '../../src/modules/lots/lot.model.js';
import { MongoLotRepository } from '../../src/modules/lots/lot.repository.js';

/** Proves the $geoNear + free-slot join against real MongoDB. Run with `npm run test:int`. */
describe('MongoLotRepository', () => {
  let mongod: MongoMemoryServer;
  const repo = new MongoLotRepository();
  const fcRoad = { lat: 18.5246, lng: 73.8411 };

  const addLot = async (name: string, lat: number, lng: number, slots: ('FREE' | 'BOOKED')[]) => {
    const lot = await LotModel.create({
      name,
      address: name,
      location: { type: 'Point', coordinates: [lng, lat] },
      pricePerHourPaise: 4000,
      totalSlots: slots.length,
    });
    await SlotModel.insertMany(
      slots.map((status, i) => ({ lotId: lot._id, label: `S${i}`, status })),
    );
    return lot.id as string;
  };

  beforeAll(async () => {
    mongod = await MongoMemoryServer.create();
    await mongoose.connect(mongod.getUri());
    await Promise.all([LotModel.syncIndexes(), SlotModel.syncIndexes()]);
  });

  afterAll(async () => {
    await mongoose.disconnect();
    await mongod.stop();
  });

  beforeEach(async () => {
    await Promise.all([LotModel.deleteMany({}), SlotModel.deleteMany({})]);
  });

  it('returns lots inside the radius, nearest first, with free-slot counts', async () => {
    const near = await addLot('Near', 18.525, 73.8415, ['FREE', 'BOOKED', 'FREE']);
    const mid = await addLot('Mid', 18.5196, 73.8474, ['BOOKED']);
    await addLot('Far', 18.5913, 73.7389, ['FREE']);

    const lots = await repo.findNearby({ center: fcRoad, radiusMeters: 2000, limit: 10 });

    expect(lots.map((l) => l.id)).toEqual([near, mid]);
    expect(lots.map((l) => l.freeSlots)).toEqual([2, 0]);
    expect(lots[0]?.location).toEqual({ lat: 18.525, lng: 73.8415 });
    expect(lots[0]?.distanceMeters).toBeGreaterThan(0);
    expect(lots[0]!.distanceMeters).toBeLessThan(lots[1]!.distanceMeters);
  });

  it('applies the limit after sorting by distance', async () => {
    const near = await addLot('Near', 18.525, 73.8415, []);
    await addLot('Mid', 18.5196, 73.8474, []);
    const lots = await repo.findNearby({ center: fcRoad, radiusMeters: 5000, limit: 1 });
    expect(lots.map((l) => l.id)).toEqual([near]);
  });

  it('findById returns availability and null for unknown or malformed ids', async () => {
    const id = await addLot('One', 18.525, 73.8415, ['FREE', 'FREE']);
    expect((await repo.findById(id))?.freeSlots).toBe(2);
    expect(await repo.findById(new mongoose.Types.ObjectId().toString())).toBeNull();
    expect(await repo.findById('not-an-id')).toBeNull();
  });
});
