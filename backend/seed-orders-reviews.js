#!/usr/bin/env node
/**
 * Seed test orders (all statuses) and reviews for the test client user.
 * Run: node backend/seed-orders-reviews.js
 */

const http = require('http');
const BASE = 'http://localhost:3000';

function request(method, path, body, headers = {}) {
  return new Promise((resolve, reject) => {
    const url = new URL(path, BASE);
    const data = body ? JSON.stringify(body) : null;
    const opts = {
      hostname: url.hostname,
      port: url.port,
      path: url.pathname + url.search,
      method,
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        ...headers,
        ...(data ? { 'Content-Length': Buffer.byteLength(data, 'utf8') } : {}),
      },
    };
    const req = http.request(opts, (res) => {
      const chunks = [];
      res.on('data', (c) => chunks.push(c));
      res.on('end', () => {
        const raw = Buffer.concat(chunks).toString('utf8');
        try { resolve({ ok: res.statusCode < 400, status: res.statusCode, data: JSON.parse(raw) }); }
        catch { resolve({ ok: res.statusCode < 400, status: res.statusCode, data: raw }); }
      });
    });
    req.on('error', reject);
    if (data) req.write(data, 'utf8');
    req.end();
  });
}

async function main() {
  console.log('=== Seeding Orders & Reviews for test client ===\n');

  // ── 1. Login as client ──
  const clientLogin = await request('POST', '/api/auth/login', {
    email: 'cliente@test.com', password: 'Cliente123!'
  });
  const clientToken = clientLogin.data.token;
  if (!clientToken) { console.error('Client login failed:', clientLogin.data); process.exit(1); }
  console.log('✓ Logged in as client');
  const clientAuth = { 'Authorization': 'Bearer ' + clientToken };

  // ── 2. Login as admin ──
  const adminLogin = await request('POST', '/api/auth/login', {
    email: 'admin@baseshop.com', password: 'Admin123!'
  });
  const adminToken = adminLogin.data.token;
  if (!adminToken) { console.error('Admin login failed:', adminLogin.data); process.exit(1); }
  console.log('✓ Logged in as admin');
  const adminAuth = { 'Authorization': 'Bearer ' + adminToken };

  // ── 3. Get products ──
  const prodRes = await request('GET', '/api/products?limit=100', null, clientAuth);
  const products = prodRes.data.products || prodRes.data.data || [];
  if (products.length < 5) { console.error('Not enough products:', products.length); process.exit(1); }
  console.log(`✓ Found ${products.length} products\n`);

  // ── 4. Create orders in different statuses ──
  const orderConfigs = [
    {
      name: 'Pedido Pendiente',
      targetStatus: 'pending',
      items: [
        { product_id: products[0].id, product_name: products[0].name, product_price: products[0].price, quantity: 1, product_image: (products[0].images || [])[0] || '' },
        { product_id: products[1].id, product_name: products[1].name, product_price: products[1].price, quantity: 2, product_image: (products[1].images || [])[0] || '' },
      ],
      address: 'Calle 100 #15-20, Bogotá, Colombia',
    },
    {
      name: 'Pedido Confirmado',
      targetStatus: 'confirmed',
      transitions: ['confirmed'],
      items: [
        { product_id: products[2].id, product_name: products[2].name, product_price: products[2].price, quantity: 1, product_image: (products[2].images || [])[0] || '' },
      ],
      address: 'Carrera 7 #45-10, Medellín, Colombia',
    },
    {
      name: 'Pedido en Proceso',
      targetStatus: 'processing',
      transitions: ['confirmed', 'processing'],
      items: [
        { product_id: products[3].id, product_name: products[3].name, product_price: products[3].price, quantity: 1, product_image: (products[3].images || [])[0] || '' },
        { product_id: products[4].id, product_name: products[4].name, product_price: products[4].price, quantity: 3, product_image: (products[4].images || [])[0] || '' },
      ],
      address: 'Av. El Dorado #68-30, Bogotá, Colombia',
    },
    {
      name: 'Pedido Enviado',
      targetStatus: 'shipped',
      transitions: ['confirmed', 'processing', 'shipped'],
      items: [
        { product_id: products[5].id, product_name: products[5].name, product_price: products[5].price, quantity: 2, product_image: (products[5].images || [])[0] || '' },
      ],
      address: 'Calle 50 #30-15, Cali, Colombia',
    },
    {
      name: 'Pedido Entregado',
      targetStatus: 'delivered',
      transitions: ['confirmed', 'processing', 'shipped', 'delivered'],
      items: [
        { product_id: products[6].id, product_name: products[6].name, product_price: products[6].price, quantity: 1, product_image: (products[6].images || [])[0] || '' },
        { product_id: products[7].id, product_name: products[7].name, product_price: products[7].price, quantity: 1, product_image: (products[7].images || [])[0] || '' },
      ],
      address: 'Carrera 15 #80-25, Barranquilla, Colombia',
    },
    {
      name: 'Pedido Cancelado',
      targetStatus: 'cancelled',
      transitions: ['cancelled'],
      items: [
        { product_id: products[8].id, product_name: products[8].name, product_price: products[8].price, quantity: 1, product_image: (products[8].images || [])[0] || '' },
      ],
      address: 'Calle 72 #10-50, Bogotá, Colombia',
    },
    {
      name: 'Pedido Reembolsado',
      targetStatus: 'refunded',
      transitions: ['confirmed', 'processing', 'shipped', 'delivered', 'refunded'],
      items: [
        { product_id: products[9].id, product_name: products[9].name, product_price: products[9].price, quantity: 1, product_image: (products[9].images || [])[0] || '' },
      ],
      address: 'Av. Boyacá #50-20, Bogotá, Colombia',
    },
  ];

  const createdOrders = [];

  for (const config of orderConfigs) {
    // Create order as client
    const orderRes = await request('POST', '/api/orders', {
      items: config.items,
      shipping_address: config.address,
      payment_method: 'credit_card',
      notes: `Orden de prueba: ${config.name}`,
    }, clientAuth);

    if (!orderRes.ok) {
      console.error(`✗ Failed to create "${config.name}":`, orderRes.status, orderRes.data);
      continue;
    }

    const orderId = orderRes.data.data?.id || orderRes.data.id || orderRes.data.order?.id;
    console.log(`✓ Created order "${config.name}" (ID: ${orderId}) → status: pending`);

    // Transition to target status (as admin)
    if (config.transitions) {
      for (const status of config.transitions) {
        const statusRes = await request('PATCH', `/api/orders/${orderId}/status`, {
          status,
          note: `Transición automática a ${status}`,
        }, adminAuth);

        if (!statusRes.ok) {
          console.error(`  ✗ Failed transition to "${status}":`, statusRes.status, statusRes.data);
          break;
        }
        console.log(`  → Transitioned to: ${status}`);
      }
    }

    createdOrders.push({ id: orderId, config });
  }

  console.log(`\n✓ Created ${createdOrders.length} orders\n`);

  // ── 5. Create reviews for delivered products ──
  const reviewData = [
    { productIdx: 0, rating: 5, title: 'Excelente producto', comment: 'Superó todas mis expectativas. La calidad es increíble y llegó en perfecto estado. Lo recomiendo al 100%.' },
    { productIdx: 1, rating: 4, title: 'Muy bueno', comment: 'Buen producto, relación calidad-precio muy buena. El envío fue rápido.' },
    { productIdx: 2, rating: 5, title: 'Lo mejor que he comprado', comment: 'Increíble calidad. Lo uso todos los días y funciona perfecto. Definitivamente volvería a comprarlo.' },
    { productIdx: 3, rating: 3, title: 'Cumple su función', comment: 'Es un buen producto pero esperaba un poco más por el precio. El empaque podría mejorar.' },
    { productIdx: 4, rating: 5, title: '¡Imprescindible!', comment: 'No puedo vivir sin este producto. Es exactamente lo que necesitaba. Envío super rápido.' },
    { productIdx: 5, rating: 4, title: 'Recomendado', comment: 'Buena compra. El material es de calidad y se ve tal cual como en las fotos.' },
    { productIdx: 6, rating: 5, title: 'Perfecto', comment: 'Llegó antes de lo esperado. La presentación es impecable. Muy satisfecho con la compra.' },
    { productIdx: 7, rating: 4, title: 'Buena calidad', comment: 'El producto cumple con lo prometido. Buen empaque y envío rápido. Lo recomiendo.' },
    { productIdx: 8, rating: 2, title: 'Podría ser mejor', comment: 'El producto no cumplió del todo mis expectativas. La calidad es aceptable pero he visto mejores opciones.' },
    { productIdx: 9, rating: 5, title: 'Espectacular', comment: 'Sin duda la mejor compra que he hecho en mucho tiempo. Calidad premium a buen precio.' },
  ];

  let reviewCount = 0;
  for (const rev of reviewData) {
    if (rev.productIdx >= products.length) continue;
    const product = products[rev.productIdx];

    const reviewRes = await request('POST', '/api/reviews', {
      product_id: product.id,
      rating: rev.rating,
      title: rev.title,
      comment: rev.comment,
    }, clientAuth);

    if (!reviewRes.ok) {
      console.error(`✗ Review for "${product.name}" failed:`, reviewRes.status, typeof reviewRes.data === 'string' ? reviewRes.data.substring(0, 100) : reviewRes.data);
      continue;
    }

    const reviewId = reviewRes.data.data?.id || reviewRes.data.id;
    console.log(`✓ Review for "${product.name}" (${rev.rating}★): "${rev.title}"`);
    reviewCount++;

    // Approve review as admin
    if (reviewId) {
      const approveRes = await request('PATCH', `/api/reviews/${reviewId}/approve`, {
        approved: true,
      }, adminAuth);
      if (approveRes.ok) {
        console.log(`  → Approved`);
      }
    }
  }

  console.log(`\n✓ Created ${reviewCount} reviews`);
  console.log('\n=== Seed complete! ===');
}

main().catch(console.error);
