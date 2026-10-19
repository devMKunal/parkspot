import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { buildTestApp } from './support/testApp.js';

// FC Road, Pune
const here = { lat: 18.5246, lng: 73.8411 };

function appWithLots() {
  const ctx = buildTestApp();
  const near = ctx.lots.add({
    name: 'Near',
    address: 'FC Road',
    location: { lat: 18.525, lng: 73.8415 },
    pricePerHourPaise: 4000,
    totalSlots: 10,
    freeSlots: 3,
    photos: [],
  });
  const mid = ctx.lots.add({
    name: 'Mid',
    address: 'JM Road',
    location: { lat: 18.5196, lng: 73.8474 },
    pricePerHourPaise: 3500,
    totalSlots: 20,
    freeSlots: 0,
    photos: [],
  });
  const far = ctx.lots.add({
    name: 'Far',
    address: 'Hinjewadi',
    location: { lat: 18.5913, lng: 73.7389 },
    pricePerHourPaise: 3000,
    totalSlots: 50,
    freeSlots: 50,
    photos: [],
  });
  return { ...ctx, near, mid, far };
}

describe('GET /v1/lots/nearby', () => {
  it('returns lots within the radius, nearest first, with distance and money in paise', async () => {
    const { app, near, mid } = appWithLots();
    const res = await request(app)
      .get('/v1/lots/nearby')
      .query({ ...here, radius: 2000 })
      .expect(200);

    expect(res.body.lots.map((l: { id: string }) => l.id)).toEqual([near.id, mid.id]);
    expect(res.body.lots[0]).toMatchObject({
      name: 'Near',
      location: { lat: 18.525, lng: 73.8415 },
      pricePerHour: { amount: 4000, currency: 'INR' },
      freeSlots: 3,
      distanceMeters: expect.any(Number),
    });
    expect(Number.isInteger(res.body.lots[0].distanceMeters)).toBe(true);
  });

  it('defaults the radius to 2 km and respects limit', async () => {
    const { app, near } = appWithLots();
    const res = await request(app)
      .get('/v1/lots/nearby')
      .query({ ...here, limit: 1 })
      .expect(200);
    expect(res.body.lots.map((l: { id: string }) => l.id)).toEqual([near.id]);
  });

  it('works without a login', async () => {
    const { app } = appWithLots();
    await request(app).get('/v1/lots/nearby').query(here).expect(200);
  });

  it('rejects missing or out-of-range coordinates with 422', async () => {
    const { app } = appWithLots();
    const missing = await request(app).get('/v1/lots/nearby').expect(422);
    expect(Object.keys(missing.body.error.details)).toEqual(expect.arrayContaining(['lat', 'lng']));

    await request(app).get('/v1/lots/nearby').query({ lat: 91, lng: 73 }).expect(422);
    await request(app)
      .get('/v1/lots/nearby')
      .query({ ...here, radius: 50_000 })
      .expect(422);
  });
});

describe('GET /v1/lots/:id', () => {
  it('returns one lot without a distance', async () => {
    const { app, mid } = appWithLots();
    const res = await request(app).get(`/v1/lots/${mid.id}`).expect(200);
    expect(res.body.lot).toMatchObject({ id: mid.id, name: 'Mid', freeSlots: 0 });
    expect(res.body.lot).not.toHaveProperty('distanceMeters');
  });

  it('404s for an unknown lot', async () => {
    const { app } = appWithLots();
    const res = await request(app).get('/v1/lots/nope').expect(404);
    expect(res.body.error.code).toBe('NOT_FOUND');
  });
});
