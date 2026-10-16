import type { RequestHandler } from 'express';
import { z } from 'zod';
import { Errors } from '../errors/AppError.js';

/** Validates and replaces `req.body` with the parsed value, or throws a 422 with field errors. */
export const validateBody =
  <S extends z.ZodType>(schema: S): RequestHandler =>
  (req, _res, next) => {
    const result = schema.safeParse(req.body);
    if (!result.success) {
      throw Errors.validation(z.flattenError(result.error).fieldErrors);
    }
    req.body = result.data;
    next();
  };
