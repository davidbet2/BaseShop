/**
 * Auth Service — Unit Tests
 * Tests: register, verify-email, login, refresh, me, logout, change-password
 */
const request = require('supertest');
const express = require('express');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');

// ── In-memory DB setup ──
const JWT_SECRET = 'test-secret-key';
process.env.JWT_SECRET = JWT_SECRET;
process.env.RECAPTCHA_SECRET_KEY = ''; // disable recaptcha in tests

let app;
let db;

beforeAll(async () => {
  // Override DB_PATH so we use in-memory db
  process.env.DB_PATH = ':memory:';
  const { initDatabase, getDb } = require('../src/database');
  await initDatabase();
  db = getDb();

  app = express();
  app.use(express.json());

  // Minimal XSS sanitizer like production
  app.use((req, res, next) => {
    const origJson = res.json.bind(res);
    res.json = (body) => {
      res.setHeader('Content-Type', 'application/json; charset=utf-8');
      return origJson(body);
    };
    next();
  });

  const authRoutes = require('../src/routes/auth.routes');
  const rateLimit = require('express-rate-limit');
  const limiter = rateLimit({ windowMs: 60000, max: 1000 }); // high limit for tests
  app.use('/api/auth', authRoutes(limiter));
});

afterAll(() => {
  const { close } = require('../src/database');
  close();
});

// ── Helper: generate a valid JWT ──
function makeToken(payload, expiresIn = '1h') {
  return jwt.sign(payload, JWT_SECRET, { expiresIn });
}

// ══════════════════════════════════════
// Registration Tests
// ══════════════════════════════════════
describe('POST /api/auth/register', () => {
  it('should register a new user and require email verification', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send({
        email: 'test@example.com',
        password: 'Test123!',
        first_name: 'Test',
        last_name: 'User',
      });

    expect(res.status).toBe(201);
    expect(res.body.requiresVerification).toBe(true);
    expect(res.body.email).toBe('test@example.com');
    expect(res.body).not.toHaveProperty('token');
    expect(res.body).not.toHaveProperty('refreshToken');
  });

  it('should reject duplicate email', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send({
        email: 'test@example.com',
        password: 'Test123!',
        first_name: 'Another',
        last_name: 'User',
      });

    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/ya está registrado/i);
  });

  it('should reject invalid email', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send({
        email: 'not-an-email',
        password: 'Test123!',
        first_name: 'Test',
        last_name: 'User',
      });

    expect(res.status).toBe(400);
    expect(res.body.error).toBeDefined();
  });

  it('should reject weak password (< 8 chars)', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send({
        email: 'short@example.com',
        password: '12345',
        first_name: 'Test',
        last_name: 'User',
      });

    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/8 caracteres/i);
  });

  it('should reject missing first_name', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send({
        email: 'nofirst@example.com',
        password: 'Test123!',
        last_name: 'User',
      });

    expect(res.status).toBe(400);
  });
});

// ══════════════════════════════════════
// Email Verification Tests
// ══════════════════════════════════════
describe('POST /api/auth/verify-email', () => {
  it('should reject an invalid code', async () => {
    const res = await request(app)
      .post('/api/auth/verify-email')
      .send({ email: 'test@example.com', code: '000000' });

    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/inválido|expirado/i);
  });

  it('should verify email with correct code', async () => {
    // Get the code directly from the database
    const user = db.prepare('SELECT verification_code FROM users WHERE email = ?').get('test@example.com');
    expect(user.verification_code).toBeTruthy();

    const res = await request(app)
      .post('/api/auth/verify-email')
      .send({ email: 'test@example.com', code: user.verification_code });

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('token');
    expect(res.body).toHaveProperty('refreshToken');
    expect(res.body.user.email).toBe('test@example.com');
    expect(res.body.user).not.toHaveProperty('password');
  });

  it('should reject verification for already verified email', async () => {
    const res = await request(app)
      .post('/api/auth/verify-email')
      .send({ email: 'test@example.com', code: '123456' });

    expect(res.status).toBe(400);
  });
});

// ══════════════════════════════════════
// Resend Verification Tests
// ══════════════════════════════════════
describe('POST /api/auth/resend-verification', () => {
  it('should always return 200 (no email leak)', async () => {
    const res = await request(app)
      .post('/api/auth/resend-verification')
      .send({ email: 'doesnotexist@example.com' });

    expect(res.status).toBe(200);
  });
});

// ══════════════════════════════════════
// Login Tests (user is now verified)
// ══════════════════════════════════════
describe('POST /api/auth/login', () => {
  it('should login successfully with valid credentials', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: 'test@example.com', password: 'Test123!' });

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('token');
    expect(res.body).toHaveProperty('refreshToken');
    expect(res.body.user.email).toBe('test@example.com');
  });

  it('should reject wrong password', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: 'test@example.com', password: 'WrongPassword!' });

    expect(res.status).toBe(401);
    expect(res.body.error).toMatch(/Credenciales inválidas/i);
  });

  it('should reject non-existent user', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: 'nobody@example.com', password: 'Test123!' });

    expect(res.status).toBe(401);
    expect(res.body.error).toMatch(/Credenciales inválidas/i);
  });

  it('should reject missing password', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: 'test@example.com' });

    expect(res.status).toBe(400);
  });
});

// ══════════════════════════════════════
// Token Refresh Tests
// ══════════════════════════════════════
describe('POST /api/auth/refresh', () => {
  let validRefreshToken;

  beforeAll(async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: 'test@example.com', password: 'Test123!' });
    validRefreshToken = res.body.refreshToken;
  });

  it('should refresh tokens with a valid refresh token', async () => {
    const res = await request(app)
      .post('/api/auth/refresh')
      .send({ refreshToken: validRefreshToken });

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('token');
    expect(res.body).toHaveProperty('refreshToken');
    // old token should be consumed (one-time use)
    expect(res.body.refreshToken).not.toBe(validRefreshToken);
  });

  it('should reject an already-consumed refresh token', async () => {
    const res = await request(app)
      .post('/api/auth/refresh')
      .send({ refreshToken: validRefreshToken });

    expect(res.status).toBe(401);
    expect(res.body.error).toMatch(/inválido/i);
  });

  it('should reject missing refresh token', async () => {
    const res = await request(app)
      .post('/api/auth/refresh')
      .send({});

    expect(res.status).toBe(400);
  });
});

// ══════════════════════════════════════
// GET /me Tests
// ══════════════════════════════════════
describe('GET /api/auth/me', () => {
  let token;

  beforeAll(async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: 'test@example.com', password: 'Test123!' });
    token = res.body.token;
  });

  it('should return current user with valid token', async () => {
    const res = await request(app)
      .get('/api/auth/me')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.user.email).toBe('test@example.com');
    expect(res.body.user).not.toHaveProperty('password');
  });

  it('should reject request without token', async () => {
    const res = await request(app).get('/api/auth/me');

    expect(res.status).toBe(401);
  });

  it('should reject invalid token', async () => {
    const res = await request(app)
      .get('/api/auth/me')
      .set('Authorization', 'Bearer invalid-token-here');

    expect(res.status).toBe(401);
  });
});

// ══════════════════════════════════════
// Logout Tests
// ══════════════════════════════════════
describe('POST /api/auth/logout', () => {
  it('should logout and clear refresh tokens', async () => {
    const loginRes = await request(app)
      .post('/api/auth/login')
      .send({ email: 'test@example.com', password: 'Test123!' });

    const res = await request(app)
      .post('/api/auth/logout')
      .set('Authorization', `Bearer ${loginRes.body.token}`);

    expect(res.status).toBe(200);
    expect(res.body.message).toMatch(/sesión cerrada/i);

    // refresh token should no longer work
    const refreshRes = await request(app)
      .post('/api/auth/refresh')
      .send({ refreshToken: loginRes.body.refreshToken });

    expect(refreshRes.status).toBe(401);
  });
});

// ══════════════════════════════════════
// Change Password Tests
// ══════════════════════════════════════
describe('POST /api/auth/change-password', () => {
  let token;

  beforeAll(async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: 'test@example.com', password: 'Test123!' });
    token = res.body.token;
  });

  it('should reject wrong current password', async () => {
    const res = await request(app)
      .post('/api/auth/change-password')
      .set('Authorization', `Bearer ${token}`)
      .send({ currentPassword: 'WrongOld!', newPassword: 'NewPass123!' });

    expect(res.status).toBe(401);
  });

  it('should change password with correct current password', async () => {
    const res = await request(app)
      .post('/api/auth/change-password')
      .set('Authorization', `Bearer ${token}`)
      .send({ currentPassword: 'Test123!', newPassword: 'NewPass123!' });

    expect(res.status).toBe(200);

    // Verify new password works
    const loginRes = await request(app)
      .post('/api/auth/login')
      .send({ email: 'test@example.com', password: 'NewPass123!' });

    expect(loginRes.status).toBe(200);
  });
});

// ══════════════════════════════════════
// Admin Users List Tests
// ══════════════════════════════════════
describe('GET /api/auth/users (admin)', () => {
  it('should reject non-admin access', async () => {
    const loginRes = await request(app)
      .post('/api/auth/login')
      .send({ email: 'test@example.com', password: 'NewPass123!' });

    const res = await request(app)
      .get('/api/auth/users')
      .set('Authorization', `Bearer ${loginRes.body.token}`);

    expect(res.status).toBe(403);
  });

  it('should allow admin to list users', async () => {
    // Login as default admin
    const loginRes = await request(app)
      .post('/api/auth/login')
      .send({ email: 'admin@baseshop.com', password: 'Admin123!' });

    expect(loginRes.status).toBe(200);

    const res = await request(app)
      .get('/api/auth/users')
      .set('Authorization', `Bearer ${loginRes.body.token}`);

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('data');
    expect(res.body).toHaveProperty('total');
    expect(Array.isArray(res.body.data)).toBe(true);
    expect(res.body.total).toBeGreaterThanOrEqual(2); // admin + test user
  });
});
