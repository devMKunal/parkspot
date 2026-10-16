import { Router } from 'express';
import { authenticate } from '../../core/middleware/authenticate.js';
import { Errors } from '../../core/errors/AppError.js';
import type { TokenService } from '../auth/token.service.js';
import type { UserRepository } from './user.repository.js';
import { toUserDto } from './user.types.js';

export function usersRouter(deps: { users: UserRepository; tokens: TokenService }): Router {
  const router = Router();

  router.get('/me', authenticate(deps.tokens), async (req, res) => {
    // authenticate() guarantees req.auth; a deleted user with a live token is treated as invalid.
    const user = await deps.users.findById(req.auth!.userId);
    if (!user) throw Errors.tokenInvalid();
    res.json({ user: toUserDto(user) });
  });

  return router;
}
