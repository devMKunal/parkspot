import { MongoMemoryServer } from 'mongodb-memory-server';
import mongoose, { Types } from 'mongoose';
import { afterAll, beforeAll, beforeEach, describe, expect, it } from 'vitest';
import { RefreshTokenModel } from '../../src/modules/auth/refreshToken.model.js';
import { MongoRefreshTokenRepository } from '../../src/modules/auth/refreshToken.repository.js';

/** Proves the atomic guarantees against real MongoDB. Run with `npm run test:int`. */
describe('MongoRefreshTokenRepository', () => {
  let mongod: MongoMemoryServer;
  const repo = new MongoRefreshTokenRepository();
  const userId = new Types.ObjectId().toString();
  const at = new Date();

  const seed = (familyId = 'fam-1', tokenHash = `h-${Math.random()}`) =>
    repo.create({ userId, familyId, tokenHash, expiresAt: new Date(Date.now() + 60_000) });

  beforeAll(async () => {
    mongod = await MongoMemoryServer.create();
    await mongoose.connect(mongod.getUri());
    await RefreshTokenModel.syncIndexes();
  });

  afterAll(async () => {
    await mongoose.disconnect();
    await mongod.stop();
  });

  beforeEach(async () => {
    await RefreshTokenModel.deleteMany({});
  });

  it('markRotated: exactly one of many parallel calls wins', async () => {
    const token = await seed();
    const results = await Promise.all(
      Array.from({ length: 10 }, () => repo.markRotated(token.id, null, at)),
    );
    expect(results.filter(Boolean)).toHaveLength(1);
  });

  it('create with a pre-allocated id lets the old token point at its replacement', async () => {
    const old = await seed();
    const nextId = repo.newId();
    expect(await repo.markRotated(old.id, nextId, at)).toBe(true);
    const next = await repo.create({
      id: nextId,
      userId,
      familyId: 'fam-1',
      tokenHash: 'next',
      expiresAt: new Date(Date.now() + 60_000),
    });
    expect(next.id).toBe(nextId);
    expect((await repo.findByHash('next'))?.id).toBe(nextId);
  });

  it('revokeFamily revokes only that family', async () => {
    await seed('fam-1', 'a');
    await seed('fam-1', 'b');
    await seed('fam-2', 'c');
    await repo.revokeFamily('fam-1', at);

    expect((await repo.findByHash('a'))?.revokedAt).not.toBeNull();
    expect((await repo.findByHash('b'))?.revokedAt).not.toBeNull();
    expect((await repo.findByHash('c'))?.revokedAt).toBeNull();
  });

  it('tokenHash is unique', async () => {
    await seed('fam-1', 'dup');
    await expect(seed('fam-1', 'dup')).rejects.toThrow();
  });
});
