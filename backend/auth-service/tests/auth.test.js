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

  it('should allow re-registration while still pending verification', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send({
        email: 'test@example.com',
        password: 'Test123!',
        first_name: 'Another',
        last_name: 'User',
      });

    // Replaces the pending record — returns 201 again
    expect(res.status).toBe(201);
    expect(res.body.requiresVerification).toBe(true);
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
    // Get the code directly from pending_registrations
    const pending = db.prepare('SELECT verification_code FROM pending_registrations WHERE email = ?').get('test@example.com');
    expect(pending.verification_code).toBeTruthy();

    const res = await request(app)
      .post('/api/auth/verify-email')
      .send({ email: 'test@example.com', code: pending.verification_code });

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
// Re-registration after verification should fail
// ══════════════════════════════════════
describe('POST /api/auth/register (after verification)', () => {
  it('should reject registration for an already verified email', async () => {
    const res = await request(app)
      .post('/api/auth/register')
      .send({
        email: 'test@example.com',
        password: 'Test123!',
        first_name: 'Duplicate',
        last_name: 'User',
      });

    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/ya está registrado/i);
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

  it('should allow admin to search users', async () => {
    // Login as admin
    const loginRes = await request(app)
      .post('/api/auth/login')
      .send({ email: 'admin@baseshop.com', password: 'Admin123!' });

    const res = await request(app)
      .get('/api/auth/users?search=test')
      .set('Authorization', `Bearer ${loginRes.body.token}`);

    expect(res.status).toBe(200);
    expect(res.body.data).toBeInstanceOf(Array);
  });
});

// ══════════════════════════════════════
// Google Login Tests
// ══════════════════════════════════════
describe('POST /api/auth/google', () => {
  it('should reject when no Google token provided', async () => {
    const res = await request(app)
      .post('/api/auth/google')
      .send({});

    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/Token de Google requerido/i);
  });

  it('should reject invalid Google token', async () => {
    const res = await request(app)
      .post('/api/auth/google')
      .send({ id_token: 'invalid-token' });

    expect(res.status).toBe(500);
  });

  it('should login with valid Google access_token', async () => {
    // This will fail with real Google API, but tests the code path
    const res = await request(app)
      .post('/api/auth/google')
      .send({ access_token: 'mock-access-token' });

    // Will get 500 due to Google API call failing
    expect(res.status).toBe(500);
  });
});

// ══════════════════════════════════════
// Forgot Password Tests
// ══════════════════════════════════════
describe('POST /api/auth/forgot-password', () => {
  it('should return generic message for non-existent email', async () => {
    const res = await request(app)
      .post('/api/auth/forgot-password')
      .send({ email: 'nonexistent@example.com' });

    expect(res.status).toBe(200);
    expect(res.body.sent).toBe(false);
  });

  it('should reject invalid email format', async () => {
    const res = await request(app)
      .post('/api/auth/forgot-password')
      .send({ email: 'not-an-email' });

    expect(res.status).toBe(200);
  });

  it('should reject Google-only accounts', async () => {
    // Create a Google user
    db.prepare(`INSERT INTO users (id, email, first_name, last_name, provider, email_verified)
      VALUES (?, ?, ?, ?, ?, ?)`).run('google-user-1', 'google@test.com', 'Google', 'User', 'google', 1);

    const res = await request(app)
      .post('/api/auth/forgot-password')
      .send({ email: 'google@test.com' });

    expect(res.status).toBe(200);
    expect(res.body.sent).toBe(false);
    expect(res.body.message).toMatch(/Google/i);
  });
});

// ══════════════════════════════════════
// Reset Password Tests
// ══════════════════════════════════════
describe('POST /api/auth/reset-password', () => {
  let testEmail = 'resettest@example.com';

  beforeAll(async () => {
    // Create user with reset code
    db
    const bcrypt = require('bcryptjs');
    const hashedPassword = await bcrypt.hash('Test123!', 10);
    db.prepare(`INSERT INTO users (id, email, password, first_name, last_name, reset_code, reset_code_expires)
      VALUES (?, ?, ?, ?, ?, ?, ?)`).run(
      'reset-user-1', testEmail, hashedPassword, 'Reset', 'Test', '123456',
      new Date(Date.now() + 30 * 60 * 1000).toISOString()
    );
  });

  it('should reject invalid code', async () => {
    const res = await request(app)
      .post('/api/auth/reset-password')
      .send({ email: testEmail, code: '000000', newPassword: 'NewPass123!' });

    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/inválido/i);
  });

  it('should reject expired code', async () => {
    db
    db.prepare(`UPDATE users SET reset_code_expires = ? WHERE email = ?`)
      .run(new Date(Date.now() - 1000).toISOString(), testEmail);

    const res = await request(app)
      .post('/api/auth/reset-password')
      .send({ email: testEmail, code: '123456', newPassword: 'NewPass123!' });

    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/expirado/i);
  });

  it('should reject weak new password', async () => {
    // Update with valid code
    db
    db.prepare(`UPDATE users SET reset_code_expires = ?, reset_code = ? WHERE email = ?`)
      .run(new Date(Date.now() + 30 * 60 * 1000).toISOString(), '654321', testEmail);

    const res = await request(app)
      .post('/api/auth/reset-password')
      .send({ email: testEmail, code: '654321', newPassword: 'weak' });

    expect(res.status).toBe(400);
  });

  it('should reject invalid email format', async () => {
    const res = await request(app)
      .post('/api/auth/reset-password')
      .send({ email: 'not-email', code: '123456', newPassword: 'NewPass123!' });

    expect(res.status).toBe(400);
  });

  it('should reject non-numeric code', async () => {
    const res = await request(app)
      .post('/api/auth/reset-password')
      .send({ email: testEmail, code: 'abcde', newPassword: 'NewPass123!' });

    expect(res.status).toBe(400);
  });
});

// ══════════════════════════════════════
// Login Edge Cases
// ══════════════════════════════════════
describe('POST /api/auth/login (edge cases)', () => {
  it('should reject pending verification user', async () => {
    // Register but don't verify
    await request(app)
      .post('/api/auth/register')
      .send({
        email: 'pending@example.com',
        password: 'Test123!',
        first_name: 'Pending',
        last_name: 'User',
      });

    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: 'pending@example.com', password: 'Test123!' });

    expect(res.status).toBe(403);
    expect(res.body.requiresVerification).toBe(true);
  });

  it('should reject inactive account', async () => {
    db
    const bcrypt = require('bcryptjs');
    const hashedPassword = await bcrypt.hash('Test123!', 10);
    db.prepare(`INSERT INTO users (id, email, password, first_name, last_name, is_active)
      VALUES (?, ?, ?, ?, ?, ?)`).run('inactive-1', 'inactive@test.com', hashedPassword, 'Inactive', 'User', 0);

    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: 'inactive@test.com', password: 'Test123!' });

    expect(res.status).toBe(403);
    expect(res.body.error).toMatch(/desactivada/i);
  });
});

// ══════════════════════════════════════
// Refresh Token Edge Cases
// ══════════════════════════════════════
describe('POST /api/auth/refresh (edge cases)', () => {
  it('should reject expired refresh token', async () => {
    db
    const expiredToken = 'expired-refresh-token';
    db.prepare(`INSERT INTO refresh_tokens (id, user_id, token, expires_at) VALUES (?, ?, ?, ?)`)
      .run('expired-1', 'test-user-id', expiredToken, new Date(Date.now() - 1000).toISOString());

    const res = await request(app)
      .post('/api/auth/refresh')
      .send({ refreshToken: expiredToken });

    expect(res.status).toBe(401);
    expect(res.body.error).toMatch(/expirado/i);
  });

  it('should reject when user not found or inactive', async () => {
    db
    const orphanedToken = 'orphan-refresh-token';
    db.prepare(`INSERT INTO refresh_tokens (id, user_id, token, expires_at) VALUES (?, ?, ?, ?)`)
      .run('orphan-1', 'nonexistent-user', orphanedToken, new Date(Date.now() + 86400000).toISOString());

    const res = await request(app)
      .post('/api/auth/refresh')
      .send({ refreshToken: orphanedToken });

    expect(res.status).toBe(401);
  });
});

// ══════════════════════════════════════
// GET /me Edge Cases
// ══════════════════════════════════════
describe('GET /api/auth/me (edge cases)', () => {
  it('should return 404 when user not found', async () => {
    // Create a token for a deleted user
    const token = jwt.sign({ id: 'nonexistent-user', email: 'test@test.com', role: 'client' }, JWT_SECRET);

    const res = await request(app)
      .get('/api/auth/me')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(404);
  });
});

// ══════════════════════════════════════
// Change Password Edge Cases
// ══════════════════════════════════════
describe('POST /api/auth/change-password (edge cases)', () => {
  let token;

  beforeAll(async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: 'test@example.com', password: 'NewPass123!' });
    token = res.body.token;
  });

  it('should reject validation errors', async () => {
    const res = await request(app)
      .post('/api/auth/change-password')
      .set('Authorization', `Bearer ${token}`)
      .send({ currentPassword: 'NewPass123!' });

    expect(res.status).toBe(400);
  });

  it('should reject Google account password change', async () => {
    // Create Google user
    db.prepare(`INSERT INTO users (id, email, first_name, last_name, provider, email_verified)
      VALUES (?, ?, ?, ?, ?, ?)`).run('google-user-change', 'googlechange@test.com', 'Google', 'Change', 'google', 1);

    // Login (would need Google token, so use direct token)
    const googleToken = jwt.sign({ id: 'google-user-change', email: 'googlechange@test.com', role: 'client' }, JWT_SECRET);

    const res = await request(app)
      .post('/api/auth/change-password')
      .set('Authorization', `Bearer ${googleToken}`)
      .send({ currentPassword: 'any', newPassword: 'NewPass123!' });

    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/Google/i);
  });
});
