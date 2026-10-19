import { Types, mongo } from 'mongoose';
import { PaymentModel, type PaymentStatus } from './payment.model.js';

export interface PaymentRecordInput {
  provider: string;
  orderId: string;
  paymentId: string;
  bookingId: string | null;
  amountPaise: number | null;
  source: 'client' | 'webhook';
}

export interface PaymentRepository {
  /** Inserts the payment once; later sightings of the same paymentId are no-ops. */
  recordCaptured(input: PaymentRecordInput): Promise<void>;
  /** CAPTURED → REFUND_PENDING, once. Only the caller that gets `true` issues the refund. */
  claimRefund(paymentId: string): Promise<boolean>;
  setStatus(paymentId: string, status: PaymentStatus): Promise<void>;
}

export class MongoPaymentRepository implements PaymentRepository {
  async recordCaptured(input: PaymentRecordInput): Promise<void> {
    try {
      await this.upsert(input);
    } catch (err) {
      // Two parallel upserts of a new paymentId: the loser hits the unique index. Already recorded.
      if (err instanceof mongo.MongoServerError && err.code === 11000) return;
      throw err;
    }
  }

  private async upsert(input: PaymentRecordInput): Promise<void> {
    await PaymentModel.updateOne(
      { paymentId: input.paymentId },
      {
        $setOnInsert: {
          ...input,
          bookingId: input.bookingId ? new Types.ObjectId(input.bookingId) : null,
          status: 'CAPTURED',
        },
      },
      { upsert: true },
    );
  }

  async claimRefund(paymentId: string): Promise<boolean> {
    const result = await PaymentModel.updateOne(
      { paymentId, status: 'CAPTURED' },
      { $set: { status: 'REFUND_PENDING' } },
    );
    return result.modifiedCount === 1;
  }

  async setStatus(paymentId: string, status: PaymentStatus): Promise<void> {
    await PaymentModel.updateOne({ paymentId }, { $set: { status } });
  }
}
