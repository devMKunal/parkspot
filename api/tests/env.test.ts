import { describe, expect, it } from 'vitest';
import { loadEnv } from '../src/config/env.js';

const required = {
  MONGO_URI: 'mongodb://localhost:27017/parkspot',
  JWT_ACCESS_SECRET: 'x'.repeat(32),
};

describe('loadEnv', () => {
  it('treats blank optional values from a copied .env.example as unset', () => {
    const env = loadEnv({
      ...required,
      RAZORPAY_KEY_ID: '',
      RAZORPAY_KEY_SECRET: '',
      RAZORPAY_WEBHOOK_SECRET: '',
    });
    expect(env.RAZORPAY_KEY_ID).toBeUndefined();
    expect(env.RAZORPAY_KEY_SECRET).toBeUndefined();
    expect(env.RAZORPAY_WEBHOOK_SECRET).toBeUndefined();
  });

  it('keeps Razorpay values that are set', () => {
    const env = loadEnv({
      ...required,
      RAZORPAY_KEY_ID: 'rzp_test_abc',
      RAZORPAY_WEBHOOK_SECRET: 'whsec',
    });
    expect(env.RAZORPAY_KEY_ID).toBe('rzp_test_abc');
    expect(env.RAZORPAY_WEBHOOK_SECRET).toBe('whsec');
  });

  it('trusts no proxy unless told to, so clients cannot spoof their IP', () => {
    expect(loadEnv(required).TRUST_PROXY).toBe(0);
    expect(loadEnv({ ...required, TRUST_PROXY: '1' }).TRUST_PROXY).toBe(1);
    expect(() => loadEnv({ ...required, TRUST_PROXY: '-1' })).toThrow(/TRUST_PROXY/);
  });

  it('still fails fast when a required value is missing', () => {
    expect(() => loadEnv({ JWT_ACCESS_SECRET: required.JWT_ACCESS_SECRET })).toThrow(/MONGO_URI/);
  });
});
