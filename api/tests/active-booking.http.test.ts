import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { setup } from './support/bookingFixture.js';
import { FakePaymentGateway } from './support/fakes.js';

/** A paid 10:00–12:00 booking, at 09:42 (T0). */
async function confirmedBooking(slots = 1) {
  const ctx = setup({ slots });
  const auth = await ctx.driver('a@x.com');
  const created = await ctx.book(auth).expect(201);
  const paid = await request(ctx.app)
    .post('/v1/payments/verify')
    .set('authorization', auth)
    .send(FakePaymentGateway.checkoutSuccess(created.body.payment.orderId))
    .expect(200);
  const id = paid.body.booking.id as string;
  const call = (path: string, body: object = {}, as = auth) =>
    request(ctx.app).post(`/v1/bookings/${id}/${path}`).set('authorization', as).send(body);
  const get = () => request(ctx.app).get(`/v1/bookings/${id}`).set('authorization', auth);
  const pay = (orderId: string, paymentId?: string) =>
    request(ctx.app)
      .post('/v1/payments/verify')
      .set('authorization', auth)
      .send(FakePaymentGateway.checkoutSuccess(orderId, paymentId));
  return { ...ctx, auth, id, passCode: paid.body.booking.passCode as string, call, get, pay };
}

describe('check-in', () => {
  it('gives a paid booking a pass code and turns it ACTIVE with that code', async () => {
    const { passCode, call, advance } = await confirmedBooking();
    expect(passCode).toMatch(/^[0-9A-F]{8}$/);

    advance(3); // 09:45, 15 minutes before start
    const res = await call('checkin', { passCode }).expect(200);
    expect(res.body.booking).toMatchObject({ status: 'ACTIVE', passCode });
  });

  it('refuses a wrong code, a too-early scan and an unpaid booking', async () => {
    const { passCode, call, advance, book, driver, app } = await confirmedBooking(2);

    const early = await call('checkin', { passCode }).expect(409); // 09:42 is too early
    expect(early.body.error.code).toBe('CHECKIN_NOT_ALLOWED');

    advance(3);
    const wrong = await call('checkin', { passCode: 'NOPE1234' }).expect(400);
    expect(wrong.body.error.code).toBe('PASS_CODE_INVALID');

    const other = await driver('b@x.com');
    const unpaid = await book(other).expect(201);
    await request(app)
      .post(`/v1/bookings/${unpaid.body.booking.id}/checkin`)
      .set('authorization', other)
      .send({ passCode: 'ANYTHING' })
      .expect(409);
  });

  it('hides the pass code from unpaid bookings', async () => {
    const { book, driver } = await confirmedBooking(2);
    const res = await book(await driver('b@x.com')).expect(201);
    expect(res.body.booking.passCode).toBeNull();
  });
});

describe('extend', () => {
  it('sells extra time on the same slot as a second payment and moves the end', async () => {
    const { call, get, pay, holds, extensionRepo } = await confirmedBooking();

    const res = await call('extend', { minutes: 30 }).expect(201);
    expect(res.body.extension).toMatchObject({
      start: '2026-10-19T12:00:00.000Z',
      end: '2026-10-19T12:30:00.000Z',
      amount: { amount: 2000, currency: 'INR' },
      status: 'PENDING',
    });
    expect(res.body.payment).toMatchObject({ orderId: 'order_2', amount: 2000 });
    expect(holds.holdsOf(res.body.extension.id)).toHaveLength(2);

    const paid = await pay(res.body.payment.orderId).expect(200);
    expect(paid.body.booking).toMatchObject({
      end: '2026-10-19T12:30:00.000Z',
      amount: { amount: 10000, currency: 'INR' },
      status: 'CONFIRMED',
    });
    expect(holds.holdsOf(res.body.extension.id).every((h) => h.expiresAt === null)).toBe(true);
    expect([...extensionRepo.rows.values()][0]?.status).toBe('CONFIRMED');

    // Paying the same extension again changes nothing.
    await pay(res.body.payment.orderId).expect(200);
    expect((await get()).body.booking.amount.amount).toBe(10000);
  });

  it('keeps per-order amounts so a refund never includes extension money', async () => {
    const { call, pay, payments } = await confirmedBooking();
    const ext = await call('extend', { minutes: 30 }).expect(201);
    await pay(ext.body.payment.orderId).expect(200);

    // A second, different payment on the booking's own (already paid) order.
    await pay('order_1', 'pay_duplicate').expect(409);
    expect(payments?.refunds).toEqual([{ paymentId: 'pay_duplicate', amountPaise: 8000 }]);
  });

  it('409s when someone has the slot right after', async () => {
    const { call, book, driver } = await confirmedBooking();
    await book(await driver('b@x.com'), { start: '2026-10-19T12:00:00.000Z' }).expect(201);
    const res = await call('extend', { minutes: 30 }).expect(409);
    expect(res.body.error.code).toBe('EXTENSION_UNAVAILABLE');
  });

  it('replaces a pending extension when asked again', async () => {
    const { call, holds, extensionRepo } = await confirmedBooking();
    const first = await call('extend', { minutes: 30 }).expect(201);
    await call('extend', { minutes: 60 }).expect(201);

    expect(holds.holdsOf(first.body.extension.id)).toHaveLength(0);
    expect([...extensionRepo.rows.values()].map((e) => e.status)).toEqual(['CANCELLED', 'PENDING']);
  });

  it('refunds an extension paid after its lock lapsed and the slot was taken', async () => {
    const { call, pay, advance, book, driver, payments, get } = await confirmedBooking();
    const ext = await call('extend', { minutes: 30 }).expect(201);
    advance(11);
    await book(await driver('b@x.com'), { start: '2026-10-19T12:00:00.000Z' }).expect(201);

    const res = await pay(ext.body.payment.orderId).expect(409);
    expect(res.body.error.code).toBe('PAYMENT_REFUNDED');
    expect(payments?.refunds).toEqual([
      { paymentId: `pay_${ext.body.payment.orderId}`, amountPaise: 2000 },
    ]);
    expect((await get()).body.booking.end).toBe('2026-10-19T12:00:00.000Z');
  });

  it('refuses to extend an unpaid or finished booking', async () => {
    const { call, advance, book, driver, app } = await confirmedBooking(2);
    const other = await driver('b@x.com');
    const unpaid = await book(other).expect(201);
    const res = await request(app)
      .post(`/v1/bookings/${unpaid.body.booking.id}/extend`)
      .set('authorization', other)
      .send({ minutes: 30 })
      .expect(409);
    expect(res.body.error.code).toBe('EXTENSION_NOT_ALLOWED');

    advance(180); // past 12:00
    await call('extend', { minutes: 30 }).expect(409);
  });

  it('validates minutes', async () => {
    const { call } = await confirmedBooking();
    await call('extend', { minutes: 20 }).expect(422);
    await call('extend', { minutes: 300 }).expect(422);
  });
});

describe('end', () => {
  it('completes an active booking and frees the rest of its time, extensions included', async () => {
    const { call, pay, passCode, advance, holds, id, book, driver, extensionRepo } =
      await confirmedBooking();
    const ext = await call('extend', { minutes: 30 }).expect(201);
    await pay(ext.body.payment.orderId).expect(200);
    advance(48); // 10:30
    await call('checkin', { passCode }).expect(200);

    const res = await call('end').expect(200);
    expect(res.body.booking).toMatchObject({
      status: 'COMPLETED',
      endedAt: '2026-10-19T10:30:00.000Z',
      passCode: null,
    });

    // Holds before 10:45 stay (the current bucket); everything from 10:45 is released.
    const left = [...holds.rows.values()].filter((h) =>
      [id, ...extensionRepo.rows.keys()].includes(h.bookingId),
    );
    expect(left.map((h) => new Date(h.bucketStart).toISOString())).toEqual([
      '2026-10-19T10:00:00.000Z',
      '2026-10-19T10:15:00.000Z',
      '2026-10-19T10:30:00.000Z',
    ]);
    await book(await driver('b@x.com'), { start: '2026-10-19T11:00:00.000Z' }).expect(201);
  });

  it('only ends ACTIVE bookings', async () => {
    const { call } = await confirmedBooking();
    const res = await call('end').expect(409);
    expect(res.body.error.code).toBe('END_NOT_ALLOWED');
  });

  it('marks a paid booking COMPLETED once its end has passed, used or not', async () => {
    const { get, advance } = await confirmedBooking();
    advance(140); // 12:02
    const res = await get().expect(200);
    expect(res.body.booking).toMatchObject({
      status: 'COMPLETED',
      endedAt: '2026-10-19T12:00:00.000Z',
    });
  });
});
