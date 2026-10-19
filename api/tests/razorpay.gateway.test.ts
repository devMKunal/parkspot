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
