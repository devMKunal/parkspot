import type { UserRole } from './user.model.js';

/** Persistence-agnostic user record, including the hash. Never send this to the client. */
export interface UserRecord {
  id: string;
  name: string;
  email: string;
  passwordHash: string;
  role: UserRole;
  createdAt: Date;
}

/** The public shape returned by the API. */
export interface UserDto {
  id: string;
  name: string;
  email: string;
  role: UserRole;
  createdAt: string;
}

export const toUserDto = (user: UserRecord): UserDto => ({
  id: user.id,
  name: user.name,
  email: user.email,
  role: user.role,
  createdAt: user.createdAt.toISOString(),
});
