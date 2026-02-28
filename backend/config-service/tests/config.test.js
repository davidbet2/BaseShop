/**
 * Config Service — Unit Tests
 * Tests: public GET config, admin PUT update (store_name, colors, support fields, banners)
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

  const { configRouter } = require('../src/routes/config.routes');
  app.use('/api/config', configRouter);
});

afterAll(() => {
  const { close } = require('../src/database');
  close();
});

const clientToken = makeToken('user-1', 'client');
const adminToken = makeToken('admin-1', 'admin');

// ══════════════════════════════════════
// GET /api/config — Public (no auth required)
// ══════════════════════════════════════
describe('GET /api/config', () => {
  it('should return config without authentication', async () => {
    const res = await request(app).get('/api/config');

    expect(res.status).toBe(200);
    expect(res.body.store_name).toBe('BaseShop');
    expect(res.body.primary_color_hex).toBe('F97316');
    expect(res.body.show_header).toBe(true);
    expect(res.body.show_footer).toBe(true);
    expect(res.body.featured_title).toBe('Colección destacada');
  });

  it('should return banners array (empty initially)', async () => {
    const res = await request(app).get('/api/config');

    expect(res.status).toBe(200);
    expect(Array.isArray(res.body.banners)).toBe(true);
  });

  it('should return support fields with defaults', async () => {
    const res = await request(app).get('/api/config');

    expect(res.status).toBe(200);
    expect(res.body.support_email).toBe('');
    expect(res.body.support_phone).toBe('');
    expect(res.body.support_whatsapp).toBe('');
    expect(res.body.support_schedule).toBe('');
  });
});

// ══════════════════════════════════════
// PUT /api/config — Admin update
// ══════════════════════════════════════
describe('PUT /api/config', () => {
  it('should reject unauthenticated access', async () => {
    const res = await request(app)
      .put('/api/config')
      .send({ store_name: 'Hacked' });

    expect(res.status).toBe(401);
  });

  it('should reject non-admin access', async () => {
    const res = await request(app)
      .put('/api/config')
      .set('Authorization', `Bearer ${clientToken}`)
      .send({ store_name: 'Hacked' });

    expect(res.status).toBe(403);
  });

  it('should update store name', async () => {
    const res = await request(app)
      .put('/api/config')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ store_name: 'Mi Tienda' });

    expect(res.status).toBe(200);
    expect(res.body.store_name).toBe('Mi Tienda');
    expect(res.body.message).toBe('Configuración actualizada');
  });

  it('should update primary color', async () => {
    const res = await request(app)
      .put('/api/config')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ primary_color_hex: 'FF5733' });

    expect(res.status).toBe(200);
    expect(res.body.primary_color_hex).toBe('FF5733');
  });

  it('should reject invalid color hex', async () => {
    const res = await request(app)
      .put('/api/config')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ primary_color_hex: 'ZZZZZZ' });

    expect(res.status).toBe(400);
  });

  it('should update support fields', async () => {
    const res = await request(app)
      .put('/api/config')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        support_email: 'support@tienda.com',
        support_phone: '+573001234567',
        support_whatsapp: '+573001234567',
        support_schedule: 'Lun-Vie 9:00-18:00',
      });

    expect(res.status).toBe(200);
    expect(res.body.support_email).toBe('support@tienda.com');
    expect(res.body.support_phone).toBe('+573001234567');
    expect(res.body.support_whatsapp).toBe('+573001234567');
    expect(res.body.support_schedule).toBe('Lun-Vie 9:00-18:00');
  });

  it('should update show_header and show_footer', async () => {
    const res = await request(app)
      .put('/api/config')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ show_header: false, show_footer: false });

    expect(res.status).toBe(200);
    expect(res.body.show_header).toBe(false);
    expect(res.body.show_footer).toBe(false);
  });

  it('should update featured section', async () => {
    const res = await request(app)
      .put('/api/config')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        featured_title: 'Lo más vendido',
        featured_desc: 'Nuestros productos estrella',
      });

    expect(res.status).toBe(200);
    expect(res.body.featured_title).toBe('Lo más vendido');
    expect(res.body.featured_desc).toBe('Nuestros productos estrella');
  });

  it('should update banners', async () => {
    const res = await request(app)
      .put('/api/config')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        banners: [
          { image_path: '/uploads/banner1.jpg', product_id: 'prod-1', sort_order: 0 },
          { image_path: '/uploads/banner2.jpg', custom_price: 29900, sort_order: 1 },
        ],
      });

    expect(res.status).toBe(200);
    expect(res.body.banners.length).toBe(2);
    expect(res.body.banners[0].image_path).toBe('/uploads/banner1.jpg');
    expect(res.body.banners[1].custom_price).toBe(29900);
  });

  it('should replace banners on subsequent update', async () => {
    const res = await request(app)
      .put('/api/config')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        banners: [
          { image_path: '/uploads/new-banner.jpg' },
        ],
      });

    expect(res.status).toBe(200);
    expect(res.body.banners.length).toBe(1);
    expect(res.body.banners[0].image_path).toBe('/uploads/new-banner.jpg');
  });

  it('should persist changes across GET calls', async () => {
    const res = await request(app).get('/api/config');

    expect(res.status).toBe(200);
    expect(res.body.store_name).toBe('Mi Tienda');
    expect(res.body.support_email).toBe('support@tienda.com');
    expect(res.body.banners.length).toBe(1);
  });
});
