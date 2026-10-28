export type PaymentProvider = 'razorpay';

export interface CreateOrderInput {
  amountPaise: number;
  currency: 'INR';
  /** Our reference, shown in the provider dashboard. Razorpay allows up to 40 chars. */
  receipt: string;
  notes?: Record<string, string>;
}

export interface CreatedOrder {
  provider: PaymentProvider;
  orderId: string;
  amountPaise: number;
  currency: 'INR';
}

/** What the checkout SDK hands the app on success, forwarded to the server as-is. */
export interface CheckoutResult {
  orderId: string;
  paymentId: string;
  signature: string;
}

/** A payment the provider says succeeded, normalised from a webhook event. */
export interface CapturedPayment {
  orderId: string;
  paymentId: string;
  amountPaise: number;
  currency: string;
}

export type WebhookEvent =
  | { kind: 'payment.captured'; payment: CapturedPayment }
  /** Paid but not captured yet (manual capture): we must capture it. */
  | { kind: 'payment.authorized'; payment: CapturedPayment }
  | { kind: 'ignored'; type: string };

/** Server-side gateway port. Razorpay today; Stripe slots in behind the same interface. */
export interface PaymentGateway {
  readonly provider: PaymentProvider;
  /** Public key the app passes to the checkout SDK. Safe to send to clients. */
  readonly publicKey: string;
  createOrder(input: CreateOrderInput): Promise<CreatedOrder>;
  /** True only if the checkout result was signed by the provider for this order. */
  verifyCheckout(result: CheckoutResult): boolean;
  /** Verifies the signature over the exact raw body, then parses it. Null if forged. */
  parseWebhook(rawBody: Buffer, signature: string | undefined): WebhookEvent | null;
  /**
   * Makes sure the money is ours: captures an authorized payment, no-op if already captured.
   * Throws if it can't be captured. An uncaptured payment is auto-refunded by the provider.
   */
  capture(paymentId: string): Promise<void>;
  refund(paymentId: string, amountPaise: number): Promise<void>;
}

export class PaymentProviderError extends Error {
  constructor(message: string, cause?: unknown) {
    super(message, { cause });
    this.name = 'PaymentProviderError';
  }
}
