import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { buildTestApp } from './support/testApp.js';

describe('HTTP plumbing', () => {
  it('GET /health is ok', async () => {
    const { app } = buildTestApp();
    await request(app).get('/health').expect(200, { status: 'ok' });
  });

  it('unknown routes use the error envelope', async () => {
    const { app } = buildTestApp();
    const res = await request(app).get('/v1/nope').expect(404);
    expect(res.body.error.code).toBe('NOT_FOUND');
  });

  it('malformed JSON is a 400, not a 500', async () => {
    const { app } = buildTestApp();
    const res = await request(app)
      .post('/v1/auth/login')
      .set('content-type', 'application/json')
      .send('{"email":')
      .expect(400);
    expect(res.body.error.code).toBe('BAD_REQUEST');
  });

  it('invalid register body returns 422 with field errors', async () => {
    const { app } = buildTestApp();
    const res = await request(app)
      .post('/v1/auth/register')
      .send({ name: '', email: 'not-an-email', password: 'short' })
      .expect(422);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
    expect(Object.keys(res.body.error.details)).toEqual(
      expect.arrayContaining(['name', 'email', 'password']),
    );
  });
});

describe('GET /v1/me', () => {
  it('401 TOKEN_INVALID without a bearer token', async () => {
    const { app } = buildTestApp();
    const res = await request(app).get('/v1/me').expect(401);
    expect(res.body.error.code).toBe('TOKEN_INVALID');
  });

  it('returns the user for a valid token and never leaks the hash', async () => {
    const { app, users, tokens } = buildTestApp();
    const user = await users.create({ name: 'Dev', email: 'Dev@Example.com', passwordHash: 'h' });
    const token = tokens.signAccessToken({ sub: user.id, role: user.role });

    const res = await request(app)
      .get('/v1/me')
      .set('authorization', `Bearer ${token}`)
      .expect(200);

    expect(res.body.user).toMatchObject({ id: user.id, email: 'dev@example.com', role: 'DRIVER' });
    expect(res.body.user).not.toHaveProperty('passwordHash');
  });

  it('401 TOKEN_INVALID when the user no longer exists', async () => {
    const { app, tokens } = buildTestApp();
    const token = tokens.signAccessToken({ sub: 'deleted-user', role: 'DRIVER' });
    const res = await request(app)
      .get('/v1/me')
      .set('authorization', `Bearer ${token}`)
      .expect(401);
    expect(res.body.error.code).toBe('TOKEN_INVALID');
  });
});
