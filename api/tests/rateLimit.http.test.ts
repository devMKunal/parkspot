import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { buildTestApp } from './support/testApp.js';

const login = (app: ReturnType<typeof buildTestApp>['app'], ip: string) =>
  request(app)
    .post('/v1/auth/login')
    .set('X-Forwarded-For', ip)
    .send({ email: 'nobody@example.com', password: 'wrong-password' });

describe('auth rate limit behind a proxy', () => {
  it('limits each client IP separately, not the proxy as a whole', async () => {
    const { app } = buildTestApp({ rateLimit: true, trustProxy: 1 });

    for (let i = 0; i < 5; i++) expect((await login(app, '10.0.0.1')).status).not.toBe(429);
    expect((await login(app, '10.0.0.1')).status).toBe(429);
    // Another driver behind the same load balancer is unaffected.
    expect((await login(app, '10.0.0.2')).status).not.toBe(429);
  });
});
