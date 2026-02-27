const express = require('express');
const { body, validationResult } = require('express-validator');
const { getDb } = require('../database');
const { authMiddleware, roleMiddleware } = require('../middleware/auth');

const configRouter = express.Router();

// ── Helpers ──

function handleValidation(req, res) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ error: errors.array()[0].msg });
  }
  return null;
}

/**
 * Read all config key-values and banners, return as a single object.
 */
function readFullConfig(db) {
  const rows = db.prepare('SELECT key, value FROM store_config').all();
  const config = {};
  for (const row of rows) {
    config[row.key] = row.value;
  }

  // Banners
  const banners = db.prepare('SELECT * FROM banners ORDER BY sort_order ASC, id ASC').all();

  return {
    store_name: config.store_name || 'BaseShop',
    store_logo: config.store_logo || '',
    show_header: config.show_header === '1',
    show_footer: config.show_footer === '1',
    featured_title: config.featured_title || 'Colección destacada',
    featured_desc: config.featured_desc || 'Los productos más elegidos por nuestros clientes',
    primary_color_hex: config.primary_color_hex || 'F97316',
    policies_content: config.policies_content || '',
    support_email: config.support_email || '',
    support_phone: config.support_phone || '',
    support_whatsapp: config.support_whatsapp || '',
    support_schedule: config.support_schedule || '',
    banners: banners.map(b => ({
      id: b.id,
      image_path: b.image_path,
      product_id: b.product_id || null,
      custom_price: b.custom_price || null,
      sort_order: b.sort_order,
    })),
  };
}

// ══════════════════════════════════════════════
//  GET /api/config — Public: get store config
// ══════════════════════════════════════════════
configRouter.get('/', (req, res) => {
  try {
    const db = getDb();
    const config = readFullConfig(db);
    res.json(config);
  } catch (err) {
    console.error('[config] GET error:', err.message);
    res.status(500).json({ error: 'Error al obtener la configuración' });
  }
});

// ══════════════════════════════════════════════
//  PUT /api/config — Admin: update store config
// ══════════════════════════════════════════════
configRouter.put(
  '/',
  authMiddleware,
  roleMiddleware('admin'),
  [
    body('store_name').optional().isString().isLength({ max: 100 }),
    body('store_logo').optional().isString(),
    body('show_header').optional().isBoolean(),
    body('show_footer').optional().isBoolean(),
    body('featured_title').optional().isString().isLength({ max: 200 }),
    body('featured_desc').optional().isString().isLength({ max: 500 }),
    body('primary_color_hex').optional().isString().matches(/^[0-9A-Fa-f]{6}$/),
    body('policies_content').optional().isString().isLength({ max: 50000 }),
    body('support_email').optional().isString().isLength({ max: 200 }),
    body('support_phone').optional().isString().isLength({ max: 50 }),
    body('support_whatsapp').optional().isString().isLength({ max: 50 }),
    body('support_schedule').optional().isString().isLength({ max: 500 }),
    body('banners').optional().isArray(),
    body('banners.*.image_path').optional({ nullable: true }).isString(),
    body('banners.*.product_id').optional({ nullable: true }).isString(),
    body('banners.*.custom_price').optional({ nullable: true }).isFloat({ min: 0 }),
    body('banners.*.sort_order').optional({ nullable: true }).isInt({ min: 0 }),
  ],
  (req, res) => {
    const err = handleValidation(req, res);
    if (err) return;

    try {
      const db = getDb();
      const {
        store_name,
        store_logo,
        show_header,
        show_footer,
        featured_title,
        featured_desc,
        primary_color_hex,
        policies_content,
        support_email,
        support_phone,
        support_whatsapp,
        support_schedule,
        banners,
      } = req.body;

      // Update key-value config
      const upsert = db.prepare(
        `INSERT INTO store_config (key, value, updated_at)
         VALUES (?, ?, datetime('now'))
         ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = excluded.updated_at`
      );

      if (store_name !== undefined) upsert.run('store_name', store_name);
      if (store_logo !== undefined) upsert.run('store_logo', store_logo);
      if (show_header !== undefined) upsert.run('show_header', show_header ? '1' : '0');
      if (show_footer !== undefined) upsert.run('show_footer', show_footer ? '1' : '0');
      if (featured_title !== undefined) upsert.run('featured_title', featured_title);
      if (featured_desc !== undefined) upsert.run('featured_desc', featured_desc);
      if (primary_color_hex !== undefined) upsert.run('primary_color_hex', primary_color_hex.toUpperCase());
      if (policies_content !== undefined) upsert.run('policies_content', policies_content);
      if (support_email !== undefined) upsert.run('support_email', support_email);
      if (support_phone !== undefined) upsert.run('support_phone', support_phone);
      if (support_whatsapp !== undefined) upsert.run('support_whatsapp', support_whatsapp);
      if (support_schedule !== undefined) upsert.run('support_schedule', support_schedule);

      // Replace banners if provided
      if (banners !== undefined) {
        db.exec('DELETE FROM banners');
        const insertBanner = db.prepare(
          'INSERT INTO banners (image_path, product_id, custom_price, sort_order) VALUES (?, ?, ?, ?)'
        );
        banners.forEach((b, i) => {
          insertBanner.run(
            b.image_path || '',
            b.product_id || null,
            b.custom_price != null ? b.custom_price : null,
            i,
          );
        });
      }

      const config = readFullConfig(db);
      res.json({ message: 'Configuración actualizada', ...config });
    } catch (err) {
      console.error('[config] PUT error:', err.message);
      res.status(500).json({ error: 'Error al actualizar la configuración' });
    }
  }
);

module.exports = { configRouter };
