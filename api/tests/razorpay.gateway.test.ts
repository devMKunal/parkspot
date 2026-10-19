import { describe, expect, it, vi } from 'vitest';
import { PaymentProviderError } from '../src/modules/payments/payment.gateway.js';
import { RazorpayGateway } from '../src/modules/payments/razorpay.gateway.js';

const input = { amountPaise: 8000, currency: 'INR' as const, receipt: 'booking-1' };
const jsonResponse = (status: number, body: unknown) =>
  new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });

describe('RazorpayGateway', () => {
  it('creates an order with Basic auth and maps the response', async () => {
    const fetchFn = vi.fn(async () =>
      jsonResponse(200, { id: 'order_abc', amount: 8000, currency: 'INR', status: 'created' }),
    );
    const gateway = new RazorpayGateway({ keyId: 'rzp_test_k', keySecret: 's3cret' }, fetchFn);

    const order = await gateway.createOrder(input);

    expect(order).toEqual({
      provider: 'razorpay',
      orderId: 'order_abc',
      amountPaise: 8000,
      currency: 'INR',
    });
    const [url, init] = fetchFn.mock.calls[0] as unknown as [string, RequestInit];
    expect(url).toBe('https://api.razorpay.com/v1/orders');
    expect((init.headers as Record<string, string>).authorization).toBe(
      `Basic ${Buffer.from('rzp_test_k:s3cret').toString('base64')}`,
    );
    expect(JSON.parse(init.body as string)).toMatchObject({ amount: 8000, receipt: 'booking-1' });
    expect(gateway.publicKey).toBe('rzp_test_k');
  });

  it('wraps HTTP errors, network errors and mismatched orders', async () => {
    const failing = [
      async () => jsonResponse(401, { error: { description: 'Authentication failed' } }),
      async () => {
        throw new TypeError('fetch failed');
      },
      async () => jsonResponse(200, { id: 'order_x', amount: 1, currency: 'INR' }),
    ];
    for (const fetchFn of failing) {
      const gateway = new RazorpayGateway({ keyId: 'k', keySecret: 's' }, fetchFn);
      await expect(gateway.createOrder(input)).rejects.toBeInstanceOf(PaymentProviderError);
    }
  });
});

describe('RazorpayGateway signatures', () => {
  const gateway = new RazorpayGateway({
    keyId: 'k',
    keySecret: 'key_secret',
    webhookSecret: 'wh_secret',
  });

  it('accepts the documented checkout signature and nothing else', async () => {
    const { hmacSha256Hex } = await import('../src/modules/payments/hmac.js');
    const signature = hmacSha256Hex('key_secret', 'order_1|pay_1');
    expect(gateway.verifyCheckout({ orderId: 'order_1', paymentId: 'pay_1', signature })).toBe(
      true,
    );
    expect(gateway.verifyCheckout({ orderId: 'order_2', paymentId: 'pay_1', signature })).toBe(
      false,
    );
    expect(
      gateway.verifyCheckout({ orderId: 'order_1', paymentId: 'pay_1', signature: 'zz' }),
    ).toBe(false);
    expect(gateway.verifyCheckout({ orderId: 'order_1', paymentId: 'pay_1', signature: '' })).toBe(
      false,
    );
  });

  it('parses only webhooks signed over the exact raw body', async () => {
    const { hmacSha256Hex } = await import('../src/modules/payments/hmac.js');
    const body = Buffer.from(
      JSON.stringify({
        event: 'payment.captured',
        payload: {
          payment: { entity: { id: 'pay_1', order_id: 'order_1', amount: 8000, currency: 'INR' } },
        },
      }),
    );
    const signature = hmacSha256Hex('wh_secret', body);

    expect(gateway.parseWebhook(body, signature)).toEqual({
      kind: 'payment.captured',
      payment: { orderId: 'order_1', paymentId: 'pay_1', amountPaise: 8000, currency: 'INR' },
    });
    const reformatted = Buffer.from(JSON.stringify(JSON.parse(body.toString()), null, 2));
    expect(gateway.parseWebhook(reformatted, signature)).toBeNull();
    expect(
      new RazorpayGateway({ keyId: 'k', keySecret: 's' }).parseWebhook(body, signature),
    ).toBeNull();
  });

  it('refunds through the payments API', async () => {
    const fetchFn = vi.fn(async () => jsonResponse(200, { id: 'rfnd_1' }));
    const g = new RazorpayGateway({ keyId: 'k', keySecret: 's' }, fetchFn);
    await g.refund('pay_1', 8000);
    const [url, init] = fetchFn.mock.calls[0] as unknown as [string, RequestInit];
    expect(url).toBe('https://api.razorpay.com/v1/payments/pay_1/refund');
    expect(JSON.parse(init.body as string)).toEqual({ amount: 8000, speed: 'normal' });
  });
});
