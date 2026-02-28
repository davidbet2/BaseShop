/**
 * Orders Service — Notifications Unit Tests
 * Tests: list notifications, unread count, mark read, mark all read, delete, delete all
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

const token = makeToken('user-1');
const otherToken = makeToken('user-2');

beforeAll(async () => {
  const { initDatabase, getDb } = require('../src/database');
  await initDatabase();

  // Seed notifications directly into DB
  const db = getDb();
  const { v4: uuidv4 } = require('uuid');

  for (let i = 1; i <= 5; i++) {
    db.prepare(
      `INSERT INTO notifications (id, user_id, order_id, order_number, type, title, message, is_read) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
    ).run(
      `notif-${i}`, 'user-1', `order-${i}`, `ORD-${1000 + i}`,
      'order_status', `Pedido #ORD-${1000 + i}`,
      `Tu pedido ha cambiado de estado`,
      i <= 2 ? 1 : 0 // first 2 read, last 3 unread
    );
  }

  // One notification for user-2
  db.prepare(
    `INSERT INTO notifications (id, user_id, order_id, order_number, type, title, message) VALUES (?, ?, ?, ?, ?, ?, ?)`
  ).run('notif-other', 'user-2', 'order-x', 'ORD-9999', 'order_status', 'Pedido', 'Mensaje');

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

// ══════════════════════════════════════
// Authentication
// ══════════════════════════════════════
describe('Notifications Authentication', () => {
  it('should reject unauthenticated access', async () => {
    const res = await request(app).get('/api/orders/notifications/me');
    expect(res.status).toBe(401);
  });
});

// ══════════════════════════════════════
// GET /notifications/me — List
// ══════════════════════════════════════
describe('GET /api/orders/notifications/me', () => {
  it('should return user notifications with pagination', async () => {
    const res = await request(app)
      .get('/api/orders/notifications/me')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.data.length).toBe(5);
    expect(res.body.unread).toBe(3);
    expect(res.body.pagination).toBeDefined();
    expect(res.body.pagination.total).toBe(5);
  });

  it('should support pagination', async () => {
    const res = await request(app)
      .get('/api/orders/notifications/me?page=1&limit=2')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.data.length).toBe(2);
    expect(res.body.pagination.totalPages).toBe(3);
  });

  it('should be user-scoped', async () => {
    const res = await request(app)
      .get('/api/orders/notifications/me')
      .set('Authorization', `Bearer ${otherToken}`);

    expect(res.status).toBe(200);
    expect(res.body.data.length).toBe(1);
  });
});

// ══════════════════════════════════════
// GET /notifications/me/unread-count
// ══════════════════════════════════════
describe('GET /api/orders/notifications/me/unread-count', () => {
  it('should return unread count', async () => {
    const res = await request(app)
      .get('/api/orders/notifications/me/unread-count')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.unread).toBe(3);
  });
});

// ══════════════════════════════════════
// PATCH /notifications/me/:id/read — Mark single
// ══════════════════════════════════════
describe('PATCH /api/orders/notifications/me/:id/read', () => {
  it('should mark notification as read', async () => {
    const res = await request(app)
      .patch('/api/orders/notifications/me/notif-3/read')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.message).toBe('Notificación marcada como leída');
  });

  it('unread count should decrease', async () => {
    const res = await request(app)
      .get('/api/orders/notifications/me/unread-count')
      .set('Authorization', `Bearer ${token}`);

    expect(res.body.unread).toBe(2);
  });

  it('should return 404 for non-existent notification', async () => {
    const res = await request(app)
      .patch('/api/orders/notifications/me/non-existent/read')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(404);
  });

  it('should return 404 for other user notification', async () => {
    const res = await request(app)
      .patch('/api/orders/notifications/me/notif-other/read')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(404);
  });
});

// ══════════════════════════════════════
// PATCH /notifications/me/read-all — Mark all read
// ══════════════════════════════════════
describe('PATCH /api/orders/notifications/me/read-all', () => {
  it('should mark all notifications as read', async () => {
    const res = await request(app)
      .patch('/api/orders/notifications/me/read-all')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.message).toBe('Todas las notificaciones marcadas como leídas');
  });

  it('unread count should be zero', async () => {
    const res = await request(app)
      .get('/api/orders/notifications/me/unread-count')
      .set('Authorization', `Bearer ${token}`);

    expect(res.body.unread).toBe(0);
  });

  it('should not affect other user notifications', async () => {
    const res = await request(app)
      .get('/api/orders/notifications/me/unread-count')
      .set('Authorization', `Bearer ${otherToken}`);

    // user-2's notification was never marked read
    expect(res.body.unread).toBe(1);
  });
});

// ══════════════════════════════════════
// DELETE /notifications/me/:id — Delete single
// ══════════════════════════════════════
describe('DELETE /api/orders/notifications/me/:id', () => {
  it('should delete a notification', async () => {
    const res = await request(app)
      .delete('/api/orders/notifications/me/notif-1')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.message).toBe('Notificación eliminada');
  });

  it('should return 404 for already deleted', async () => {
    const res = await request(app)
      .delete('/api/orders/notifications/me/notif-1')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(404);
  });

  it('should return 404 for other user notification', async () => {
    const res = await request(app)
      .delete('/api/orders/notifications/me/notif-other')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(404);
  });

  it('should have fewer notifications', async () => {
    const res = await request(app)
      .get('/api/orders/notifications/me')
      .set('Authorization', `Bearer ${token}`);

    expect(res.body.data.length).toBe(4);
  });
});

// ══════════════════════════════════════
// DELETE /notifications/me — Delete all
// ══════════════════════════════════════
describe('DELETE /api/orders/notifications/me', () => {
  it('should delete all notifications', async () => {
    const res = await request(app)
      .delete('/api/orders/notifications/me')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.message).toBe('Todas las notificaciones eliminadas');
  });

  it('should have zero notifications', async () => {
    const res = await request(app)
      .get('/api/orders/notifications/me')
      .set('Authorization', `Bearer ${token}`);

    expect(res.body.data.length).toBe(0);
  });

  it('should not delete other user notifications', async () => {
    const res = await request(app)
      .get('/api/orders/notifications/me')
      .set('Authorization', `Bearer ${otherToken}`);

    expect(res.body.data.length).toBe(1);
  });
});
