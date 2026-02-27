/**
 * Products Service — Unit Tests
 * Tests: list products, get product detail, CRUD (admin), categories
 */
const request = require('supertest');
const express = require('express');
const jwt = require('jsonwebtoken');

const JWT_SECRET = 'test-secret-key';
process.env.JWT_SECRET = JWT_SECRET;
process.env.DB_PATH = ':memory:';

let app;

function makeToken(role = 'admin') {
  return jwt.sign({ id: 'user-1', email: 'admin@test.com', role }, JWT_SECRET, { expiresIn: '1h' });
}

const adminToken = makeToken('admin');
const clientToken = makeToken('client');

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

  const { productsRouter, categoriesRouter } = require('../src/routes/products.routes');
  app.use('/api/products', productsRouter);
  app.use('/api/categories', categoriesRouter);
});

afterAll(() => {
  const { close } = require('../src/database');
  close();
});

let testCategoryId;
let testProductId;

// ══════════════════════════════════════
// Categories CRUD
// ══════════════════════════════════════
describe('Categories', () => {
  it('GET /api/categories should return seeded categories', async () => {
    const res = await request(app).get('/api/categories');
    expect(res.status).toBe(200);
    expect(res.body.categories.length).toBeGreaterThanOrEqual(5);
  });

  it('GET /api/categories?flat=true should return flat list', async () => {
    const res = await request(app).get('/api/categories?flat=true');
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body.categories)).toBe(true);
    testCategoryId = res.body.categories[0].id;
  });

  it('POST /api/categories should require admin', async () => {
    const res = await request(app)
      .post('/api/categories')
      .set('Authorization', `Bearer ${clientToken}`)
      .send({ name: 'New Cat' });
    expect(res.status).toBe(403);
  });

  it('POST /api/categories should create category (admin)', async () => {
    const res = await request(app)
      .post('/api/categories')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ name: 'Test Category', description: 'Desc' });

    expect(res.status).toBe(201);
    expect(res.body.category.name).toBe('Test Category');
  });

  it('GET /api/categories/:id should return category details', async () => {
    const res = await request(app).get(`/api/categories/${testCategoryId}`);
    expect(res.status).toBe(200);
    expect(res.body.category).toBeDefined();
  });

  it('GET /api/categories/:id should return 404 for non-existent', async () => {
    const res = await request(app).get('/api/categories/non-existent');
    expect(res.status).toBe(404);
  });
});

// ══════════════════════════════════════
// Products CRUD
// ══════════════════════════════════════
describe('Products - Create (Admin)', () => {
  it('POST /api/products should require admin', async () => {
    const res = await request(app)
      .post('/api/products')
      .set('Authorization', `Bearer ${clientToken}`)
      .send({ name: 'Prod', price: 10000 });
    expect(res.status).toBe(403);
  });

  it('POST /api/products should create product', async () => {
    const res = await request(app)
      .post('/api/products')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        name: 'Test Product',
        price: 50000,
        stock: 10,
        category_id: testCategoryId,
        description: 'A test product',
        tags: ['test', 'sample'],
        is_featured: true,
      });

    expect(res.status).toBe(201);
    expect(res.body.product.name).toBe('Test Product');
    expect(res.body.product.price).toBe(50000);
    expect(res.body.product.is_featured).toBe(true);
    testProductId = res.body.product.id;
  });

  it('POST /api/products should reject missing name', async () => {
    const res = await request(app)
      .post('/api/products')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ price: 10000 });
    expect(res.status).toBe(400);
  });

  it('POST /api/products should reject negative price', async () => {
    const res = await request(app)
      .post('/api/products')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ name: 'Bad', price: -100 });
    expect(res.status).toBe(400);
  });

  it('POST /api/products should create product with discount', async () => {
    const res = await request(app)
      .post('/api/products')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        name: 'Discount Product',
        price: 100000,
        discount_percent: 20,
        stock: 5,
      });

    expect(res.status).toBe(201);
    // Final price should be 80000 (100000 * 0.8)
    expect(res.body.product.price).toBe(80000);
    expect(res.body.product.compare_price).toBe(100000);
    expect(res.body.product.discount_percent).toBe(20);
  });

  it('POST /api/products should create product with variants', async () => {
    const res = await request(app)
      .post('/api/products')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        name: 'Variant Product',
        price: 60000,
        stock: 20,
        variants: [
          {
            name: 'Color',
            options: [
              { name: 'Rojo', price_adjustment: 0 },
              { name: 'Azul', price_adjustment: 5000 },
            ],
          },
          {
            name: 'Talla',
            options: [
              { name: 'S', price_adjustment: 0 },
              { name: 'M', price_adjustment: 0 },
              { name: 'L', price_adjustment: 2000 },
            ],
          },
        ],
      });

    expect(res.status).toBe(201);
    expect(res.body.product.has_variants).toBe(true);
    expect(res.body.product.variants.length).toBe(2);
    expect(res.body.product.variants[0].options.length).toBe(2);
    expect(res.body.product.variants[1].options.length).toBe(3);
  });
});

// ══════════════════════════════════════
// Products - List (Public)
// ══════════════════════════════════════
describe('Products - List (Public)', () => {
  it('GET /api/products should return products', async () => {
    const res = await request(app).get('/api/products');
    expect(res.status).toBe(200);
    expect(res.body.products.length).toBeGreaterThanOrEqual(3);
    expect(res.body.pagination).toBeDefined();
  });

  it('GET /api/products?is_featured=true should filter featured', async () => {
    const res = await request(app).get('/api/products?is_featured=true');
    expect(res.status).toBe(200);
    res.body.products.forEach(p => expect(p.is_featured).toBe(true));
  });

  it('GET /api/products?search=Test should filter by search', async () => {
    const res = await request(app).get('/api/products?search=Test');
    expect(res.status).toBe(200);
    expect(res.body.products.length).toBeGreaterThanOrEqual(1);
  });

  it('GET /api/products?sort_by=price_asc should sort ascending', async () => {
    const res = await request(app).get('/api/products?sort_by=price_asc');
    expect(res.status).toBe(200);
    const prices = res.body.products.map(p => p.price);
    for (let i = 1; i < prices.length; i++) {
      expect(prices[i]).toBeGreaterThanOrEqual(prices[i - 1]);
    }
  });

  it('should support pagination', async () => {
    const res = await request(app).get('/api/products?page=1&limit=2');
    expect(res.status).toBe(200);
    expect(res.body.products.length).toBeLessThanOrEqual(2);
    expect(res.body.pagination.limit).toBe(2);
  });
});

// ══════════════════════════════════════
// Products - Detail (Public)
// ══════════════════════════════════════
describe('Products - Detail', () => {
  it('GET /api/products/:id should return product', async () => {
    const res = await request(app).get(`/api/products/${testProductId}`);
    expect(res.status).toBe(200);
    expect(res.body.product.id).toBe(testProductId);
    expect(res.body.product.name).toBe('Test Product');
  });

  it('GET /api/products/:id should return 404 for non-existent', async () => {
    const res = await request(app).get('/api/products/non-existent-id');
    expect(res.status).toBe(404);
  });
});

// ══════════════════════════════════════
// Products - Update (Admin)
// ══════════════════════════════════════
describe('Products - Update', () => {
  it('PUT /api/products/:id should update product', async () => {
    const res = await request(app)
      .put(`/api/products/${testProductId}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ name: 'Updated Product', price: 75000 });

    expect(res.status).toBe(200);
    expect(res.body.product.name).toBe('Updated Product');
    expect(res.body.product.price).toBe(75000);
  });

  it('PUT /api/products/:id should require admin', async () => {
    const res = await request(app)
      .put(`/api/products/${testProductId}`)
      .set('Authorization', `Bearer ${clientToken}`)
      .send({ name: 'Hacked' });
    expect(res.status).toBe(403);
  });
});

// ══════════════════════════════════════
// Products - Stock & Featured
// ══════════════════════════════════════
describe('Products - Stock & Featured', () => {
  it('PATCH /api/products/:id/stock should update stock', async () => {
    const res = await request(app)
      .patch(`/api/products/${testProductId}/stock`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ stock: 99 });

    expect(res.status).toBe(200);
    expect(res.body.product.stock).toBe(99);
  });

  it('PATCH /api/products/:id/featured should toggle featured', async () => {
    const res = await request(app)
      .patch(`/api/products/${testProductId}/featured`)
      .set('Authorization', `Bearer ${adminToken}`);

    expect(res.status).toBe(200);
    expect(res.body.product.is_featured).toBe(false); // was true, now toggled
  });
});

// ══════════════════════════════════════
// Products - Delete (Soft Delete)
// ══════════════════════════════════════
describe('Products - Delete', () => {
  it('DELETE /api/products/:id should soft-delete product', async () => {
    const res = await request(app)
      .delete(`/api/products/${testProductId}`)
      .set('Authorization', `Bearer ${adminToken}`);

    expect(res.status).toBe(200);

    // Product should no longer appear in public listing
    const listRes = await request(app).get('/api/products');
    const ids = listRes.body.products.map(p => p.id);
    expect(ids).not.toContain(testProductId);
  });

  it('DELETE /api/products/:id should return 404 for non-existent', async () => {
    const res = await request(app)
      .delete('/api/products/non-existent-id')
      .set('Authorization', `Bearer ${adminToken}`);
    expect(res.status).toBe(404);
  });
});
