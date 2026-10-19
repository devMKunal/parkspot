import { describe, expect, it } from 'vitest';
import { Argon2PasswordHasher } from '../src/modules/auth/password.hasher.js';

describe('Argon2PasswordHasher', () => {
  const hasher = new Argon2PasswordHasher();

  it('produces an argon2id hash that verifies only the original password', async () => {
    const hash = await hasher.hash('correct-horse');
    expect(hash.startsWith('$argon2id$')).toBe(true);
    expect(await hasher.verify(hash, 'correct-horse')).toBe(true);
    expect(await hasher.verify(hash, 'wrong-horse')).toBe(false);
  });
});
