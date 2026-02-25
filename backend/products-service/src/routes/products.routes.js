const express = require('express');
const { body, param, query, validationResult } = require('express-validator');
const { v4: uuidv4 } = require('uuid');
const path = require('path');
const fs = require('fs');
const multer = require('multer');
const { getDb } = require('../database');
const { authMiddleware, roleMiddleware } = require('../middleware/auth');

// ── Multer config for image uploads ──
const UPLOADS_DIR = path.resolve(process.env.UPLOADS_PATH || './data/uploads');
if (!fs.existsSync(UPLOADS_DIR)) fs.mkdirSync(UPLOADS_DIR, { recursive: true });

const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, UPLOADS_DIR),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname) || '.jpg';
    cb(null, `${uuidv4()}${ext}`);
  },
});
const upload = multer({
  storage,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
  fileFilter: (req, file, cb) => {
    const allowed = /jpeg|jpg|png|gif|webp|svg/;
    const ext = allowed.test(path.extname(file.originalname).toLowerCase());
    const mime = allowed.test(file.mimetype);
    cb(null, ext && mime);
  },
});

const productsRouter = express.Router();
const categoriesRouter = express.Router();

// ── Helpers ──

function slugify(text) {
  return text
    .toString()
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)+/g, '');
}

function handleValidation(req, res) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ error: errors.array()[0].msg });
  }
  return null;
}

function parseProduct(product) {
  if (!product) return null;
  const discountPct = product.discount_percent || 0;
  const originalPrice = product.price;
  const finalPrice = discountPct > 0
    ? Math.round(originalPrice * (1 - discountPct / 100) * 100) / 100
    : originalPrice;

  const parsed = {
    ...product,
    images: (() => { try { return JSON.parse(product.images || '[]'); } catch { return []; } })(),
    tags: product.tags ? product.tags.split(',').map(t => t.trim()).filter(Boolean) : [],
    is_active: !!product.is_active,
    is_featured: !!product.is_featured,
    has_variants: !!product.has_variants,
    discount_percent: discountPct,
    // For backward compatibility: price = final selling price, compare_price = original
    price: finalPrice,
    compare_price: discountPct > 0 ? originalPrice : 0,
    original_price: originalPrice,
    final_price: finalPrice,
  };
  return parsed;
}

// Load variants for a product
function loadProductVariants(db, productId) {
  const types = db.prepare(
    'SELECT * FROM product_variant_types WHERE product_id = ? ORDER BY sort_order ASC'
  ).all(productId);

  return types.map(type => {
    const options = db.prepare(
      'SELECT * FROM product_variant_options WHERE variant_type_id = ? AND is_active = 1 ORDER BY sort_order ASC'
    ).all(type.id);
    return {
      id: type.id,
      name: type.name,
      sort_order: type.sort_order,
      options: options.map(opt => ({
        id: opt.id,
        name: opt.name,
        price_adjustment: opt.price_adjustment || 0,
        image: opt.image || '',
        sort_order: opt.sort_order,
      })),
    };
  });
}

// Save variants for a product (creates/replaces all)
function saveProductVariants(db, productId, variants) {
  // Delete existing variants
  db.prepare('DELETE FROM product_variant_options WHERE product_id = ?').run(productId);
  db.prepare('DELETE FROM product_variant_types WHERE product_id = ?').run(productId);

  if (!variants || !Array.isArray(variants) || variants.length === 0) {
    db.prepare('UPDATE products SET has_variants = 0, updated_at = datetime("now") WHERE id = ?').run(productId);
    return;
  }

  db.prepare('UPDATE products SET has_variants = 1, updated_at = datetime("now") WHERE id = ?').run(productId);

  for (let i = 0; i < variants.length; i++) {
    const variant = variants[i];
    const typeId = uuidv4();
    db.prepare(
      'INSERT INTO product_variant_types (id, product_id, name, sort_order) VALUES (?, ?, ?, ?)'
    ).run(typeId, productId, variant.name, i);

    if (variant.options && Array.isArray(variant.options)) {
      for (let j = 0; j < variant.options.length; j++) {
        const opt = variant.options[j];
        db.prepare(
          `INSERT INTO product_variant_options (id, variant_type_id, product_id, name, price_adjustment, image, sort_order)
           VALUES (?, ?, ?, ?, ?, ?, ?)`
        ).run(uuidv4(), typeId, productId, opt.name, parseFloat(opt.price_adjustment || 0), opt.image || '', j);
      }
    }
  }
}

// Obtiene todos los IDs de subcategorías de una categoría (recursivo)
function getSubcategoryIds(db, parentId) {
  const ids = [parentId];
  const children = db.prepare('SELECT id FROM categories WHERE parent_id = ? AND is_active = 1').all(parentId);
  for (const child of children) {
    ids.push(...getSubcategoryIds(db, child.id));
  }
  return ids;
}

// Construye árbol jerárquico de categorías
function buildCategoryTree(categories, parentId = null) {
  return categories
    .filter(cat => cat.parent_id === parentId)
    .sort((a, b) => a.sort_order - b.sort_order)
    .map(cat => ({
      ...cat,
      is_active: !!cat.is_active,
      children: buildCategoryTree(categories, cat.id),
    }));
}

// ══════════════════════════════════════════════
//  PRODUCTS ROUTES
// ══════════════════════════════════════════════

// ──────────────────────────────────────────────
// POST /api/products/upload — Subir una imagen (admin)
// ──────────────────────────────────────────────
productsRouter.post('/upload',
  authMiddleware,
  roleMiddleware('admin'),
  upload.single('image'),
  (req, res) => {
    if (!req.file) {
      return res.status(400).json({ error: 'No se proporcionó ninguna imagen válida' });
    }
    const baseUrl = `${req.protocol}://${req.get('host')}`;
    const url = `${baseUrl}/uploads/${req.file.filename}`;
    res.json({ url, filename: req.file.filename });
  }
);

// ──────────────────────────────────────────────
// GET /api/products — Listar productos (público)
// ──────────────────────────────────────────────
productsRouter.get('/', (req, res) => {
  try {
    const db = getDb();
    const {
      page = 1,
      limit = 20,
      search,
      category_id,
      min_price,
      max_price,
      is_featured,
      sort_by = 'newest',
    } = req.query;

    const pageNum = Math.max(1, parseInt(page));
    const limitNum = Math.min(100, Math.max(1, parseInt(limit)));
    const offset = (pageNum - 1) * limitNum;

    let where = ['p.is_active = 1'];
    let params = [];

    if (search) {
      where.push('(p.name LIKE ? OR p.description LIKE ? OR p.tags LIKE ? OR p.sku LIKE ?)');
      const term = `%${search}%`;
      params.push(term, term, term, term);
    }

    if (category_id) {
      const categoryIds = getSubcategoryIds(db, category_id);
      const placeholders = categoryIds.map(() => '?').join(',');
      where.push(`p.category_id IN (${placeholders})`);
      params.push(...categoryIds);
    }

    if (min_price) {
      where.push('p.price >= ?');
      params.push(parseFloat(min_price));
    }

    if (max_price) {
      where.push('p.price <= ?');
      params.push(parseFloat(max_price));
    }

    if (is_featured !== undefined && is_featured !== '') {
      where.push('p.is_featured = ?');
      params.push(is_featured === 'true' || is_featured === '1' ? 1 : 0);
    }

    const whereClause = where.length > 0 ? `WHERE ${where.join(' AND ')}` : '';

    let orderBy;
    switch (sort_by) {
      case 'price_asc':  orderBy = 'p.price ASC'; break;
      case 'price_desc': orderBy = 'p.price DESC'; break;
      case 'name':       orderBy = 'p.name ASC'; break;
      case 'newest':
      default:           orderBy = 'p.created_at DESC'; break;
    }

    // Total count
    const countRow = db.prepare(
      `SELECT COUNT(*) as total FROM products p ${whereClause}`
    ).get(...params);
    const total = countRow ? countRow.total : 0;

    // Paginated results
    const rows = db.prepare(
      `SELECT p.*, c.name as category_name, c.slug as category_slug
       FROM products p
       LEFT JOIN categories c ON p.category_id = c.id
       ${whereClause}
       ORDER BY ${orderBy}
       LIMIT ? OFFSET ?`
    ).all(...params, limitNum, offset);

    const products = rows.map(row => {
      const parsed = parseProduct(row);
      if (parsed.has_variants) {
        parsed.variants = loadProductVariants(db, parsed.id);
      } else {
        parsed.variants = [];
      }
      return parsed;
    });

    res.json({
      products,
      pagination: {
        page: pageNum,
        limit: limitNum,
        total,
        pages: Math.ceil(total / limitNum),
      },
    });
  } catch (error) {
    console.error('[products] List error:', error);
    res.status(500).json({ error: 'Error al obtener productos' });
  }
});

// ──────────────────────────────────────────────
// GET /api/products/:id — Detalle de producto (público)
// ──────────────────────────────────────────────
productsRouter.get('/:id', (req, res) => {
  try {
    const db = getDb();
    const product = db.prepare(
      `SELECT p.*, c.name as category_name, c.slug as category_slug
       FROM products p
       LEFT JOIN categories c ON p.category_id = c.id
       WHERE p.id = ?`
    ).get(req.params.id);

    if (!product) {
      return res.status(404).json({ error: 'Producto no encontrado' });
    }

    const parsed = parseProduct(product);
    // Load variants if product has them
    if (parsed.has_variants) {
      parsed.variants = loadProductVariants(db, req.params.id);
    } else {
      parsed.variants = [];
    }

    res.json({ product: parsed });
  } catch (error) {
    console.error('[products] Detail error:', error);
    res.status(500).json({ error: 'Error al obtener producto' });
  }
});

// ──────────────────────────────────────────────
// POST /api/products — Crear producto (admin)
// ──────────────────────────────────────────────
productsRouter.post('/',
  authMiddleware,
  roleMiddleware('admin'),
  [
    body('name').notEmpty().trim().withMessage('Nombre del producto requerido'),
    body('price').isFloat({ min: 0 }).withMessage('Precio debe ser un número positivo'),
    body('stock').optional().isInt({ min: 0 }).withMessage('Stock debe ser un entero positivo'),
    body('category_id').optional().isString(),
    body('sku').optional().trim(),
    body('images').optional().isArray(),
    body('tags').optional(),
    body('is_featured').optional().isBoolean(),
  ],
  (req, res) => {
    try {
      const validationError = handleValidation(req, res);
      if (validationError) return;

      const db = getDb();
      const {
        name, description, short_description, price, compare_price,
        discount_percent, sku, stock, category_id, images, is_active,
        is_featured, weight, dimensions, tags, variants,
      } = req.body;

      // Verificar categoría si se envía
      if (category_id) {
        const cat = db.prepare('SELECT id FROM categories WHERE id = ?').get(category_id);
        if (!cat) {
          return res.status(400).json({ error: 'Categoría no encontrada' });
        }
      }

      // Verificar SKU único
      if (sku) {
        const existingSku = db.prepare('SELECT id FROM products WHERE sku = ?').get(sku);
        if (existingSku) {
          return res.status(400).json({ error: 'El SKU ya está en uso' });
        }
      }

      const id = uuidv4();
      const slug = slugify(name) + '-' + id.substring(0, 8);
      const imagesJson = JSON.stringify(images || []);
      const tagsStr = Array.isArray(tags) ? tags.join(',') : (tags || '');
      const hasVariants = variants && Array.isArray(variants) && variants.length > 0 ? 1 : 0;
      const discountPct = parseFloat(discount_percent || 0);

      db.prepare(`INSERT INTO products (id, name, slug, description, short_description, price, compare_price, discount_percent, has_variants, sku, stock, category_id, images, is_active, is_featured, weight, dimensions, tags)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`).run(
        id, name, slug,
        description || '', short_description || '',
        parseFloat(price), parseFloat(compare_price || 0),
        discountPct, hasVariants,
        sku || null, parseInt(stock || 0),
        category_id || null, imagesJson,
        is_active !== undefined ? (is_active ? 1 : 0) : 1,
        is_featured ? 1 : 0,
        parseFloat(weight || 0), dimensions || '', tagsStr
      );

      // Save variants if provided
      if (hasVariants) {
        saveProductVariants(db, id, variants);
      }

      const product = db.prepare(
        `SELECT p.*, c.name as category_name, c.slug as category_slug
         FROM products p
         LEFT JOIN categories c ON p.category_id = c.id
         WHERE p.id = ?`
      ).get(id);

      const parsed = parseProduct(product);
      parsed.variants = hasVariants ? loadProductVariants(db, id) : [];

      res.status(201).json({ product: parsed, message: 'Producto creado exitosamente' });
    } catch (error) {
      console.error('[products] Create error:', error);
      res.status(500).json({ error: 'Error al crear producto' });
    }
  }
);

// ──────────────────────────────────────────────
// PUT /api/products/:id — Actualizar producto (admin)
// ──────────────────────────────────────────────
productsRouter.put('/:id',
  authMiddleware,
  roleMiddleware('admin'),
  [
    body('name').optional().notEmpty().trim().withMessage('Nombre no puede estar vacío'),
    body('price').optional().isFloat({ min: 0 }).withMessage('Precio debe ser un número positivo'),
    body('stock').optional().isInt({ min: 0 }).withMessage('Stock debe ser un entero positivo'),
  ],
  (req, res) => {
    try {
      const validationError = handleValidation(req, res);
      if (validationError) return;

      const db = getDb();
      const existing = db.prepare('SELECT * FROM products WHERE id = ?').get(req.params.id);
      if (!existing) {
        return res.status(404).json({ error: 'Producto no encontrado' });
      }

      const {
        name, description, short_description, price, compare_price,
        discount_percent, sku, stock, category_id, images, is_active,
        is_featured, weight, dimensions, tags, variants,
      } = req.body;

      // Verificar categoría si se envía
      if (category_id) {
        const cat = db.prepare('SELECT id FROM categories WHERE id = ?').get(category_id);
        if (!cat) {
          return res.status(400).json({ error: 'Categoría no encontrada' });
        }
      }

      // Verificar SKU único (excluyendo el actual)
      if (sku) {
        const existingSku = db.prepare('SELECT id FROM products WHERE sku = ? AND id != ?').get(sku, req.params.id);
        if (existingSku) {
          return res.status(400).json({ error: 'El SKU ya está en uso' });
        }
      }

      const updatedName = name !== undefined ? name : existing.name;
      const slug = name !== undefined ? slugify(name) + '-' + req.params.id.substring(0, 8) : existing.slug;
      const imagesJson = images !== undefined ? JSON.stringify(images) : existing.images;
      const tagsStr = tags !== undefined
        ? (Array.isArray(tags) ? tags.join(',') : tags)
        : existing.tags;

      const hasVariants = variants !== undefined
        ? (variants && Array.isArray(variants) && variants.length > 0 ? 1 : 0)
        : existing.has_variants;

      db.prepare(`UPDATE products SET
        name = ?, slug = ?, description = ?, short_description = ?,
        price = ?, compare_price = ?, discount_percent = ?, has_variants = ?,
        sku = ?, stock = ?,
        category_id = ?, images = ?, is_active = ?, is_featured = ?,
        weight = ?, dimensions = ?, tags = ?, updated_at = datetime('now')
        WHERE id = ?`).run(
        updatedName, slug,
        description !== undefined ? description : existing.description,
        short_description !== undefined ? short_description : existing.short_description,
        price !== undefined ? parseFloat(price) : existing.price,
        compare_price !== undefined ? parseFloat(compare_price) : existing.compare_price,
        discount_percent !== undefined ? parseFloat(discount_percent) : (existing.discount_percent || 0),
        hasVariants,
        sku !== undefined ? (sku || null) : existing.sku,
        stock !== undefined ? parseInt(stock) : existing.stock,
        category_id !== undefined ? (category_id || null) : existing.category_id,
        imagesJson,
        is_active !== undefined ? (is_active ? 1 : 0) : existing.is_active,
        is_featured !== undefined ? (is_featured ? 1 : 0) : existing.is_featured,
        weight !== undefined ? parseFloat(weight) : existing.weight,
        dimensions !== undefined ? dimensions : existing.dimensions,
        tagsStr,
        req.params.id
      );

      // Update variants if provided
      if (variants !== undefined) {
        saveProductVariants(db, req.params.id, variants);
      }

      const product = db.prepare(
        `SELECT p.*, c.name as category_name, c.slug as category_slug
         FROM products p
         LEFT JOIN categories c ON p.category_id = c.id
         WHERE p.id = ?`
      ).get(req.params.id);

      const parsed = parseProduct(product);
      parsed.variants = loadProductVariants(db, req.params.id);

      res.json({ product: parsed, message: 'Producto actualizado exitosamente' });
    } catch (error) {
      console.error('[products] Update error:', error);
      res.status(500).json({ error: 'Error al actualizar producto' });
    }
  }
);

// ──────────────────────────────────────────────
// DELETE /api/products/:id — Eliminar producto (soft delete, admin)
// ──────────────────────────────────────────────
productsRouter.delete('/:id',
  authMiddleware,
  roleMiddleware('admin'),
  (req, res) => {
    try {
      const db = getDb();
      const existing = db.prepare('SELECT id FROM products WHERE id = ?').get(req.params.id);
      if (!existing) {
        return res.status(404).json({ error: 'Producto no encontrado' });
      }

      db.prepare('UPDATE products SET is_active = 0, updated_at = datetime("now") WHERE id = ?').run(req.params.id);

      // Also deactivate variant options
      db.prepare('UPDATE product_variant_options SET is_active = 0 WHERE product_id = ?').run(req.params.id);

      res.json({ message: 'Producto eliminado exitosamente' });
    } catch (error) {
      console.error('[products] Delete error:', error);
      res.status(500).json({ error: 'Error al eliminar producto' });
    }
  }
);

// ──────────────────────────────────────────────
// PATCH /api/products/:id/stock — Actualizar stock (admin)
// ──────────────────────────────────────────────
productsRouter.patch('/:id/stock',
  authMiddleware,
  roleMiddleware('admin'),
  [
    body('stock').isInt({ min: 0 }).withMessage('Stock debe ser un entero positivo'),
  ],
  (req, res) => {
    try {
      const validationError = handleValidation(req, res);
      if (validationError) return;

      const db = getDb();
      const existing = db.prepare('SELECT id FROM products WHERE id = ?').get(req.params.id);
      if (!existing) {
        return res.status(404).json({ error: 'Producto no encontrado' });
      }

      db.prepare('UPDATE products SET stock = ?, updated_at = datetime("now") WHERE id = ?')
        .run(parseInt(req.body.stock), req.params.id);

      const product = db.prepare('SELECT * FROM products WHERE id = ?').get(req.params.id);

      res.json({ product: parseProduct(product), message: 'Stock actualizado exitosamente' });
    } catch (error) {
      console.error('[products] Stock update error:', error);
      res.status(500).json({ error: 'Error al actualizar stock' });
    }
  }
);

// ──────────────────────────────────────────────
// PATCH /api/products/:id/featured — Toggle featured (admin)
// ──────────────────────────────────────────────
productsRouter.patch('/:id/featured',
  authMiddleware,
  roleMiddleware('admin'),
  (req, res) => {
    try {
      const db = getDb();
      const existing = db.prepare('SELECT id, is_featured FROM products WHERE id = ?').get(req.params.id);
      if (!existing) {
        return res.status(404).json({ error: 'Producto no encontrado' });
      }

      const newFeatured = existing.is_featured ? 0 : 1;
      db.prepare('UPDATE products SET is_featured = ?, updated_at = datetime("now") WHERE id = ?')
        .run(newFeatured, req.params.id);

      const product = db.prepare('SELECT * FROM products WHERE id = ?').get(req.params.id);

      res.json({ product: parseProduct(product), message: `Producto ${newFeatured ? 'destacado' : 'no destacado'}` });
    } catch (error) {
      console.error('[products] Featured toggle error:', error);
      res.status(500).json({ error: 'Error al cambiar estado destacado' });
    }
  }
);

// ══════════════════════════════════════════════
//  CATEGORIES ROUTES
// ══════════════════════════════════════════════

// ──────────────────────────────────────────────
// GET /api/categories — Listar categorías en árbol (público)
// ──────────────────────────────────────────────
categoriesRouter.get('/', (req, res) => {
  try {
    const db = getDb();
    const { flat } = req.query;

    const categories = db.prepare('SELECT * FROM categories WHERE is_active = 1 ORDER BY sort_order ASC, name ASC').all();

    if (flat === 'true' || flat === '1') {
      return res.json({
        categories: categories.map(c => ({ ...c, is_active: !!c.is_active })),
      });
    }

    const tree = buildCategoryTree(categories);
    res.json({ categories: tree });
  } catch (error) {
    console.error('[categories] List error:', error);
    res.status(500).json({ error: 'Error al obtener categorías' });
  }
});

// ──────────────────────────────────────────────
// GET /api/categories/:id — Detalle de categoría con productos (público)
// ──────────────────────────────────────────────
categoriesRouter.get('/:id', (req, res) => {
  try {
    const db = getDb();
    const category = db.prepare('SELECT * FROM categories WHERE id = ?').get(req.params.id);

    if (!category) {
      return res.status(404).json({ error: 'Categoría no encontrada' });
    }

    // Obtener subcategorías directas
    const subcategories = db.prepare('SELECT * FROM categories WHERE parent_id = ? AND is_active = 1 ORDER BY sort_order ASC').all(req.params.id);

    // Obtener productos directos de la categoría
    const products = db.prepare(
      `SELECT p.*, c.name as category_name, c.slug as category_slug
       FROM products p
       LEFT JOIN categories c ON p.category_id = c.id
       WHERE p.category_id = ? AND p.is_active = 1
       ORDER BY p.created_at DESC`
    ).all(req.params.id);

    res.json({
      category: { ...category, is_active: !!category.is_active },
      subcategories: subcategories.map(c => ({ ...c, is_active: !!c.is_active })),
      products: products.map(parseProduct),
    });
  } catch (error) {
    console.error('[categories] Detail error:', error);
    res.status(500).json({ error: 'Error al obtener categoría' });
  }
});

// ──────────────────────────────────────────────
// GET /api/categories/:id/products — Productos por categoría incluyendo subcategorías (público)
// ──────────────────────────────────────────────
categoriesRouter.get('/:id/products', (req, res) => {
  try {
    const db = getDb();
    const category = db.prepare('SELECT * FROM categories WHERE id = ?').get(req.params.id);

    if (!category) {
      return res.status(404).json({ error: 'Categoría no encontrada' });
    }

    const {
      page = 1,
      limit = 20,
      sort_by = 'newest',
      min_price,
      max_price,
    } = req.query;

    const pageNum = Math.max(1, parseInt(page));
    const limitNum = Math.min(100, Math.max(1, parseInt(limit)));
    const offset = (pageNum - 1) * limitNum;

    // Obtener IDs de la categoría y subcategorías recursivas
    const categoryIds = getSubcategoryIds(db, req.params.id);
    const placeholders = categoryIds.map(() => '?').join(',');

    let where = [`p.category_id IN (${placeholders})`, 'p.is_active = 1'];
    let params = [...categoryIds];

    if (min_price) {
      where.push('p.price >= ?');
      params.push(parseFloat(min_price));
    }

    if (max_price) {
      where.push('p.price <= ?');
      params.push(parseFloat(max_price));
    }

    const whereClause = `WHERE ${where.join(' AND ')}`;

    let orderBy;
    switch (sort_by) {
      case 'price_asc':  orderBy = 'p.price ASC'; break;
      case 'price_desc': orderBy = 'p.price DESC'; break;
      case 'name':       orderBy = 'p.name ASC'; break;
      case 'newest':
      default:           orderBy = 'p.created_at DESC'; break;
    }

    const countRow = db.prepare(`SELECT COUNT(*) as total FROM products p ${whereClause}`).get(...params);
    const total = countRow ? countRow.total : 0;

    const rows = db.prepare(
      `SELECT p.*, c.name as category_name, c.slug as category_slug
       FROM products p
       LEFT JOIN categories c ON p.category_id = c.id
       ${whereClause}
       ORDER BY ${orderBy}
       LIMIT ? OFFSET ?`
    ).all(...params, limitNum, offset);

    res.json({
      category: { ...category, is_active: !!category.is_active },
      products: rows.map(parseProduct),
      pagination: {
        page: pageNum,
        limit: limitNum,
        total,
        pages: Math.ceil(total / limitNum),
      },
    });
  } catch (error) {
    console.error('[categories] Products by category error:', error);
    res.status(500).json({ error: 'Error al obtener productos de la categoría' });
  }
});

// ──────────────────────────────────────────────
// POST /api/categories — Crear categoría (admin)
// ──────────────────────────────────────────────
categoriesRouter.post('/',
  authMiddleware,
  roleMiddleware('admin'),
  [
    body('name').notEmpty().trim().withMessage('Nombre de la categoría requerido'),
    body('parent_id').optional({ nullable: true }).isString(),
    body('sort_order').optional().isInt({ min: 0 }),
  ],
  (req, res) => {
    try {
      const validationError = handleValidation(req, res);
      if (validationError) return;

      const db = getDb();
      const { name, description, image, parent_id, sort_order } = req.body;

      // Verificar categoría padre si se envía
      if (parent_id) {
        const parent = db.prepare('SELECT id FROM categories WHERE id = ?').get(parent_id);
        if (!parent) {
          return res.status(400).json({ error: 'Categoría padre no encontrada' });
        }
      }

      const id = uuidv4();
      const slug = slugify(name) + '-' + id.substring(0, 8);

      db.prepare(`INSERT INTO categories (id, name, slug, description, image, parent_id, sort_order)
        VALUES (?, ?, ?, ?, ?, ?, ?)`).run(
        id, name, slug,
        description || '', image || '',
        parent_id || null, parseInt(sort_order || 0)
      );

      const category = db.prepare('SELECT * FROM categories WHERE id = ?').get(id);

      res.status(201).json({
        category: { ...category, is_active: !!category.is_active },
        message: 'Categoría creada exitosamente',
      });
    } catch (error) {
      console.error('[categories] Create error:', error);
      res.status(500).json({ error: 'Error al crear categoría' });
    }
  }
);

// ──────────────────────────────────────────────
// PUT /api/categories/:id — Actualizar categoría (admin)
// ──────────────────────────────────────────────
categoriesRouter.put('/:id',
  authMiddleware,
  roleMiddleware('admin'),
  [
    body('name').optional().notEmpty().trim().withMessage('Nombre no puede estar vacío'),
    body('parent_id').optional({ nullable: true }),
    body('sort_order').optional().isInt({ min: 0 }),
  ],
  (req, res) => {
    try {
      const validationError = handleValidation(req, res);
      if (validationError) return;

      const db = getDb();
      const existing = db.prepare('SELECT * FROM categories WHERE id = ?').get(req.params.id);
      if (!existing) {
        return res.status(404).json({ error: 'Categoría no encontrada' });
      }

      const { name, description, image, parent_id, sort_order, is_active } = req.body;

      // Evitar que una categoría sea su propia padre
      if (parent_id === req.params.id) {
        return res.status(400).json({ error: 'Una categoría no puede ser su propia categoría padre' });
      }

      // Verificar categoría padre si se envía
      if (parent_id) {
        const parent = db.prepare('SELECT id FROM categories WHERE id = ?').get(parent_id);
        if (!parent) {
          return res.status(400).json({ error: 'Categoría padre no encontrada' });
        }
        // Evitar ciclos: verificar que el padre no sea descendiente de esta categoría
        const descendantIds = getSubcategoryIds(db, req.params.id);
        if (descendantIds.includes(parent_id)) {
          return res.status(400).json({ error: 'No se puede asignar un descendiente como categoría padre (referencia circular)' });
        }
      }

      const updatedName = name !== undefined ? name : existing.name;
      const slug = name !== undefined ? slugify(name) + '-' + req.params.id.substring(0, 8) : existing.slug;

      db.prepare(`UPDATE categories SET
        name = ?, slug = ?, description = ?, image = ?,
        parent_id = ?, sort_order = ?, is_active = ?, updated_at = datetime('now')
        WHERE id = ?`).run(
        updatedName, slug,
        description !== undefined ? description : existing.description,
        image !== undefined ? image : existing.image,
        parent_id !== undefined ? (parent_id || null) : existing.parent_id,
        sort_order !== undefined ? parseInt(sort_order) : existing.sort_order,
        is_active !== undefined ? (is_active ? 1 : 0) : existing.is_active,
        req.params.id
      );

      const category = db.prepare('SELECT * FROM categories WHERE id = ?').get(req.params.id);

      res.json({
        category: { ...category, is_active: !!category.is_active },
        message: 'Categoría actualizada exitosamente',
      });
    } catch (error) {
      console.error('[categories] Update error:', error);
      res.status(500).json({ error: 'Error al actualizar categoría' });
    }
  }
);

// ──────────────────────────────────────────────
// DELETE /api/categories/:id — Eliminar categoría (soft delete, admin)
// ──────────────────────────────────────────────
categoriesRouter.delete('/:id',
  authMiddleware,
  roleMiddleware('admin'),
  (req, res) => {
    try {
      const db = getDb();
      const existing = db.prepare('SELECT id FROM categories WHERE id = ?').get(req.params.id);
      if (!existing) {
        return res.status(404).json({ error: 'Categoría no encontrada' });
      }

      // Soft delete: desactivar categoría
      db.prepare('UPDATE categories SET is_active = 0, updated_at = datetime("now") WHERE id = ?').run(req.params.id);

      // Mover subcategorías al nivel padre (o raíz)
      const parent = db.prepare('SELECT parent_id FROM categories WHERE id = ?').get(req.params.id);
      db.prepare('UPDATE categories SET parent_id = ?, updated_at = datetime("now") WHERE parent_id = ?')
        .run(parent ? parent.parent_id : null, req.params.id);

      // Desasociar productos de esta categoría
      db.prepare('UPDATE products SET category_id = NULL, updated_at = datetime("now") WHERE category_id = ?')
        .run(req.params.id);

      res.json({ message: 'Categoría eliminada exitosamente' });
    } catch (error) {
      console.error('[categories] Delete error:', error);
      res.status(500).json({ error: 'Error al eliminar categoría' });
    }
  }
);

// ──────────────────────────────────────────────
// PATCH /api/categories/:id/sort — Actualizar orden (admin)
// ──────────────────────────────────────────────
categoriesRouter.patch('/:id/sort',
  authMiddleware,
  roleMiddleware('admin'),
  [
    body('sort_order').isInt({ min: 0 }).withMessage('Orden debe ser un entero positivo'),
  ],
  (req, res) => {
    try {
      const validationError = handleValidation(req, res);
      if (validationError) return;

      const db = getDb();
      const existing = db.prepare('SELECT id FROM categories WHERE id = ?').get(req.params.id);
      if (!existing) {
        return res.status(404).json({ error: 'Categoría no encontrada' });
      }

      db.prepare('UPDATE categories SET sort_order = ?, updated_at = datetime("now") WHERE id = ?')
        .run(parseInt(req.body.sort_order), req.params.id);

      const category = db.prepare('SELECT * FROM categories WHERE id = ?').get(req.params.id);

      res.json({
        category: { ...category, is_active: !!category.is_active },
        message: 'Orden actualizado exitosamente',
      });
    } catch (error) {
      console.error('[categories] Sort update error:', error);
      res.status(500).json({ error: 'Error al actualizar orden' });
    }
  }
);

module.exports = { productsRouter, categoriesRouter };
