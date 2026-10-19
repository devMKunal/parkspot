import mongoose, { Types } from 'mongoose';
import { ExtensionModel, type ExtensionDoc, type ExtensionStatus } from './booking.model.js';
import type { ExtensionRecord } from './booking.types.js';

export type CreateExtensionInput = Omit<ExtensionRecord, 'orderId' | 'paymentId'>;

export interface ExtensionRepository {
  newId(): string;
  create(input: CreateExtensionInput): Promise<ExtensionRecord>;
  findByOrderId(orderId: string): Promise<ExtensionRecord | null>;
  listByBooking(bookingId: string, statuses?: ExtensionStatus[]): Promise<ExtensionRecord[]>;
  /** Compare-and-set on status, like bookings. */
  transition(
    id: string,
    from: ExtensionStatus[],
    to: ExtensionStatus,
    patch?: Partial<Pick<ExtensionRecord, 'lockExpiresAt' | 'paymentId'>>,
  ): Promise<ExtensionRecord | null>;
  attachOrder(id: string, orderId: string): Promise<void>;
}

const toRecord = (doc: ExtensionDoc): ExtensionRecord => ({
  id: doc.id as string,
  bookingId: doc.bookingId.toString(),
  userId: doc.userId.toString(),
  start: doc.start,
  end: doc.end,
  minutes: doc.minutes,
  amountPaise: doc.amountPaise,
  status: doc.status,
  lockExpiresAt: doc.lockExpiresAt ?? null,
  orderId: doc.orderId ?? null,
  paymentId: doc.paymentId ?? null,
});

export class MongoExtensionRepository implements ExtensionRepository {
  newId(): string {
    return new Types.ObjectId().toString();
  }

  async create(input: CreateExtensionInput): Promise<ExtensionRecord> {
    const doc = await ExtensionModel.create({ ...input, _id: new Types.ObjectId(input.id) });
    return toRecord(doc);
  }

  async findByOrderId(orderId: string): Promise<ExtensionRecord | null> {
    const doc = await ExtensionModel.findOne({ orderId });
    return doc ? toRecord(doc) : null;
  }

  async listByBooking(bookingId: string, statuses?: ExtensionStatus[]): Promise<ExtensionRecord[]> {
    if (!mongoose.isValidObjectId(bookingId)) return [];
    const docs = await ExtensionModel.find({
      bookingId: new Types.ObjectId(bookingId),
      ...(statuses?.length ? { status: { $in: statuses } } : {}),
    }).sort({ createdAt: 1 });
    return docs.map(toRecord);
  }

  async transition(
    id: string,
    from: ExtensionStatus[],
    to: ExtensionStatus,
    patch: Partial<Pick<ExtensionRecord, 'lockExpiresAt' | 'paymentId'>> = {},
  ): Promise<ExtensionRecord | null> {
    const doc = await ExtensionModel.findOneAndUpdate(
      { _id: id, status: { $in: from } },
      { $set: { status: to, ...patch } },
      { new: true },
    );
    return doc ? toRecord(doc) : null;
  }

  async attachOrder(id: string, orderId: string): Promise<void> {
    await ExtensionModel.updateOne({ _id: id }, { $set: { orderId } });
  }
}
