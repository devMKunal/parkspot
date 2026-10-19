import { z } from 'zod';

export const MAX_RADIUS_METERS = 10_000;

export const NearbyQuery = z.object({
  lat: z.coerce.number().min(-90).max(90),
  lng: z.coerce.number().min(-180).max(180),
  radius: z.coerce.number().int().positive().max(MAX_RADIUS_METERS).default(2_000),
  limit: z.coerce.number().int().positive().max(100).default(50),
});

export type NearbyQueryInput = z.infer<typeof NearbyQuery>;
