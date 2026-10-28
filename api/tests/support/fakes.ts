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
import type {
  ClaimInput,
  SlotHoldRepository,
  SlotRecord,
  SlotRepository,
} from '../../src/modules/lots/slot.repository.js';
import type { BookingStatus } from '../../src/modules/bookings/booking.model.js';
import type {
  BookingPatch,
  BookingRepository,
  CreateBookingInput,
} from '../../src/modules/bookings/booking.repository.js';
import type { BookingRecord, ExtensionRecord } from '../../src/modules/bookings/booking.types.js';
import type { ExtensionStatus } from '../../src/modules/bookings/booking.model.js';
import type {
  CreateExtensionInput,
  ExtensionRepository,
} from '../../src/modules/bookings/extension.repository.js';
import type {
  CheckoutResult,
  CreateOrderInput,
  CreatedOrder,
  PaymentGateway,
  WebhookEvent,
} from '../../src/modules/payments/payment.gateway.js';
import { hmacSha256Hex } from '../../src/modules/payments/hmac.js';
import type { PaymentStatus } from '../../src/modules/payments/payment.model.js';
import type {
  PaymentRecordInput,
  PaymentRepository,
} from '../../src/modules/payments/payment.repository.js';
import { RazorpayGateway } from '../../src/modules/payments/razorpay.gateway.js';

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

export class InMemorySlotRepository implements SlotRepository {
  readonly rows: SlotRecord[] = [];

  addMany(lotId: string, count: number): SlotRecord[] {
    const created = Array.from({ length: count }, (_, i) => ({
      id: randomUUID(),
      lotId,
      label: `S${String(i + 1).padStart(3, '0')}`,
    }));
    this.rows.push(...created);
    return created;
  }

  async listByLot(lotId: string) {
    return this.rows.filter((s) => s.lotId === lotId);
  }
}

interface HoldRow {
  slotId: string;
  lotId: string;
  bucketStart: number;
  bookingId: string;
  expiresAt: Date | null;
}

/** Mirrors the unique (slotId, bucketStart) index: a claim is all-or-nothing per slot. */
export class InMemorySlotHoldRepository implements SlotHoldRepository {
  readonly rows = new Map<string, HoldRow>();

  private static key(slotId: string, bucket: number) {
    return `${slotId}@${bucket}`;
  }

  private static live(row: HoldRow, now: Date) {
    return row.expiresAt === null || row.expiresAt > now;
  }

  async busySlotIds(lotId: string, buckets: Date[], now: Date) {
    const times = new Set(buckets.map((b) => b.getTime()));
    return new Set(
      [...this.rows.values()]
        .filter((r) => r.lotId === lotId && times.has(r.bucketStart))
        .filter((r) => InMemorySlotHoldRepository.live(r, now))
        .map((r) => r.slotId),
    );
  }

  // Deliberately synchronous inside: like a unique index, no other claim can interleave.
  async tryClaim(input: ClaimInput, now: Date) {
    const keys = input.buckets.map((b) =>
      InMemorySlotHoldRepository.key(input.slotId, b.getTime()),
    );
    const taken = keys.some((k) => {
      const row = this.rows.get(k);
      return row !== undefined && InMemorySlotHoldRepository.live(row, now);
    });
    if (taken) return false;
    input.buckets.forEach((b, i) =>
      this.rows.set(keys[i]!, {
        slotId: input.slotId,
        lotId: input.lotId,
        bucketStart: b.getTime(),
        bookingId: input.bookingId,
        expiresAt: input.expiresAt,
      }),
    );
    return true;
  }

  async releaseBooking(bookingId: string) {
    for (const [k, row] of this.rows) if (row.bookingId === bookingId) this.rows.delete(k);
  }

  async releaseFrom(ownerIds: string[], from: Date) {
    for (const [k, row] of this.rows) {
      if (ownerIds.includes(row.bookingId) && row.bucketStart >= from.getTime())
        this.rows.delete(k);
    }
  }

  async confirmBooking(bookingId: string) {
    const mine = this.holdsOf(bookingId);
    for (const row of mine) row.expiresAt = null;
    return mine.length;
  }

  holdsOf(bookingId: string) {
    return [...this.rows.values()].filter((r) => r.bookingId === bookingId);
  }
}

export class InMemoryBookingRepository implements BookingRepository {
  readonly rows = new Map<string, BookingRecord>();

  newId() {
    return randomUUID();
  }

  async create(input: CreateBookingInput) {
    const row: BookingRecord = {
      ...input,
      provider: null,
      orderId: null,
      paymentId: null,
      passCode: null,
      endedAt: null,
      extensionsPaise: 0,
      createdAt: new Date(Date.now() + this.rows.size), // keeps creation order stable
    };
    this.rows.set(row.id, row);
    return { ...row };
  }

  async findById(id: string) {
    const row = this.rows.get(id);
    return row ? { ...row } : null;
  }

  async listByUser(userId: string, statuses?: BookingStatus[]) {
    return [...this.rows.values()]
      .filter((b) => b.userId === userId && (!statuses || statuses.includes(b.status)))
      .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime())
      .map((b) => ({ ...b }));
  }

  async transition(id: string, from: BookingStatus[], to: BookingStatus, patch: BookingPatch = {}) {
    const row = this.rows.get(id);
    if (!row || !from.includes(row.status)) return null;
    Object.assign(row, patch, { status: to });
    return { ...row };
  }

  async applyExtension(id: string, fromEnd: Date, newEnd: Date, addPaise: number) {
    const row = this.rows.get(id);
    if (!row || row.end.getTime() !== fromEnd.getTime()) return null;
    if (row.status !== 'CONFIRMED' && row.status !== 'ACTIVE') return null;
    Object.assign(row, { end: newEnd, extensionsPaise: row.extensionsPaise + addPaise });
    return { ...row };
  }

  async attachOrder(id: string, provider: string, orderId: string) {
    const row = this.rows.get(id);
    if (row) Object.assign(row, { provider, orderId });
  }

  async findByOrderId(orderId: string) {
    const row = [...this.rows.values()].find((b) => b.orderId === orderId);
    return row ? { ...row } : null;
  }

  async reassignSlot(id: string, slotId: string, slotLabel: string) {
    const row = this.rows.get(id);
    if (row) Object.assign(row, { slotId, slotLabel });
  }
}

export const FAKE_KEY_SECRET = 'fake_key_secret';
export const FAKE_WEBHOOK_SECRET = 'fake_webhook_secret';

/** Behaves like Razorpay, including real HMAC signatures, without the network. */
export class FakePaymentGateway implements PaymentGateway {
  readonly provider = 'razorpay' as const;
  readonly publicKey = 'rzp_test_fake';
  readonly orders: CreateOrderInput[] = [];
  readonly refunds: { paymentId: string; amountPaise: number }[] = [];
  failNext = false;
  private readonly real = new RazorpayGateway({
    keyId: this.publicKey,
    keySecret: FAKE_KEY_SECRET,
    webhookSecret: FAKE_WEBHOOK_SECRET,
  });

  async createOrder(input: CreateOrderInput): Promise<CreatedOrder> {
    if (this.failNext) {
      this.failNext = false;
      throw new Error('provider down');
    }
    this.orders.push(input);
    return {
      provider: 'razorpay',
      orderId: `order_${this.orders.length}`,
      amountPaise: input.amountPaise,
      currency: input.currency,
    };
  }

  verifyCheckout(result: CheckoutResult) {
    return this.real.verifyCheckout(result);
  }

  parseWebhook(rawBody: Buffer, signature: string | undefined): WebhookEvent | null {
    return this.real.parseWebhook(rawBody, signature);
  }

  readonly captured: string[] = [];
  failCapture = false;

  async capture(paymentId: string) {
    if (this.failCapture) throw new Error('provider down');
    if (!this.captured.includes(paymentId)) this.captured.push(paymentId);
  }

  async refund(paymentId: string, amountPaise: number) {
    this.refunds.push({ paymentId, amountPaise });
  }

  /** What Razorpay checkout returns to the app after a successful payment. */
  static checkoutSuccess(orderId: string, paymentId = `pay_${orderId}`): CheckoutResult {
    return {
      orderId,
      paymentId,
      signature: hmacSha256Hex(FAKE_KEY_SECRET, `${orderId}|${paymentId}`),
    };
  }

  /** A signed payment.captured (or .authorized) webhook body, as Razorpay would POST it. */
  static capturedWebhook(
    orderId: string,
    paymentId: string,
    amountPaise: number,
    event: 'payment.captured' | 'payment.authorized' = 'payment.captured',
  ) {
    const body = JSON.stringify({
      event,
      payload: {
        payment: {
          entity: {
            id: paymentId,
            order_id: orderId,
            amount: amountPaise,
            currency: 'INR',
            status: event === 'payment.captured' ? 'captured' : 'authorized',
          },
        },
      },
    });
    return { body, signature: hmacSha256Hex(FAKE_WEBHOOK_SECRET, body) };
  }
}

export class InMemoryPaymentRepository implements PaymentRepository {
  readonly rows = new Map<string, PaymentRecordInput & { status: PaymentStatus }>();

  async recordCaptured(input: PaymentRecordInput) {
    if (!this.rows.has(input.paymentId)) {
      this.rows.set(input.paymentId, { ...input, status: 'CAPTURED' });
    }
  }

  async claimRefund(paymentId: string) {
    const row = this.rows.get(paymentId);
    if (!row || row.status !== 'CAPTURED') return false;
    row.status = 'REFUND_PENDING';
    return true;
  }

  async setStatus(paymentId: string, status: PaymentStatus) {
    const row = this.rows.get(paymentId);
    if (row) row.status = status;
  }
}

export class InMemoryExtensionRepository implements ExtensionRepository {
  readonly rows = new Map<string, ExtensionRecord>();

  newId() {
    return randomUUID();
  }

  async create(input: CreateExtensionInput) {
    const row: ExtensionRecord = { ...input, orderId: null, paymentId: null };
    this.rows.set(row.id, row);
    return { ...row };
  }

  async findByOrderId(orderId: string) {
    const row = [...this.rows.values()].find((e) => e.orderId === orderId);
    return row ? { ...row } : null;
  }

  async listByBooking(bookingId: string, statuses?: ExtensionStatus[]) {
    return [...this.rows.values()]
      .filter((e) => e.bookingId === bookingId && (!statuses || statuses.includes(e.status)))
      .map((e) => ({ ...e }));
  }

  async transition(
    id: string,
    from: ExtensionStatus[],
    to: ExtensionStatus,
    patch: Partial<Pick<ExtensionRecord, 'lockExpiresAt' | 'paymentId'>> = {},
  ) {
    const row = this.rows.get(id);
    if (!row || !from.includes(row.status)) return null;
    Object.assign(row, patch, { status: to });
    return { ...row };
  }

  async attachOrder(id: string, orderId: string) {
    const row = this.rows.get(id);
    if (row) row.orderId = orderId;
  }
}
