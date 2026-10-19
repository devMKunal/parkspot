# ParkSpot: Bookings and slot locking (Milestone 4)

Status: implemented in `api/src/modules/bookings`. Payment verification and the webhook (Milestone 5) build on this.

## Flow

```
Lot sheet → "Book"
  └─ Booking setup: pick start (15-min steps) + duration → price shown from lot.pricePerHour
       └─ POST /v1/bookings { lotId, start, durationMinutes }
            ├─ 201 → { booking (PENDING, lockExpiresAt), payment { keyId, orderId, amount } }
            │        → open Razorpay checkout with orderId (Milestone 5 verifies on the server)
            ├─ 409 LOT_FULL → "No free slot for that time", suggest another time
            └─ 503 PAYMENTS_UNAVAILABLE / 502 PAYMENT_PROVIDER_ERROR → error state with retry

Lock lifetime: 10 minutes. If payment isn't verified by lockExpiresAt the slot frees itself
and the booking reads as EXPIRED. Booking again while one is PENDING cancels the old one.
```

## Why time buckets (the interview answer)

A slot is not simply FREE or BOOKED. It is free or busy **for a time window**, and two drivers
racing for the last slot must never both win. MongoDB has no exclusion constraint for
overlapping intervals, so each booking is split into **15-minute buckets** and each bucket is
claimed as a `SlotHold { slotId, bucketStart }` document with a **unique index on
`(slotId, bucketStart)`**:

- Claiming a 2h booking inserts 8 holds. If any insert hits a duplicate key, someone else owns
  that slot for part of the window: the inserted holds are removed and the next slot is tried.
- The database index is the lock, so there's no race window and no transactions (which would
  need a replica set in local Docker).
- A pending hold carries `expiresAt` (now + 10 min) with a **TTL index**, so abandoned checkouts
  release themselves even if the server crashes. Confirming a booking clears `expiresAt`.
  TTL deletion runs about once a minute, so every availability read also ignores holds whose
  `expiresAt` has passed.

The cost is coarser start times (15-minute steps), which is how most parking apps work anyway.

## Endpoints (all require `Authorization: Bearer`)

| Method & path | Body / query | Success | Errors |
|---|---|---|---|
| `POST /v1/bookings` | `{ lotId, start (ISO, on a 15-min boundary, from 5 min ago to 7 days ahead), durationMinutes (30–720, multiple of 15) }` | `201 { booking, payment }` | `404 NOT_FOUND` lot, `409 LOT_FULL`, `422`, `502 PAYMENT_PROVIDER_ERROR`, `503 PAYMENTS_UNAVAILABLE` |
| `GET /v1/bookings/:id` | | `200 { booking }` | `404` (also for someone else's booking) |
| `POST /v1/bookings/:id/cancel` | | `200 { booking }` (CANCELLED) | `404`, `409 BOOKING_NOT_CANCELLABLE` (only PENDING for MVP) |
| `GET /v1/me/bookings` | `?status=PENDING,CONFIRMED` optional | `200 { bookings }`, newest first | |

```json
{
  "booking": {
    "id": "6713…",
    "lotId": "6712…",
    "slotLabel": "S014",
    "start": "2026-10-19T10:00:00.000Z",
    "end": "2026-10-19T12:00:00.000Z",
    "amount": { "amount": 8000, "currency": "INR" },
    "status": "PENDING",
    "lockExpiresAt": "2026-10-19T09:52:00.000Z",
    "createdAt": "2026-10-19T09:42:00.000Z"
  },
  "payment": { "provider": "razorpay", "keyId": "rzp_test_…", "orderId": "order_…", "amount": 8000, "currency": "INR" }
}
```

- The amount is computed on the server only (`pricePerHourPaise × minutes / 60`, rounded to whole paise). The client never sends a price.
- Booking statuses: `PENDING → CONFIRMED → ACTIVE → COMPLETED`, plus `CANCELLED`, `FAILED` and `EXPIRED`. `EXPIRED` is applied lazily when a PENDING booking is read after `lockExpiresAt`.

## Data model

- `Booking { userId, lotId, slotId, slotLabel, start, end, amountPaise, currency, status, lockExpiresAt, provider, orderId, paymentId }`, indexed on `{ userId, createdAt }` and `{ orderId }` (unique, sparse)
- `SlotHold { slotId, lotId, bucketStart, bookingId, expiresAt? }`: unique `{ slotId, bucketStart }`, TTL on `expiresAt`, plus `{ lotId, bucketStart }` for availability
- `Slot { lotId, label }`: the old `status` field is gone; availability now comes from holds
- `GET /lots/nearby` → `freeSlots` = slots with no live hold in the current 15-minute bucket

## Payment gateway

`PaymentGateway.createOrder({ amountPaise, currency, receipt, notes })` with `RazorpayGateway` (REST `POST /v1/orders`, HTTP Basic with key id and secret). Without `RAZORPAY_KEY_ID`/`RAZORPAY_KEY_SECRET` the API still boots, and booking returns `503 PAYMENTS_UNAVAILABLE`. If order creation fails after the slot was claimed, the holds are released and the booking is marked `FAILED`.

## Next (Milestone 5)

`POST /v1/payments/verify` (HMAC-SHA256 of `orderId|paymentId` with the key secret), `POST /v1/webhooks/razorpay` (`payment.captured`, signature over the raw body), both idempotent. A payment that arrives after the lock expired re-claims the slot, or is refunded if the slot is gone.

## Stretch

Cancelling confirmed bookings with refunds, `Idempotency-Key` on `POST /bookings`, an availability endpoint for a chosen window, choosing a specific slot.
