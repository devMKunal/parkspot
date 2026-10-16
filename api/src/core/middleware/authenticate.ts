import type { RequestHandler } from 'express';
import { Errors } from '../errors/AppError.js';
import type { TokenService } from '../../modules/auth/token.service.js';

/** Verifies the Bearer access token and sets `req.auth`. Throws TOKEN_EXPIRED or TOKEN_INVALID. */
export const authenticate =
  (tokens: TokenService): RequestHandler =>
  (req, _res, next) => {
    const header = req.headers.authorization;
    const [scheme, token] = header?.split(' ') ?? [];
    if (scheme !== 'Bearer' || !token) throw Errors.tokenInvalid();

    const claims = tokens.verifyAccessToken(token);
    req.auth = { userId: claims.sub, role: claims.role };
    next();
  };
