import { Schema, model } from 'mongoose';

export const PAYMENT_STATUSES = [
  'CAPTURED',
  'REFUND_PENDING',
  'REFUNDED',
  'REFUND_FAILED',
] as const;
export type PaymentStatus = (typeof PAYMENT_STATUSES)[number];

/** Audit trail of every verified payment, one row per provider payment id. */
const paymentSchema = new Schema(
  {
    provider: { type: String, required: true },
    orderId: { type: String, required: true, index: true },
    paymentId: { type: String, required: true, unique: true },
    bookingId: { type: Schema.Types.ObjectId, ref: 'Booking', default: null },
    amountPaise: { type: Number, default: null },
    status: { type: String, enum: PAYMENT_STATUSES, required: true },
    /** Which path saw it first: the app's verify call or the provider webhook. */
    source: { type: String, enum: ['client', 'webhook'], required: true },
  },
  { timestamps: true },
);

export const PaymentModel = model('Payment', paymentSchema);
