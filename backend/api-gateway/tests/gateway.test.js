/**
 * API Gateway — Integration Tests
 * Tests: health, proxy routing, CORS, errors
 */
const request = require('supertest');

const GATEWAY_URL = process.env.GATEWAY_URL || 'http://localhost:3000';

describe('GET /health', () => {
  it('should return gateway status', async () => {
    const res = await request(GATEWAY_URL)
      .get('/health');

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('service', 'api-gateway');
    expect(res.body).toHaveProperty('status', 'running');
  });
});

describe('GET /api/products (proxy)', () => {
  it('should proxy to products-service', async () => {
    const res = await request(GATEWAY_URL)
      .get('/api/products');

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('products');
  });
});

describe('POST /api/auth/login (proxy)', () => {
  it('should proxy to auth-service', async () => {
    const res = await request(GATEWAY_URL)
      .post('/api/auth/login')
      .send({
        email: 'admin@baseshop.com',
        password: 'Admin123!'
      });

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('token');
  });

  it('should return 401 for invalid credentials', async () => {
    const res = await request(GATEWAY_URL)
      .post('/api/auth/login')
      .send({
        email: 'invalid@test.com',
        password: 'wrongpass'
      });

    expect(res.status).toBe(401);
  });
});

describe('GET /api/users (proxy)', () => {
  it('should proxy to users-service with auth', async () => {
    const loginRes = await request(GATEWAY_URL)
      .post('/api/auth/login')
      .send({ email: 'admin@baseshop.com', password: 'Admin123!' });
    
    const token = loginRes.body.token;

    const res = await request(GATEWAY_URL)
      .get('/api/users')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
  });
});

describe('CORS', () => {
  it('should allow localhost:8080 origin', async () => {
    const res = await request(GATEWAY_URL)
      .get('/api/products')
      .set('Origin', 'http://localhost:8080');

    expect(res.headers).toHaveProperty('access-control-allow-origin', 'http://localhost:8080');
  });

  it('should allow credentials', async () => {
    const res = await request(GATEWAY_URL)
      .get('/api/products')
      .set('Origin', 'http://localhost:8080');

    expect(res.headers).toHaveProperty('access-control-allow-credentials', 'true');
  });
});

describe('404 - Unmatched routes', () => {
  it('should return 404 for non-existent route', async () => {
    const res = await request(GATEWAY_URL)
      .get('/api/non-existent-route');

    expect(res.status).toBe(404);
    expect(res.body).toHaveProperty('error');
  });
});

describe('Rate Limiting', () => {
  it('should have rate limit headers', async () => {
    const res = await request(GATEWAY_URL)
      .get('/api/products');

    expect(res.headers).toHaveProperty('ratelimit-limit');
    expect(res.headers).toHaveProperty('ratelimit-remaining');
  });
});
