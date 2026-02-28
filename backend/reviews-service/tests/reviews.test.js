/**
 * Reviews Service — Unit Tests
 * Tests: public product reviews, summary, auth CRUD, duplicate rejection, admin list/approve
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

  const reviewsRoutes = require('../src/routes/reviews.routes');
  app.use('/api/reviews', reviewsRoutes);
});

afterAll(() => {
  const { close } = require('../src/database');
  close();
});

const token = makeToken('user-1');
const otherToken = makeToken('user-2');
const adminToken = makeToken('admin-1', 'admin');

// ══════════════════════════════════════
// Public Routes — No auth required
// ══════════════════════════════════════
describe('GET /api/reviews/product/:productId (public)', () => {
  it('should return empty reviews for new product', async () => {
    const res = await request(app).get('/api/reviews/product/prod-1');

    expect(res.status).toBe(200);
    expect(res.body.data.reviews).toEqual([]);
    expect(res.body.data.avgRating).toBe(0);
    expect(res.body.data.totalReviews).toBe(0);
    expect(res.body.pagination).toBeDefined();
  });
});

describe('GET /api/reviews/product/:productId/summary (public)', () => {
  it('should return empty summary for new product', async () => {
    const res = await request(app).get('/api/reviews/product/prod-1/summary');

    expect(res.status).toBe(200);
    expect(res.body.data.avgRating).toBe(0);
    expect(res.body.data.total).toBe(0);
    expect(res.body.data.distribution).toBeDefined();
  });
});

// ══════════════════════════════════════
// Auth Routes — Create Review
// ══════════════════════════════════════
describe('POST /api/reviews', () => {
  it('should reject unauthenticated', async () => {
    const res = await request(app)
      .post('/api/reviews')
      .send({ product_id: 'prod-1', rating: 5 });

    expect(res.status).toBe(401);
  });

  it('should create review', async () => {
    const res = await request(app)
      .post('/api/reviews')
      .set('Authorization', `Bearer ${token}`)
      .send({
        product_id: 'prod-1',
        rating: 5,
        title: 'Excelente',
        comment: 'Muy buen producto',
      });

    expect(res.status).toBe(201);
    expect(res.body.data.rating).toBe(5);
    expect(res.body.data.title).toBe('Excelente');
    expect(res.body.data.product_id).toBe('prod-1');
    expect(res.body.message).toBe('Reseña creada exitosamente');
  });

  it('should reject duplicate review for same product', async () => {
    const res = await request(app)
      .post('/api/reviews')
      .set('Authorization', `Bearer ${token}`)
      .send({ product_id: 'prod-1', rating: 3 });

    expect(res.status).toBe(409);
  });

  it('should allow different user to review same product', async () => {
    const res = await request(app)
      .post('/api/reviews')
      .set('Authorization', `Bearer ${otherToken}`)
      .send({ product_id: 'prod-1', rating: 3, comment: 'Regular' });

    expect(res.status).toBe(201);
  });

  it('should reject missing product_id', async () => {
    const res = await request(app)
      .post('/api/reviews')
      .set('Authorization', `Bearer ${token}`)
      .send({ rating: 5 });

    expect(res.status).toBe(400);
  });

  it('should reject rating out of range', async () => {
    const res = await request(app)
      .post('/api/reviews')
      .set('Authorization', `Bearer ${token}`)
      .send({ product_id: 'prod-2', rating: 6 });

    expect(res.status).toBe(400);
  });

  it('should reject rating below 1', async () => {
    const res = await request(app)
      .post('/api/reviews')
      .set('Authorization', `Bearer ${token}`)
      .send({ product_id: 'prod-2', rating: 0 });

    expect(res.status).toBe(400);
  });
});

// ══════════════════════════════════════
// Public Routes — After data created
// ══════════════════════════════════════
describe('GET /api/reviews/product/:productId (with data)', () => {
  it('should return reviews with avg rating', async () => {
    const res = await request(app).get('/api/reviews/product/prod-1');

    expect(res.status).toBe(200);
    expect(res.body.data.reviews.length).toBe(2);
    expect(res.body.data.avgRating).toBe(4); // (5+3)/2
    expect(res.body.data.totalReviews).toBe(2);
  });

  it('should support pagination', async () => {
    const res = await request(app).get('/api/reviews/product/prod-1?page=1&limit=1');

    expect(res.status).toBe(200);
    expect(res.body.data.reviews.length).toBe(1);
    expect(res.body.pagination.pages).toBe(2);
  });

  it('should support sorting by rating_asc', async () => {
    const res = await request(app).get('/api/reviews/product/prod-1?sort_by=rating_asc');

    expect(res.status).toBe(200);
    expect(res.body.data.reviews[0].rating).toBe(3);
  });

  it('should support sorting by rating_desc', async () => {
    const res = await request(app).get('/api/reviews/product/prod-1?sort_by=rating_desc');

    expect(res.status).toBe(200);
    expect(res.body.data.reviews[0].rating).toBe(5);
  });
});

describe('GET /api/reviews/product/:productId/summary (with data)', () => {
  it('should return correct summary and distribution', async () => {
    const res = await request(app).get('/api/reviews/product/prod-1/summary');

    expect(res.status).toBe(200);
    expect(res.body.data.avgRating).toBe(4);
    expect(res.body.data.total).toBe(2);
    expect(res.body.data.distribution['5']).toBe(1);
    expect(res.body.data.distribution['3']).toBe(1);
    expect(res.body.data.distribution['1']).toBe(0);
  });
});

// ══════════════════════════════════════
// Auth Routes — My Reviews
// ══════════════════════════════════════
describe('GET /api/reviews/me', () => {
  it('should reject unauthenticated', async () => {
    const res = await request(app).get('/api/reviews/me');
    expect(res.status).toBe(401);
  });

  it('should return my reviews', async () => {
    const res = await request(app)
      .get('/api/reviews/me')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.data.length).toBe(1);
    expect(res.body.data[0].user_id).toBe('user-1');
  });
});

// ══════════════════════════════════════
// Auth Routes — Update Review
// ══════════════════════════════════════
describe('PUT /api/reviews/:id', () => {
  let reviewId;

  beforeAll(async () => {
    const res = await request(app)
      .get('/api/reviews/me')
      .set('Authorization', `Bearer ${token}`);
    reviewId = res.body.data[0].id;
  });

  it('should update review rating', async () => {
    const res = await request(app)
      .put(`/api/reviews/${reviewId}`)
      .set('Authorization', `Bearer ${token}`)
      .send({ rating: 4, comment: 'Updated comment' });

    expect(res.status).toBe(200);
    expect(res.body.data.rating).toBe(4);
    expect(res.body.data.comment).toBe('Updated comment');
  });

  it('should not allow other user to update', async () => {
    const res = await request(app)
      .put(`/api/reviews/${reviewId}`)
      .set('Authorization', `Bearer ${otherToken}`)
      .send({ rating: 1 });

    expect(res.status).toBe(404);
  });

  it('should return 404 for non-existent review', async () => {
    const res = await request(app)
      .put('/api/reviews/non-existent-id')
      .set('Authorization', `Bearer ${token}`)
      .send({ rating: 3 });

    expect(res.status).toBe(404);
  });
});

// ══════════════════════════════════════
// Auth Routes — Delete Review
// ══════════════════════════════════════
describe('DELETE /api/reviews/:id', () => {
  let otherReviewId;

  beforeAll(async () => {
    const res = await request(app)
      .get('/api/reviews/me')
      .set('Authorization', `Bearer ${otherToken}`);
    otherReviewId = res.body.data[0].id;
  });

  it('should not allow other user to delete', async () => {
    const res = await request(app)
      .delete(`/api/reviews/${otherReviewId}`)
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(403);
  });

  it('should delete own review', async () => {
    const res = await request(app)
      .delete(`/api/reviews/${otherReviewId}`)
      .set('Authorization', `Bearer ${otherToken}`);

    expect(res.status).toBe(200);
    expect(res.body.message).toBe('Reseña eliminada exitosamente');
  });

  it('should return 404 for already deleted', async () => {
    const res = await request(app)
      .delete(`/api/reviews/${otherReviewId}`)
      .set('Authorization', `Bearer ${otherToken}`);

    expect(res.status).toBe(404);
  });
});

// ══════════════════════════════════════
// Admin Routes — List all reviews
// ══════════════════════════════════════
describe('GET /api/reviews (admin)', () => {
  it('should reject non-admin', async () => {
    const res = await request(app)
      .get('/api/reviews')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(403);
  });

  it('should list all reviews for admin', async () => {
    const res = await request(app)
      .get('/api/reviews')
      .set('Authorization', `Bearer ${adminToken}`);

    expect(res.status).toBe(200);
    expect(res.body.data).toBeDefined();
    expect(res.body.pagination).toBeDefined();
  });

  it('should support filtering by product_id', async () => {
    const res = await request(app)
      .get('/api/reviews?product_id=prod-1')
      .set('Authorization', `Bearer ${adminToken}`);

    expect(res.status).toBe(200);
    expect(res.body.data.every(r => r.product_id === 'prod-1')).toBe(true);
  });
});

// ══════════════════════════════════════
// Admin Routes — Approve/Reject
// ══════════════════════════════════════
describe('PATCH /api/reviews/:id/approve (admin)', () => {
  let reviewId;

  beforeAll(async () => {
    const res = await request(app)
      .get('/api/reviews')
      .set('Authorization', `Bearer ${adminToken}`);
    reviewId = res.body.data[0].id;
  });

  it('should reject non-admin', async () => {
    const res = await request(app)
      .patch(`/api/reviews/${reviewId}/approve`)
      .set('Authorization', `Bearer ${token}`)
      .send({ is_approved: 0 });

    expect(res.status).toBe(403);
  });

  it('should reject review (is_approved = 0)', async () => {
    const res = await request(app)
      .patch(`/api/reviews/${reviewId}/approve`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ is_approved: 0 });

    expect(res.status).toBe(200);
    expect(res.body.message).toBe('Reseña rechazada');
    expect(res.body.data.is_approved).toBe(0);
  });

  it('rejected review should not appear in public listing', async () => {
    const res = await request(app).get('/api/reviews/product/prod-1');

    expect(res.status).toBe(200);
    expect(res.body.data.reviews.length).toBe(0);
  });

  it('should approve review', async () => {
    const res = await request(app)
      .patch(`/api/reviews/${reviewId}/approve`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ is_approved: 1 });

    expect(res.status).toBe(200);
    expect(res.body.message).toBe('Reseña aprobada');
    expect(res.body.data.is_approved).toBe(1);
  });

  it('should return 404 for non-existent review', async () => {
    const res = await request(app)
      .patch('/api/reviews/non-existent/approve')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ is_approved: 1 });

    expect(res.status).toBe(404);
  });

  it('approved review should appear in public listing', async () => {
    const res = await request(app).get('/api/reviews/product/prod-1');

    expect(res.status).toBe(200);
    expect(res.body.data.reviews.length).toBe(1);
  });
});
