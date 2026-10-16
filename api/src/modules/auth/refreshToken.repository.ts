import { Types } from 'mongoose';
import { RefreshTokenModel, type RefreshTokenDoc } from './refreshToken.model.js';

export interface RefreshTokenRecord {
  id: string;
  userId: string;
  familyId: string;
  expiresAt: Date;
  revokedAt: Date | null;
  replacedById: string | null;
}

export interface CreateRefreshTokenInput {
  /** Optional pre-allocated id (`newObjectId()`), so the old token can point at its replacement. */
  id?: string;
  userId: string;
  familyId: string;
  tokenHash: string;
  expiresAt: Date;
  userAgent?: string;
}

export interface RefreshTokenRepository {
  /** Allocates an id without writing, for `create({ id })`. */
  newId(): string;
  create(input: CreateRefreshTokenInput): Promise<RefreshTokenRecord>;
  findByHash(tokenHash: string): Promise<RefreshTokenRecord | null>;
  /**
   * Atomically revokes the token only if it is still active.
   * Returns false when another request already rotated or revoked it, which is how
   * two parallel refreshes with the same token are told apart: exactly one gets `true`.
   */
  markRotated(id: string, replacedById: string | null, at: Date): Promise<boolean>;
  /** Revokes every still-active token in the family (reuse detected, or logout everywhere). */
  revokeFamily(familyId: string, at: Date): Promise<void>;
  /** Idempotent: no-op when the token is unknown or already revoked. */
  revokeByHash(tokenHash: string, at: Date): Promise<void>;
}

const toRecord = (doc: RefreshTokenDoc): RefreshTokenRecord => ({
  id: doc.id as string,
  userId: doc.userId.toString(),
  familyId: doc.familyId,
  expiresAt: doc.expiresAt,
  revokedAt: doc.revokedAt ?? null,
  replacedById: doc.replacedById?.toString() ?? null,
});

export class MongoRefreshTokenRepository implements RefreshTokenRepository {
  newId(): string {
    return new Types.ObjectId().toString();
  }

  async create(input: CreateRefreshTokenInput): Promise<RefreshTokenRecord> {
    return toRecord(
      await RefreshTokenModel.create({
        _id: input.id ? new Types.ObjectId(input.id) : new Types.ObjectId(),
        userId: new Types.ObjectId(input.userId),
        familyId: input.familyId,
        tokenHash: input.tokenHash,
        expiresAt: input.expiresAt,
        userAgent: input.userAgent ?? null,
      }),
    );
  }

  async findByHash(tokenHash: string): Promise<RefreshTokenRecord | null> {
    const doc = await RefreshTokenModel.findOne({ tokenHash });
    return doc ? toRecord(doc) : null;
  }

  async markRotated(id: string, replacedById: string | null, at: Date): Promise<boolean> {
    const result = await RefreshTokenModel.updateOne(
      { _id: id, revokedAt: null },
      { $set: { revokedAt: at, replacedById } },
    );
    return result.modifiedCount === 1;
  }

  async revokeFamily(familyId: string, at: Date): Promise<void> {
    await RefreshTokenModel.updateMany({ familyId, revokedAt: null }, { $set: { revokedAt: at } });
  }

  async revokeByHash(tokenHash: string, at: Date): Promise<void> {
    await RefreshTokenModel.updateOne({ tokenHash, revokedAt: null }, { $set: { revokedAt: at } });
  }
}
