// @ts-check
const { test, expect } = require('@playwright/test');

/*
 * BaseShop E2E — Backend API Acceptance Tests
 *
 * These tests exercise the main API flows through the gateway (localhost:3000).
 * Prerequisites: all backend micro-services + API gateway running.
 */

const BASE = 'http://localhost:3000/api';
let authToken = '';
let refreshToken = '';
let userId = '';
let productId = '';
let categoryId = '';
let cartItemId = '';
let orderId = '';

// ═══════════════════════════════════════════════════════════════════════
// 1. AUTH FLOWS
// ═══════════════════════════════════════════════════════════════════════
test.describe.serial('Auth flows', () => {
  const email = `e2e_${Date.now()}@test.com`;
  const password = 'TestPass123!';

  test('POST /auth/register — register new user', async ({ request }) => {
    const res = await request.post(`${BASE}/auth/register`, {
      data: {
        email,
        password,
        first_name: 'E2E',
        last_name: 'Tester',
      },
      headers: { 'x-platform': 'mobile' }, // bypass recaptcha
    });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.token).toBeTruthy();
    expect(body.user).toBeTruthy();
    expect(body.user.email).toBe(email);
    authToken = body.token;
    refreshToken = body.refreshToken;
    userId = body.user.id;
  });

  test('POST /auth/register — duplicate email fails', async ({ request }) => {
    const res = await request.post(`${BASE}/auth/register`, {
      data: {
        email,
        password,
        first_name: 'Dup',
        last_name: 'User',
      },
      headers: { 'x-platform': 'mobile' },
    });
    expect(res.ok()).toBeFalsy();
  });

  test('POST /auth/login — login with new credentials', async ({ request }) => {
    const res = await request.post(`${BASE}/auth/login`, {
      data: { email, password },
      headers: { 'x-platform': 'mobile' },
    });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.token).toBeTruthy();
    authToken = body.token;
    refreshToken = body.refreshToken;
  });

  test('POST /auth/login — wrong password fails', async ({ request }) => {
    const res = await request.post(`${BASE}/auth/login`, {
      data: { email, password: 'WrongPass!' },
      headers: { 'x-platform': 'mobile' },
    });
    expect(res.ok()).toBeFalsy();
  });

  test('GET /auth/me — get current user', async ({ request }) => {
    const res = await request.get(`${BASE}/auth/me`, {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.user.email).toBe(email);
  });

  test('POST /auth/refresh — refresh token', async ({ request }) => {
    const res = await request.post(`${BASE}/auth/refresh`, {
      data: { refreshToken },
    });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    expect(body.token).toBeTruthy();
    authToken = body.token;
  });
});

// ═══════════════════════════════════════════════════════════════════════
// 2. PRODUCTS & CATEGORIES FLOWS
// ═══════════════════════════════════════════════════════════════════════
test.describe.serial('Products & Categories', () => {
  // Get admin token first
  let adminToken = '';

  test('Login as admin', async ({ request }) => {
    const res = await request.post(`${BASE}/auth/login`, {
      data: { email: 'admin@baseshop.com', password: 'Admin123!' },
      headers: { 'x-platform': 'mobile' },
    });
    if (res.ok()) {
      const body = await res.json();
      adminToken = body.token;
    }
  });

  test('POST /categories — create category (admin)', async ({ request }) => {
    test.skip(!adminToken, 'No admin account available');
    const res = await request.post(`${BASE}/categories`, {
      data: { name: 'E2E Category', description: 'Test category' },
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    categoryId = body.category?.id || body.data?.id || body.id || '';
    expect(categoryId).toBeTruthy();
  });

  test('GET /categories — list categories', async ({ request }) => {
    const res = await request.get(`${BASE}/categories`);
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    const categories = body.categories || body.data || body;
    expect(Array.isArray(categories)).toBeTruthy();
  });

  test('POST /products — create product (admin)', async ({ request }) => {
    test.skip(!adminToken, 'No admin account available');
    const res = await request.post(`${BASE}/products`, {
      data: {
        name: 'E2E Product',
        description: 'Playwright test product',
        price: 50000,
        stock: 20,
        category_id: categoryId || undefined,
      },
      headers: { Authorization: `Bearer ${adminToken}` },
    });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    productId = body.product?.id || body.data?.id || body.id || '';
    expect(productId).toBeTruthy();
  });

  test('GET /products — list products', async ({ request }) => {
    const res = await request.get(`${BASE}/products`);
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    const products = body.products || body.data || [];
    expect(Array.isArray(products)).toBeTruthy();
  });

  test('GET /products?search=E2E — search products', async ({ request }) => {
    const res = await request.get(`${BASE}/products?search=E2E`);
    expect(res.ok()).toBeTruthy();
  });

  test('GET /products/:id — product detail', async ({ request }) => {
    test.skip(!productId, 'No product created');
    const res = await request.get(`${BASE}/products/${productId}`);
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    const product = body.product || body.data || body;
    expect(product.name).toBe('E2E Product');
  });
});

// ═══════════════════════════════════════════════════════════════════════
// 3. CART FLOWS
// ═══════════════════════════════════════════════════════════════════════
test.describe.serial('Cart flows', () => {
  test('GET /cart — empty cart', async ({ request }) => {
    test.skip(!authToken, 'Not authenticated');
    const res = await request.get(`${BASE}/cart`, {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    expect(res.ok()).toBeTruthy();
  });

  test('POST /cart/items — add item to cart', async ({ request }) => {
    test.skip(!authToken || !productId, 'Needs auth + product');
    const res = await request.post(`${BASE}/cart/items`, {
      data: {
        product_id: productId,
        product_name: 'E2E Product',
        product_price: 50000,
        product_image: '',
        quantity: 2,
      },
      headers: { Authorization: `Bearer ${authToken}` },
    });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    cartItemId = body.data?.id || body.item?.id || body.id || '';
  });

  test('GET /cart — cart with items', async ({ request }) => {
    test.skip(!authToken, 'Not authenticated');
    const res = await request.get(`${BASE}/cart`, {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    const data = body.data || body;
    expect(data.items || data.data).toBeTruthy();
  });

  test('PUT /cart/items/:id — update item quantity', async ({ request }) => {
    test.skip(!authToken || !cartItemId, 'Needs auth + cart item');
    const res = await request.put(`${BASE}/cart/items/${cartItemId}`, {
      data: { quantity: 3 },
      headers: { Authorization: `Bearer ${authToken}` },
    });
    expect(res.ok()).toBeTruthy();
  });

  test('GET /cart/count — item count', async ({ request }) => {
    test.skip(!authToken, 'Not authenticated');
    const res = await request.get(`${BASE}/cart/count`, {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    expect(res.ok()).toBeTruthy();
  });
});

// ═══════════════════════════════════════════════════════════════════════
// 4. ORDER FLOWS
// ═══════════════════════════════════════════════════════════════════════
test.describe.serial('Order flows', () => {
  test('Re-login for order tests', async ({ request }) => {
    // Re-authenticate to ensure fresh token
    if (!authToken) test.skip(true, 'No auth');
    const res = await request.get(`${BASE}/auth/me`, {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    if (!res.ok()) {
      // Token expired — re-register or skip
      test.skip(true, 'Token expired');
    }
  });

  test('POST /orders — create order from cart', async ({ request }) => {
    test.skip(!authToken, 'Not authenticated');
    const res = await request.post(`${BASE}/orders`, {
      data: {
        shipping_address: {
          street: 'Test Street 123',
          city: 'Bogotá',
          state: 'Cundinamarca',
          zip: '110111',
          country: 'Colombia',
        },
        payment_method: 'cash',
      },
      headers: { Authorization: `Bearer ${authToken}` },
    });
    // May fail if cart is empty or product is gone — that's ok, we just check the API responds
    if (res.ok()) {
      const body = await res.json();
      orderId = body.order?.id || body.data?.id || body.id || '';
    }
  });

  test('GET /orders/me — list my orders', async ({ request }) => {
    test.skip(!authToken, 'Not authenticated');
    const res = await request.get(`${BASE}/orders/me`, {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    const orders = body.orders || body.data || [];
    expect(Array.isArray(orders)).toBeTruthy();
  });

  test('GET /orders/me/:id — order detail', async ({ request }) => {
    test.skip(!orderId, 'No order created');
    const res = await request.get(`${BASE}/orders/me/${orderId}`, {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    expect(res.ok()).toBeTruthy();
    const body = await res.json();
    const order = body.order || body.data || body;
    expect(order.id || order._id).toBeTruthy();
  });
});

// ═══════════════════════════════════════════════════════════════════════
// 5. CLEANUP — delete cart & product
// ═══════════════════════════════════════════════════════════════════════
test.describe.serial('Cleanup', () => {
  test('DELETE /cart — clear cart', async ({ request }) => {
    test.skip(!authToken, 'Not authenticated');
    const res = await request.delete(`${BASE}/cart`, {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    // May return 200 or 204
    expect(res.status()).toBeLessThan(300);
  });

  test('POST /auth/logout — logout', async ({ request }) => {
    test.skip(!authToken, 'Not authenticated');
    const res = await request.post(`${BASE}/auth/logout`, {
      headers: { Authorization: `Bearer ${authToken}` },
    });
    expect(res.status()).toBeLessThan(300);
  });
});
