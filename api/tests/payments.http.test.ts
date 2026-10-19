import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { setup } from './support/bookingFixture.js';
import { FakePaymentGateway } from './support/fakes.js';

async function pendingBooking(slots = 1) {
  const ctx = setup({ slots });
  const auth = await ctx.driver('a@x.com');
  const res = await ctx.book(auth).expect(201);
  const verify = (body: object, as = auth) =>
    request(ctx.app).post('/v1/payments/verify').set('authorization', as).send(body);
  const webhook = (orderId: string, paymentId: string, amount: number, signature?: string) => {
    const signed = FakePaymentGateway.capturedWebhook(orderId, paymentId, amount);
    return request(ctx.app)
      .post('/v1/webhooks/razorpay')
      .set('content-type', 'application/json')
      .set('x-razorpay-signature', signature ?? signed.signature)
      .send(signed.body);
  };
  return {
    ...ctx,
    auth,
    bookingId: res.body.booking.id as string,
    orderId: res.body.payment.orderId as string,
    verify,
    webhook,
  };
}

describe('POST /v1/payments/verify', () => {
  it('confirms the booking and makes its slot hold permanent', async () => {
    const { verify, orderId, bookingId, holds, paymentRepo } = await pendingBooking();

    const res = await verify(FakePaymentGateway.checkoutSuccess(orderId)).expect(200);

    expect(res.body.booking).toMatchObject({
      id: bookingId,
      status: 'CONFIRMED',
      lockExpiresAt: null,
    });
    expect(holds.holdsOf(bookingId).every((h) => h.expiresAt === null)).toBe(true);
    expect(paymentRepo.rows.get(`pay_${orderId}`)).toMatchObject({
      status: 'CAPTURED',
      source: 'client',
    });
  });

  it('rejects a forged signature and leaves the booking pending', async () => {
    const { verify, orderId, bookingRepo, bookingId } = await pendingBooking();
    const forged = { ...FakePaymentGateway.checkoutSuccess(orderId), signature: 'ab'.repeat(32) };

    const res = await verify(forged).expect(400);
    expect(res.body.error.code).toBe('PAYMENT_SIGNATURE_INVALID');
    expect(bookingRepo.rows.get(bookingId)?.status).toBe('PENDING');
  });

  it("404s for someone else's order even with a valid signature", async () => {
    const { verify, orderId, driver } = await pendingBooking();
    await verify(FakePaymentGateway.checkoutSuccess(orderId), await driver('b@x.com')).expect(404);
  });

  it('is idempotent: verifying twice returns the same confirmed booking', async () => {
    const { verify, orderId } = await pendingBooking();
    const ok = FakePaymentGateway.checkoutSuccess(orderId);
    const [a, b] = await Promise.all([verify(ok), verify(ok)]);
    expect([a.status, b.status]).toEqual([200, 200]);
    expect(b.body.booking).toEqual(a.body.booking);
  });

  it('confirms a payment that lands after the lock expired if the slot is still free', async () => {
    const { verify, orderId, advance } = await pendingBooking();
    advance(15);
    const res = await verify(FakePaymentGateway.checkoutSuccess(orderId)).expect(200);
    expect(res.body.booking.status).toBe('CONFIRMED');
  });

  it('moves a late payment to another free slot when its own was taken', async () => {
    const { verify, orderId, advance, book, driver } = await pendingBooking(2);
    advance(15);
    const other = await book(await driver('b@x.com')).expect(201); // takes S001 back
    expect(other.body.booking.slotLabel).toBe('S001');

    const res = await verify(FakePaymentGateway.checkoutSuccess(orderId)).expect(200);
    expect(res.body.booking).toMatchObject({ status: 'CONFIRMED', slotLabel: 'S002' });
  });

  it('refunds a late payment when the lot filled up meanwhile', async () => {
    const { verify, orderId, advance, book, driver, payments, bookingRepo, bookingId } =
      await pendingBooking(1);
    advance(15);
    await book(await driver('b@x.com')).expect(201);

    const res = await verify(FakePaymentGateway.checkoutSuccess(orderId)).expect(409);
    expect(res.body.error.code).toBe('PAYMENT_REFUNDED');
    expect(payments?.refunds).toEqual([{ paymentId: `pay_${orderId}`, amountPaise: 8000 }]);
    expect(bookingRepo.rows.get(bookingId)?.status).toBe('FAILED');
  });

  it('refunds a payment for a booking the driver already cancelled', async () => {
    const { app, auth, verify, orderId, bookingId, payments } = await pendingBooking();
    await request(app)
      .post(`/v1/bookings/${bookingId}/cancel`)
      .set('authorization', auth)
      .expect(200);

    await verify(FakePaymentGateway.checkoutSuccess(orderId)).expect(409);
    expect(payments?.refunds).toHaveLength(1);
  });
});

describe('POST /v1/webhooks/razorpay', () => {
  it('confirms the booking when the app never called verify (crash mid-flow)', async () => {
    const { webhook, orderId, bookingId, bookingRepo, paymentRepo } = await pendingBooking();

    await webhook(orderId, 'pay_hook', 8000).expect(200, { ok: true });

    expect(bookingRepo.rows.get(bookingId)).toMatchObject({
      status: 'CONFIRMED',
      paymentId: 'pay_hook',
    });
    expect(paymentRepo.rows.get('pay_hook')?.source).toBe('webhook');
  });

  it('is a no-op after verify already confirmed the same payment', async () => {
    const { verify, webhook, orderId, bookingRepo, bookingId, payments } = await pendingBooking();
    await verify(FakePaymentGateway.checkoutSuccess(orderId, 'pay_1')).expect(200);

    await webhook(orderId, 'pay_1', 8000).expect(200);
    await webhook(orderId, 'pay_1', 8000).expect(200); // Razorpay retries

    expect(bookingRepo.rows.get(bookingId)?.status).toBe('CONFIRMED');
    expect(payments?.refunds).toHaveLength(0);
  });

  it('refunds exactly once when both paths report an unusable payment', async () => {
    const { verify, webhook, orderId, advance, book, driver, payments } = await pendingBooking(1);
    advance(15);
    await book(await driver('b@x.com')).expect(201);

    await verify(FakePaymentGateway.checkoutSuccess(orderId, 'pay_1')).expect(409);
    await webhook(orderId, 'pay_1', 8000).expect(200);
    expect(payments?.refunds).toHaveLength(1);
  });

  it('refunds a payment whose amount does not match the booking', async () => {
    const { webhook, orderId, payments, bookingRepo, bookingId } = await pendingBooking();
    await webhook(orderId, 'pay_odd', 100).expect(200);
    expect(payments?.refunds).toEqual([{ paymentId: 'pay_odd', amountPaise: 8000 }]);
    expect(bookingRepo.rows.get(bookingId)?.status).toBe('PENDING');
  });

  it('rejects an unsigned or tampered body', async () => {
    const { webhook, orderId, bookingRepo, bookingId } = await pendingBooking();
    const res = await webhook(orderId, 'pay_x', 8000, 'deadbeef').expect(400);
    expect(res.body.error.code).toBe('WEBHOOK_SIGNATURE_INVALID');
    expect(bookingRepo.rows.get(bookingId)?.status).toBe('PENDING');
  });

  it('acknowledges events it does not handle', async () => {
    const { app } = await pendingBooking();
    const body = JSON.stringify({ event: 'refund.processed', payload: {} });
    const signature = FakePaymentGateway.capturedWebhook('o', 'p', 1).signature; // wrong body
    await request(app)
      .post('/v1/webhooks/razorpay')
      .set('content-type', 'application/json')
      .set('x-razorpay-signature', signature)
      .send(body)
      .expect(400);

    const { hmacSha256Hex } = await import('../src/modules/payments/hmac.js');
    const { FAKE_WEBHOOK_SECRET } = await import('./support/fakes.js');
    await request(app)
      .post('/v1/webhooks/razorpay')
      .set('content-type', 'application/json')
      .set('x-razorpay-signature', hmacSha256Hex(FAKE_WEBHOOK_SECRET, body))
      .send(body)
      .expect(200);
  });
});
