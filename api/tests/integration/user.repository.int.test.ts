import { MongoMemoryServer } from 'mongodb-memory-server';
import mongoose from 'mongoose';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { UserModel } from '../../src/modules/users/user.model.js';
import {
  DuplicateEmailError,
  MongoUserRepository,
} from '../../src/modules/users/user.repository.js';

/** Proves the unique-email guarantee against real MongoDB. Run with `npm run test:int`. */
describe('MongoUserRepository', () => {
  let mongod: MongoMemoryServer;
  const repo = new MongoUserRepository();
  const input = (email: string) => ({ name: 'Asha', email, passwordHash: 'hash' });

  beforeAll(async () => {
    mongod = await MongoMemoryServer.create();
    await mongoose.connect(mongod.getUri());
    await UserModel.syncIndexes();
  });

  afterAll(async () => {
    await mongoose.disconnect();
    await mongod.stop();
  });

  beforeEach(async () => {
    await UserModel.deleteMany({});
  });

  it('create: exactly one of many parallel sign-ups with the same email wins', async () => {
    const results = await Promise.allSettled(
      Array.from({ length: 10 }, () => repo.create(input('race@example.com'))),
    );
    expect(results.filter((r) => r.status === 'fulfilled')).toHaveLength(1);
    for (const r of results.filter((r) => r.status === 'rejected')) {
      expect(r.reason).toBeInstanceOf(DuplicateEmailError);
    }
  });

  it('treats emails differing only in case or spacing as the same account', async () => {
    const user = await repo.create(input('Asha@Example.com'));
    await expect(repo.create(input(' asha@example.COM '))).rejects.toBeInstanceOf(
      DuplicateEmailError,
    );
    expect((await repo.findByEmail('ASHA@example.com '))?.id).toBe(user.id);
  });

  it('findById returns null for a malformed id instead of throwing', async () => {
    expect(await repo.findById('not-an-id')).toBeNull();
  });
});
