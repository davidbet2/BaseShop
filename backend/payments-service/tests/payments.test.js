/**
 * Payments Service — Integration Tests
 * Tests: payments CRUD, webhook, auth, validation
 */
const request = require('supertest');
const express = require('express');
const jwt = require('jsonwebtoken');

const JWT_SECRET = 'test-secret-key';
process.env.JWT_SECRET = JWT_SECRET;

let app;
let db;

jest.mock('axios', () => ({
  patch: jest.fn().mockResolvedValue({ data: {} })
}));

beforeAll(async () => {
  process.env.DB_PATH = ':memory:';
  const { initDatabase, getDb } = require('../src/database');
  await initDatabase();
  db = getDb();

  app = express();
  app.use(express.json());

  app.use((req, res, next) => {
    const origJson = res.json.bind(res);
    res.json = (body) => {
      res.setHeader('Content-Type', 'application/json; charset=utf-8');
      return origJson(body);
    };
    next();
  });

  const paymentRoutes = require('../src/routes/payments.routes');
  app.use('/api/payments', paymentRoutes);
});

afterAll(() => {
  const { close } = require('../src/database');
  close();
});

function generateToken(payload = { userId: 'user-1', email: 'test@test.com', role: 'user' }) {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: '1h', algorithm: 'HS256' });
}

function generateAdminToken() {
  return jwt.sign({ userId: 'admin-1', email: 'admin@test.com', role: 'admin' }, JWT_SECRET, { expiresIn: '1h', algorithm: 'HS256' });
}

describe('POST /api/payments/create', () => {
  it('should create payment with valid data', async () => {
    const token = generateToken();
    
    const res = await request(app)
      .post('/api/payments/create')
      .set('Authorization', `Bearer ${token}`)
      .send({
        order_id: 'order-123',
        amount: 100000,
        buyer_email: 'buyer@test.com',
        buyer_name: 'Test Buyer',
        currency: 'COP'
      });

    expect(res.status).toBe(201);
    expect(res.body.data).toHaveProperty('payment_id');
    expect(res.body.data).toHaveProperty('order_id', 'order-123');
    expect(res.body.data).toHaveProperty('payu_form_data');
  });

  it('should return 401 without token', async () => {
    const res = await request(app)
      .post('/api/payments/create')
      .send({
        order_id: 'order-123',
        amount: 100000,
        buyer_email: 'buyer@test.com',
        buyer_name: 'Test Buyer'
      });

    expect(res.status).toBe(401);
  });

  it('should return 400 with missing required fields', async () => {
    const token = generateToken();

    const res = await request(app)
      .post('/api/payments/create')
      .set('Authorization', `Bearer ${token}`)
      .send({
        order_id: 'order-123'
      });

    expect(res.status).toBe(400);
    expect(res.body).toHaveProperty('error');
  });
});

describe('GET /api/payments/order/:orderId', () => {
  beforeAll(async () => {
    const token = generateToken({ userId: 'user-owner', email: 'owner@test.com', role: 'user' });
    await request(app)
      .post('/api/payments/create')
      .set('Authorization', `Bearer ${token}`)
      .send({
        order_id: 'order-owned',
        amount: 50000,
        buyer_email: 'owner@test.com',
        buyer_name: 'Owner User'
      });
  });

  it('should return payment for owner', async () => {
    const token = generateToken({ userId: 'user-owner', email: 'owner@test.com', role: 'user' });

    const res = await request(app)
      .get('/api/payments/order/order-owned')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.data).toHaveProperty('order_id', 'order-owned');
  });

  it('should return 404 for non-owner', async () => {
    const token = generateToken({ userId: 'other-user', email: 'other@test.com', role: 'user' });

    const res = await request(app)
      .get('/api/payments/order/order-owned')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(404);
  });
});

describe('GET /api/payments (admin)', () => {
  it('should return payments for admin', async () => {
    const token = generateAdminToken();

    const res = await request(app)
      .get('/api/payments')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('data');
    expect(res.body).toHaveProperty('pagination');
  });

  it('should return 403 for non-admin', async () => {
    const token = generateToken();

    const res = await request(app)
      .get('/api/payments')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(403);
  });
});

describe('GET /api/payments/stats/summary (admin)', () => {
  it('should return stats for admin', async () => {
    const token = generateAdminToken();

    const res = await request(app)
      .get('/api/payments/stats/summary')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.data).toHaveProperty('totalPayments');
    expect(res.body.data).toHaveProperty('byStatus');
    expect(res.body.data).toHaveProperty('revenue');
  });
});

describe('POST /api/payments/:id/refund', () => {
  let paymentId;

  beforeAll(async () => {
    const token = generateToken({ userId: 'user-test', email: 'test@test.com', role: 'user' });
    const res = await request(app)
      .post('/api/payments/create')
      .set('Authorization', `Bearer ${token}`)
      .send({
        order_id: 'order-refund',
        amount: 75000,
        buyer_email: 'test@test.com',
        buyer_name: 'Test User'
      });
    paymentId = res.body.data.payment_id;
  });

  it('should refund approved payment as admin', async () => {
    const token = generateAdminToken();
    
    db.prepare("UPDATE payments SET status = 'approved' WHERE id = ?").run(paymentId);

    const res = await request(app)
      .post(`/api/payments/${paymentId}/refund`)
      .set('Authorization', `Bearer ${token}`)
      .send({ reason: 'Customer request' });

    expect(res.status).toBe(200);
    expect(res.body.data).toHaveProperty('status', 'refunded');
  });

  it('should return 400 for non-approved payment', async () => {
    const token = generateAdminToken();
    
    const res = await request(app)
      .post(`/api/payments/non-existent/refund`)
      .set('Authorization', `Bearer ${token}`)
      .send({ reason: 'Test' });

    expect(res.status).toBe(404);
  });
});

describe('POST /api/payments/webhook/payu', () => {
  let paymentId;

  beforeAll(async () => {
    const token = generateToken();
    const res = await request(app)
      .post('/api/payments/create')
      .set('Authorization', `Bearer ${token}`)
      .send({
        order_id: 'order-webhook',
        amount: 100000,
        buyer_email: 'webhook@test.com',
        buyer_name: 'Webhook Test'
      });
    paymentId = res.body.data.payment_id;
  });

  it('should return 400 with invalid signature', async () => {
    const res = await request(app)
      .post('/api/payments/webhook/payu')
      .send({
        merchant_id: 'test-merchant',
        reference_sale: paymentId,
        value: '100000.00',
        currency: 'COP',
        state_pol: '4',
        sign: 'invalid-signature',
        transaction_id: 'tx-123'
      });

    expect(res.status).toBe(400);
  });

  it('should return 404 for non-existent payment', async () => {
    const res = await request(app)
      .post('/api/payments/webhook/payu')
      .send({
        merchant_id: 'test-merchant',
        reference_sale: 'non-existent-order',
        value: '100000.00',
        currency: 'COP',
        state_pol: '4',
        sign: 'some-sign',
        transaction_id: 'tx-123'
      });

    expect(res.status).toBe(400);
  });
});

describe('Auth Middleware', () => {
  it('should return 401 without token', async () => {
    const res = await request(app)
      .get('/api/payments/order/test');

    expect(res.status).toBe(401);
    expect(res.body.error).toContain('Token');
  });

  it('should return 401 with invalid token', async () => {
    const res = await request(app)
      .get('/api/payments/order/test')
      .set('Authorization', 'Bearer invalid-token');

    expect(res.status).toBe(401);
  });

  it('should allow request with valid token', async () => {
    const token = generateToken();
    
    const res = await request(app)
      .get('/api/payments/order/test')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(404);
  });
});
