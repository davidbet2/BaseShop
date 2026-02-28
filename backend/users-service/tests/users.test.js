/**
 * Users Service — Unit Tests
 * Tests: profile CRUD, address CRUD, admin user management, device tokens
 */
const request = require('supertest');
const express = require('express');
const jwt = require('jsonwebtoken');

const JWT_SECRET = 'test-secret-key';
process.env.JWT_SECRET = JWT_SECRET;
process.env.DB_PATH = ':memory:';

let app;

// Use valid UUIDs since admin routes validate :id with isUUID()
const USER_1 = '11111111-1111-4111-a111-111111111111';
const USER_2 = '22222222-2222-4222-a222-222222222222';
const ADMIN_1 = '44444444-4444-4444-a444-444444444444';

function makeToken(userId = USER_1, role = 'client', email = 'test@example.com') {
  return jwt.sign({ id: userId, email, role }, JWT_SECRET, { expiresIn: '1h' });
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

  const usersRoutes = require('../src/routes/users.routes');
  app.use('/api/users', usersRoutes);
});

afterAll(() => {
  const { close } = require('../src/database');
  close();
});

const token = makeToken(USER_1);
const otherToken = makeToken(USER_2);
const adminToken = makeToken(ADMIN_1, 'admin', 'admin@example.com');

// ══════════════════════════════════════
// Authentication
// ══════════════════════════════════════
describe('Users Authentication', () => {
  it('should reject unauthenticated access', async () => {
    const res = await request(app).get('/api/users/me/profile');
    expect(res.status).toBe(401);
  });

  it('should reject invalid token', async () => {
    const res = await request(app)
      .get('/api/users/me/profile')
      .set('Authorization', 'Bearer invalid-token');
    expect(res.status).toBe(401);
  });
});

// ══════════════════════════════════════
// Profile — GET /me/profile
// ══════════════════════════════════════
describe('GET /api/users/me/profile', () => {
  it('should create and return empty profile for new user', async () => {
    const res = await request(app)
      .get('/api/users/me/profile')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.profile).toBeDefined();
    expect(res.body.profile.user_id).toBe(USER_1);
    expect(res.body.profile.first_name).toBe('');
    expect(res.body.profile.country).toBe('Colombia');
  });

  it('should return existing profile on second call', async () => {
    const res = await request(app)
      .get('/api/users/me/profile')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.profile.user_id).toBe(USER_1);
  });
});

// ══════════════════════════════════════
// Profile — PUT /me/profile
// ══════════════════════════════════════
describe('PUT /api/users/me/profile', () => {
  it('should update profile fields', async () => {
    const res = await request(app)
      .put('/api/users/me/profile')
      .set('Authorization', `Bearer ${token}`)
      .send({
        first_name: 'John',
        last_name: 'Doe',
        phone: '3001234567',
        city: 'Bogotá',
      });

    expect(res.status).toBe(200);
    expect(res.body.profile.first_name).toBe('John');
    expect(res.body.profile.last_name).toBe('Doe');
    expect(res.body.profile.phone).toBe('3001234567');
    expect(res.body.profile.city).toBe('Bogotá');
    expect(res.body.message).toBe('Perfil actualizado exitosamente');
  });

  it('should reject when no fields provided', async () => {
    const res = await request(app)
      .put('/api/users/me/profile')
      .set('Authorization', `Bearer ${token}`)
      .send({});

    expect(res.status).toBe(400);
  });

  it('should create profile on update if not exists', async () => {
    const newUserToken = makeToken('33333333-3333-4333-a333-333333333333');
    const res = await request(app)
      .put('/api/users/me/profile')
      .set('Authorization', `Bearer ${newUserToken}`)
      .send({ first_name: 'New User' });

    expect(res.status).toBe(200);
    expect(res.body.profile.first_name).toBe('New User');
  });
});

// ══════════════════════════════════════
// Addresses — GET /me/addresses
// ══════════════════════════════════════
describe('GET /api/users/me/addresses', () => {
  it('should return empty addresses for new user', async () => {
    const res = await request(app)
      .get('/api/users/me/addresses')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.addresses).toEqual([]);
  });
});

// ══════════════════════════════════════
// Addresses — POST /me/addresses
// ══════════════════════════════════════
describe('POST /api/users/me/addresses', () => {
  it('should add first address as default', async () => {
    const res = await request(app)
      .post('/api/users/me/addresses')
      .set('Authorization', `Bearer ${token}`)
      .send({
        label: 'Casa',
        address: 'Calle 123 #45-67',
        city: 'Bogotá',
        state: 'Cundinamarca',
        zip_code: '110111',
      });

    expect(res.status).toBe(201);
    expect(res.body.address.label).toBe('Casa');
    expect(res.body.address.is_default).toBe(1);
    expect(res.body.address.country).toBe('Colombia');
  });

  it('should add second address as non-default', async () => {
    const res = await request(app)
      .post('/api/users/me/addresses')
      .set('Authorization', `Bearer ${token}`)
      .send({
        label: 'Oficina',
        address: 'Carrera 7 #22-33',
        city: 'Medellín',
      });

    expect(res.status).toBe(201);
    expect(res.body.address.is_default).toBe(0);
  });

  it('should reject missing address field', async () => {
    const res = await request(app)
      .post('/api/users/me/addresses')
      .set('Authorization', `Bearer ${token}`)
      .send({ label: 'Without address', city: 'Bogotá' });

    expect(res.status).toBe(400);
  });

  it('should reject missing city field', async () => {
    const res = await request(app)
      .post('/api/users/me/addresses')
      .set('Authorization', `Bearer ${token}`)
      .send({ address: 'My address' });

    expect(res.status).toBe(400);
  });

  it('should set new address as default when is_default is true', async () => {
    const res = await request(app)
      .post('/api/users/me/addresses')
      .set('Authorization', `Bearer ${token}`)
      .send({
        label: 'Nueva Default',
        address: 'Calle nueva',
        city: 'Cali',
        is_default: true,
      });

    expect(res.status).toBe(201);
    expect(res.body.address.is_default).toBe(1);

    // Verify previous addresses lost default
    const listRes = await request(app)
      .get('/api/users/me/addresses')
      .set('Authorization', `Bearer ${token}`);
    const defaults = listRes.body.addresses.filter(a => a.is_default === 1);
    expect(defaults.length).toBe(1);
    expect(defaults[0].label).toBe('Nueva Default');
  });
});

// ══════════════════════════════════════
// Addresses — PUT /me/addresses/:id
// ══════════════════════════════════════
describe('PUT /api/users/me/addresses/:id', () => {
  let addressId;

  beforeAll(async () => {
    const res = await request(app)
      .get('/api/users/me/addresses')
      .set('Authorization', `Bearer ${token}`);
    addressId = res.body.addresses[0].id;
  });

  it('should update address', async () => {
    const res = await request(app)
      .put(`/api/users/me/addresses/${addressId}`)
      .set('Authorization', `Bearer ${token}`)
      .send({ city: 'Barranquilla' });

    expect(res.status).toBe(200);
    expect(res.body.address.city).toBe('Barranquilla');
  });

  it('should return 404 for non-existent address', async () => {
    const fakeId = '00000000-0000-0000-0000-000000000000';
    const res = await request(app)
      .put(`/api/users/me/addresses/${fakeId}`)
      .set('Authorization', `Bearer ${token}`)
      .send({ city: 'Test' });

    expect(res.status).toBe(404);
  });

  it('should not allow other user to update', async () => {
    const res = await request(app)
      .put(`/api/users/me/addresses/${addressId}`)
      .set('Authorization', `Bearer ${otherToken}`)
      .send({ city: 'Hijacked' });

    expect(res.status).toBe(404);
  });

  it('should reject invalid UUID', async () => {
    const res = await request(app)
      .put('/api/users/me/addresses/not-a-uuid')
      .set('Authorization', `Bearer ${token}`)
      .send({ city: 'Test' });

    expect(res.status).toBe(400);
  });
});

// ══════════════════════════════════════
// Addresses — DELETE /me/addresses/:id
// ══════════════════════════════════════
describe('DELETE /api/users/me/addresses/:id', () => {
  let addressId;

  beforeAll(async () => {
    // Add a fresh address to delete
    const addRes = await request(app)
      .post('/api/users/me/addresses')
      .set('Authorization', `Bearer ${token}`)
      .send({ label: 'ToDelete', address: 'Temp', city: 'Temp' });
    addressId = addRes.body.address.id;
  });

  it('should delete address', async () => {
    const res = await request(app)
      .delete(`/api/users/me/addresses/${addressId}`)
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.message).toBe('Dirección eliminada exitosamente');
  });

  it('should return 404 for already deleted', async () => {
    const res = await request(app)
      .delete(`/api/users/me/addresses/${addressId}`)
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(404);
  });

  it('should reassign default when deleting default address', async () => {
    // Make a default address
    const addr1 = await request(app)
      .post('/api/users/me/addresses')
      .set('Authorization', `Bearer ${otherToken}`)
      .send({ address: 'First', city: 'City1' });
    
    const addr2 = await request(app)
      .post('/api/users/me/addresses')
      .set('Authorization', `Bearer ${otherToken}`)
      .send({ address: 'Second', city: 'City2' });

    // addr1 should be default (first address)
    expect(addr1.body.address.is_default).toBe(1);

    // Delete the default
    await request(app)
      .delete(`/api/users/me/addresses/${addr1.body.address.id}`)
      .set('Authorization', `Bearer ${otherToken}`);

    // Remaining address should become default
    const listRes = await request(app)
      .get('/api/users/me/addresses')
      .set('Authorization', `Bearer ${otherToken}`);

    const defaults = listRes.body.addresses.filter(a => a.is_default === 1);
    expect(defaults.length).toBe(1);
  });
});

// ══════════════════════════════════════
// Admin — GET /api/users (list)
// ══════════════════════════════════════
describe('GET /api/users (admin)', () => {
  it('should reject non-admin access', async () => {
    const res = await request(app)
      .get('/api/users')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(403);
  });

  it('should list users for admin', async () => {
    const res = await request(app)
      .get('/api/users')
      .set('Authorization', `Bearer ${adminToken}`);

    expect(res.status).toBe(200);
    expect(res.body.users).toBeDefined();
    expect(res.body.pagination).toBeDefined();
    expect(res.body.pagination.page).toBe(1);
  });

  it('should support pagination', async () => {
    const res = await request(app)
      .get('/api/users?page=1&limit=1')
      .set('Authorization', `Bearer ${adminToken}`);

    expect(res.status).toBe(200);
    expect(res.body.pagination.limit).toBe(1);
  });

  it('should support search', async () => {
    const res = await request(app)
      .get('/api/users?search=John')
      .set('Authorization', `Bearer ${adminToken}`);

    expect(res.status).toBe(200);
    // Our user-1 has first_name John
    expect(res.body.users.length).toBeGreaterThanOrEqual(1);
  });
});

// ══════════════════════════════════════
// Admin — GET /api/users/:id
// ══════════════════════════════════════
describe('GET /api/users/:id (admin)', () => {
  it('should reject non-admin access', async () => {
    const res = await request(app)
      .get(`/api/users/${USER_1}`)
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(403);
  });

  it('should return user profile and addresses', async () => {
    const res = await request(app)
      .get(`/api/users/${USER_1}`)
      .set('Authorization', `Bearer ${adminToken}`);

    expect(res.status).toBe(200);
    expect(res.body.profile).toBeDefined();
    expect(res.body.profile.user_id).toBe(USER_1);
    expect(res.body.addresses).toBeDefined();
    expect(Array.isArray(res.body.addresses)).toBe(true);
  });

  it('should return 404 for non-existent user', async () => {
    const fakeId = '00000000-0000-0000-0000-000000000000';
    const res = await request(app)
      .get(`/api/users/${fakeId}`)
      .set('Authorization', `Bearer ${adminToken}`);

    expect(res.status).toBe(404);
  });
});

// ══════════════════════════════════════
// Admin — PATCH /api/users/:id/status
// ══════════════════════════════════════
describe('PATCH /api/users/:id/status (admin)', () => {
  it('should reject non-admin access', async () => {
    const res = await request(app)
      .patch(`/api/users/${USER_1}/status`)
      .set('Authorization', `Bearer ${token}`)
      .send({ is_active: false });

    expect(res.status).toBe(403);
  });

  it('should activate user', async () => {
    const res = await request(app)
      .patch(`/api/users/${USER_1}/status`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ is_active: true });

    expect(res.status).toBe(200);
    expect(res.body.message).toBe('Usuario activado');
    expect(res.body.is_active).toBe(true);
  });

  it('should deactivate user', async () => {
    const res = await request(app)
      .patch(`/api/users/${USER_1}/status`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ is_active: false });

    expect(res.status).toBe(200);
    expect(res.body.message).toBe('Usuario desactivado');
    expect(res.body.is_active).toBe(false);
  });

  it('should return 404 for non-existent user', async () => {
    const fakeId = '00000000-0000-0000-0000-000000000000';
    const res = await request(app)
      .patch(`/api/users/${fakeId}/status`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ is_active: true });

    expect(res.status).toBe(404);
  });
});

// ══════════════════════════════════════
// Device Tokens — POST /device-tokens
// ══════════════════════════════════════
describe('POST /api/users/device-tokens', () => {
  it('should register device token', async () => {
    const res = await request(app)
      .post('/api/users/device-tokens')
      .set('Authorization', `Bearer ${token}`)
      .send({ token: 'fcm-token-12345', platform: 'android' });

    expect(res.status).toBe(201);
    expect(res.body.message).toBe('Token de dispositivo registrado');
  });

  it('should update existing token', async () => {
    const res = await request(app)
      .post('/api/users/device-tokens')
      .set('Authorization', `Bearer ${token}`)
      .send({ token: 'fcm-token-12345', platform: 'web' });

    expect(res.status).toBe(200);
    expect(res.body.message).toBe('Token de dispositivo actualizado');
  });

  it('should reject missing token', async () => {
    const res = await request(app)
      .post('/api/users/device-tokens')
      .set('Authorization', `Bearer ${token}`)
      .send({ platform: 'android' });

    expect(res.status).toBe(400);
  });

  it('should reject invalid platform', async () => {
    const res = await request(app)
      .post('/api/users/device-tokens')
      .set('Authorization', `Bearer ${token}`)
      .send({ token: 'new-token', platform: 'invalid' });

    expect(res.status).toBe(400);
  });
});

// ══════════════════════════════════════
// Device Tokens — DELETE /device-tokens
// ══════════════════════════════════════
describe('DELETE /api/users/device-tokens', () => {
  beforeAll(async () => {
    // Ensure token exists before trying to delete
    await request(app)
      .post('/api/users/device-tokens')
      .set('Authorization', `Bearer ${token}`)
      .send({ token: 'fcm-delete-test', platform: 'android' });
  });

  it('should delete device token', async () => {
    const res = await request(app)
      .delete('/api/users/device-tokens')
      .set('Authorization', `Bearer ${token}`)
      .send({ token: 'fcm-delete-test' });

    expect(res.status).toBe(200);
    expect(res.body.message).toBe('Token de dispositivo eliminado');
  });

  it('should return 404 for non-existent token', async () => {
    const res = await request(app)
      .delete('/api/users/device-tokens')
      .set('Authorization', `Bearer ${token}`)
      .send({ token: 'non-existent-token' });

    expect(res.status).toBe(404);
  });

  it('should reject missing token in body', async () => {
    const res = await request(app)
      .delete('/api/users/device-tokens')
      .set('Authorization', `Bearer ${token}`)
      .send({});

    expect(res.status).toBe(400);
  });
});

// ══════════════════════════════════════
// User Isolation
// ══════════════════════════════════════
describe('User Isolation', () => {
  it('should not show other user addresses', async () => {
    const user3Token = makeToken('55555555-5555-4555-a555-555555555555');
    const res = await request(app)
      .get('/api/users/me/addresses')
      .set('Authorization', `Bearer ${user3Token}`);

    expect(res.body.addresses).toEqual([]);
  });

  it('should not show other user profile', async () => {
    const user3Token = makeToken('55555555-5555-4555-a555-555555555555');
    const res = await request(app)
      .get('/api/users/me/profile')
      .set('Authorization', `Bearer ${user3Token}`);

    // Should get a new empty profile
    expect(res.body.profile.first_name).toBe('');
  });
});
