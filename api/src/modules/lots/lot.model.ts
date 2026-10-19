import { Schema, model, type InferSchemaType, type HydratedDocument } from 'mongoose';

export const SLOT_STATUSES = ['FREE', 'LOCKED', 'BOOKED'] as const;
export type SlotStatus = (typeof SLOT_STATUSES)[number];

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
    status: { type: String, enum: SLOT_STATUSES, default: 'FREE', required: true },
  },
  { timestamps: true },
);
slotSchema.index({ lotId: 1, status: 1 });
slotSchema.index({ lotId: 1, label: 1 }, { unique: true });

export type LotDoc = HydratedDocument<InferSchemaType<typeof lotSchema>>;
export const LotModel = model('Lot', lotSchema);
export const SlotModel = model('Slot', slotSchema);
