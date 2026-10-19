import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { buildTestApp } from './support/testApp.js';

const DAY_MS = 86_400_000;

/**
 * Executable spec for AuthService (docs/auth-api.md, sections 1, 4 and 8).
 * Don't edit the assertions unless the contract in the design doc changes.
 */
describe('auth flow', () => {
  const creds = { name: 'Dev', email: 'dev@example.com', password: 'correct-horse' };

  const register = (app: ReturnType<typeof buildTestApp>['app']) =>
    request(app).post('/v1/auth/register').send(creds);

  it('register returns 201 with user and token pair', async () => {
    const { app } = buildTestApp();
    const res = await register(app).expect(201);
    expect(res.body.user).toMatchObject({ email: creds.email, role: 'DRIVER' });
    expect(res.body.tokens).toEqual({
      accessToken: expect.any(String),
      accessTokenExpiresIn: 900,
      refreshToken: expect.stringMatching(/^rt_/),
      refreshTokenExpiresAt: expect.any(String),
    });
  });

  it('register with an existing email is 409 EMAIL_TAKEN', async () => {
    const { app } = buildTestApp();
    await register(app).expect(201);
    const res = await request(app)
      .post('/v1/auth/register')
      .send({ ...creds, email: 'DEV@example.com' })
      .expect(409);
    expect(res.body.error.code).toBe('EMAIL_TAKEN');
  });

  it('wrong password and unknown email give the same 401', async () => {
    const { app } = buildTestApp();
    await register(app).expect(201);
    const wrong = await request(app)
      .post('/v1/auth/login')
      .send({ email: creds.email, password: 'nope-nope' })
      .expect(401);
    const unknown = await request(app)
      .post('/v1/auth/login')
      .send({ email: 'ghost@example.com', password: 'nope-nope' })
      .expect(401);
    expect(wrong.body).toEqual(unknown.body);
    expect(wrong.body.error.code).toBe('INVALID_CREDENTIALS');
  });

  it('login token works on /me', async () => {
    const { app } = buildTestApp();
    await register(app).expect(201);
    const login = await request(app)
      .post('/v1/auth/login')
      .send({ email: creds.email, password: creds.password })
      .expect(200);
    await request(app)
      .get('/v1/me')
      .set('authorization', `Bearer ${login.body.tokens.accessToken}`)
      .expect(200);
  });

  it('refresh rotates; reusing the old token revokes the whole family', async () => {
    const { app } = buildTestApp();
    const first = (await register(app).expect(201)).body.tokens.refreshToken;

    const rotated = await request(app)
      .post('/v1/auth/refresh')
      .send({ refreshToken: first })
      .expect(200);
    const second = rotated.body.tokens.refreshToken;
    expect(second).not.toBe(first);

    const reuse = await request(app)
      .post('/v1/auth/refresh')
      .send({ refreshToken: first })
      .expect(401);
    expect(reuse.body.error.code).toBe('REFRESH_REUSED');

    // The legitimate newer token died with the family.
    const after = await request(app)
      .post('/v1/auth/refresh')
      .send({ refreshToken: second })
      .expect(401);
    expect(after.body.error.code).toBe('REFRESH_REUSED');
  });

  it('two parallel refreshes with one token: exactly one succeeds', async () => {
    const { app } = buildTestApp();
    const token = (await register(app).expect(201)).body.tokens.refreshToken;

    const results = await Promise.all([
      request(app).post('/v1/auth/refresh').send({ refreshToken: token }),
      request(app).post('/v1/auth/refresh').send({ refreshToken: token }),
    ]);

    expect(results.map((r) => r.status).sort()).toEqual([200, 401]);
  });

  it('unknown refresh token is 401 REFRESH_INVALID', async () => {
    const { app } = buildTestApp();
    const res = await request(app)
      .post('/v1/auth/refresh')
      .send({ refreshToken: 'rt_made_up' })
      .expect(401);
    expect(res.body.error.code).toBe('REFRESH_INVALID');
  });

  it('logout revokes the token and is idempotent', async () => {
    const { app } = buildTestApp();
    const token = (await register(app).expect(201)).body.tokens.refreshToken;

    await request(app).post('/v1/auth/logout').send({ refreshToken: token }).expect(204);
    await request(app).post('/v1/auth/logout').send({ refreshToken: token }).expect(204);
    await request(app).post('/v1/auth/refresh').send({ refreshToken: token }).expect(401);
  });

  it('an expired refresh token is REFRESH_INVALID, not reuse', async () => {
    let now = new Date('2026-10-19T00:00:00Z');
    const { app } = buildTestApp({ now: () => now });
    const token = (await register(app).expect(201)).body.tokens.refreshToken;

    now = new Date(now.getTime() + 31 * DAY_MS);
    const res = await request(app)
      .post('/v1/auth/refresh')
      .send({ refreshToken: token })
      .expect(401);
    expect(res.body.error.code).toBe('REFRESH_INVALID');
  });

  it('refresh keeps the family and links the old token to its replacement', async () => {
    const { app, refreshTokens } = buildTestApp();
    const token = (await register(app).expect(201)).body.tokens.refreshToken;
    await request(app).post('/v1/auth/refresh').send({ refreshToken: token }).expect(200);

    const rows = [...refreshTokens.rows.values()];
    expect(rows).toHaveLength(2);
    expect(new Set(rows.map((r) => r.familyId)).size).toBe(1);
    const [old, next] = rows;
    expect(old?.revokedAt).not.toBeNull();
    expect(old?.replacedById).toBe(next?.id);
  });

  it('each login starts its own family, so logging out one device keeps the other', async () => {
    const { app } = buildTestApp();
    await register(app).expect(201);
    const login = () =>
      request(app).post('/v1/auth/login').send({ email: creds.email, password: creds.password });
    const phone = (await login().expect(200)).body.tokens.refreshToken;
    const tablet = (await login().expect(200)).body.tokens.refreshToken;

    await request(app).post('/v1/auth/logout').send({ refreshToken: phone }).expect(204);
    await request(app).post('/v1/auth/refresh').send({ refreshToken: tablet }).expect(200);
  });

  it('stores the password hashed and the refresh token only as a hash', async () => {
    const { app, users, refreshTokens } = buildTestApp();
    const token = (await register(app).expect(201)).body.tokens.refreshToken;

    const [user] = [...users.rows.values()];
    expect(user?.passwordHash).not.toBe(creds.password);
    const stored = [...refreshTokens.rows.values()].map((r) => r.tokenHash);
    expect(stored).not.toContain(token);
  });
});
