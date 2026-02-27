/**
 * Cart Service — Unit Tests
 * Tests: get cart, add item, update quantity, delete item, clear cart, count
 */
const request = require('supertest');
const express = require('express');
const jwt = require('jsonwebtoken');

const JWT_SECRET = 'test-secret-key';
process.env.JWT_SECRET = JWT_SECRET;
process.env.DB_PATH = ':memory:';

let app;

function makeToken(userId = 'user-1', role = 'client') {
  return jwt.sign({ id: userId, email: 'test@example.com', role }, JWT_SECRET, { expiresIn: '1h' });
}

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

  const cartRoutes = require('../src/routes/cart.routes');
  app.use('/api/cart', cartRoutes);
});

afterAll(() => {
  const { close } = require('../src/database');
  close();
});

const token = makeToken('user-1');
const otherToken = makeToken('user-2');

// ══════════════════════════════════════
// Authentication
// ══════════════════════════════════════
describe('Cart Authentication', () => {
  it('should reject unauthenticated access', async () => {
    const res = await request(app).get('/api/cart');
    expect(res.status).toBe(401);
  });
});

// ══════════════════════════════════════
// Empty Cart
// ══════════════════════════════════════
describe('GET /api/cart (empty)', () => {
  it('should return empty cart for new user', async () => {
    const res = await request(app)
      .get('/api/cart')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.data.items).toEqual([]);
    expect(res.body.data.subtotal).toBe(0);
    expect(res.body.data.itemCount).toBe(0);
  });
});

// ══════════════════════════════════════
// Add Items
// ══════════════════════════════════════
describe('POST /api/cart/items', () => {
  it('should add item to cart', async () => {
    const res = await request(app)
      .post('/api/cart/items')
      .set('Authorization', `Bearer ${token}`)
      .send({
        product_id: 'prod-1',
        product_name: 'Test Product',
        product_price: 50000,
        product_image: 'http://example.com/img.jpg',
        quantity: 2,
      });

    expect(res.status).toBe(201);
    expect(res.body.data.product_id).toBe('prod-1');
    expect(res.body.data.quantity).toBe(2);
  });

  it('should increment quantity for duplicate product', async () => {
    const res = await request(app)
      .post('/api/cart/items')
      .set('Authorization', `Bearer ${token}`)
      .send({
        product_id: 'prod-1',
        product_name: 'Test Product',
        product_price: 50000,
        quantity: 3,
      });

    expect(res.status).toBe(200);
    expect(res.body.data.quantity).toBe(5); // 2 + 3
  });

  it('should add second different product', async () => {
    const res = await request(app)
      .post('/api/cart/items')
      .set('Authorization', `Bearer ${token}`)
      .send({
        product_id: 'prod-2',
        product_name: 'Second Product',
        product_price: 30000,
        quantity: 1,
      });

    expect(res.status).toBe(201);
  });

  it('should reject missing product_id', async () => {
    const res = await request(app)
      .post('/api/cart/items')
      .set('Authorization', `Bearer ${token}`)
      .send({
        product_name: 'No ID',
        product_price: 10000,
      });

    expect(res.status).toBe(400);
  });

  it('should reject negative price', async () => {
    const res = await request(app)
      .post('/api/cart/items')
      .set('Authorization', `Bearer ${token}`)
      .send({
        product_id: 'prod-neg',
        product_name: 'Negative',
        product_price: -100,
      });

    expect(res.status).toBe(400);
  });
});

// ══════════════════════════════════════
// Get Cart with Items
// ══════════════════════════════════════
describe('GET /api/cart (with items)', () => {
  it('should return cart with correct items and subtotal', async () => {
    const res = await request(app)
      .get('/api/cart')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.data.items.length).toBe(2);
    expect(res.body.data.itemCount).toBe(6); // 5 + 1
    expect(res.body.data.subtotal).toBe(280000); // 50000*5 + 30000*1
  });
});

// ══════════════════════════════════════
// Cart Count
// ══════════════════════════════════════
describe('GET /api/cart/count', () => {
  it('should return total item count', async () => {
    const res = await request(app)
      .get('/api/cart/count')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.data.count).toBe(6);
  });
});

// ══════════════════════════════════════
// Update Quantity
// ══════════════════════════════════════
describe('PUT /api/cart/items/:id', () => {
  let itemId;

  beforeAll(async () => {
    const res = await request(app)
      .get('/api/cart')
      .set('Authorization', `Bearer ${token}`);
    itemId = res.body.data.items[0].id;
  });

  it('should update item quantity', async () => {
    const res = await request(app)
      .put(`/api/cart/items/${itemId}`)
      .set('Authorization', `Bearer ${token}`)
      .send({ quantity: 10 });

    expect(res.status).toBe(200);
    expect(res.body.data.quantity).toBe(10);
  });

  it('should reject quantity < 1', async () => {
    const res = await request(app)
      .put(`/api/cart/items/${itemId}`)
      .set('Authorization', `Bearer ${token}`)
      .send({ quantity: 0 });

    expect(res.status).toBe(400);
  });

  it('should not allow other user to update', async () => {
    const res = await request(app)
      .put(`/api/cart/items/${itemId}`)
      .set('Authorization', `Bearer ${otherToken}`)
      .send({ quantity: 1 });

    expect(res.status).toBe(404);
  });
});

// ══════════════════════════════════════
// Delete Item
// ══════════════════════════════════════
describe('DELETE /api/cart/items/:id', () => {
  let itemId;

  beforeAll(async () => {
    const res = await request(app)
      .get('/api/cart')
      .set('Authorization', `Bearer ${token}`);
    itemId = res.body.data.items[1].id; // delete second item
  });

  it('should delete an item from cart', async () => {
    const res = await request(app)
      .delete(`/api/cart/items/${itemId}`)
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);

    // Verify cart has one item now
    const cartRes = await request(app)
      .get('/api/cart')
      .set('Authorization', `Bearer ${token}`);
    expect(cartRes.body.data.items.length).toBe(1);
  });

  it('should return 404 for non-existent item', async () => {
    const res = await request(app)
      .delete('/api/cart/items/non-existent-id')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(404);
  });
});

// ══════════════════════════════════════
// Clear Cart
// ══════════════════════════════════════
describe('DELETE /api/cart (clear)', () => {
  it('should clear all items from cart', async () => {
    const res = await request(app)
      .delete('/api/cart')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);

    const cartRes = await request(app)
      .get('/api/cart')
      .set('Authorization', `Bearer ${token}`);
    expect(cartRes.body.data.items.length).toBe(0);
    expect(cartRes.body.data.subtotal).toBe(0);
  });
});

// ══════════════════════════════════════
// User Isolation
// ══════════════════════════════════════
describe('User Isolation', () => {
  it('should not see other user cart items', async () => {
    // Add item for user-1
    await request(app)
      .post('/api/cart/items')
      .set('Authorization', `Bearer ${token}`)
      .send({
        product_id: 'prod-isolated',
        product_name: 'Isolated',
        product_price: 10000,
      });

    // user-2 should not see it
    const res = await request(app)
      .get('/api/cart')
      .set('Authorization', `Bearer ${otherToken}`);

    expect(res.body.data.items.length).toBe(0);
  });
});
