# ParkSpot: Check-in, extend and end (Milestone 6)

Status: implemented in `api/src/modules/bookings`. It builds on [bookings-api.md](bookings-api.md) and [payments-api.md](payments-api.md).

## Flow

```
CONFIRMED booking → QR pass shows booking.passCode (qr_flutter)
  └─ "Scan" (simulated: the app posts its own pass code)
       └─ POST /v1/bookings/:id/checkin { passCode }   allowed from 15 min before start until end
            └─ ACTIVE → countdown to booking.end
                 ├─ "Extend" → POST /v1/bookings/:id/extend { minutes }
                 │    └─ 201 { extension, payment } → Razorpay checkout (second payment)
                 │         └─ POST /v1/payments/verify (same endpoint) → 200 { booking } with the new end
                 └─ "End" → POST /v1/bookings/:id/end → COMPLETED, remaining time released

Nobody ends it: a CONFIRMED or ACTIVE booking reads as COMPLETED once its end has passed.
```

## Rules

- **Check-in** needs the booking's `passCode`. That's what a gate scanner would read from the QR code. In the demo the app sends it itself. Check-in opens 15 minutes before `start` and closes at `end`.
- **Extensions keep the same slot**, because the car is already parked there. The extra time is claimed as holds on that slot from the current `end`, with the same 10-minute lock and TTL as a booking. If anyone holds that time, you get `409 EXTENSION_UNAVAILABLE`.
- An extension is paid for separately, with its own Razorpay order. It is verified through the same `POST /v1/payments/verify` and webhook, and the same idempotency and refund rules apply. Once paid, `booking.end` and `booking.amount` grow. One pending extension is allowed per booking: asking again replaces it.
- An extension can be bought while the booking is CONFIRMED or ACTIVE and before its end. If the booking ended before the payment landed, the payment is refunded.
- **Ending early** releases every hold from the next 15-minute bucket onward, so the slot shows as free on the map straight away. There's no partial refund in the MVP (Stretch).

## Endpoints (all need `Authorization: Bearer`, owner only, `404` otherwise)

| Method & path | Body | Success | Errors |
|---|---|---|---|
| `POST /v1/bookings/:id/checkin` | `{ passCode }` | `200 { booking }` (ACTIVE) | `400 PASS_CODE_INVALID`, `409 CHECKIN_NOT_ALLOWED` |
| `POST /v1/bookings/:id/extend` | `{ minutes }` (15–240, multiple of 15) | `201 { extension, payment }` | `409 EXTENSION_NOT_ALLOWED`, `409 EXTENSION_UNAVAILABLE`, `502`, `503` |
| `POST /v1/bookings/:id/end` | | `200 { booking }` (COMPLETED) | `409 END_NOT_ALLOWED` (only ACTIVE) |

The booking DTO gains `passCode` (only while CONFIRMED or ACTIVE) and `endedAt`.

```json
{
  "extension": { "id": "…", "bookingId": "…", "start": "…T12:00Z", "end": "…T12:30Z",
                 "amount": { "amount": 2000, "currency": "INR" }, "status": "PENDING", "lockExpiresAt": "…" },
  "payment": { "provider": "razorpay", "keyId": "rzp_test_…", "orderId": "order_…", "amount": 2000, "currency": "INR" }
}
```

## Data model

- `Booking` gains `passCode` (random, set on confirmation) and `endedAt`.
- `BookingExtension { bookingId, userId, start, end, minutes, amountPaise, status: PENDING | CONFIRMED | CANCELLED | FAILED | EXPIRED, lockExpiresAt, orderId (unique), paymentId }`. Its holds use the extension's id as their owner.

## Stretch

Signed QR payloads checked by a real gate scanner, a partial refund for ending early, overstay charges, push reminders 15 minutes before the end.
