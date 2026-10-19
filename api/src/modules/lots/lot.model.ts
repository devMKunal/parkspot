import { Schema, model, type InferSchemaType, type HydratedDocument } from 'mongoose';

const pointSchema = new Schema(
  {
    type: { type: String, enum: ['Point'], required: true, default: 'Point' },
    // GeoJSON order is [longitude, latitude].
    coordinates: { type: [Number], required: true },
  },
  { _id: false },
);

const lotSchema = new Schema(
  {
    name: { type: String, required: true, trim: true },
    address: { type: String, required: true, trim: true },
    location: { type: pointSchema, required: true },
    // Money is stored in minor units (paise) as an integer, never as a float of rupees.
    pricePerHourPaise: { type: Number, required: true, min: 0 },
    totalSlots: { type: Number, required: true, min: 0 },
    photos: { type: [String], default: [] },
    ownerId: { type: Schema.Types.ObjectId, ref: 'User', default: null },
  },
  { timestamps: true },
);
lotSchema.index({ location: '2dsphere' });

const slotSchema = new Schema(
  {
    lotId: { type: Schema.Types.ObjectId, ref: 'Lot', required: true },
    label: { type: String, required: true },
  },
  { timestamps: true },
);
slotSchema.index({ lotId: 1, label: 1 }, { unique: true });

/**
 * One 15-minute claim on one slot. The unique (slotId, bucketStart) index is the lock that
 * stops two bookings overlapping; see docs/bookings-api.md.
 */
const slotHoldSchema = new Schema({
  slotId: { type: Schema.Types.ObjectId, ref: 'Slot', required: true },
  lotId: { type: Schema.Types.ObjectId, ref: 'Lot', required: true },
  bucketStart: { type: Date, required: true },
  bookingId: { type: Schema.Types.ObjectId, ref: 'Booking', default: null },
  // Set while the booking is unpaid; the TTL index deletes the hold once it passes.
  // Confirmed bookings clear it, and TTL ignores documents without a date here.
  expiresAt: { type: Date, default: null },
});
slotHoldSchema.index({ slotId: 1, bucketStart: 1 }, { unique: true });
slotHoldSchema.index({ lotId: 1, bucketStart: 1 });
slotHoldSchema.index({ bookingId: 1 });
slotHoldSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

export type LotDoc = HydratedDocument<InferSchemaType<typeof lotSchema>>;
export const LotModel = model('Lot', lotSchema);
export const SlotModel = model('Slot', slotSchema);
export const SlotHoldModel = model('SlotHold', slotHoldSchema);
