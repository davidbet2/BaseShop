#!/usr/bin/env node
/**
 * Seed: Lencería Femenina
 * - Crea categorías de lencería como subcategorías de "ropa"
 * - Crea 12 productos con imágenes Unsplash
 * - Configura banners/sliders del home y textos del home
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
  console.log('\n[1/4] Autenticando admin...');
  const login = await request('POST', '/api/auth/login', {
    email: 'admin@baseshop.com',
    password: 'Admin123!',
  });
  const token = login.data.token;
  if (!token) { console.error('Login fallido:', login.data); process.exit(1); }
  const auth = { Authorization: 'Bearer ' + token };
  console.log('     ✓ Admin autenticado');

  // ─────────────────────────────────────────────
  //  2. Obtener / crear categorías de lencería
  // ─────────────────────────────────────────────
  console.log('\n[2/4] Configurando categorías...');

  const catRes = await request('GET', '/api/categories?flat=true', null, auth);
  const allCats = catRes.data.categories || [];
  const catMap = {};
  for (const c of allCats) catMap[c.slug] = c.id;

  // Encontrar o crear categoría padre "lencería"
  async function ensureCategory(name, slug, parentSlug = null, description = '') {
    if (catMap[slug]) {
      console.log(`     → ya existe: "${name}"`);
      return catMap[slug];
    }
    const body = { name, slug, description, is_active: true };
    if (parentSlug && catMap[parentSlug]) body.parent_id = catMap[parentSlug];
    const res = await request('POST', '/api/categories', body, auth);
    if (res.ok) {
      const id = res.data.category?.id || res.data.id;
      catMap[slug] = id;
      console.log(`     + creada: "${name}" (id=${id})`);
      return id;
    } else {
      console.warn(`     ! Error creando "${name}":`, res.data?.message || res.data);
      // Reintentar búsqueda
      const retry = await request('GET', '/api/categories?flat=true', null, auth);
      for (const c of (retry.data.categories || [])) {
        if (c.slug === slug) { catMap[slug] = c.id; return c.id; }
      }
      return null;
    }
  }

  const catLenceria     = await ensureCategory('Lencería Femenina', 'lenceria-femenina', null,            'Lencería íntima y de moda para mujer');
  const catBralets      = await ensureCategory('Bralets y Sujetadores', 'bralets',       'lenceria-femenina', 'Bralets modernos y sujetadores con soporte');
  const catBriefs       = await ensureCategory('Panties y Bikinis',   'panties',         'lenceria-femenina', 'Ropa interior femenina cómoda y elegante');
  const catSets         = await ensureCategory('Sets y Conjuntos',    'sets-lenceria',   'lenceria-femenina', 'Conjuntos coordinados de lencería');
  const catBodys        = await ensureCategory('Bodys y Teddys',      'bodys-teddys',    'lenceria-femenina', 'Bodys, babydolls y teddys sensuales');
  const catPijamas      = await ensureCategory('Pijamas y Loungewear','pijamas',         'lenceria-femenina', 'Pijamas, salidas de baño y ropa de dormir');

  // ─────────────────────────────────────────────
  //  3. Crear productos de lencería
  // ─────────────────────────────────────────────
  console.log('\n[3/4] Creando productos...');

  const products = [
    // ── Bralets ──
    {
      name: 'Bralet Encaje Francés Negro',
      description: 'Delicado bralet confeccionado en encaje francés de alta calidad. Tirantes ajustables, cierre trasero y forro interior de algodón para máxima comodidad. Disponible en tallas XS–XL. Perfecto para usar solo o con blazer.',
      short_description: 'Bralet de encaje francés con tirantes ajustables',
      price: 89000,
      discount_percent: 25,
      stock: 45,
      category_id: catBralets,
      images: [
        'https://images.unsplash.com/photo-1594938298603-c8148c4b4d7c?w=600',
        'https://images.unsplash.com/photo-1571513722275-4257cd5e9ac3?w=600',
      ],
      tags: ['bralet', 'encaje', 'negro', 'lenceria'],
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
      name: 'Sujetador Bralette Wireless Rosa Poudré',
      description: 'Sujetador sin aros en encaje tipo bralette, totalmente inalámbrico para máxima comodidad. Parte trasera de encaje floral, relleno extraíble fino. Ideal para uso diario. Tallas: 32A-38D.',
      short_description: 'Bralette sin aros con encaje floral, uso diario',
      price: 79000,
      discount_percent: 20,
      stock: 60,
      category_id: catBralets,
      images: [
        'https://images.unsplash.com/photo-1563219152-8b2e3a4d36c7?w=600',
        'https://images.unsplash.com/photo-1616400619175-5beda3a17896?w=600',
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
      name: 'Bralet Satén Ivory con Detalles Dorados',
      description: 'Elegante bralet en satén ivory con costuras y detalles en tono dorado. Silueta estructurada, tirantes finos regulables, forro de tul suave. Para ocasiones especiales o noche. Tallas XS–L.',
      short_description: 'Bralet en satén ivory con acabados dorados',
      price: 115000,
      discount_percent: 23,
      stock: 30,
      category_id: catBralets,
      images: [
        'https://images.unsplash.com/photo-1526958097901-5e6d742d3371?w=600',
      ],
      tags: ['bralet', 'saten', 'dorado', 'elegante'],
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

    // ── Panties ──
    {
      name: 'Pack 3 Bikinis Algodón Premium',
      description: 'Pack de 3 bikinis de corte clásico en algodón Pima premium. Cinturilla elástica suave, tiro medio, sin costuras laterales. Colores surtidos: crema, nude y negro. Tallas: S, M, L, XL.',
      short_description: 'Pack de 3 bikinis algodón Pima, sin costuras',
      price: 69000,
      discount_percent: 22,
      stock: 80,
      category_id: catBriefs,
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
      name: 'Hipster Encaje Floral Coral',
      description: 'Panty tipo hipster en encaje floral con fondo de algodón. Corte de tiro bajo a medio que favorece todas las siluetas. Amplio diseño sin costuras visibles. Tallas XS–XL.',
      short_description: 'Hipster de encaje floral con fundo de algodón',
      price: 45000,
      discount_percent: 24,
      stock: 70,
      category_id: catBriefs,
      images: [
        'https://images.unsplash.com/photo-1592301933927-35b597393c0a?w=600',
      ],
      tags: ['hipster', 'encaje', 'coral', 'lenceria'],
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

    // ── Sets ──
    {
      name: 'Set Bralet + Panty Encaje Champagne',
      description: 'Conjunto coordinado: bralet de encaje con copa moldeada y panty hipster a juego. Encaje de Calais importado, tono champagne. Forro interior de microfibra suave. Perfecto como regalo. Tallas: S, M, L.',
      short_description: 'Conjunto de encaje bralet + panty champagne',
      price: 159000,
      discount_percent: 20,
      stock: 35,
      category_id: catSets,
      images: [
        'https://images.unsplash.com/photo-1567401893414-76b7b1e5a7a5?w=600',
        'https://images.unsplash.com/photo-1553481187-be93c21490a9?w=600',
      ],
      tags: ['set', 'conjunto', 'encaje', 'champagne', 'regalo'],
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
      name: 'Set Sensual Negro Microfibra',
      description: 'Conjunto íntimo en microfibra premium ultra suave color negro. Incluye bralette con escote pronunciado y tanga coordinada. Acabados con puntilla de encaje. Elásticos planos sin costuras. Tallas XS–XL.',
      short_description: 'Set bralette + tanga en microfibra negra',
      price: 129000,
      discount_percent: 24,
      stock: 40,
      category_id: catSets,
      images: [
        'https://images.unsplash.com/photo-1609710228159-0fa9bd7c0827?w=600',
      ],
      tags: ['set', 'negro', 'microfibra', 'sensual'],
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

    // ── Bodys ──
    {
      name: 'Teddy Encaje Floral con Abertura Posterior',
      description: 'Hermoso teddy en encaje floral semitransparente con escote pronunciado en pico y cierre de botones en la entrepierna. Tirantes finos ajustables. Tallas S–XL. Una pieza para momentos especiales.',
      short_description: 'Teddy encaje floral, escote en pico, cierre botones',
      price: 139000,
      discount_percent: 22,
      stock: 25,
      category_id: catBodys,
      images: [
        'https://images.unsplash.com/photo-1617551307578-aeabf244f4b4?w=600',
      ],
      tags: ['teddy', 'encaje', 'floral', 'especial'],
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
      name: 'Body Bodysuit Satén Vino',
      description: 'Bodysuit en satén fluido color vino con escote cuadrado, tirantes regulables y corte que favorece la figura. Cierre de broche entrepierna. También úsalo como top con jeans. Tallas XS–L.',
      short_description: 'Bodysuit satén vino, escote cuadrado, versátil',
      price: 99000,
      discount_percent: 23,
      stock: 38,
      category_id: catBodys,
      images: [
        'https://images.unsplash.com/photo-1539109136881-3be0616acf4b?w=600',
      ],
      tags: ['bodysuit', 'saten', 'vino', 'versatil'],
      is_featured: false,
    },

    // ── Pijamas Loungewear ──
    {
      name: 'Pijama Satén Floral 2 Piezas Lavanda',
      description: 'Conjunto de pijama en satén suave color lavanda con estampado floral sutil. Pantalón de corte recto con elástico en cintura y camisa tipo camisola con encaje en escote. Tallas S–XL.',
      short_description: 'Pijama satén floral pantalón + camisola lavanda',
      price: 179000,
      discount_percent: 18,
      stock: 30,
      category_id: catPijamas,
      images: [
        'https://images.unsplash.com/photo-1585314062340-f1a5a7c9328d?w=600',
      ],
      tags: ['pijama', 'saten', 'floral', 'lavanda'],
      is_featured: true,
      variants: [
        {
          name: 'Talla',
          options: [
            { name: 'S', price_adjustment: 0 },
            { name: 'M', price_adjustment: 0 },
            { name: 'L', price_adjustment: 0 },
            { name: 'XL', price_adjustment: 5000 },
          ],
        },
      ],
    },
    {
      name: 'Salida de Baño Robe Corta Plush Blanca',
      description: 'Bata corta tipo robe en tela plush ultra suave por dentro. Largo a la cadera, cierre con cinto, bolsillos laterales. Ideal para spa, hotel o en casa. Disponible en blanco perla. Tallas S–XL.',
      short_description: 'Robe corta plush ultra suave, con bolsillos',
      price: 149000,
      discount_percent: 21,
      stock: 22,
      category_id: catPijamas,
      images: [
        'https://images.unsplash.com/photo-1515377905703-c4788e51af15?w=600',
      ],
      tags: ['robe', 'bata', 'spa', 'blanca', 'suave'],
      is_featured: false,
    },
    {
      name: 'Short Set Crop Top + Short Encaje Nude',
      description: 'Set de dos piezas para dormir: crop top de tirantes con encaje en el pecho y short coordinado de cinturilla elástica. Material: modal + elastano para máxima suavidad. Color nude. Tallas XS–XL.',
      short_description: 'Short Set crop top + short encaje nude, modal',
      price: 119000,
      discount_percent: 20,
      stock: 50,
      category_id: catPijamas,
      images: [
        'https://images.unsplash.com/photo-1549298916-b41d501d3772?w=600',
      ],
      tags: ['short set', 'crop top', 'nude', 'modal', 'loungewear'],
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
  //  4. Actualizar config: home texts + banners
  // ─────────────────────────────────────────────
  console.log('\n[4/4] Actualizando configuración del home y banners...');

  // Elegir los 4 primeros productos con is_featured=true para los sliders
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
      image_path: 'https://images.unsplash.com/photo-1526958097901-5e6d742d3371?w=1200&h=500&fit=crop',
      product_id: featuredIds[2] ? String(featuredIds[2]) : null,
      custom_price: null,
      sort_order: 3,
    },
    {
      image_path: 'https://images.unsplash.com/photo-1585314062340-f1a5a7c9328d?w=1200&h=500&fit=crop',
      product_id: featuredIds[3] ? String(featuredIds[3]) : null,
      custom_price: null,
      sort_order: 4,
    },
  ];

  const configUpdate = {
    store_name: 'LencerIA Boutique',
    featured_title: 'Nueva Colección Lencería',
    featured_desc: 'Descubre nuestra exclusiva selección de lencería femenina: encajes franceses, conjuntos coordinados, pijamas de satén y mucho más. Elige comodidad, elegancia y sensualidad en cada pieza.',
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
  console.log(`  Categorías creadas : 6 (lencería y subcategorías)`);
  console.log(`  Productos creados  : ${created}`);
  console.log(`  Banners del home   : ${banners.length}`);
  console.log(`  Store name         : LencerIA Boutique`);
  console.log(`  Color principal    : #E91E8C`);
  console.log('\n  Visita http://localhost:8080 para ver los cambios');
}

main().catch(console.error);
