import { Schema, Types, model, type InferSchemaType, type HydratedDocument } from 'mongoose';

const refreshTokenSchema = new Schema(
  {
    userId: { type: Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    familyId: { type: String, required: true, index: true },
    tokenHash: { type: String, required: true, unique: true },
    // TTL index: MongoDB deletes the document once expiresAt has passed.
    expiresAt: { type: Date, required: true, index: { expires: 0 } },
    revokedAt: { type: Date, default: null },
    replacedById: { type: Types.ObjectId, default: null },
    userAgent: { type: String, default: null },
  },
  { timestamps: { createdAt: true, updatedAt: false } },
);

export type RefreshTokenDoc = HydratedDocument<InferSchemaType<typeof refreshTokenSchema>>;
export const RefreshTokenModel = model('RefreshToken', refreshTokenSchema);
