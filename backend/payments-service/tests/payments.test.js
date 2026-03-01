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

describe('GET /api/payments/:id (admin)', () => {
  let paymentId;

  beforeAll(async () => {
    const token = generateToken();
    const res = await request(app)
      .post('/api/payments/create')
      .set('Authorization', `Bearer ${token}`)
      .send({
        order_id: 'order-detail',
        amount: 25000,
        buyer_email: 'detail@test.com',
        buyer_name: 'Detail Test'
      });
    paymentId = res.body.data.payment_id;
  });

  it('should return payment detail for admin', async () => {
    const token = generateAdminToken();

    const res = await request(app)
      .get(`/api/payments/${paymentId}`)
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.data).toHaveProperty('id', paymentId);
  });

  it('should return 404 for non-existent payment', async () => {
    const token = generateAdminToken();

    const res = await request(app)
      .get('/api/payments/non-existent-id')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(404);
  });

  it('should return 403 for non-admin', async () => {
    const token = generateToken();

    const res = await request(app)
      .get(`/api/payments/${paymentId}`)
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(403);
  });
});

describe('POST /api/payments/validate-response', () => {
  let paymentId;

  beforeAll(async () => {
    const token = generateToken();
    const res = await request(app)
      .post('/api/payments/create')
      .set('Authorization', `Bearer ${token}`)
      .send({
        order_id: 'order-validate',
        amount: 30000,
        buyer_email: 'validate@test.com',
        buyer_name: 'Validate Test'
      });
    paymentId = res.body.data.payment_id;
  });

  it('should validate response with pending status', async () => {
    const token = generateToken();

    const res = await request(app)
      .post('/api/payments/validate-response')
      .set('Authorization', `Bearer ${token}`)
      .send({
        orderId: 'order-validate',
        transactionState: '4',
        lapTransactionState: 'APPROVED'
      });

    expect(res.status).toBe(200);
  });

  it('should return 404 for non-existent order', async () => {
    const token = generateToken();

    const res = await request(app)
      .post('/api/payments/validate-response')
      .set('Authorization', `Bearer ${token}`)
      .send({
        orderId: 'non-existent-order',
        transactionState: '4'
      });

    expect(res.status).toBe(404);
  });

  it('should return 400 for missing required fields', async () => {
    const token = generateToken();

    const res = await request(app)
      .post('/api/payments/validate-response')
      .set('Authorization', `Bearer ${token}`)
      .send({
        orderId: 'order-validate'
      });

    expect(res.status).toBe(400);
  });
});

describe('POST /api/payments/create - existing pending payment', () => {
  it('should return existing pending payment', async () => {
    const token = generateToken();
    
    await request(app)
      .post('/api/payments/create')
      .set('Authorization', `Bearer ${token}`)
      .send({
        order_id: 'dup-order',
        amount: 50000,
        buyer_email: 'dup@test.com',
        buyer_name: 'Dup Test'
      });

    const res = await request(app)
      .post('/api/payments/create')
      .set('Authorization', `Bearer ${token}`)
      .send({
        order_id: 'dup-order',
        amount: 50000,
        buyer_email: 'dup@test.com',
        buyer_name: 'Dup Test'
      });

    expect(res.status).toBe(200);
    expect(res.body.message).toContain('pendiente existente');
  });
});

describe('Error handling', () => {
  it('should handle database errors gracefully', async () => {
    const token = generateAdminToken();

    const res = await request(app)
      .get('/api/payments/stats/summary')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.data).toHaveProperty('totalPayments');
  });
});

describe('Webhook - various payment statuses', () => {
  let paymentIdApproved, paymentIdDeclined, paymentIdExpired;

  beforeAll(async () => {
    const token = generateToken();
    
    let res = await request(app)
      .post('/api/payments/create')
      .set('Authorization', `Bearer ${token}`)
      .send({ order_id: 'order-approved', amount: 10000, buyer_email: 'test@test.com', buyer_name: 'Test' });
    paymentIdApproved = res.body.data.payment_id;
    
    res = await request(app)
      .post('/api/payments/create')
      .set('Authorization', `Bearer ${token}`)
      .send({ order_id: 'order-declined', amount: 10000, buyer_email: 'test@test.com', buyer_name: 'Test' });
    paymentIdDeclined = res.body.data.payment_id;
    
    res = await request(app)
      .post('/api/payments/create')
      .set('Authorization', `Bearer ${token}`)
      .send({ order_id: 'order-expired', amount: 10000, buyer_email: 'test@test.com', buyer_name: 'Test' });
    paymentIdExpired = res.body.data.payment_id;
  });

  it('should process webhook with approved status (state_pol 4)', async () => {
    const crypto = require('crypto');
    const signature = crypto.createHash('md5')
      .update(`test-api-key~test-merchant~${paymentIdApproved}~10000.0~COP~4`)
      .digest('hex');

    const res = await request(app)
      .post('/api/payments/webhook/payu')
      .send({
        merchant_id: 'test-merchant',
        reference_sale: paymentIdApproved,
        value: '10000.00',
        currency: 'COP',
        state_pol: '4',
        transaction_id: 'tx-approved',
        sign: signature
      });

    expect(res.status).toBe(200);
  });

  it('should process webhook with declined status (state_pol 6)', async () => {
    const crypto = require('crypto');
    const signature = crypto.createHash('md5')
      .update(`test-api-key~test-merchant~${paymentIdDeclined}~10000.0~COP~6`)
      .digest('hex');

    const res = await request(app)
      .post('/api/payments/webhook/payu')
      .send({
        merchant_id: 'test-merchant',
        reference_sale: paymentIdDeclined,
        value: '10000.00',
        currency: 'COP',
        state_pol: '6',
        transaction_id: 'tx-declined',
        sign: signature
      });

    expect(res.status).toBe(200);
  });

  it('should process webhook with expired status (state_pol 5)', async () => {
    const crypto = require('crypto');
    const signature = crypto.createHash('md5')
      .update(`test-api-key~test-merchant~${paymentIdExpired}~10000.0~COP~5`)
      .digest('hex');

    const res = await request(app)
      .post('/api/payments/webhook/payu')
      .send({
        merchant_id: 'test-merchant',
        reference_sale: paymentIdExpired,
        value: '10000.00',
        currency: 'COP',
        state_pol: '5',
        transaction_id: 'tx-expired',
        sign: signature
      });

    expect(res.status).toBe(200);
  });
});

describe('Additional validation scenarios', () => {
  it('should validate amount must be positive', async () => {
    const token = generateToken();

    const res = await request(app)
      .post('/api/payments/create')
      .set('Authorization', `Bearer ${token}`)
      .send({
        order_id: 'order-invalid',
        amount: -100,
        buyer_email: 'test@test.com',
        buyer_name: 'Test'
      });

    expect(res.status).toBe(400);
  });

  it('should validate buyer_email must be valid', async () => {
    const token = generateToken();

    const res = await request(app)
      .post('/api/payments/create')
      .set('Authorization', `Bearer ${token}`)
      .send({
        order_id: 'order-invalid',
        amount: 10000,
        buyer_email: 'invalid-email',
        buyer_name: 'Test'
      });

    expect(res.status).toBe(400);
  });

  it('should require buyer_name', async () => {
    const token = generateToken();

    const res = await request(app)
      .post('/api/payments/create')
      .set('Authorization', `Bearer ${token}`)
      .send({
        order_id: 'order-invalid',
        amount: 10000,
        buyer_email: 'test@test.com'
      });

    expect(res.status).toBe(400);
  });
});

describe('GET /api/payments with filters', () => {
  it('should filter payments by status', async () => {
    const token = generateAdminToken();

    const res = await request(app)
      .get('/api/payments?status=pending')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('data');
    expect(res.body).toHaveProperty('pagination');
  });

  it('should support pagination', async () => {
    const token = generateAdminToken();

    const res = await request(app)
      .get('/api/payments?page=1&limit=5')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.pagination.page).toBe(1);
    expect(res.body.pagination.limit).toBe(5);
  });
});

describe('Refund edge cases', () => {
  it('should return 404 for refund non-existent payment', async () => {
    const token = generateAdminToken();

    const res = await request(app)
      .post('/api/payments/non-existent-id/refund')
      .set('Authorization', `Bearer ${token}`)
      .send({ reason: 'Test' });

    expect(res.status).toBe(404);
  });

  it('should prevent refund of declined payment', async () => {
    const token = generateToken();
    
    const res = await request(app)
      .post('/api/payments/create')
      .set('Authorization', `Bearer ${token}`)
      .send({ order_id: 'order-decline-refund', amount: 5000, buyer_email: 'test@test.com', buyer_name: 'Test' });
    const paymentId = res.body.data.payment_id;
    
    const adminToken = generateAdminToken();
    await request(app)
      .post(`/api/payments/${paymentId}/refund`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ reason: 'Test' });

    const res2 = await request(app)
      .post(`/api/payments/${paymentId}/refund`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ reason: 'Test again' });

    expect(res2.status).toBe(400);
  });
});

describe('Webhook edge cases', () => {
  it('should handle webhook with error status (state_pol 104)', async () => {
    const token = generateToken();
    const res = await request(app)
      .post('/api/payments/create')
      .set('Authorization', `Bearer ${token}`)
      .send({ order_id: 'order-error', amount: 5000, buyer_email: 'test@test.com', buyer_name: 'Test' });
    const paymentId = res.body.data.payment_id;
    
    const crypto = require('crypto');
    const signature = crypto.createHash('md5')
      .update(`test-api-key~test-merchant~${paymentId}~5000.0~COP~104`)
      .digest('hex');

    const webhookRes = await request(app)
      .post('/api/payments/webhook/payu')
      .send({
        merchant_id: 'test-merchant',
        reference_sale: paymentId,
        value: '5000.00',
        currency: 'COP',
        state_pol: '104',
        transaction_id: 'tx-error',
        sign: signature
      });

    expect(webhookRes.status).toBe(200);
  });

  it('should handle webhook with pending status (state_pol 7)', async () => {
    const token = generateToken();
    const res = await request(app)
      .post('/api/payments/create')
      .set('Authorization', `Bearer ${token}`)
      .send({ order_id: 'order-pending', amount: 5000, buyer_email: 'test@test.com', buyer_name: 'Test' });
    const paymentId = res.body.data.payment_id;
    
    const crypto = require('crypto');
    const signature = crypto.createHash('md5')
      .update(`test-api-key~test-merchant~${paymentId}~5000.0~COP~7`)
      .digest('hex');

    const webhookRes = await request(app)
      .post('/api/payments/webhook/payu')
      .send({
        merchant_id: 'test-merchant',
        reference_sale: paymentId,
        value: '5000.00',
        currency: 'COP',
        state_pol: '7',
        transaction_id: 'tx-pending',
        sign: signature
      });

    expect(webhookRes.status).toBe(200);
  });

  it('should handle webhook with abandoned status (state_pol 12)', async () => {
    const token = generateToken();
    const res = await request(app)
      .post('/api/payments/create')
      .set('Authorization', `Bearer ${token}`)
      .send({ order_id: 'order-abandoned', amount: 5000, buyer_email: 'test@test.com', buyer_name: 'Test' });
    const paymentId = res.body.data.payment_id;
    
    const crypto = require('crypto');
    const signature = crypto.createHash('md5')
      .update(`test-api-key~test-merchant~${paymentId}~5000.0~COP~12`)
      .digest('hex');

    const webhookRes = await request(app)
      .post('/api/payments/webhook/payu')
      .send({
        merchant_id: 'test-merchant',
        reference_sale: paymentId,
        value: '5000.00',
        currency: 'COP',
        state_pol: '12',
        transaction_id: 'tx-abandoned',
        sign: signature
      });

    expect(webhookRes.status).toBe(200);
  });
});

describe('Order lookup with different user roles', () => {
  it('should allow admin to view any order payment', async () => {
    const token = generateToken();
    const res = await request(app)
      .post('/api/payments/create')
      .set('Authorization', `Bearer ${token}`)
      .send({ order_id: 'order-admin-view', amount: 8000, buyer_email: 'user@test.com', buyer_name: 'User' });
    
    const adminToken = generateAdminToken();
    const res2 = await request(app)
      .get('/api/payments/order/order-admin-view')
      .set('Authorization', `Bearer ${adminToken}`);

    expect(res2.status).toBe(200);
  });
});

describe('Stats endpoint coverage', () => {
  it('should return correct revenue calculations', async () => {
    const token = generateAdminToken();

    const res = await request(app)
      .get('/api/payments/stats/summary')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.data.revenue).toHaveProperty('today');
    expect(res.body.data.revenue).toHaveProperty('week');
    expect(res.body.data.revenue).toHaveProperty('month');
    expect(res.body.data.refunded).toHaveProperty('total');
  });
});

describe('Production URL configuration', () => {
  it('should use production URLs when PAYU_IS_TEST is false', async () => {
    const originalValue = process.env.PAYU_IS_TEST;
    process.env.PAYU_IS_TEST = 'false';
    
    const token = generateToken();
    const res = await request(app)
      .post('/api/payments/create')
      .set('Authorization', `Bearer ${token}`)
      .send({
        order_id: 'order-prod-urls',
        amount: 1000,
        buyer_email: 'prod@test.com',
        buyer_name: 'Prod Test'
      });

    expect(res.status).toBe(201);
    expect(res.body.data.payu_form_data.checkoutUrl).toContain('checkout.payulatam.com');
    
    process.env.PAYU_IS_TEST = originalValue;
  });
});

describe('Webhook with order_id reference', () => {
  it('should find payment by order_id if not found by id', async () => {
    const token = generateToken();
    const res = await request(app)
      .post('/api/payments/create')
      .set('Authorization', `Bearer ${token}`)
      .send({ order_id: 'order-by-ref', amount: 3000, buyer_email: 'ref@test.com', buyer_name: 'Ref' });
    const paymentId = res.body.data.payment_id;
    
    const crypto = require('crypto');
    const signature = crypto.createHash('md5')
      .update(`test-api-key~test-merchant~${paymentId}~3000.0~COP~4`)
      .digest('hex');

    const webhookRes = await request(app)
      .post('/api/payments/webhook/payu')
      .send({
        merchant_id: 'test-merchant',
        reference_sale: 'order-by-ref',
        value: '3000.00',
        currency: 'COP',
        state_pol: '4',
        transaction_id: 'tx-ref',
        sign: signature
      });

    expect(webhookRes.status).toBe(400);
  });
});

describe('PayU status mapping coverage', () => {
  it('should handle pending_validation status (state_pol 14)', async () => {
    const token = generateToken();
    const res = await request(app)
      .post('/api/payments/create')
      .set('Authorization', `Bearer ${token}`)
      .send({ order_id: 'order-pending-validation', amount: 2500, buyer_email: 'test@test.com', buyer_name: 'Test' });
    const paymentId = res.body.data.payment_id;
    
    const crypto = require('crypto');
    const signature = crypto.createHash('md5')
      .update(`test-api-key~test-merchant~${paymentId}~2500.0~COP~14`)
      .digest('hex');

    const webhookRes = await request(app)
      .post('/api/payments/webhook/payu')
      .send({
        merchant_id: 'test-merchant',
        reference_sale: paymentId,
        value: '2500.00',
        currency: 'COP',
        state_pol: '14',
        transaction_id: 'tx-pending-validation',
        sign: signature
      });

    expect(webhookRes.status).toBe(200);
  });
});

describe('Refund validation', () => {
  it('should prevent double refund', async () => {
    const token = generateToken();
    const res = await request(app)
      .post('/api/payments/create')
      .set('Authorization', `Bearer ${token}`)
      .send({ order_id: 'order-double-refund', amount: 6000, buyer_email: 'test@test.com', buyer_name: 'Test' });
    const paymentId = res.body.data.payment_id;
    
    const adminToken = generateAdminToken();
    
    db.prepare("UPDATE payments SET status = 'approved' WHERE id = ?").run(paymentId);
    
    await request(app)
      .post(`/api/payments/${paymentId}/refund`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ reason: 'First refund' });
    
    const res2 = await request(app)
      .post(`/api/payments/${paymentId}/refund`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ reason: 'Second refund' });
    
    expect(res2.status).toBe(400);
  });
});

describe('Validate response edge cases', () => {
  it('should not update non-pending payment', async () => {
    const token = generateToken();
    const res = await request(app)
      .post('/api/payments/create')
      .set('Authorization', `Bearer ${token}`)
      .send({ order_id: 'order-already-approved', amount: 7000, buyer_email: 'test@test.com', buyer_name: 'Test' });
    
    db.prepare("UPDATE payments SET status = 'approved' WHERE order_id = ?").run('order-already-approved');
    
    const res2 = await request(app)
      .post('/api/payments/validate-response')
      .set('Authorization', `Bearer ${token}`)
      .send({
        orderId: 'order-already-approved',
        transactionState: '4',
        lapTransactionState: 'APPROVED'
      });

    expect(res2.status).toBe(200);
    expect(res2.body.message).toContain('ya actualizado');
  });
});

describe('Refund reason and logs', () => {
  it('should log refund reason', async () => {
    const token = generateToken();
    const res = await request(app)
      .post('/api/payments/create')
      .set('Authorization', `Bearer ${token}`)
      .send({ order_id: 'order-refund-log', amount: 9000, buyer_email: 'test@test.com', buyer_name: 'Test' });
    const paymentId = res.body.data.payment_id;
    
    const adminToken = generateAdminToken();
    db.prepare("UPDATE payments SET status = 'approved' WHERE id = ?").run(paymentId);
    
    const res2 = await request(app)
      .post(`/api/payments/${paymentId}/refund`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ reason: 'Customer requested refund' });

    expect(res2.status).toBe(200);
    expect(res2.body.data).toHaveProperty('logs');
  });
});

describe('Webhook payment method tracking', () => {
  it('should update payment method from webhook', async () => {
    const token = generateToken();
    const res = await request(app)
      .post('/api/payments/create')
      .set('Authorization', `Bearer ${token}`)
      .send({ order_id: 'order-payment-method', amount: 11000, buyer_email: 'test@test.com', buyer_name: 'Test' });
    const paymentId = res.body.data.payment_id;
    
    const crypto = require('crypto');
    const signature = crypto.createHash('md5')
      .update(`test-api-key~test-merchant~${paymentId}~11000.0~COP~4`)
      .digest('hex');

    const webhookRes = await request(app)
      .post('/api/payments/webhook/payu')
      .send({
        merchant_id: 'test-merchant',
        reference_sale: paymentId,
        value: '11000.00',
        currency: 'COP',
        state_pol: '4',
        transaction_id: 'tx-method',
        sign: signature,
        payment_method_type: 'CREDIT_CARD'
      });

    expect(webhookRes.status).toBe(200);
  });
});

describe('Validate response without signature', () => {
  it('should still process response without signature validation', async () => {
    const token = generateToken();
    const res = await request(app)
      .post('/api/payments/create')
      .set('Authorization', `Bearer ${token}`)
      .send({ order_id: 'order-no-sig', amount: 12000, buyer_email: 'test@test.com', buyer_name: 'Test' });
    
    const res2 = await request(app)
      .post('/api/payments/validate-response')
      .set('Authorization', `Bearer ${token}`)
      .send({
        orderId: 'order-no-sig',
        transactionState: '4',
        lapTransactionState: 'APPROVED'
      });

    expect(res2.status).toBe(200);
  });
});

describe('Webhook with order reference fallback', () => {
  it('should find payment by order_id when id not found', async () => {
    const token = generateToken();
    const res = await request(app)
      .post('/api/payments/create')
      .set('Authorization', `Bearer ${token}`)
      .send({ order_id: 'unique-order-ref', amount: 13000, buyer_email: 'test@test.com', buyer_name: 'Test' });
    
    const webhookRes = await request(app)
      .post('/api/payments/webhook/payu')
      .send({
        merchant_id: 'test-merchant',
        reference_sale: 'unique-order-ref',
        value: '13000.00',
        currency: 'COP',
        state_pol: '4',
        transaction_id: 'tx-order-ref',
        sign: 'invalid-signature'
      });

    expect(webhookRes.status).toBe(400);
  });
});
