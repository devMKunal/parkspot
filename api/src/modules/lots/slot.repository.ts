import mongoose, { Types, mongo } from 'mongoose';
import { SlotHoldModel, SlotModel } from './lot.model.js';
import { liveHoldFilter } from './lot.repository.js';

export interface SlotRecord {
  id: string;
  lotId: string;
  label: string;
}

export interface SlotRepository {
  listByLot(lotId: string): Promise<SlotRecord[]>;
}

export interface ClaimInput {
  slotId: string;
  lotId: string;
  bookingId: string;
  buckets: Date[];
  /** null for a confirmed claim that never expires. */
  expiresAt: Date | null;
}

export interface SlotHoldRepository {
  /** Slots in the lot with a live hold in any of the buckets. */
  busySlotIds(lotId: string, buckets: Date[], now: Date): Promise<Set<string>>;
  /**
   * Claims every bucket on the slot for the booking, or nothing.
   * Returns false when another live hold already owns one of the buckets.
   */
  tryClaim(input: ClaimInput, now: Date): Promise<boolean>;
  /** Removes all holds of the booking (cancel, failure). Idempotent. */
  releaseBooking(bookingId: string): Promise<void>;
  /**
   * Makes the booking's remaining holds permanent (paid). Returns how many holds it still owns,
   * which is fewer than its buckets if a lapsed lock was taken over by someone else.
   */
  confirmBooking(bookingId: string): Promise<number>;
}

export class MongoSlotRepository implements SlotRepository {
  async listByLot(lotId: string): Promise<SlotRecord[]> {
    if (!mongoose.isValidObjectId(lotId)) return [];
    const docs = await SlotModel.find({ lotId }).sort({ label: 1 }).lean();
    return docs.map((d) => ({ id: d._id.toString(), lotId: d.lotId.toString(), label: d.label }));
  }
}

export class MongoSlotHoldRepository implements SlotHoldRepository {
  async busySlotIds(lotId: string, buckets: Date[], now: Date): Promise<Set<string>> {
    const ids = await SlotHoldModel.distinct('slotId', {
      lotId: new Types.ObjectId(lotId),
      bucketStart: { $in: buckets },
      ...liveHoldFilter(now),
    });
    return new Set(ids.map((id) => id.toString()));
  }

  async tryClaim(input: ClaimInput, now: Date): Promise<boolean> {
    const slotId = new Types.ObjectId(input.slotId);
    const bookingId = new Types.ObjectId(input.bookingId);

    // Expired holds that TTL hasn't swept yet would still trip the unique index.
    await SlotHoldModel.deleteMany({
      slotId,
      bucketStart: { $in: input.buckets },
      expiresAt: { $ne: null, $lte: now },
    });

    try {
      await SlotHoldModel.insertMany(
        input.buckets.map((bucketStart) => ({
          slotId,
          lotId: new Types.ObjectId(input.lotId),
          bucketStart,
          bookingId,
          expiresAt: input.expiresAt,
        })),
        { ordered: true },
      );
      return true;
    } catch (err) {
      if (!isDuplicateKey(err)) throw err;
      // Lost the race for at least one bucket: undo our partial claim on this slot.
      await SlotHoldModel.deleteMany({ slotId, bookingId });
      return false;
    }
  }

  async releaseBooking(bookingId: string): Promise<void> {
    if (!mongoose.isValidObjectId(bookingId)) return;
    await SlotHoldModel.deleteMany({ bookingId: new Types.ObjectId(bookingId) });
  }

  async confirmBooking(bookingId: string): Promise<number> {
    const result = await SlotHoldModel.updateMany(
      { bookingId: new Types.ObjectId(bookingId) },
      { $set: { expiresAt: null } },
    );
    return result.matchedCount;
  }
}

const isDuplicateKey = (err: unknown): boolean =>
  (err instanceof mongo.MongoServerError || err instanceof mongo.MongoBulkWriteError) &&
  err.code === 11000;
