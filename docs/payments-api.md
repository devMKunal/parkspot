# ParkSpot: Payment verification and webhook (Milestone 5)

Status: implemented in `api/src/modules/payments`. It builds on [bookings-api.md](bookings-api.md).

## Flow

```
POST /v1/bookings → { booking: PENDING, payment: { keyId, orderId, amount } }
  └─ App opens Razorpay checkout(keyId, orderId)
       ├─ success → { razorpay_order_id, razorpay_payment_id, razorpay_signature }
       │    └─ POST /v1/payments/verify { orderId, paymentId, signature }
       │         ├─ 200 { booking: CONFIRMED } → QR pass
       │         ├─ 409 PAYMENT_REFUNDED → "Slot was taken, refund on its way"
       │         └─ network error → poll GET /v1/bookings/:id (the webhook confirms it anyway)
       └─ failure / dismissed → booking stays PENDING until lockExpiresAt, then EXPIRED

Razorpay ──POST /v1/webhooks/razorpay (payment.captured, order.paid)──► same confirm logic
```

Both paths call the same `BookingService.confirmPaid`. Whichever arrives first wins the
`PENDING/EXPIRED → CONFIRMED` compare-and-set, and the other gets the same answer back.

## Rules (never trust the client)

1. A booking moves forward only on a **provider signature**: `HMAC-SHA256(key_secret, "order_id|payment_id")` from checkout, or `HMAC-SHA256(webhook_secret, rawBody)` on the webhook. Both are compared in constant time.
2. The webhook body is kept **raw** until it is verified. Parsing and re-serialising JSON would change the bytes and break the signature.
3. The amount is fixed by the order the server created. A webhook amount that doesn't match the booking is refunded.
4. **Late payments** (lock expired before the money arrived):
   - If the same slot is still free, the booking is confirmed on it.
   - If that slot was taken, the booking moves to another free slot in the lot.
   - If the lot is full, the booking becomes `FAILED` and the payment is refunded automatically.
5. A payment for a `CANCELLED` or `FAILED` booking, or a second payment on a paid order, is refunded.
6. **Exactly-once refunds**: each payment is recorded once (unique `paymentId`), and only the caller that moves it from `CAPTURED` to `REFUND_PENDING` issues the refund. A refund that fails is left as `REFUND_FAILED` for a manual refund from the dashboard.

## Endpoints

| Method & path | Auth | Body | Success | Errors |
|---|---|---|---|---|
| `POST /v1/payments/verify` | Bearer | `{ orderId, paymentId, signature }` | `200 { booking }` | `400 PAYMENT_SIGNATURE_INVALID`, `404` (unknown order or someone else's), `409 PAYMENT_REFUNDED`, `503 PAYMENTS_UNAVAILABLE` |
| `POST /v1/webhooks/razorpay` | `X-Razorpay-Signature` | Razorpay event | `200 { ok: true }` for every authentic event, handled or not | `400 WEBHOOK_SIGNATURE_INVALID`, `503` |

## Data model

`Payment { provider, orderId, paymentId (unique), bookingId, amountPaise, status: CAPTURED | REFUND_PENDING | REFUNDED | REFUND_FAILED, source: client | webhook }`

## Razorpay setup (test mode, free)

1. Sign up at razorpay.com and stay in **Test Mode**. Under Account & Settings → API Keys, generate a key and put it in `RAZORPAY_KEY_ID` / `RAZORPAY_KEY_SECRET`.
2. Under Webhooks → Add, set the URL to `https://<tunnel>/v1/webhooks/razorpay`, choose a secret and set it as `RAZORPAY_WEBHOOK_SECRET`, and subscribe to `payment.captured` and `order.paid`. For local testing, expose port 3000 with `cloudflared tunnel --url http://localhost:3000` or ngrok.
3. Keep payment capture on automatic (the default). An "authorized" but uncaptured payment never fires `payment.captured`.
4. Use the test cards and UPI ids from Razorpay's test-mode docs.

## Stretch

Stripe behind the same `PaymentGateway`, refund webhooks (`refund.processed`) to finalise `REFUNDED`, a reconciliation job for `REFUND_FAILED`, refunds for confirmed bookings the driver cancels.
