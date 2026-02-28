/**
 * Favorites Service — Unit Tests
 * Tests: add, list paginated, check, delete, clear all, duplicate handling, user isolation
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

  const favoritesRoutes = require('../src/routes/favorites.routes');
  app.use('/api/favorites', favoritesRoutes);
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
describe('Favorites Authentication', () => {
  it('should reject unauthenticated access', async () => {
    const res = await request(app).get('/api/favorites');
    expect(res.status).toBe(401);
  });
});

// ══════════════════════════════════════
// Empty Favorites
// ══════════════════════════════════════
describe('GET /api/favorites (empty)', () => {
  it('should return empty favorites for new user', async () => {
    const res = await request(app)
      .get('/api/favorites')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.data).toEqual([]);
    expect(res.body.pagination.total).toBe(0);
  });
});

// ══════════════════════════════════════
// Add Favorites
// ══════════════════════════════════════
describe('POST /api/favorites', () => {
  it('should add product to favorites', async () => {
    const res = await request(app)
      .post('/api/favorites')
      .set('Authorization', `Bearer ${token}`)
      .send({
        product_id: 'prod-1',
        product_name: 'Test Product',
        product_price: 50000,
        product_image: 'http://example.com/img.jpg',
      });

    expect(res.status).toBe(201);
    expect(res.body.data.product_id).toBe('prod-1');
    expect(res.body.data.product_name).toBe('Test Product');
    expect(res.body.message).toBe('Producto agregado a favoritos');
  });

  it('should return existing on duplicate (no error)', async () => {
    const res = await request(app)
      .post('/api/favorites')
      .set('Authorization', `Bearer ${token}`)
      .send({ product_id: 'prod-1' });

    expect(res.status).toBe(200);
    expect(res.body.message).toBe('El producto ya está en favoritos');
  });

  it('should add second product', async () => {
    const res = await request(app)
      .post('/api/favorites')
      .set('Authorization', `Bearer ${token}`)
      .send({
        product_id: 'prod-2',
        product_name: 'Second Product',
        product_price: 30000,
      });

    expect(res.status).toBe(201);
  });

  it('should reject missing product_id', async () => {
    const res = await request(app)
      .post('/api/favorites')
      .set('Authorization', `Bearer ${token}`)
      .send({ product_name: 'No ID' });

    expect(res.status).toBe(400);
  });
});

// ══════════════════════════════════════
// List Favorites (paginated)
// ══════════════════════════════════════
describe('GET /api/favorites (with items)', () => {
  it('should return favorites with pagination', async () => {
    const res = await request(app)
      .get('/api/favorites')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.data.length).toBe(2);
    expect(res.body.pagination.total).toBe(2);
    expect(res.body.pagination.page).toBe(1);
  });

  it('should support pagination params', async () => {
    const res = await request(app)
      .get('/api/favorites?page=1&limit=1')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.data.length).toBe(1);
    expect(res.body.pagination.limit).toBe(1);
    expect(res.body.pagination.pages).toBe(2);
  });
});

// ══════════════════════════════════════
// Check Favorite
// ══════════════════════════════════════
describe('GET /api/favorites/check/:productId', () => {
  it('should return true for favorited product', async () => {
    const res = await request(app)
      .get('/api/favorites/check/prod-1')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.data.isFavorite).toBe(true);
    expect(res.body.data.favorite).toBeDefined();
  });

  it('should return false for non-favorited product', async () => {
    const res = await request(app)
      .get('/api/favorites/check/prod-999')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.data.isFavorite).toBe(false);
    expect(res.body.data.favorite).toBeNull();
  });
});

// ══════════════════════════════════════
// Delete Favorite
// ══════════════════════════════════════
describe('DELETE /api/favorites/:productId', () => {
  it('should delete favorite by product_id', async () => {
    const res = await request(app)
      .delete('/api/favorites/prod-2')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.message).toBe('Producto eliminado de favoritos');
  });

  it('should return 404 for non-existent favorite', async () => {
    const res = await request(app)
      .delete('/api/favorites/prod-999')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(404);
  });

  it('should verify deletion', async () => {
    const res = await request(app)
      .get('/api/favorites')
      .set('Authorization', `Bearer ${token}`);

    expect(res.body.data.length).toBe(1);
  });
});

// ══════════════════════════════════════
// Clear All Favorites
// ══════════════════════════════════════
describe('DELETE /api/favorites (clear all)', () => {
  it('should clear all favorites', async () => {
    // Add some first
    await request(app)
      .post('/api/favorites')
      .set('Authorization', `Bearer ${token}`)
      .send({ product_id: 'prod-3' });

    const res = await request(app)
      .delete('/api/favorites')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.message).toBe('Favoritos vaciados');
    expect(res.body.data.deletedCount).toBeGreaterThanOrEqual(1);

    // Verify empty
    const listRes = await request(app)
      .get('/api/favorites')
      .set('Authorization', `Bearer ${token}`);
    expect(listRes.body.data.length).toBe(0);
  });
});

// ══════════════════════════════════════
// User Isolation
// ══════════════════════════════════════
describe('User Isolation', () => {
  it('should not see other user favorites', async () => {
    // Add for user-1
    await request(app)
      .post('/api/favorites')
      .set('Authorization', `Bearer ${token}`)
      .send({ product_id: 'prod-isolated' });

    // user-2 should not see it
    const res = await request(app)
      .get('/api/favorites')
      .set('Authorization', `Bearer ${otherToken}`);

    expect(res.body.data.length).toBe(0);
  });

  it('should not allow other user to delete', async () => {
    const res = await request(app)
      .delete('/api/favorites/prod-isolated')
      .set('Authorization', `Bearer ${otherToken}`);

    expect(res.status).toBe(404);
  });

  it('check should be user-scoped', async () => {
    const res = await request(app)
      .get('/api/favorites/check/prod-isolated')
      .set('Authorization', `Bearer ${otherToken}`);

    expect(res.body.data.isFavorite).toBe(false);
  });
});
