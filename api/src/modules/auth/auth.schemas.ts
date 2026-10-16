import { z } from 'zod';

const email = z.email().trim().toLowerCase();
const password = z.string().min(8, 'Password must be at least 8 characters').max(128);

export const RegisterBody = z.object({
  name: z.string().trim().min(1).max(80),
  email,
  password,
});

export const LoginBody = z.object({
  email,
  // No min length here: a short password is just "incorrect", not a validation hint.
  password: z.string().min(1).max(128),
});

export const RefreshBody = z.object({ refreshToken: z.string().min(1) });
export const LogoutBody = RefreshBody;

export type RegisterInput = z.infer<typeof RegisterBody>;
export type LoginInput = z.infer<typeof LoginBody>;
export type RefreshInput = z.infer<typeof RefreshBody>;
export type LogoutInput = z.infer<typeof LogoutBody>;
