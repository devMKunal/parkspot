import mongoose, { Types } from 'mongoose';
import { BookingModel, type BookingDoc, type BookingStatus } from './booking.model.js';
import type { BookingRecord } from './booking.types.js';

export type CreateBookingInput = Omit<
  BookingRecord,
  'createdAt' | 'provider' | 'orderId' | 'paymentId' | 'passCode' | 'endedAt' | 'extensionsPaise'
>;

export type BookingPatch = Partial<
  Pick<BookingRecord, 'lockExpiresAt' | 'paymentId' | 'passCode' | 'endedAt'>
>;

export interface BookingRepository {
  newId(): string;
  create(input: CreateBookingInput): Promise<BookingRecord>;
  findById(id: string): Promise<BookingRecord | null>;
  listByUser(userId: string, statuses?: BookingStatus[]): Promise<BookingRecord[]>;
  /**
   * Moves the booking to `to` only if it is currently in one of `from` (compare-and-set),
   * merging `patch`. Returns the updated booking, or null if the status had already moved on.
   */
  transition(
    id: string,
    from: BookingStatus[],
    to: BookingStatus,
    patch?: BookingPatch,
  ): Promise<BookingRecord | null>;
  /**
   * Adds paid extra time, only if the booking is still live and still ends at `fromEnd`
   * (so the same extension can never be applied twice). Null if that no longer holds.
   */
  applyExtension(
    id: string,
    fromEnd: Date,
    newEnd: Date,
    addPaise: number,
  ): Promise<BookingRecord | null>;
  attachOrder(id: string, provider: string, orderId: string): Promise<void>;
  findByOrderId(orderId: string): Promise<BookingRecord | null>;
  /** Moves a paid booking to another slot when its original one was lost to a lapsed lock. */
  reassignSlot(id: string, slotId: string, slotLabel: string): Promise<void>;
}

const toRecord = (doc: BookingDoc): BookingRecord => ({
  id: doc.id as string,
  userId: doc.userId.toString(),
  lotId: doc.lotId.toString(),
  slotId: doc.slotId.toString(),
  slotLabel: doc.slotLabel,
  start: doc.start,
  end: doc.end,
  amountPaise: doc.amountPaise,
  extensionsPaise: doc.extensionsPaise ?? 0,
  currency: doc.currency,
  status: doc.status,
  lockExpiresAt: doc.lockExpiresAt ?? null,
  provider: doc.provider ?? null,
  orderId: doc.orderId ?? null,
  paymentId: doc.paymentId ?? null,
  passCode: doc.passCode ?? null,
  endedAt: doc.endedAt ?? null,
  createdAt: doc.createdAt,
});

export class MongoBookingRepository implements BookingRepository {
  newId(): string {
    return new Types.ObjectId().toString();
  }

  async create(input: CreateBookingInput): Promise<BookingRecord> {
    const doc = await BookingModel.create({ ...input, _id: new Types.ObjectId(input.id) });
    return toRecord(doc);
  }

  async findById(id: string): Promise<BookingRecord | null> {
    if (!mongoose.isValidObjectId(id)) return null;
    const doc = await BookingModel.findById(id);
    return doc ? toRecord(doc) : null;
  }

  async listByUser(userId: string, statuses?: BookingStatus[]): Promise<BookingRecord[]> {
    const docs = await BookingModel.find({
      userId: new Types.ObjectId(userId),
      ...(statuses?.length ? { status: { $in: statuses } } : {}),
    })
      .sort({ createdAt: -1 })
      .limit(100);
    return docs.map(toRecord);
  }

  async transition(
    id: string,
    from: BookingStatus[],
    to: BookingStatus,
    patch: BookingPatch = {},
  ): Promise<BookingRecord | null> {
    if (!mongoose.isValidObjectId(id)) return null;
    const doc = await BookingModel.findOneAndUpdate(
      { _id: id, status: { $in: from } },
      { $set: { status: to, ...patch } },
      { new: true },
    );
    return doc ? toRecord(doc) : null;
  }

  async attachOrder(id: string, provider: string, orderId: string): Promise<void> {
    await BookingModel.updateOne({ _id: id }, { $set: { provider, orderId } });
  }

  async applyExtension(
    id: string,
    fromEnd: Date,
    newEnd: Date,
    addPaise: number,
  ): Promise<BookingRecord | null> {
    const doc = await BookingModel.findOneAndUpdate(
      { _id: id, end: fromEnd, status: { $in: ['CONFIRMED', 'ACTIVE'] } },
      { $set: { end: newEnd }, $inc: { extensionsPaise: addPaise } },
      { new: true },
    );
    return doc ? toRecord(doc) : null;
  }

  async findByOrderId(orderId: string): Promise<BookingRecord | null> {
    const doc = await BookingModel.findOne({ orderId });
    return doc ? toRecord(doc) : null;
  }

  async reassignSlot(id: string, slotId: string, slotLabel: string): Promise<void> {
    await BookingModel.updateOne(
      { _id: id },
      { $set: { slotId: new Types.ObjectId(slotId), slotLabel } },
    );
  }
}
