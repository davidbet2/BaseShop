#!/usr/bin/env node
/**
 * Seed: Lencería Femenina (Demo)
 * - BORRA todas las categorías y productos existentes
 * - Crea 3 categorías de lencería
 * - Crea 10 productos con imágenes reales
 * - Configura banners/sliders del home
 *
 * Uso: node backend/seed-lingerie.js
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
  // ─────────────────────────────────────────────
  //  1. Login como admin
  // ─────────────────────────────────────────────
  console.log('\n[1/5] Autenticando admin...');
  const login = await request('POST', '/api/auth/login', {
    email: 'admin@baseshop.com',
    password: 'Admin123!',
  });
  const token = login.data.token;
  if (!token) { console.error('Login fallido:', login.data); process.exit(1); }
  const auth = { Authorization: 'Bearer ' + token };
  console.log('     ✓ Admin autenticado');

  // ─────────────────────────────────────────────
  //  2. Borrar TODOS los productos y categorías existentes
  // ─────────────────────────────────────────────
  console.log('\n[2/5] Limpiando datos existentes...');

  // Borrar productos
  const prodRes = await request('GET', '/api/products?limit=200', null, auth);
  const existingProducts = prodRes.data?.products || [];
  for (const p of existingProducts) {
    await request('DELETE', `/api/products/${p.id}`, null, auth);
  }
  console.log(`     ✓ ${existingProducts.length} productos eliminados`);

  // Borrar categorías (hijos primero, luego padres)
  const catRes = await request('GET', '/api/categories?flat=true', null, auth);
  const existingCats = catRes.data?.categories || [];
  // Primero subcategorías (las que tienen parent_id)
  for (const c of existingCats.filter(c => c.parent_id)) {
    await request('DELETE', `/api/categories/${c.id}`, null, auth);
  }
  // Luego categorías padre
  for (const c of existingCats.filter(c => !c.parent_id)) {
    await request('DELETE', `/api/categories/${c.id}`, null, auth);
  }
  console.log(`     ✓ ${existingCats.length} categorías eliminadas`);

  // ─────────────────────────────────────────────
  //  3. Crear 3 categorías de lencería
  // ─────────────────────────────────────────────
  console.log('\n[3/5] Creando 3 categorías...');

  const catMap = {};
  async function createCategory(name, slug, description, image = '') {
    const body = { name, slug, description, image, is_active: true };
    const res = await request('POST', '/api/categories', body, auth);
    if (res.ok) {
      const id = res.data.category?.id || res.data.id;
      catMap[slug] = id;
      console.log(`     + "${name}" (id=${id})`);
      return id;
    } else {
      console.warn(`     ! Error creando "${name}":`, res.data?.message || res.data);
      return null;
    }
  }

  const catConjuntos = await createCategory(
    'Conjuntos',
    'conjuntos',
    'Sets coordinados de lencería: bralet + panty, sujetador + tanga',
    'https://images.unsplash.com/photo-1616400619175-5beda3a17896?w=400'
  );
  const catBralets = await createCategory(
    'Bralets & Sujetadores',
    'bralets-sujetadores',
    'Bralets de encaje, sujetadores sin aros y tops íntimos',
    'https://images.unsplash.com/photo-1563219152-8b2e3a4d36c7?w=400'
  );
  const catPanties = await createCategory(
    'Panties & Bodys',
    'panties-bodys',
    'Panties, tangas, hipsters y bodysuits sensuales',
    'https://images.unsplash.com/photo-1609710228159-0fa9bd7c0827?w=400'
  );

  // ─────────────────────────────────────────────
  //  4. Crear 10 productos
  // ─────────────────────────────────────────────
  console.log('\n[4/5] Creando 10 productos...');

  const products = [
    // ── CONJUNTOS (4 productos) ──
    {
      name: 'Set Encaje Francés Negro',
      description: 'Conjunto de lencería en encaje francés de alta calidad. Incluye bralet con tirantes ajustables y panty hipster a juego. Forro interior de algodón suave. Perfecto para ocasiones especiales.',
      short_description: 'Set bralet + panty en encaje francés negro',
      price: 159000,
      discount_percent: 20,
      stock: 40,
      category_id: catConjuntos,
      images: [
        'https://images.unsplash.com/photo-1594938298603-c8148c4b4d7c?w=600',
        'https://images.unsplash.com/photo-1571513722275-4257cd5e9ac3?w=600',
      ],
      tags: ['set', 'encaje', 'negro', 'frances'],
      is_featured: true,
      variants: [
        {
          name: 'Talla',
          options: [
            { name: 'XS', price_adjustment: 0 },
            { name: 'S', price_adjustment: 0 },
            { name: 'M', price_adjustment: 0 },
            { name: 'L', price_adjustment: 0 },
            { name: 'XL', price_adjustment: 0 },
          ],
        },
        {
          name: 'Color',
          options: [
            { name: 'Negro', price_adjustment: 0, image: 'https://images.unsplash.com/photo-1594938298603-c8148c4b4d7c?w=600' },
            { name: 'Blanco', price_adjustment: 0, image: 'https://images.unsplash.com/photo-1571513722275-4257cd5e9ac3?w=600' },
          ],
        },
      ],
    },
    {
      name: 'Set Champagne Elegance',
      description: 'Conjunto coordinado en tono champagne con encaje de Calais importado. Bralet con copa moldeada y panty bikini. Forro de microfibra ultra suave. Ideal como regalo.',
      short_description: 'Set bralet + bikini encaje champagne',
      price: 189000,
      discount_percent: 15,
      stock: 30,
      category_id: catConjuntos,
      images: [
        'https://images.unsplash.com/photo-1567401893414-76b7b1e5a7a5?w=600',
        'https://images.unsplash.com/photo-1553481187-be93c21490a9?w=600',
      ],
      tags: ['set', 'champagne', 'elegante', 'regalo'],
      is_featured: true,
      variants: [
        {
          name: 'Talla',
          options: [
            { name: 'S', price_adjustment: 0 },
            { name: 'M', price_adjustment: 0 },
            { name: 'L', price_adjustment: 5000 },
          ],
        },
        {
          name: 'Color',
          options: [
            { name: 'Champagne', price_adjustment: 0, image: 'https://images.unsplash.com/photo-1567401893414-76b7b1e5a7a5?w=600' },
            { name: 'Negro', price_adjustment: 0, image: 'https://images.unsplash.com/photo-1553481187-be93c21490a9?w=600' },
          ],
        },
      ],
    },
    {
      name: 'Set Microfibra Sensual Negro',
      description: 'Conjunto íntimo en microfibra premium ultra suave. Bralette con escote pronunciado y tanga coordinada con puntilla de encaje. Elásticos planos sin costuras visibles.',
      short_description: 'Set bralette + tanga microfibra negra',
      price: 129000,
      discount_percent: 25,
      stock: 50,
      category_id: catConjuntos,
      images: [
        'https://images.unsplash.com/photo-1609710228159-0fa9bd7c0827?w=600',
      ],
      tags: ['set', 'microfibra', 'negro', 'sensual'],
      is_featured: true,
      variants: [
        {
          name: 'Talla',
          options: [
            { name: 'XS', price_adjustment: 0 },
            { name: 'S', price_adjustment: 0 },
            { name: 'M', price_adjustment: 0 },
            { name: 'L', price_adjustment: 0 },
            { name: 'XL', price_adjustment: 0 },
          ],
        },
      ],
    },
    {
      name: 'Set Crop Top + Short Nude',
      description: 'Set de dos piezas para dormir y descansar: crop top de tirantes con detalle de encaje y short coordinado de cinturilla elástica. Material modal + elastano para máxima suavidad.',
      short_description: 'Set crop top + short modal nude',
      price: 119000,
      discount_percent: 20,
      stock: 45,
      category_id: catConjuntos,
      images: [
        'https://images.unsplash.com/photo-1616400619175-5beda3a17896?w=600',
      ],
      tags: ['set', 'crop top', 'short', 'nude', 'modal'],
      is_featured: false,
      variants: [
        {
          name: 'Talla',
          options: [
            { name: 'XS', price_adjustment: 0 },
            { name: 'S', price_adjustment: 0 },
            { name: 'M', price_adjustment: 0 },
            { name: 'L', price_adjustment: 0 },
            { name: 'XL', price_adjustment: 0 },
          ],
        },
      ],
    },

    // ── BRALETS & SUJETADORES (3 productos) ──
    {
      name: 'Bralette Wireless Rosa Poudré',
      description: 'Sujetador sin aros tipo bralette totalmente inalámbrico para máxima comodidad diaria. Parte trasera de encaje floral, relleno extraíble fino. Copa sin varilla. Ideal para el día a día.',
      short_description: 'Bralette sin aros con encaje floral rosa',
      price: 79000,
      discount_percent: 20,
      stock: 60,
      category_id: catBralets,
      images: [
        'https://images.unsplash.com/photo-1563219152-8b2e3a4d36c7?w=600',
      ],
      tags: ['bralette', 'rosa', 'sin aros', 'diario'],
      is_featured: true,
      variants: [
        {
          name: 'Talla',
          options: [
            { name: 'S', price_adjustment: 0 },
            { name: 'M', price_adjustment: 0 },
            { name: 'L', price_adjustment: 0 },
            { name: 'XL', price_adjustment: 0 },
          ],
        },
      ],
    },
    {
      name: 'Bralet Satén Ivory Dorado',
      description: 'Elegante bralet en satén ivory con costuras y acabados en tono dorado. Silueta estructurada con tirantes finos regulables y forro de tul suave. Para noche y ocasiones especiales.',
      short_description: 'Bralet satén ivory con detalles dorados',
      price: 115000,
      discount_percent: 18,
      stock: 35,
      category_id: catBralets,
      images: [
        'https://images.unsplash.com/photo-1526958097901-5e6d742d3371?w=600',
      ],
      tags: ['bralet', 'saten', 'ivory', 'dorado', 'elegante'],
      is_featured: false,
      variants: [
        {
          name: 'Talla',
          options: [
            { name: 'XS', price_adjustment: 0 },
            { name: 'S', price_adjustment: 0 },
            { name: 'M', price_adjustment: 0 },
            { name: 'L', price_adjustment: 0 },
          ],
        },
      ],
    },
    {
      name: 'Bralet Encaje Floral Burdeo',
      description: 'Bralet romántico en encaje floral color burdeo con forro de algodón. Tirantes ajustables cruzados en la espalda. Diseño sin aros para comodidad total. Combínalo con blazer o bajo camisa transparente.',
      short_description: 'Bralet encaje floral burdeo, tirantes cruzados',
      price: 89000,
      discount_percent: 22,
      stock: 40,
      category_id: catBralets,
      images: [
        'https://images.unsplash.com/photo-1617551307578-aeabf244f4b4?w=600',
      ],
      tags: ['bralet', 'encaje', 'burdeo', 'floral'],
      is_featured: false,
      variants: [
        {
          name: 'Talla',
          options: [
            { name: 'XS', price_adjustment: 0 },
            { name: 'S', price_adjustment: 0 },
            { name: 'M', price_adjustment: 0 },
            { name: 'L', price_adjustment: 0 },
            { name: 'XL', price_adjustment: 0 },
          ],
        },
      ],
    },

    // ── PANTIES & BODYS (3 productos) ──
    {
      name: 'Pack 3 Bikinis Algodón Premium',
      description: 'Pack de 3 bikinis de corte clásico en algodón Pima premium. Cinturilla elástica suave, tiro medio, sin costuras laterales. Colores surtidos: crema, nude y negro.',
      short_description: 'Pack x3 bikinis algodón Pima sin costuras',
      price: 69000,
      discount_percent: 15,
      stock: 80,
      category_id: catPanties,
      images: [
        'https://images.unsplash.com/photo-1591561954555-607968c989ab?w=600',
      ],
      tags: ['bikini', 'algodon', 'pack', 'diario'],
      is_featured: false,
      variants: [
        {
          name: 'Talla',
          options: [
            { name: 'S', price_adjustment: 0 },
            { name: 'M', price_adjustment: 0 },
            { name: 'L', price_adjustment: 0 },
            { name: 'XL', price_adjustment: 0 },
          ],
        },
      ],
    },
    {
      name: 'Bodysuit Satén Vino',
      description: 'Bodysuit en satén fluido color vino con escote cuadrado elegante, tirantes regulables y corte que favorece la silueta. Cierre de broche entrepierna. Úsalo como lencería o como top con jeans.',
      short_description: 'Bodysuit satén vino, escote cuadrado versátil',
      price: 99000,
      discount_percent: 23,
      stock: 38,
      category_id: catPanties,
      images: [
        'https://images.unsplash.com/photo-1539109136881-3be0616acf4b?w=600',
      ],
      tags: ['bodysuit', 'saten', 'vino', 'versatil'],
      is_featured: true,
      variants: [
        {
          name: 'Talla',
          options: [
            { name: 'XS', price_adjustment: 0 },
            { name: 'S', price_adjustment: 0 },
            { name: 'M', price_adjustment: 0 },
            { name: 'L', price_adjustment: 0 },
          ],
        },
      ],
    },
    {
      name: 'Hipster Encaje Floral Coral',
      description: 'Panty tipo hipster en encaje floral semitransparente con fondo de algodón. Corte de tiro bajo a medio que favorece todas las siluetas. Diseño sin costuras visibles bajo la ropa.',
      short_description: 'Hipster encaje floral con fondo algodón',
      price: 45000,
      discount_percent: 20,
      stock: 70,
      category_id: catPanties,
      images: [
        'https://images.unsplash.com/photo-1592301933927-35b597393c0a?w=600',
      ],
      tags: ['hipster', 'encaje', 'coral', 'floral'],
      is_featured: false,
      variants: [
        {
          name: 'Talla',
          options: [
            { name: 'XS', price_adjustment: 0 },
            { name: 'S', price_adjustment: 0 },
            { name: 'M', price_adjustment: 0 },
            { name: 'L', price_adjustment: 0 },
            { name: 'XL', price_adjustment: 0 },
          ],
        },
      ],
    },
  ];

  let created = 0;
  const createdProducts = [];
  for (const p of products) {
    const res = await request('POST', '/api/products', p, auth);
    if (res.ok) {
      created++;
      const prod = res.data.product || res.data;
      createdProducts.push(prod);
      console.log(`  ✓ ${p.name}`);
    } else {
      console.log(`  ✗ ${p.name}: ${res.data?.message || JSON.stringify(res.data)}`);
    }
  }
  console.log(`\n     ${created}/${products.length} productos creados`);

  // ─────────────────────────────────────────────
  //  5. Actualizar config: home texts + banners
  // ─────────────────────────────────────────────
  console.log('\n[5/5] Actualizando configuración del home y banners...');

  const featuredIds = createdProducts
    .filter((_, i) => products[i]?.is_featured)
    .slice(0, 4)
    .map(p => p.id);

  const banners = [
    {
      image_path: 'https://images.unsplash.com/photo-1594938298603-c8148c4b4d7c?w=1200&h=500&fit=crop',
      product_id: featuredIds[0] ? String(featuredIds[0]) : null,
      custom_price: null,
      sort_order: 1,
    },
    {
      image_path: 'https://images.unsplash.com/photo-1567401893414-76b7b1e5a7a5?w=1200&h=500&fit=crop',
      product_id: featuredIds[1] ? String(featuredIds[1]) : null,
      custom_price: null,
      sort_order: 2,
    },
    {
      image_path: 'https://images.unsplash.com/photo-1609710228159-0fa9bd7c0827?w=1200&h=500&fit=crop',
      product_id: featuredIds[2] ? String(featuredIds[2]) : null,
      custom_price: null,
      sort_order: 3,
    },
    {
      image_path: 'https://images.unsplash.com/photo-1563219152-8b2e3a4d36c7?w=1200&h=500&fit=crop',
      product_id: featuredIds[3] ? String(featuredIds[3]) : null,
      custom_price: null,
      sort_order: 4,
    },
  ];

  const configUpdate = {
    store_name: 'LencerIA Boutique',
    featured_title: 'Nueva Colección Lencería',
    featured_desc: 'Descubre nuestra exclusiva selección de lencería femenina: encajes franceses, conjuntos coordinados y mucho más. Comodidad, elegancia y sensualidad en cada pieza.',
    primary_color_hex: 'E91E8C',
    banners,
  };

  const cfgRes = await request('PUT', '/api/config', configUpdate, auth);
  if (cfgRes.ok) {
    console.log('  ✓ Configuración del home actualizada');
    console.log('  ✓ Banners/sliders configurados:', banners.length);
  } else {
    console.warn('  ! Error actualizando config:', cfgRes.data?.error || cfgRes.data);
  }

  // ─────────────────────────────────────────────
  //  Resumen
  // ─────────────────────────────────────────────
  console.log('\n══════════════════════════════════════════');
  console.log('  ✅  Seed completado con éxito');
  console.log('══════════════════════════════════════════');
  console.log(`  Categorías creadas : 3`);
  console.log(`  Productos creados  : ${created}`);
  console.log(`  Banners del home   : ${banners.length}`);
  console.log(`  Store name         : LencerIA Boutique`);
  console.log(`  Color principal    : #E91E8C`);
  console.log('\n  Visita http://localhost:8080 para ver los cambios');
}

main().catch(console.error);
