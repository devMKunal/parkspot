import { createHmac, timingSafeEqual } from 'node:crypto';

export const hmacSha256Hex = (secret: string, payload: string | Buffer): string =>
  createHmac('sha256', secret).update(payload).digest('hex');

/** Constant-time comparison of two hex digests; false for any malformed input. */
export function safeEqualHex(expectedHex: string, actual: string | undefined): boolean {
  if (!actual || !/^[0-9a-f]+$/i.test(actual)) return false;
  const a = Buffer.from(expectedHex, 'hex');
  const b = Buffer.from(actual, 'hex');
  return a.length === b.length && timingSafeEqual(a, b);
}
