import type { UserRole } from '../modules/users/user.model.js';

declare global {
  namespace Express {
    interface Request {
      auth?: { userId: string; role: UserRole };
    }
  }
}

export {};
