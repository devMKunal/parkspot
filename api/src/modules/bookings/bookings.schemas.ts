import { z } from 'zod';
import { BOOKING_STATUSES } from './booking.model.js';

export const MIN_DURATION_MINUTES = 30;
export const MAX_DURATION_MINUTES = 12 * 60;

export const CreateBookingBody = z.object({
  lotId: z.string().min(1),
  start: z.iso.datetime({ offset: true }).transform((value) => new Date(value)),
  durationMinutes: z
    .number()
    .int()
    .min(MIN_DURATION_MINUTES)
    .max(MAX_DURATION_MINUTES)
    .refine((m) => m % 15 === 0, 'Duration must be a multiple of 15 minutes'),
});

export const ListBookingsQuery = z.object({
  status: z
    .string()
    .optional()
    .transform((value) => (value ? value.split(',').map((s) => s.trim()) : undefined))
    .pipe(z.array(z.enum(BOOKING_STATUSES)).optional()),
});

export type CreateBookingInput = z.infer<typeof CreateBookingBody>;
