# ParkSpot: Auth API design (Milestone 0)

Status: design for Dev's review. Skeleton lives in `api/`; `AuthService` is left for Dev. Backend: Node.js + TypeScript + Express + MongoDB (Mongoose), zod, JWT.

## 0. Decisions for Dev

Defaults are marked; change any of them before we scaffold.

| # | Decision | Default | Alternative |
|---|---|---|---|
| D1 | Login method for MVP | **Email + password** (free, no SMS cost) | Phone OTP (needs a paid SMS provider: push to Stretch) |
| D2 | HTTP framework | **Express** (most familiar to reviewers) | Fastify (faster, schema-first) |
| D3 | Password hashing | **argon2id** | bcrypt cost 12 |
| D4 | Access token | **JWT HS256, 15 min** | RS256 (only matters once a second service verifies tokens) |
| D5 | Refresh token | **Opaque random, 30 days, rotated on every use, stored hashed** | JWT refresh (harder to revoke; not recommended) |
| D6 | Concurrent refresh race | **Client single-flight only** (strict reuse detection) | 10s server grace window for the just-rotated token |

## 1. Flow

```
App start
  └─ Splash: read refreshToken from secure storage
       ├─ none ─────────────────────────────► Login screen
       └─ found → POST /auth/refresh
              ├─ 200 → save new pair → GET /me → Map home
              └─ 401 → wipe storage ─────────► Login screen

Login / Register
  └─ POST /auth/login | /auth/register → { user, tokens } → save → Map home

Any API call (dio AuthInterceptor)
  └─ attach `Authorization: Bearer <access>`
       └─ 401 TOKEN_EXPIRED → single-flight POST /auth/refresh
              ├─ 200 → retry original request once
              └─ 401 → emit SessionExpired → AuthBloc → Login

Logout
  └─ POST /auth/logout { refreshToken } → wipe storage → Login (even if the call fails)
```

Token storage on device: refresh token in `flutter_secure_storage` (Android Keystore / iOS Keychain); access token in memory only.

**Refresh rotation and reuse detection (server).** Each login starts a token *family*. On `/auth/refresh` the server looks up the token by hash:
1. Not found or expired → `401 REFRESH_INVALID`.
2. Already rotated or revoked → **reuse detected**: revoke the whole family → `401 REFRESH_REUSED`. (A stolen token used after the real app rotated it kills both sessions.)
3. Valid → atomically mark it rotated (`findOneAndUpdate` with `revokedAt: null` in the filter, so two parallel calls can't both win) and issue a new pair in the same family.

Because of rule 2, the app must never fire two refreshes in parallel; the interceptor queues requests behind one in-flight refresh (D6).

## 2. Screens (auth slice only)

| Screen | Purpose | States to design |
|---|---|---|
| Splash | Restore session | loading only |
| Login | Email + password, link to Register | idle, submitting, field errors, invalid credentials, offline, rate-limited |
| Register | Name, email, password (+ confirm) | idle, submitting, field errors, email taken, offline |
| Profile (stub) | Show user, Logout button | loaded, logging out |

Onboarding (3 screens) sits between Splash and Login on first launch only; not part of this slice.

## 3. BLoC states and events (names and shape only; Dev writes the logic)

**AuthBloc** (app-wide session, drives go_router redirect)
- Events: `AuthSessionRestoreRequested` (splash), `AuthLoggedIn(User)`, `AuthLogoutRequested`, `AuthSessionExpired` (from interceptor stream)
- States: `AuthUnknown` → `AuthAuthenticated(User)` | `AuthUnauthenticated`

**LoginCubit** (form)
- State: `{ email, password, status: initial | submitting | success | failure, failure?: Failure }`
- Methods: `emailChanged`, `passwordChanged`, `submitted`
- On success it hands the user to AuthBloc (via repository stream or `AuthLoggedIn`): Dev's call which way.

**RegisterCubit**: same shape plus `name`, `confirmPassword`.

Domain: `AuthRepository` (`login`, `register`, `restoreSession`, `logout`, `Stream<AuthStatus> status`) returning `Either<Failure, User>`. Failures to model: `InvalidCredentials`, `EmailTaken`, `Validation(fieldErrors)`, `Network`, `RateLimited`, `SessionExpired`, `Server`.

## 4. API contract (`/v1`)

All errors use one envelope:
```json
{ "error": { "code": "INVALID_CREDENTIALS", "message": "Email or password is incorrect", "details": null } }
```
`details` holds zod field errors for `422`: `{ "email": ["Invalid email"] }`.

Token pair returned by register, login, refresh:
```json
{ "accessToken": "eyJ…", "accessTokenExpiresIn": 900, "refreshToken": "rt_9f3c…", "refreshTokenExpiresAt": "2026-11-15T11:00:00Z" }
```

| Method & path | Auth | Request | Success | Errors |
|---|---|---|---|---|
| `POST /v1/auth/register` | none | `{ name, email, password }` (password ≥ 8) | `201 { user, tokens }` | `409 EMAIL_TAKEN`, `422 VALIDATION_ERROR`, `429 RATE_LIMITED` |
| `POST /v1/auth/login` | none | `{ email, password }` | `200 { user, tokens }` | `401 INVALID_CREDENTIALS` (same for unknown email), `422`, `429` |
| `POST /v1/auth/refresh` | none | `{ refreshToken }` | `200 { tokens }` | `401 REFRESH_INVALID`, `401 REFRESH_REUSED` |
| `POST /v1/auth/logout` | none | `{ refreshToken }` | `204` (idempotent, also for unknown token) | `422` |
| `GET /v1/me` | Bearer | | `200 { user }` | `401 TOKEN_EXPIRED`, `401 TOKEN_INVALID` |

`user` = `{ id, name, email, role: "DRIVER" | "OWNER", createdAt }`. Never return `passwordHash`.

Splitting `TOKEN_EXPIRED` from `TOKEN_INVALID` lets the interceptor refresh only when refreshing can help.

Access JWT claims: `sub` (userId), `role`, `iat`, `exp`, `iss: "parkspot-api"`, `aud: "parkspot-app"`. No email or PII.

## 5. Data model

```ts
User {
  _id, name, email (unique, lowercased), passwordHash, role: 'DRIVER' | 'OWNER' (default DRIVER),
  createdAt, updatedAt
}

RefreshToken {
  _id, userId (index), familyId (index), tokenHash (sha256, unique),
  expiresAt (TTL index → Mongo deletes expired docs), revokedAt?, replacedById?,
  userAgent?, createdAt
}
```

Only the SHA-256 of the refresh token is stored, so a DB leak doesn't leak usable sessions.

## 6. Folder structure (api/)

```
api/
  src/
    app.ts                 # express app: middleware, routes, error handler
    server.ts              # connects DB, starts listening, graceful shutdown
    config/env.ts          # zod-parsed process.env, fails fast on boot
    core/
      errors/AppError.ts   # code + status + message
      errors/errorHandler.ts
      http/validate.ts     # zod middleware → 422 envelope
      http/asyncHandler.ts
      middleware/authenticate.ts   # verifies access JWT → req.auth
      middleware/rateLimit.ts
      logger.ts            # pino
    modules/
      auth/
        auth.routes.ts
        auth.controller.ts # HTTP in/out only
        auth.service.ts    # register/login/refresh/logout use cases
        auth.schemas.ts    # zod request schemas
        token.service.ts   # sign/verify JWT, generate + hash refresh tokens
        password.hasher.ts # interface + argon2 impl
        refreshToken.model.ts
        refreshToken.repository.ts
      users/
        user.model.ts
        user.repository.ts
        users.routes.ts    # GET /me
    infra/db/mongo.ts
  tests/                   # vitest + supertest + mongodb-memory-server
  docker-compose.yml       # mongo:7
  .env.example             # PORT, MONGO_URI, JWT_ACCESS_SECRET, ACCESS_TTL, REFRESH_TTL_DAYS
  tsconfig.json, eslint, prettier
```

Dependency direction: routes → controller → service → repository/interfaces. Services depend on `PasswordHasher` and repository interfaces, not on Mongoose or argon2 directly, so they unit-test without a DB.

## 7. Hardening checklist (MVP)

helmet, CORS allowlist, `express-rate-limit` on `/auth/login` and `/auth/register` (for example 5/min/IP), JSON body size limit, constant-time behaviour for unknown email (hash a dummy password), central error handler that never leaks stack traces in prod.

## 8. Tests that prove it (for the README)

- login wrong password → 401, unknown email → same 401
- refresh rotates: old token then fails with `REFRESH_REUSED` and the new one is revoked too
- two parallel refreshes with the same token → exactly one 200
- `/me` with expired token → `TOKEN_EXPIRED`

## Stretch

Phone OTP login, Google sign-in, email verification and password reset, device/session list with "log out other devices", RS256 + JWKS.

---

# Payment provider: Razorpay vs Stripe onboarding

| | Razorpay | Stripe |
|---|---|---|
| Sign-up from India | Open: email + phone, dashboard in minutes | **Invite-only for Indian businesses** since 2024 ([Stripe support](https://support.stripe.com/questions/stripe-accounts-are-invite-only-in-india)) |
| Test mode | Test API keys available right after sign-up, no KYC ([quickstart](https://razorpay.com/docs/payments/quickstart)) | Sandbox works without activation, but the account itself is the hurdle from India |
| Going live | Needs business KYC (PAN, bank account); not needed for a portfolio demo | Not realistically available without an invite |
| Cost | Free in test mode; ~2% per live domestic transaction, no setup or annual fee | Free in test mode; live pricing irrelevant while invite-only |
| Indian methods in test | UPI, cards, netbanking, wallets, all simulated | Cards mainly |
| Flutter SDK | `razorpay_flutter` | `flutter_stripe` |
| Webhooks locally | Dashboard webhook + ngrok/cloudflared tunnel | Stripe CLI `stripe listen` (nicer DX) |

**Recommendation: Razorpay for the MVP.** It is the only one you can sign up for and use today at zero cost, and UPI in the demo resonates with Indian recruiters. Keep the `PaymentGateway` interface so Stripe drops in later (already in Stretch); for German employers, the interface plus a Stripe test-mode implementation is the talking point, if you can get a sandbox account.
