const express = require('express');
const { body, param, validationResult } = require('express-validator');
const { v4: uuidv4 } = require('uuid');
const { getDb } = require('../database');
const { authMiddleware } = require('../middleware/auth');

const router = express.Router();

// ── Helpers ──

function handleValidation(req, res) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ error: errors.array()[0].msg });
  }
  return null;
}

// Todas las rutas requieren autenticación
router.use(authMiddleware);

// ══════════════════════════════════════════════
//  FAVORITES ROUTES
// ══════════════════════════════════════════════

// ──────────────────────────────────────────────
// GET /api/favorites — Mis favoritos con paginación
// ──────────────────────────────────────────────
router.get('/', (req, res) => {
  try {
    const db = getDb();
    const userId = req.user.id || req.user.userId;
    const { page = 1, limit = 20 } = req.query;

    const pageNum = Math.max(1, parseInt(page));
    const limitNum = Math.min(100, Math.max(1, parseInt(limit)));
    const offset = (pageNum - 1) * limitNum;

    // Total count
    const countRow = db.prepare(
      'SELECT COUNT(*) as total FROM favorites WHERE user_id = ?'
    ).get(userId);
    const total = countRow ? countRow.total : 0;

    // Paginated favorites
    const favorites = db.prepare(
      'SELECT * FROM favorites WHERE user_id = ? ORDER BY created_at DESC LIMIT ? OFFSET ?'
    ).all(userId, limitNum, offset);

    res.json({
      data: favorites,
      pagination: {
        page: pageNum,
        limit: limitNum,
        total,
        pages: Math.ceil(total / limitNum),
      },
    });
  } catch (error) {
    console.error('[favorites-service] Error getting favorites:', error);
    res.status(500).json({ error: 'Error al obtener los favoritos' });
  }
});

// ──────────────────────────────────────────────
// POST /api/favorites — Agregar a favoritos
// ──────────────────────────────────────────────
router.post('/', [
  body('product_id').notEmpty().withMessage('El ID del producto es requerido'),
  body('product_name').optional().isString().trim(),
  body('product_price').optional().isFloat({ min: 0 }).withMessage('El precio debe ser un número positivo'),
  body('product_image').optional().isString(),
], (req, res) => {
  try {
    const validationError = handleValidation(req, res);
    if (validationError) return;

    const db = getDb();
    const userId = req.user.id || req.user.userId;
    const { product_id, product_name, product_price, product_image } = req.body;

    // Verificar si ya existe en favoritos
    const existing = db.prepare(
      'SELECT * FROM favorites WHERE user_id = ? AND product_id = ?'
    ).get(userId, product_id);

    if (existing) {
      return res.json({
        message: 'El producto ya está en favoritos',
        data: existing,
      });
    }

    const id = uuidv4();
    db.prepare(
      `INSERT INTO favorites (id, user_id, product_id, product_name, product_price, product_image)
       VALUES (?, ?, ?, ?, ?, ?)`
    ).run(id, userId, product_id, product_name || '', product_price || 0, product_image || '');

    const favorite = db.prepare('SELECT * FROM favorites WHERE id = ?').get(id);

    res.status(201).json({
      message: 'Producto agregado a favoritos',
      data: favorite,
    });
  } catch (error) {
    console.error('[favorites-service] Error adding favorite:', error);
    res.status(500).json({ error: 'Error al agregar a favoritos' });
  }
});

// ──────────────────────────────────────────────
// GET /api/favorites/check/:productId — Verificar si está en favoritos
// ──────────────────────────────────────────────
router.get('/check/:productId', (req, res) => {
  try {
    const db = getDb();
    const userId = req.user.id || req.user.userId;
    const { productId } = req.params;

    const favorite = db.prepare(
      'SELECT * FROM favorites WHERE user_id = ? AND product_id = ?'
    ).get(userId, productId);

    res.json({
      data: {
        isFavorite: !!favorite,
        favorite: favorite || null,
      },
    });
  } catch (error) {
    console.error('[favorites-service] Error checking favorite:', error);
    res.status(500).json({ error: 'Error al verificar favorito' });
  }
});

// ──────────────────────────────────────────────
// DELETE /api/favorites/:productId — Eliminar de favoritos (por product_id)
// ──────────────────────────────────────────────
router.delete('/:productId', (req, res) => {
  try {
    const db = getDb();
    const userId = req.user.id || req.user.userId;
    const { productId } = req.params;

    const favorite = db.prepare(
      'SELECT * FROM favorites WHERE user_id = ? AND product_id = ?'
    ).get(userId, productId);

    if (!favorite) {
      return res.status(404).json({ error: 'Producto no encontrado en favoritos' });
    }

    db.prepare(
      'DELETE FROM favorites WHERE user_id = ? AND product_id = ?'
    ).run(userId, productId);

    res.json({ message: 'Producto eliminado de favoritos' });
  } catch (error) {
    console.error('[favorites-service] Error removing favorite:', error);
    res.status(500).json({ error: 'Error al eliminar de favoritos' });
  }
});

// ──────────────────────────────────────────────
// DELETE /api/favorites — Vaciar todos los favoritos
// ──────────────────────────────────────────────
router.delete('/', (req, res) => {
  try {
    const db = getDb();
    const userId = req.user.id || req.user.userId;

    const result = db.prepare('DELETE FROM favorites WHERE user_id = ?').run(userId);

    res.json({
      message: 'Favoritos vaciados',
      data: { deletedCount: result.changes },
    });
  } catch (error) {
    console.error('[favorites-service] Error clearing favorites:', error);
    res.status(500).json({ error: 'Error al vaciar los favoritos' });
  }
});

module.exports = router;
