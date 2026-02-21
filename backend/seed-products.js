#!/usr/bin/env node
/**
 * Seed products with proper UTF-8 encoding.
 * Uses http module for Node 16 compatibility.
 * Run: node backend/seed-products.js
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
  const login = await request('POST', '/api/auth/login', {
    email: 'admin@baseshop.com', password: 'Admin123!'
  });
  const token = login.data.token;
  if (!token) { console.error('Login failed:', login.data); process.exit(1); }
  console.log('Logged in as admin');

  const auth = { 'Authorization': 'Bearer ' + token };

  const catRes = await request('GET', '/api/categories?flat=true', null, auth);
  const cats = {};
  for (const c of catRes.data.categories) cats[c.slug] = c.id;
  console.log('Categories:', Object.keys(cats).join(', '));

  const existing = await request('GET', '/api/products?limit=100', null, auth);
  for (const p of (existing.data.products || [])) {
    await request('DELETE', '/api/products/' + p.id, null, auth);
  }
  console.log('Deleted ' + (existing.data.products?.length || 0) + ' existing products');

  const products = [
    { name: 'iPhone 15 Pro Max', description: 'Smartphone Apple con chip A17 Pro, pantalla Super Retina XDR de 6.7 pulgadas, c\u00e1mara de 48MP con zoom \u00f3ptico 5x.', short_description: 'El iPhone m\u00e1s avanzado con chip A17 Pro', price: 5499000, compare_price: 5999000, stock: 25, category_id: cats.electronica, images: ['https://images.unsplash.com/photo-1695048133142-1a20484d2569?w=400'], tags: ['apple', 'smartphone', 'iphone'], is_featured: true },
    { name: 'MacBook Air M3', description: 'Laptop Apple con chip M3, pantalla Liquid Retina de 15 pulgadas, 8GB RAM, 256GB SSD. Bater\u00eda de hasta 18 horas.', short_description: 'Potencia y portabilidad con chip M3', price: 5299000, compare_price: 5799000, stock: 15, category_id: cats.electronica, images: ['https://images.unsplash.com/photo-1517336714731-489689fd1ca8?w=400'], tags: ['apple', 'laptop', 'macbook'], is_featured: true },
    { name: 'Samsung Galaxy S24 Ultra', description: 'Smartphone Samsung con S Pen integrado, c\u00e1mara de 200MP, Galaxy AI y pantalla Dynamic AMOLED 2X.', short_description: 'Samsung con S Pen y Galaxy AI', price: 4999000, compare_price: 5499000, stock: 30, category_id: cats.electronica, images: ['https://images.unsplash.com/photo-1610945265064-0e34e5519bbf?w=400'], tags: ['samsung', 'smartphone', 'galaxy'], is_featured: true },
    { name: 'Sony WH-1000XM5', description: 'Auriculares over-ear con la mejor cancelaci\u00f3n de ruido del mercado. Audio de alta resoluci\u00f3n y 30 horas de bater\u00eda.', short_description: 'Auriculares premium con cancelaci\u00f3n de ruido', price: 1299000, compare_price: 1499000, stock: 20, category_id: cats.electronica, images: ['https://images.unsplash.com/photo-1618366712010-f4ae9c647dcb?w=400'], tags: ['sony', 'auriculares', 'noise-cancelling'], is_featured: false },
    { name: 'AirPods Pro 2', description: 'Auriculares inal\u00e1mbricos con cancelaci\u00f3n activa de ruido, audio espacial personalizado y resistencia al agua IPX4.', short_description: 'Auriculares inal\u00e1mbricos con cancelaci\u00f3n de ruido', price: 899000, compare_price: 999000, stock: 50, category_id: cats.electronica, images: ['https://images.unsplash.com/photo-1606220945770-b5b6c2c55bf1?w=400'], tags: ['apple', 'auriculares', 'airpods'], is_featured: false },
    { name: "Jeans Levi's 501 Original", description: 'El cl\u00e1sico jean recto que nunca pasa de moda. Algod\u00f3n 100%, tallas: 28-38.', short_description: 'El jean cl\u00e1sico por excelencia', price: 249000, compare_price: 299000, stock: 60, category_id: cats.ropa, images: ['https://images.unsplash.com/photo-1542272454315-4c01d7abdf4a?w=400'], tags: ['levis', 'jeans', 'ropa'], is_featured: false },
    { name: 'Camiseta Nike Dri-FIT', description: 'Camiseta deportiva con tecnolog\u00eda Dri-FIT para m\u00e1xima comodidad. Tallas: S, M, L, XL.', short_description: 'Camiseta deportiva de alto rendimiento', price: 129000, compare_price: 159000, stock: 100, category_id: cats.ropa, images: ['https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=400'], tags: ['nike', 'camiseta', 'deportiva'], is_featured: true },
    { name: 'Vestido Zara Elegante', description: 'Vestido midi elegante para ocasiones especiales. Tallas: XS-XL. Colores: Negro, Rojo, Azul.', short_description: 'Vestido midi elegante', price: 189000, compare_price: 249000, stock: 35, category_id: cats.ropa, images: ['https://images.unsplash.com/photo-1595777457583-95e059d581b8?w=400'], tags: ['zara', 'vestido', 'elegante'], is_featured: false },
    { name: 'Zapatillas Adidas Ultraboost', description: 'Zapatillas de running con tecnolog\u00eda Boost en la mediasuela para m\u00e1xima amortiguaci\u00f3n. Tallas: 7-12.', short_description: 'Zapatillas de running premium', price: 599000, compare_price: 699000, stock: 40, category_id: cats.ropa, images: ['https://images.unsplash.com/photo-1542291026-7eec264c27ff?w=400'], tags: ['adidas', 'zapatillas', 'running'], is_featured: true },
    { name: 'Chaqueta North Face Thermoball', description: 'Chaqueta aislante ligera con tecnolog\u00eda ThermoBall perfecta para clima fr\u00edo. Colores: Negro, Azul, Verde.', short_description: 'Chaqueta aislante ligera', price: 599000, compare_price: 749000, stock: 25, category_id: cats.ropa, images: ['https://images.unsplash.com/photo-1544923246-77307dd270ce?w=400'], tags: ['north-face', 'chaqueta', 'invierno'], is_featured: true },
    { name: 'S\u00e1banas Premium 600 Hilos', description: 'Juego de s\u00e1banas de algod\u00f3n egipcio 600 hilos. Incluye s\u00e1bana ajustable, plana y 2 fundas.', short_description: 'S\u00e1banas de algod\u00f3n egipcio premium', price: 299000, compare_price: 399000, stock: 40, category_id: cats.hogar, images: ['https://images.unsplash.com/photo-1631049307264-da0ec9d70304?w=400'], tags: ['hogar', 'cama'], is_featured: false },
    { name: 'Cafetera Nespresso Vertuo', description: 'Cafetera de c\u00e1psulas con tecnolog\u00eda Centrifusion para un caf\u00e9 perfecto. Incluye kit con 12 c\u00e1psulas.', short_description: 'Cafetera de c\u00e1psulas premium', price: 799000, compare_price: 999000, stock: 20, category_id: cats.hogar, images: ['https://images.unsplash.com/photo-1517668808822-9ebb02f2a0e6?w=400'], tags: ['nespresso', 'cafetera', 'hogar'], is_featured: true },
    { name: 'Aspiradora Robot iRobot Roomba', description: 'Robot aspirador inteligente con mapeo l\u00e1ser, navegaci\u00f3n avanzada y control por app.', short_description: 'Robot aspirador con mapeo inteligente', price: 1899000, compare_price: 2199000, stock: 10, category_id: cats.hogar, images: ['https://images.unsplash.com/photo-1558618666-fcd25c85f82e?w=400'], tags: ['irobot', 'aspiradora', 'hogar'], is_featured: true },
    { name: 'Bicicleta MTB Trek Marlin 7', description: 'Bicicleta de monta\u00f1a con suspensi\u00f3n delantera RockShox, cuadro de aluminio y ruedas de 29 pulgadas.', short_description: 'Bicicleta de monta\u00f1a profesional', price: 3499000, compare_price: 3999000, stock: 8, category_id: cats.deportes, images: ['https://images.unsplash.com/photo-1532298229144-0ec0c57515c7?w=400'], tags: ['trek', 'bicicleta'], is_featured: true },
    { name: 'Kit de Yoga Premium', description: 'Kit completo: mat antideslizante de 6mm, 2 bloques de corcho, correa de algod\u00f3n y bolsa de transporte.', short_description: 'Kit completo para yoga', price: 199000, compare_price: 249000, stock: 45, category_id: cats.deportes, images: ['https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?w=400'], tags: ['yoga', 'kit', 'fitness'], is_featured: false },
    { name: 'Bal\u00f3n de F\u00fatbol Adidas UCL', description: 'Bal\u00f3n oficial de la Champions League, tama\u00f1o 5. Paneles termosellados.', short_description: 'Bal\u00f3n oficial Champions League', price: 149000, compare_price: 189000, stock: 80, category_id: cats.deportes, images: ['https://images.unsplash.com/photo-1614632537197-38a17061c2bd?w=400'], tags: ['adidas', 'deportes'], is_featured: false },
    { name: 'Set Cuidado Facial The Ordinary', description: 'Set b\u00e1sico de skincare: limpiador con niacinamida, s\u00e9rum de \u00e1cido hialur\u00f3nico, hidratante y protector solar SPF 50.', short_description: 'Set completo de cuidado facial', price: 189000, compare_price: 239000, stock: 55, category_id: cats.belleza, images: ['https://images.unsplash.com/photo-1556228578-8c89e6adf883?w=400'], tags: ['skincare', 'facial'], is_featured: false },
    { name: 'Perfume Chanel N\u00b05 EDP 100ml', description: 'El ic\u00f3nico perfume floral-aldeh\u00eddico de la maison Chanel. Una fragancia atemporal.', short_description: 'El perfume m\u00e1s ic\u00f3nico del mundo', price: 699000, compare_price: 799000, stock: 30, category_id: cats.belleza, images: ['https://images.unsplash.com/photo-1541643600914-78b084683601?w=400'], tags: ['chanel', 'perfume'], is_featured: true },
    { name: 'Plancha de Cabello GHD Platinum+', description: 'Plancha profesional con tecnolog\u00eda predictiva que adapta la temperatura seg\u00fan tu tipo de cabello.', short_description: 'Plancha profesional predictiva', price: 899000, compare_price: 1099000, stock: 15, category_id: cats.belleza, images: ['https://images.unsplash.com/photo-1522337360788-8b13dee7a37e?w=400'], tags: ['ghd', 'plancha', 'cabello'], is_featured: false },
  ];

  let created = 0;
  for (const p of products) {
    const res = await request('POST', '/api/products', p, auth);
    if (res.ok) { created++; console.log('  + ' + p.name); }
    else { console.log('  x ' + p.name + ': ' + (res.data.message || JSON.stringify(res.data))); }
  }
  console.log('\nSeeded ' + created + '/' + products.length + ' products');
}

main().catch(console.error);
