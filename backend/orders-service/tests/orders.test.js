/**
 * Orders Service — Unit Tests
 * Tests: create order, list my orders, order detail, admin list, status update, stats
 */
const request = require('supertest');
const express = require('express');
const jwt = require('jsonwebtoken');

const JWT_SECRET = 'test-secret-key';
process.env.JWT_SECRET = JWT_SECRET;
process.env.DB_PATH = ':memory:';
process.env.INTERNAL_SERVICE_SECRET = 'test-internal-secret';

let app;

function makeToken(userId = 'user-1', role = 'client') {
  return jwt.sign({ id: userId, email: 'test@example.com', role }, JWT_SECRET, { expiresIn: '1h' });
}

const clientToken = makeToken('user-1', 'client');
const adminToken = makeToken('admin-1', 'admin');
const otherUserToken = makeToken('user-2', 'client');

beforeAll(async () => {
  const { initDatabase } = require('../src/database');
  await initDatabase();

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

  const ordersRoutes = require('../src/routes/orders.routes');
  app.use('/api/orders', ordersRoutes);
});

afterAll(() => {
  const { close } = require('../src/database');
  close();
});

let testOrderId;
let testOrderNumber;

// ══════════════════════════════════════
// Create Order
// ══════════════════════════════════════
describe('POST /api/orders', () => {
  it('should require authentication', async () => {
    const res = await request(app)
      .post('/api/orders')
      .send({ items: [{ product_id: 'p1', product_name: 'Test', product_price: 10000, quantity: 1 }] });
    expect(res.status).toBe(401);
  });

  it('should create order with valid data', async () => {
    const res = await request(app)
      .post('/api/orders')
      .set('Authorization', `Bearer ${clientToken}`)
      .send({
        items: [
          { product_id: 'prod-1', product_name: 'Product A', product_price: 50000, product_image: 'img.jpg', quantity: 2 },
          { product_id: 'prod-2', product_name: 'Product B', product_price: 30000, quantity: 1 },
        ],
        shipping_address: { street: 'Calle 100 #15-20', city: 'Bogotá', department: 'Cundinamarca', country: 'Colombia' },
        payment_method: 'credit_card',
        customer_name: 'Test User',
        customer_email: 'test@example.com',
        notes: 'Please deliver ASAP',
      });

    expect(res.status).toBe(201);
    expect(res.body.data).toBeDefined();
    expect(res.body.data.order_number).toMatch(/^BS-\d{6}$/);
    expect(res.body.data.status).toBe('pending');
    expect(res.body.data.items.length).toBe(2);

    // Verify math: subtotal = 50000*2 + 30000*1 = 130000, tax = 130000*0.19 = 24700
    expect(res.body.data.subtotal).toBe(130000);
    expect(res.body.data.tax).toBe(24700);
    expect(res.body.data.total).toBe(154700);

    testOrderId = res.body.data.id;
    testOrderNumber = res.body.data.order_number;
  });

  it('should reject empty items array', async () => {
    const res = await request(app)
      .post('/api/orders')
      .set('Authorization', `Bearer ${clientToken}`)
      .send({
        items: [],
        shipping_address: 'Some address',
      });

    expect(res.status).toBe(400);
  });

  it('should reject missing shipping_address', async () => {
    const res = await request(app)
      .post('/api/orders')
      .set('Authorization', `Bearer ${clientToken}`)
      .send({
        items: [{ product_id: 'p1', product_name: 'Test', product_price: 10000, quantity: 1 }],
      });

    expect(res.status).toBe(400);
  });

  it('should generate sequential order numbers', async () => {
    const res = await request(app)
      .post('/api/orders')
      .set('Authorization', `Bearer ${clientToken}`)
      .send({
        items: [{ product_id: 'p1', product_name: 'Test', product_price: 10000, quantity: 1 }],
        shipping_address: 'Address 2',
      });

    expect(res.status).toBe(201);
    // Second order should have next sequential number
    const num1 = parseInt(testOrderNumber.replace('BS-', ''));
    const num2 = parseInt(res.body.data.order_number.replace('BS-', ''));
    expect(num2).toBe(num1 + 1);
  });
});

// ══════════════════════════════════════
// My Orders
// ══════════════════════════════════════
describe('GET /api/orders/me', () => {
  it('should list current user orders', async () => {
    const res = await request(app)
      .get('/api/orders/me')
      .set('Authorization', `Bearer ${clientToken}`);

    expect(res.status).toBe(200);
    expect(res.body.data.length).toBe(2); // we created 2 above
    expect(res.body.pagination).toBeDefined();
  });

  it('should return empty for other user', async () => {
    const res = await request(app)
      .get('/api/orders/me')
      .set('Authorization', `Bearer ${otherUserToken}`);

    expect(res.status).toBe(200);
    expect(res.body.data.length).toBe(0);
  });
});

// ══════════════════════════════════════
// Order Detail
// ══════════════════════════════════════
describe('GET /api/orders/me/:id', () => {
  it('should return order detail for owner', async () => {
    const res = await request(app)
      .get(`/api/orders/me/${testOrderId}`)
      .set('Authorization', `Bearer ${clientToken}`);

    expect(res.status).toBe(200);
    expect(res.body.data.id).toBe(testOrderId);
    expect(res.body.data.items.length).toBe(2);
    expect(res.body.data.status_history.length).toBeGreaterThanOrEqual(1);
  });

  it('should return 404 for other user', async () => {
    const res = await request(app)
      .get(`/api/orders/me/${testOrderId}`)
      .set('Authorization', `Bearer ${otherUserToken}`);

    expect(res.status).toBe(404);
  });
});

// ══════════════════════════════════════
// Internal Service Payment Status Update
// ══════════════════════════════════════
describe('PATCH /api/orders/:id/payment-status (internal)', () => {
  it('should reject without x-internal-service header', async () => {
    const res = await request(app)
      .patch(`/api/orders/${testOrderId}/payment-status`)
      .send({ status: 'confirmed' });

    expect(res.status).toBe(403);
  });

  it('should update status with internal header', async () => {
    const res = await request(app)
      .patch(`/api/orders/${testOrderId}/payment-status`)
      .set('x-internal-service', 'test-internal-secret')
      .send({
        status: 'confirmed',
        payment_id: 'pay-123',
        payment_status: 'approved',
        note: 'Pago aprobado via PayU',
      });

    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe('confirmed');
  });

  it('should reject invalid status transition', async () => {
    const res = await request(app)
      .patch(`/api/orders/${testOrderId}/payment-status`)
      .set('x-internal-service', 'test-internal-secret')
      .send({ status: 'delivered' }); // confirmed → delivered not valid

    expect(res.status).toBe(400);
    expect(res.body.error).toMatch(/Transición no permitida/i);
  });
});

// ══════════════════════════════════════
// Admin - List All Orders
// ══════════════════════════════════════
describe('GET /api/orders (admin)', () => {
  it('should reject non-admin access', async () => {
    const res = await request(app)
      .get('/api/orders')
      .set('Authorization', `Bearer ${clientToken}`);

    expect(res.status).toBe(403);
  });

  it('should list all orders for admin', async () => {
    const res = await request(app)
      .get('/api/orders')
      .set('Authorization', `Bearer ${adminToken}`);

    expect(res.status).toBe(200);
    expect(res.body.data.length).toBeGreaterThanOrEqual(2);
    expect(res.body.pagination).toBeDefined();
  });

  it('should filter by status', async () => {
    const res = await request(app)
      .get('/api/orders?status=confirmed')
      .set('Authorization', `Bearer ${adminToken}`);

    expect(res.status).toBe(200);
    res.body.data.forEach(o => expect(o.status).toBe('confirmed'));
  });
});

// ══════════════════════════════════════
// Admin - Status Update
// ══════════════════════════════════════
describe('PATCH /api/orders/:id/status (admin)', () => {
  it('should update status with valid transition', async () => {
    const res = await request(app)
      .patch(`/api/orders/${testOrderId}/status`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ status: 'processing', note: 'Preparando envío' });

    expect(res.status).toBe(200);
    expect(res.body.data.status).toBe('processing');
    expect(res.body.data.status_history.length).toBeGreaterThanOrEqual(3);
  });

  it('should reject invalid transition', async () => {
    const res = await request(app)
      .patch(`/api/orders/${testOrderId}/status`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ status: 'pending' }); // processing → pending not valid

    expect(res.status).toBe(400);
  });
});

// ══════════════════════════════════════
// Admin - Stats
// ══════════════════════════════════════
describe('GET /api/orders/stats/summary (admin)', () => {
  it('should return statistics', async () => {
    const res = await request(app)
      .get('/api/orders/stats/summary')
      .set('Authorization', `Bearer ${adminToken}`);

    expect(res.status).toBe(200);
    expect(res.body.data.totalOrders).toBeGreaterThanOrEqual(2);
    expect(res.body.data.byStatus).toBeDefined();
    expect(res.body.data.revenue).toBeDefined();
    expect(res.body.data.revenue.today).toBeDefined();
  });
});

// ══════════════════════════════════════
// Error Handling Tests
// ══════════════════════════════════════
describe('Error Handling', () => {
  it('PATCH /api/orders/:id/payment-status should return 404 for non-existent order', async () => {
    const res = await request(app)
      .patch('/api/orders/non-existent-order/payment-status')
      .set('x-internal-service', 'test-internal-secret')
      .send({ status: 'confirmed' });

    expect(res.status).toBe(404);
  });

  it('PATCH /api/orders/:id/status should return 404 for non-existent order', async () => {
    const res = await request(app)
      .patch('/api/orders/non-existent-order/status')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ status: 'processing' });

    expect(res.status).toBe(404);
  });

  it('GET /api/orders/me/:id should return 404 for non-existent order', async () => {
    const res = await request(app)
      .get('/api/orders/me/non-existent-order')
      .set('Authorization', `Bearer ${clientToken}`);

    expect(res.status).toBe(404);
  });

  it('GET /api/orders/:id (admin) should return 404 for non-existent order', async () => {
    const res = await request(app)
      .get('/api/orders/non-existent-order')
      .set('Authorization', `Bearer ${adminToken}`);

    expect(res.status).toBe(404);
  });
});
