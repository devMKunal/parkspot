import { Router } from 'express';
import { validateBody } from '../../core/http/validate.js';
import { authRateLimit } from '../../core/middleware/rateLimit.js';
import { AuthController } from './auth.controller.js';
import type { AuthService } from './auth.service.js';
import { LoginBody, LogoutBody, RefreshBody, RegisterBody } from './auth.schemas.js';

export function authRouter(auth: AuthService, opts: { rateLimit?: boolean } = {}): Router {
  const controller = new AuthController(auth);
  const router = Router();
  const limited = opts.rateLimit === false ? [] : [authRateLimit];

  router.post('/register', ...limited, validateBody(RegisterBody), controller.register);
  router.post('/login', ...limited, validateBody(LoginBody), controller.login);
  router.post('/refresh', validateBody(RefreshBody), controller.refresh);
  router.post('/logout', validateBody(LogoutBody), controller.logout);

  return router;
}
