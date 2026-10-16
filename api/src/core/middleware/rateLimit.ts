import { rateLimit } from 'express-rate-limit';

/** Brute-force guard for credential endpoints: 5 attempts per minute per IP. */
export const authRateLimit = rateLimit({
  windowMs: 60_000,
  limit: 5,
  standardHeaders: 'draft-8',
  legacyHeaders: false,
  handler: (_req, res) => {
    res.status(429).json({
      error: {
        code: 'RATE_LIMITED',
        message: 'Too many attempts, try again shortly',
        details: null,
      },
    });
  },
});
