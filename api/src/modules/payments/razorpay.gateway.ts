import { hmacSha256Hex, safeEqualHex } from './hmac.js';
import {
  PaymentProviderError,
  type CheckoutResult,
  type CreateOrderInput,
  type CreatedOrder,
  type PaymentGateway,
  type WebhookEvent,
} from './payment.gateway.js';

export interface RazorpayConfig {
  keyId: string;
  keySecret: string;
  /** Webhook secret is separate from the API secret in Razorpay. */
  webhookSecret?: string;
  baseUrl?: string;
  timeoutMs?: number;
}

interface RazorpayOrderResponse {
  id: string;
  amount: number;
  currency: string;
  status: string;
}

interface RazorpayWebhookBody {
  event: string;
  payload?: {
    payment?: {
      entity?: { id: string; order_id: string; amount: number; currency: string; status: string };
    };
  };
}

/** Talks to the Razorpay REST API directly; no SDK needed for three calls. */
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
    const order = await this.post<RazorpayOrderResponse>('/v1/orders', {
      amount: input.amountPaise,
      currency: input.currency,
      receipt: input.receipt,
      notes: input.notes,
    });
    if (order.amount !== input.amountPaise || order.currency !== input.currency) {
      throw new PaymentProviderError('Razorpay returned an order that does not match the request');
    }
    return { provider: 'razorpay', orderId: order.id, amountPaise: order.amount, currency: 'INR' };
  }

  /** Razorpay signs `order_id|payment_id` with the API key secret. */
  verifyCheckout({ orderId, paymentId, signature }: CheckoutResult): boolean {
    const expected = hmacSha256Hex(this.config.keySecret, `${orderId}|${paymentId}`);
    return safeEqualHex(expected, signature);
  }

  parseWebhook(rawBody: Buffer, signature: string | undefined): WebhookEvent | null {
    if (!this.config.webhookSecret) return null;
    if (!safeEqualHex(hmacSha256Hex(this.config.webhookSecret, rawBody), signature)) return null;

    const body = JSON.parse(rawBody.toString('utf8')) as RazorpayWebhookBody;
    const entity = body.payload?.payment?.entity;
    // order.paid also carries the payment entity; both confirm the same way (idempotently).
    if ((body.event === 'payment.captured' || body.event === 'order.paid') && entity) {
      return {
        kind: 'payment.captured',
        payment: {
          orderId: entity.order_id,
          paymentId: entity.id,
          amountPaise: entity.amount,
          currency: entity.currency,
        },
      };
    }
    return { kind: 'ignored', type: body.event };
  }

  async refund(paymentId: string, amountPaise: number): Promise<void> {
    await this.post(`/v1/payments/${encodeURIComponent(paymentId)}/refund`, {
      amount: amountPaise,
      speed: 'normal',
    });
  }

  private async post<T>(path: string, body: unknown): Promise<T> {
    const auth = Buffer.from(`${this.config.keyId}:${this.config.keySecret}`).toString('base64');
    let res: Response;
    try {
      res = await this.fetchFn(`${this.config.baseUrl ?? 'https://api.razorpay.com'}${path}`, {
        method: 'POST',
        headers: { authorization: `Basic ${auth}`, 'content-type': 'application/json' },
        body: JSON.stringify(body),
        signal: AbortSignal.timeout(this.config.timeoutMs ?? 10_000),
      });
    } catch (err) {
      throw new PaymentProviderError('Razorpay unreachable', err);
    }
    if (!res.ok) {
      throw new PaymentProviderError(
        `Razorpay ${path} failed with ${res.status}: ${await res.text()}`,
      );
    }
    return (await res.json()) as T;
  }
}
