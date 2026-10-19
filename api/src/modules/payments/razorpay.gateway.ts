import {
  PaymentProviderError,
  type CreateOrderInput,
  type CreatedOrder,
  type PaymentGateway,
} from './payment.gateway.js';

export interface RazorpayConfig {
  keyId: string;
  keySecret: string;
  baseUrl?: string;
  timeoutMs?: number;
}

interface RazorpayOrderResponse {
  id: string;
  amount: number;
  currency: string;
  status: string;
}

/** Talks to the Razorpay Orders REST API directly; no SDK needed for one call. */
export class RazorpayGateway implements PaymentGateway {
  readonly provider = 'razorpay' as const;

  constructor(
    private readonly config: RazorpayConfig,
    private readonly fetchFn: typeof fetch = fetch,
  ) {}

  get publicKey(): string {
    return this.config.keyId;
  }

  async createOrder(input: CreateOrderInput): Promise<CreatedOrder> {
    const auth = Buffer.from(`${this.config.keyId}:${this.config.keySecret}`).toString('base64');
    let res: Response;
    try {
      res = await this.fetchFn(`${this.config.baseUrl ?? 'https://api.razorpay.com'}/v1/orders`, {
        method: 'POST',
        headers: { authorization: `Basic ${auth}`, 'content-type': 'application/json' },
        body: JSON.stringify({
          amount: input.amountPaise,
          currency: input.currency,
          receipt: input.receipt,
          notes: input.notes,
        }),
        signal: AbortSignal.timeout(this.config.timeoutMs ?? 10_000),
      });
    } catch (err) {
      throw new PaymentProviderError('Razorpay unreachable', err);
    }

    if (!res.ok) {
      throw new PaymentProviderError(
        `Razorpay order failed with ${res.status}: ${await res.text()}`,
      );
    }

    const order = (await res.json()) as RazorpayOrderResponse;
    if (order.amount !== input.amountPaise || order.currency !== input.currency) {
      throw new PaymentProviderError('Razorpay returned an order that does not match the request');
    }
    return { provider: 'razorpay', orderId: order.id, amountPaise: order.amount, currency: 'INR' };
  }
}
