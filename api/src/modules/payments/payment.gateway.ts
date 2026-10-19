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

/** Server-side gateway port. Razorpay today; Stripe slots in behind the same interface. */
export interface PaymentGateway {
  readonly provider: PaymentProvider;
  /** Public key the app passes to the checkout SDK. Safe to send to clients. */
  readonly publicKey: string;
  createOrder(input: CreateOrderInput): Promise<CreatedOrder>;
}

export class PaymentProviderError extends Error {
  constructor(message: string, cause?: unknown) {
    super(message, { cause });
    this.name = 'PaymentProviderError';
  }
}
