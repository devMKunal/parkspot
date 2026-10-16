import { mongo } from 'mongoose';
import { UserModel, type UserDoc, type UserRole } from './user.model.js';
import type { UserRecord } from './user.types.js';

export class DuplicateEmailError extends Error {
  constructor() {
    super('Duplicate email');
    this.name = 'DuplicateEmailError';
  }
}

export interface CreateUserInput {
  name: string;
  email: string;
  passwordHash: string;
  role?: UserRole;
}

export interface UserRepository {
  findById(id: string): Promise<UserRecord | null>;
  /** Email is matched case-insensitively (stored lowercased). */
  findByEmail(email: string): Promise<UserRecord | null>;
  /** Throws DuplicateEmailError when the email already exists. */
  create(input: CreateUserInput): Promise<UserRecord>;
}

const toRecord = (doc: UserDoc): UserRecord => ({
  id: doc.id as string,
  name: doc.name,
  email: doc.email,
  passwordHash: doc.passwordHash,
  role: doc.role,
  createdAt: doc.createdAt,
});

export class MongoUserRepository implements UserRepository {
  async findById(id: string): Promise<UserRecord | null> {
    if (!UserModel.base.isValidObjectId(id)) return null;
    const doc = await UserModel.findById(id);
    return doc ? toRecord(doc) : null;
  }

  async findByEmail(email: string): Promise<UserRecord | null> {
    const doc = await UserModel.findOne({ email: email.toLowerCase().trim() });
    return doc ? toRecord(doc) : null;
  }

  async create(input: CreateUserInput): Promise<UserRecord> {
    try {
      return toRecord(await UserModel.create(input));
    } catch (err) {
      // Rely on the unique index, not a findByEmail pre-check, so two parallel sign-ups can't both win.
      if (err instanceof mongo.MongoServerError && err.code === 11000)
        throw new DuplicateEmailError();
      throw err;
    }
  }
}
