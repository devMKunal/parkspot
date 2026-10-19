import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { START, setup } from './support/bookingFixture.js';
import { FakePaymentGateway } from './support/fakes.js';

describe('POST /v1/bookings', () => {
  it('locks a slot for 10 minutes, prices on the server and returns a checkout payload', async () => {
    const { book, driver, holds, payments } = setup();
    const res = await book(await driver('a@x.com')).expect(201);

    expect(res.body.booking).toMatchObject({
      status: 'PENDING',
      start: START,
      end: '2026-10-19T12:00:00.000Z',
      amount: { amount: 8000, currency: 'INR' },
      slotLabel: 'S001',
      lockExpiresAt: '2026-10-19T09:52:00.000Z',
    });
    expect(res.body.payment).toEqual({
      provider: 'razorpay',
      keyId: 'rzp_test_fake',
      orderId: 'order_1',
      amount: 8000,
      currency: 'INR',
    });
    expect(holds.holdsOf(res.body.booking.id)).toHaveLength(8); // 2h in 15-min buckets
    expect(payments?.orders[0]).toMatchObject({ amountPaise: 8000, receipt: res.body.booking.id });
  });

  it('ignores any price the client sends', async () => {
    const { book, driver } = setup();
    const res = await book(await driver('a@x.com'), { amount: 1 }).expect(201);
    expect(res.body.booking.amount.amount).toBe(8000);
  });

  it('rounds odd prices to whole paise', async () => {
    const { book, driver } = setup({ price: 3333 });
    const res = await book(await driver('a@x.com'), { durationMinutes: 45 }).expect(201);
    expect(res.body.booking.amount.amount).toBe(2500); // 2499.75
  });

  it('needs a login', async () => {
    const { app, lot } = setup();
    await request(app).post('/v1/bookings').send({ lotId: lot.id, start: START }).expect(401);
  });

  it.each([
    ['start off the 15-minute grid', { start: '2026-10-19T10:05:00.000Z' }],
    ['start in the past', { start: '2026-10-19T09:00:00.000Z' }],
    ['start more than 7 days ahead', { start: '2026-10-27T10:00:00.000Z' }],
    ['duration under 30 minutes', { durationMinutes: 15 }],
    ['duration not a multiple of 15', { durationMinutes: 50 }],
    ['duration over 12 hours', { durationMinutes: 735 }],
  ])('422 for %s', async (_case, body) => {
    const { book, driver } = setup();
    const res = await book(await driver('a@x.com'), body).expect(422);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('404 for an unknown lot', async () => {
    const { book, driver } = setup();
    await book(await driver('a@x.com'), { lotId: 'nope' }).expect(404);
  });

  it('never gives the same slot to two drivers racing for the last spaces', async () => {
    const { book, driver } = setup({ slots: 2 });
    const auths = await Promise.all(['a', 'b', 'c'].map((n) => driver(`${n}@x.com`)));

    const results = await Promise.all(auths.map((a) => book(a)));

    const statuses = results.map((r) => r.status).sort();
    expect(statuses).toEqual([201, 201, 409]);
    const labels = results.filter((r) => r.status === 201).map((r) => r.body.booking.slotLabel);
    expect(new Set(labels).size).toBe(2);
    expect(results.find((r) => r.status === 409)?.body.error.code).toBe('LOT_FULL');
  });

  it('blocks overlapping windows but allows back-to-back ones', async () => {
    const { book, driver } = setup({ slots: 1 });
    await book(await driver('a@x.com')).expect(201); // 10:00–12:00

    await book(await driver('b@x.com'), { start: '2026-10-19T11:00:00.000Z' }).expect(409);
    await book(await driver('c@x.com'), { start: '2026-10-19T12:00:00.000Z' }).expect(201);
  });

  it('frees the slot when the lock expires and reports the booking as EXPIRED', async () => {
    const { app, book, driver, advance } = setup({ slots: 1 });
    const first = await driver('a@x.com');
    const booked = await book(first).expect(201);

    await book(await driver('b@x.com')).expect(409);
    advance(11);
    await book(await driver('c@x.com')).expect(201);

    const res = await request(app)
      .get(`/v1/bookings/${booked.body.booking.id}`)
      .set('authorization', first)
      .expect(200);
    expect(res.body.booking.status).toBe('EXPIRED');
  });

  it("booking again cancels the driver's previous unpaid booking", async () => {
    const { app, book, driver, holds } = setup({ slots: 1 });
    const auth = await driver('a@x.com');
    const first = await book(auth).expect(201);
    const second = await book(auth).expect(201); // same single slot, so the first had to let go

    expect(holds.holdsOf(first.body.booking.id)).toHaveLength(0);
    const res = await request(app)
      .get(`/v1/bookings/${first.body.booking.id}`)
      .set('authorization', auth)
      .expect(200);
    expect(res.body.booking.status).toBe('CANCELLED');
    expect(second.body.booking.status).toBe('PENDING');
  });

  it('releases the slot and marks FAILED when the payment provider errors', async () => {
    const payments = new FakePaymentGateway();
    const { book, driver, holds, bookingRepo } = setup({ slots: 1, payments });
    payments.failNext = true;

    const res = await book(await driver('a@x.com')).expect(502);
    expect(res.body.error.code).toBe('PAYMENT_PROVIDER_ERROR');
    expect(holds.rows.size).toBe(0);
    expect([...bookingRepo.rows.values()].map((b) => b.status)).toEqual(['FAILED']);

    await book(await driver('b@x.com')).expect(201);
  });

  it('503 without Razorpay keys, before claiming anything', async () => {
    const { book, driver, holds } = setup({ payments: null });
    const res = await book(await driver('a@x.com')).expect(503);
    expect(res.body.error.code).toBe('PAYMENTS_UNAVAILABLE');
    expect(holds.rows.size).toBe(0);
  });
});

describe('reading and cancelling bookings', () => {
  it("hides other drivers' bookings behind a 404", async () => {
    const { app, book, driver } = setup();
    const booked = await book(await driver('a@x.com')).expect(201);
    await request(app)
      .get(`/v1/bookings/${booked.body.booking.id}`)
      .set('authorization', await driver('b@x.com'))
      .expect(404);
  });

  it('cancels a pending booking once and frees the slot', async () => {
    const { app, book, driver, holds } = setup({ slots: 1 });
    const auth = await driver('a@x.com');
    const id = (await book(auth).expect(201)).body.booking.id;

    const res = await request(app)
      .post(`/v1/bookings/${id}/cancel`)
      .set('authorization', auth)
      .expect(200);
    expect(res.body.booking.status).toBe('CANCELLED');
    expect(holds.rows.size).toBe(0);

    const again = await request(app)
      .post(`/v1/bookings/${id}/cancel`)
      .set('authorization', auth)
      .expect(409);
    expect(again.body.error.code).toBe('BOOKING_NOT_CANCELLABLE');
  });

  it('lists my bookings newest first, filterable by status', async () => {
    const { app, book, driver } = setup();
    const auth = await driver('a@x.com');
    const first = (await book(auth).expect(201)).body.booking.id; // cancelled by the next one
    const second = (await book(auth).expect(201)).body.booking.id;
    await book(await driver('b@x.com')).expect(201); // someone else's

    const all = await request(app).get('/v1/me/bookings').set('authorization', auth).expect(200);
    expect(all.body.bookings.map((b: { id: string }) => b.id)).toEqual([second, first]);

    const pending = await request(app)
      .get('/v1/me/bookings')
      .query({ status: 'PENDING' })
      .set('authorization', auth)
      .expect(200);
    expect(pending.body.bookings.map((b: { id: string }) => b.id)).toEqual([second]);

    await request(app)
      .get('/v1/me/bookings')
      .query({ status: 'NOPE' })
      .set('authorization', auth)
      .expect(422);
  });
});
