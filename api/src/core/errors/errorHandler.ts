import type { ErrorRequestHandler, RequestHandler } from 'express';
import { AppError, Errors } from './AppError.js';
import { logger } from '../logger.js';

export const notFoundHandler: RequestHandler = (req) => {
  throw Errors.notFound(`Route ${req.method} ${req.path}`);
};

/** Single place that turns any thrown error into the `{ error: { code, message, details } }` envelope. */
export const errorHandler: ErrorRequestHandler = (err, _req, res, _next) => {
  if (err instanceof AppError) {
    res.status(err.status).json({
      error: { code: err.code, message: err.message, details: err.details ?? null },
    });
    return;
  }

  // express.json() throws a SyntaxError with status 400 on malformed JSON.
  if (err instanceof SyntaxError && 'status' in err && err.status === 400) {
    res
      .status(400)
      .json({ error: { code: 'BAD_REQUEST', message: 'Malformed JSON', details: null } });
    return;
  }

  logger.error({ err }, 'Unhandled error');
  res.status(500).json({
    error: { code: 'INTERNAL_ERROR', message: 'Something went wrong', details: null },
  });
};
