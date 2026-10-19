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
    amountPaise: { type: Number, required: true, min: 0 },
    currency: { type: String, enum: ['INR'], default: 'INR', required: true },
    status: { type: String, enum: BOOKING_STATUSES, default: 'PENDING', required: true },
    lockExpiresAt: { type: Date, default: null },
    provider: { type: String, default: null },
    orderId: { type: String, default: null },
    paymentId: { type: String, default: null },
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
