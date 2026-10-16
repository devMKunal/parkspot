import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { buildTestApp } from './support/testApp.js';

/**
 * Executable spec for AuthService (docs/auth-api.md, sections 1, 4 and 8).
 *
 * TODO(Dev): these are skipped until AuthService is implemented. Remove `.skip` and make
 * them pass; don't edit the assertions unless the contract in the design doc changes.
 */
describe.skip('auth flow (spec for AuthService)', () => {
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
});
