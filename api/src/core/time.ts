/** Bookings are claimed in fixed buckets; see docs/bookings-api.md ("Why time buckets"). */
export const BUCKET_MINUTES = 15;
const BUCKET_MS = BUCKET_MINUTES * 60_000;

export const floorToBucket = (date: Date): Date =>
  new Date(Math.floor(date.getTime() / BUCKET_MS) * BUCKET_MS);

export const isOnBucketBoundary = (date: Date): boolean => date.getTime() % BUCKET_MS === 0;

/** Bucket start times covering [start, end). `start` must be on a boundary. */
export function bucketsBetween(start: Date, end: Date): Date[] {
  const buckets: Date[] = [];
  for (let t = start.getTime(); t < end.getTime(); t += BUCKET_MS) buckets.push(new Date(t));
  return buckets;
}

export const addMinutes = (date: Date, minutes: number): Date =>
  new Date(date.getTime() + minutes * 60_000);
