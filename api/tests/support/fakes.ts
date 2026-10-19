import { randomUUID } from 'node:crypto';
import type {
  CreateRefreshTokenInput,
  RefreshTokenRecord,
  RefreshTokenRepository,
} from '../../src/modules/auth/refreshToken.repository.js';
import type { PasswordHasher } from '../../src/modules/auth/password.hasher.js';
import {
  DuplicateEmailError,
  type CreateUserInput,
  type UserRepository,
} from '../../src/modules/users/user.repository.js';
import type { UserRecord } from '../../src/modules/users/user.types.js';
import type { LotRepository, NearbyQuery } from '../../src/modules/lots/lot.repository.js';
import type { LotRecord, NearbyLotRecord } from '../../src/modules/lots/lot.types.js';

/** In-memory repositories with the same contracts as the Mongo ones, for fast unit tests. */
export class InMemoryUserRepository implements UserRepository {
  readonly rows = new Map<string, UserRecord>();

  async findById(id: string) {
    return this.rows.get(id) ?? null;
  }

  async findByEmail(email: string) {
    const needle = email.toLowerCase().trim();
    return [...this.rows.values()].find((u) => u.email === needle) ?? null;
  }

  async create(input: CreateUserInput) {
    if (await this.findByEmail(input.email)) throw new DuplicateEmailError();
    const user: UserRecord = {
      id: randomUUID(),
      name: input.name,
      email: input.email.toLowerCase().trim(),
      passwordHash: input.passwordHash,
      role: input.role ?? 'DRIVER',
      createdAt: new Date(),
    };
    this.rows.set(user.id, user);
    return user;
  }
}

export class InMemoryRefreshTokenRepository implements RefreshTokenRepository {
  readonly rows = new Map<string, RefreshTokenRecord & { tokenHash: string }>();

  newId() {
    return randomUUID();
  }

  async create(input: CreateRefreshTokenInput) {
    const row = {
      id: input.id ?? this.newId(),
      userId: input.userId,
      familyId: input.familyId,
      tokenHash: input.tokenHash,
      expiresAt: input.expiresAt,
      revokedAt: null,
      replacedById: null,
    };
    this.rows.set(row.id, row);
    return { ...row };
  }

  async findByHash(tokenHash: string) {
    const row = [...this.rows.values()].find((r) => r.tokenHash === tokenHash);
    return row ? { ...row } : null;
  }

  async markRotated(id: string, replacedById: string | null, at: Date) {
    const row = this.rows.get(id);
    if (!row || row.revokedAt) return false;
    row.revokedAt = at;
    row.replacedById = replacedById;
    return true;
  }

  async revokeFamily(familyId: string, at: Date) {
    for (const row of this.rows.values()) {
      if (row.familyId === familyId && !row.revokedAt) row.revokedAt = at;
    }
  }

  async revokeByHash(tokenHash: string, at: Date) {
    for (const row of this.rows.values()) {
      if (row.tokenHash === tokenHash && !row.revokedAt) row.revokedAt = at;
    }
  }
}

/** Fast, obviously-not-secure hasher so unit tests don't pay argon2's cost. */
export class FakePasswordHasher implements PasswordHasher {
  async hash(plain: string) {
    return `hashed:${plain}`;
  }

  async verify(hash: string, plain: string) {
    return hash === `hashed:${plain}`;
  }
}

export const TEST_TOKEN_CONFIG = {
  accessSecret: 'test-secret-test-secret-test-secret-1234',
  accessTtlSeconds: 900,
  refreshTtlDays: 30,
};

/** Haversine distance, good enough to stand in for MongoDB's spherical $geoNear in tests. */
export function distanceMeters(a: { lat: number; lng: number }, b: { lat: number; lng: number }) {
  const R = 6_371_008.8;
  const rad = (d: number) => (d * Math.PI) / 180;
  const dLat = rad(b.lat - a.lat);
  const dLng = rad(b.lng - a.lng);
  const h =
    Math.sin(dLat / 2) ** 2 + Math.cos(rad(a.lat)) * Math.cos(rad(b.lat)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

export class InMemoryLotRepository implements LotRepository {
  readonly rows = new Map<string, LotRecord>();

  add(lot: Omit<LotRecord, 'id'> & { id?: string }): LotRecord {
    const record = { ...lot, id: lot.id ?? randomUUID() };
    this.rows.set(record.id, record);
    return record;
  }

  async findNearby({ center, radiusMeters, limit }: NearbyQuery): Promise<NearbyLotRecord[]> {
    return [...this.rows.values()]
      .map((lot) => ({ ...lot, distanceMeters: distanceMeters(center, lot.location) }))
      .filter((lot) => lot.distanceMeters <= radiusMeters)
      .sort((a, b) => a.distanceMeters - b.distanceMeters)
      .slice(0, limit);
  }

  async findById(id: string) {
    return this.rows.get(id) ?? null;
  }
}
