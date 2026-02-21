const express = require('express');
const { body, param, validationResult } = require('express-validator');
const { v4: uuidv4 } = require('uuid');
const { getDb } = require('../database');
const { authMiddleware, roleMiddleware } = require('../middleware/auth');

const router = express.Router();

// ── Helpers ──

function handleValidation(req, res) {
  const errors = validationResult(req);
  if (!errors.isEmpty()) {
    return res.status(400).json({ error: errors.array()[0].msg });
  }
  return null;
}

// ══════════════════════════════════════════════
//  PUBLIC ROUTES
// ══════════════════════════════════════════════

// ──────────────────────────────────────────────
// GET /api/reviews/product/:productId — Reseñas de un producto
// ──────────────────────────────────────────────
router.get('/product/:productId', (req, res) => {
  try {
    const db = getDb();
    const { productId } = req.params;
    const { page = 1, limit = 10, sort_by = 'newest' } = req.query;

    const pageNum = Math.max(1, parseInt(page));
    const limitNum = Math.min(100, Math.max(1, parseInt(limit)));
    const offset = (pageNum - 1) * limitNum;

    let orderBy;
    switch (sort_by) {
      case 'rating_asc':  orderBy = 'r.rating ASC'; break;
      case 'rating_desc': orderBy = 'r.rating DESC'; break;
      case 'oldest':      orderBy = 'r.created_at ASC'; break;
      case 'newest':
      default:            orderBy = 'r.created_at DESC'; break;
    }

    // Total count (solo aprobadas)
    const countRow = db.prepare(
      'SELECT COUNT(*) as total FROM reviews WHERE product_id = ? AND is_approved = 1'
    ).get(productId);
    const total = countRow ? countRow.total : 0;

    // Average rating
    const avgRow = db.prepare(
      'SELECT AVG(rating) as avg_rating FROM reviews WHERE product_id = ? AND is_approved = 1'
    ).get(productId);
    const avgRating = avgRow && avgRow.avg_rating ? Math.round(avgRow.avg_rating * 10) / 10 : 0;

    // Paginated reviews
    const reviews = db.prepare(
      `SELECT r.* FROM reviews r
       WHERE r.product_id = ? AND r.is_approved = 1
       ORDER BY ${orderBy}
       LIMIT ? OFFSET ?`
    ).all(productId, limitNum, offset);

    res.json({
      data: {
        reviews,
        avgRating,
        totalReviews: total,
      },
      pagination: {
        page: pageNum,
        limit: limitNum,
        total,
        pages: Math.ceil(total / limitNum),
      },
    });
  } catch (error) {
    console.error('[reviews-service] Error getting product reviews:', error);
    res.status(500).json({ error: 'Error al obtener las reseñas del producto' });
  }
});

// ──────────────────────────────────────────────
// GET /api/reviews/product/:productId/summary — Resumen de ratings
// ──────────────────────────────────────────────
router.get('/product/:productId/summary', (req, res) => {
  try {
    const db = getDb();
    const { productId } = req.params;

    const avgRow = db.prepare(
      'SELECT AVG(rating) as avg_rating, COUNT(*) as total FROM reviews WHERE product_id = ? AND is_approved = 1'
    ).get(productId);

    const avgRating = avgRow && avgRow.avg_rating ? Math.round(avgRow.avg_rating * 10) / 10 : 0;
    const total = avgRow ? avgRow.total : 0;

    // Count per star
    const distribution = {};
    for (let star = 1; star <= 5; star++) {
      const row = db.prepare(
        'SELECT COUNT(*) as count FROM reviews WHERE product_id = ? AND is_approved = 1 AND rating = ?'
      ).get(productId, star);
      distribution[star] = row ? row.count : 0;
    }

    res.json({
      data: {
        avgRating,
        total,
        distribution,
      },
    });
  } catch (error) {
    console.error('[reviews-service] Error getting review summary:', error);
    res.status(500).json({ error: 'Error al obtener el resumen de reseñas' });
  }
});

// ══════════════════════════════════════════════
//  AUTH ROUTES (any authenticated user)
// ══════════════════════════════════════════════

// ──────────────────────────────────────────────
// GET /api/reviews/me — Mis reseñas
// ──────────────────────────────────────────────
router.get('/me', authMiddleware, (req, res) => {
  try {
    const db = getDb();
    const userId = req.user.id || req.user.userId;

    const reviews = db.prepare(
      'SELECT * FROM reviews WHERE user_id = ? ORDER BY created_at DESC'
    ).all(userId);

    res.json({ data: reviews });
  } catch (error) {
    console.error('[reviews-service] Error getting my reviews:', error);
    res.status(500).json({ error: 'Error al obtener tus reseñas' });
  }
});

// ──────────────────────────────────────────────
// POST /api/reviews — Crear reseña
// ──────────────────────────────────────────────
router.post('/', authMiddleware, [
  body('product_id').notEmpty().withMessage('El ID del producto es requerido'),
  body('rating')
    .isInt({ min: 1, max: 5 }).withMessage('La calificación debe ser entre 1 y 5'),
  body('title').optional().isString().trim(),
  body('comment').optional().isString().trim(),
], (req, res) => {
  try {
    const validationError = handleValidation(req, res);
    if (validationError) return;

    const db = getDb();
    const userId = req.user.id || req.user.userId;
    const { product_id, rating, title, comment } = req.body;

    // Verificar si ya existe una reseña de este usuario para este producto
    const existing = db.prepare(
      'SELECT * FROM reviews WHERE product_id = ? AND user_id = ?'
    ).get(product_id, userId);

    if (existing) {
      return res.status(409).json({ error: 'Ya has dejado una reseña para este producto' });
    }

    const id = uuidv4();
    db.prepare(
      `INSERT INTO reviews (id, product_id, user_id, rating, title, comment)
       VALUES (?, ?, ?, ?, ?, ?)`
    ).run(id, product_id, userId, rating, title || '', comment || '');

    const review = db.prepare('SELECT * FROM reviews WHERE id = ?').get(id);

    res.status(201).json({
      message: 'Reseña creada exitosamente',
      data: review,
    });
  } catch (error) {
    console.error('[reviews-service] Error creating review:', error);
    res.status(500).json({ error: 'Error al crear la reseña' });
  }
});

// ──────────────────────────────────────────────
// PUT /api/reviews/:id — Actualizar mi reseña
// ──────────────────────────────────────────────
router.put('/:id', authMiddleware, [
  param('id').notEmpty().withMessage('El ID de la reseña es requerido'),
  body('rating')
    .optional()
    .isInt({ min: 1, max: 5 }).withMessage('La calificación debe ser entre 1 y 5'),
  body('title').optional().isString().trim(),
  body('comment').optional().isString().trim(),
], (req, res) => {
  try {
    const validationError = handleValidation(req, res);
    if (validationError) return;

    const db = getDb();
    const userId = req.user.id || req.user.userId;
    const { id } = req.params;

    // Verificar que la reseña pertenece al usuario
    const review = db.prepare(
      'SELECT * FROM reviews WHERE id = ? AND user_id = ?'
    ).get(id, userId);

    if (!review) {
      return res.status(404).json({ error: 'Reseña no encontrada' });
    }

    const { rating, title, comment } = req.body;

    const newRating = rating !== undefined ? rating : review.rating;
    const newTitle = title !== undefined ? title : review.title;
    const newComment = comment !== undefined ? comment : review.comment;

    db.prepare(
      "UPDATE reviews SET rating = ?, title = ?, comment = ?, updated_at = datetime('now') WHERE id = ?"
    ).run(newRating, newTitle, newComment, id);

    const updated = db.prepare('SELECT * FROM reviews WHERE id = ?').get(id);

    res.json({
      message: 'Reseña actualizada exitosamente',
      data: updated,
    });
  } catch (error) {
    console.error('[reviews-service] Error updating review:', error);
    res.status(500).json({ error: 'Error al actualizar la reseña' });
  }
});

// ──────────────────────────────────────────────
// DELETE /api/reviews/:id — Eliminar mi reseña
// ──────────────────────────────────────────────
router.delete('/:id', authMiddleware, [
  param('id').notEmpty().withMessage('El ID de la reseña es requerido'),
], (req, res) => {
  try {
    const validationError = handleValidation(req, res);
    if (validationError) return;

    const db = getDb();
    const userId = req.user.id || req.user.userId;
    const { id } = req.params;

    // Verificar que la reseña pertenece al usuario (o es admin)
    const review = db.prepare(
      'SELECT * FROM reviews WHERE id = ?'
    ).get(id);

    if (!review) {
      return res.status(404).json({ error: 'Reseña no encontrada' });
    }

    if (review.user_id !== userId && req.user.role !== 'admin') {
      return res.status(403).json({ error: 'No tienes permisos para eliminar esta reseña' });
    }

    db.prepare('DELETE FROM reviews WHERE id = ?').run(id);

    res.json({ message: 'Reseña eliminada exitosamente' });
  } catch (error) {
    console.error('[reviews-service] Error deleting review:', error);
    res.status(500).json({ error: 'Error al eliminar la reseña' });
  }
});

// ══════════════════════════════════════════════
//  ADMIN ROUTES
// ══════════════════════════════════════════════

// ──────────────────────────────────────────────
// GET /api/reviews — Todas las reseñas (admin)
// ──────────────────────────────────────────────
router.get('/', authMiddleware, roleMiddleware('admin'), (req, res) => {
  try {
    const db = getDb();
    const { page = 1, limit = 20, product_id, rating, is_approved } = req.query;

    const pageNum = Math.max(1, parseInt(page));
    const limitNum = Math.min(100, Math.max(1, parseInt(limit)));
    const offset = (pageNum - 1) * limitNum;

    let where = [];
    let params = [];

    if (product_id) {
      where.push('product_id = ?');
      params.push(product_id);
    }

    if (rating) {
      where.push('rating = ?');
      params.push(parseInt(rating));
    }

    if (is_approved !== undefined && is_approved !== '') {
      where.push('is_approved = ?');
      params.push(is_approved === 'true' || is_approved === '1' ? 1 : 0);
    }

    const whereClause = where.length > 0 ? `WHERE ${where.join(' AND ')}` : '';

    const countRow = db.prepare(
      `SELECT COUNT(*) as total FROM reviews ${whereClause}`
    ).get(...params);
    const total = countRow ? countRow.total : 0;

    const reviews = db.prepare(
      `SELECT * FROM reviews ${whereClause} ORDER BY created_at DESC LIMIT ? OFFSET ?`
    ).all(...params, limitNum, offset);

    res.json({
      data: reviews,
      pagination: {
        page: pageNum,
        limit: limitNum,
        total,
        pages: Math.ceil(total / limitNum),
      },
    });
  } catch (error) {
    console.error('[reviews-service] Error getting all reviews:', error);
    res.status(500).json({ error: 'Error al obtener las reseñas' });
  }
});

// ──────────────────────────────────────────────
// PATCH /api/reviews/:id/approve — Aprobar/rechazar reseña (admin)
// ──────────────────────────────────────────────
router.patch('/:id/approve', authMiddleware, roleMiddleware('admin'), [
  param('id').notEmpty().withMessage('El ID de la reseña es requerido'),
  body('is_approved')
    .isIn([0, 1, true, false]).withMessage('is_approved debe ser 0, 1, true o false'),
], (req, res) => {
  try {
    const validationError = handleValidation(req, res);
    if (validationError) return;

    const db = getDb();
    const { id } = req.params;
    const { is_approved } = req.body;

    const review = db.prepare('SELECT * FROM reviews WHERE id = ?').get(id);
    if (!review) {
      return res.status(404).json({ error: 'Reseña no encontrada' });
    }

    const approvedValue = (is_approved === true || is_approved === 1) ? 1 : 0;

    db.prepare(
      "UPDATE reviews SET is_approved = ?, updated_at = datetime('now') WHERE id = ?"
    ).run(approvedValue, id);

    const updated = db.prepare('SELECT * FROM reviews WHERE id = ?').get(id);

    res.json({
      message: approvedValue ? 'Reseña aprobada' : 'Reseña rechazada',
      data: updated,
    });
  } catch (error) {
    console.error('[reviews-service] Error approving review:', error);
    res.status(500).json({ error: 'Error al aprobar/rechazar la reseña' });
  }
});

module.exports = router;
