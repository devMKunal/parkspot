import request from 'supertest';
import { buildTestApp, type TestAppOptions } from './testApp.js';

export const T0 = new Date('2026-10-19T09:42:00Z');
export const START = '2026-10-19T10:00:00.000Z';

export function setup(opts: { slots?: number; price?: number } & TestAppOptions = {}) {
  let now = T0;
  const ctx = buildTestApp({ now: () => now, ...opts });
  const lot = ctx.lots.add({
    name: 'FC Road Multilevel Parking',
    address: 'FC Road',
    location: { lat: 18.5246, lng: 73.8411 },
    pricePerHourPaise: opts.price ?? 4000,
    totalSlots: opts.slots ?? 3,
    freeSlots: opts.slots ?? 3,
    photos: [],
  });
  ctx.slots.addMany(lot.id, opts.slots ?? 3);

  const driver = async (email: string) => {
    const user = await ctx.users.create({ name: email, email, passwordHash: 'x' });
    return `Bearer ${ctx.tokens.signAccessToken({ sub: user.id, role: user.role })}`;
  };
  const book = (auth: string, body: Record<string, unknown> = {}) =>
    request(ctx.app)
      .post('/v1/bookings')
      .set('authorization', auth)
      .send({ lotId: lot.id, start: START, durationMinutes: 120, ...body });
  const advance = (minutes: number) => {
    now = new Date(now.getTime() + minutes * 60_000);
  };

  return { ...ctx, lot, driver, book, advance };
}
