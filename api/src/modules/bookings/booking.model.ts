import { Schema, model, type InferSchemaType, type HydratedDocument } from 'mongoose';

export const BOOKING_STATUSES = [
  'PENDING',
  'CONFIRMED',
  'ACTIVE',
  'COMPLETED',
  'CANCELLED',
  'FAILED',
  'EXPIRED',
] as const;
export type BookingStatus = (typeof BOOKING_STATUSES)[number];

const bookingSchema = new Schema(
  {
    userId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    lotId: { type: Schema.Types.ObjectId, ref: 'Lot', required: true },
    slotId: { type: Schema.Types.ObjectId, ref: 'Slot', required: true },
    slotLabel: { type: String, required: true },
    start: { type: Date, required: true },
    end: { type: Date, required: true },
    /** What the booking's own order charged. Never changes, so refunds of it stay correct. */
    amountPaise: { type: Number, required: true, min: 0 },
    /** Sum of paid extensions, charged by their own orders. */
    extensionsPaise: { type: Number, default: 0, min: 0 },
    currency: { type: String, enum: ['INR'], default: 'INR', required: true },
    status: { type: String, enum: BOOKING_STATUSES, default: 'PENDING', required: true },
    lockExpiresAt: { type: Date, default: null },
    provider: { type: String, default: null },
    orderId: { type: String, default: null },
    paymentId: { type: String, default: null },
    /** Shown as the QR pass once paid; what a gate scanner would check. */
    passCode: { type: String, default: null },
    endedAt: { type: Date, default: null },
  },
  { timestamps: true },
);
bookingSchema.index({ userId: 1, createdAt: -1 });
bookingSchema.index({ userId: 1, status: 1 });
bookingSchema.index(
  { orderId: 1 },
  { unique: true, partialFilterExpression: { orderId: { $type: 'string' } } },
);

export type BookingDoc = HydratedDocument<InferSchemaType<typeof bookingSchema>>;
export const BookingModel = model('Booking', bookingSchema);

export const EXTENSION_STATUSES = [
  'PENDING',
  'CONFIRMED',
  'CANCELLED',
  'FAILED',
  'EXPIRED',
] as const;
export type ExtensionStatus = (typeof EXTENSION_STATUSES)[number];

/** Extra time on a booking, paid with its own order. Its slot holds are owned by its own id. */
const extensionSchema = new Schema(
  {
    bookingId: { type: Schema.Types.ObjectId, ref: 'Booking', required: true, index: true },
    userId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    start: { type: Date, required: true },
    end: { type: Date, required: true },
    minutes: { type: Number, required: true },
    amountPaise: { type: Number, required: true, min: 0 },
    status: { type: String, enum: EXTENSION_STATUSES, default: 'PENDING', required: true },
    lockExpiresAt: { type: Date, default: null },
    orderId: { type: String, default: null },
    paymentId: { type: String, default: null },
  },
  { timestamps: true },
);
extensionSchema.index(
  { orderId: 1 },
  { unique: true, partialFilterExpression: { orderId: { $type: 'string' } } },
);

export type ExtensionDoc = HydratedDocument<InferSchemaType<typeof extensionSchema>>;
export const ExtensionModel = model('BookingExtension', extensionSchema);
