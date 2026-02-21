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
//  CART ROUTES
// ══════════════════════════════════════════════

// ──────────────────────────────────────────────
// GET /api/cart — Obtener carrito del usuario
// ──────────────────────────────────────────────
router.get('/', (req, res) => {
  try {
    const db = getDb();
    const userId = req.user.id || req.user.userId;

    const items = db.prepare(
      'SELECT * FROM cart_items WHERE user_id = ? ORDER BY created_at DESC'
    ).all(userId);

    const subtotal = items.reduce((sum, item) => sum + (item.product_price || 0) * (item.quantity || 1), 0);
    const itemCount = items.reduce((count, item) => count + (item.quantity || 1), 0);

    res.json({
      data: {
        items,
        subtotal: Math.round(subtotal * 100) / 100,
        itemCount,
      },
    });
  } catch (error) {
    console.error('[cart-service] Error getting cart:', error);
    res.status(500).json({ error: 'Error al obtener el carrito' });
  }
});

// ──────────────────────────────────────────────
// GET /api/cart/count — Obtener cantidad de items
// ──────────────────────────────────────────────
router.get('/count', (req, res) => {
  try {
    const db = getDb();
    const userId = req.user.id || req.user.userId;

    const result = db.prepare(
      'SELECT COALESCE(SUM(quantity), 0) as count FROM cart_items WHERE user_id = ?'
    ).get(userId);

    res.json({ data: { count: result ? result.count : 0 } });
  } catch (error) {
    console.error('[cart-service] Error getting cart count:', error);
    res.status(500).json({ error: 'Error al obtener la cantidad de items' });
  }
});

// ──────────────────────────────────────────────
// POST /api/cart/items — Agregar item al carrito
// ──────────────────────────────────────────────
router.post('/items', [
  body('product_id').notEmpty().withMessage('El ID del producto es requerido'),
  body('product_name').notEmpty().withMessage('El nombre del producto es requerido'),
  body('product_price')
    .isFloat({ min: 0 }).withMessage('El precio debe ser un número positivo'),
  body('product_image').optional().isString(),
  body('quantity')
    .optional()
    .isInt({ min: 1 }).withMessage('La cantidad debe ser al menos 1'),
], (req, res) => {
  try {
    const validationError = handleValidation(req, res);
    if (validationError) return;

    const db = getDb();
    const userId = req.user.id || req.user.userId;
    const { product_id, product_name, product_price, product_image, quantity = 1 } = req.body;

    // Verificar si el producto ya está en el carrito
    const existing = db.prepare(
      'SELECT * FROM cart_items WHERE user_id = ? AND product_id = ?'
    ).get(userId, product_id);

    if (existing) {
      // Incrementar cantidad
      const newQuantity = existing.quantity + quantity;
      db.prepare(
        "UPDATE cart_items SET quantity = ?, updated_at = datetime('now') WHERE id = ?"
      ).run(newQuantity, existing.id);

      const updated = db.prepare('SELECT * FROM cart_items WHERE id = ?').get(existing.id);
      return res.json({
        message: 'Cantidad actualizada en el carrito',
        data: updated,
      });
    }

    // Insertar nuevo item
    const id = uuidv4();
    db.prepare(
      `INSERT INTO cart_items (id, user_id, product_id, product_name, product_price, product_image, quantity)
       VALUES (?, ?, ?, ?, ?, ?, ?)`
    ).run(id, userId, product_id, product_name, product_price, product_image || '', quantity);

    const newItem = db.prepare('SELECT * FROM cart_items WHERE id = ?').get(id);
    res.status(201).json({
      message: 'Producto agregado al carrito',
      data: newItem,
    });
  } catch (error) {
    console.error('[cart-service] Error adding item to cart:', error);
    res.status(500).json({ error: 'Error al agregar al carrito' });
  }
});

// ──────────────────────────────────────────────
// PUT /api/cart/items/:id — Actualizar cantidad
// ──────────────────────────────────────────────
router.put('/items/:id', [
  param('id').notEmpty().withMessage('El ID del item es requerido'),
  body('quantity')
    .isInt({ min: 1 }).withMessage('La cantidad debe ser al menos 1'),
], (req, res) => {
  try {
    const validationError = handleValidation(req, res);
    if (validationError) return;

    const db = getDb();
    const userId = req.user.id || req.user.userId;
    const { id } = req.params;
    const { quantity } = req.body;

    // Verificar que el item pertenece al usuario
    const item = db.prepare(
      'SELECT * FROM cart_items WHERE id = ? AND user_id = ?'
    ).get(id, userId);

    if (!item) {
      return res.status(404).json({ error: 'Item no encontrado en el carrito' });
    }

    db.prepare(
      "UPDATE cart_items SET quantity = ?, updated_at = datetime('now') WHERE id = ?"
    ).run(quantity, id);

    const updated = db.prepare('SELECT * FROM cart_items WHERE id = ?').get(id);
    res.json({
      message: 'Cantidad actualizada',
      data: updated,
    });
  } catch (error) {
    console.error('[cart-service] Error updating cart item:', error);
    res.status(500).json({ error: 'Error al actualizar el item' });
  }
});

// ──────────────────────────────────────────────
// DELETE /api/cart/items/:id — Eliminar item
// ──────────────────────────────────────────────
router.delete('/items/:id', [
  param('id').notEmpty().withMessage('El ID del item es requerido'),
], (req, res) => {
  try {
    const validationError = handleValidation(req, res);
    if (validationError) return;

    const db = getDb();
    const userId = req.user.id || req.user.userId;
    const { id } = req.params;

    // Verificar que el item pertenece al usuario
    const item = db.prepare(
      'SELECT * FROM cart_items WHERE id = ? AND user_id = ?'
    ).get(id, userId);

    if (!item) {
      return res.status(404).json({ error: 'Item no encontrado en el carrito' });
    }

    db.prepare('DELETE FROM cart_items WHERE id = ?').run(id);

    res.json({ message: 'Item eliminado del carrito' });
  } catch (error) {
    console.error('[cart-service] Error deleting cart item:', error);
    res.status(500).json({ error: 'Error al eliminar el item' });
  }
});

// ──────────────────────────────────────────────
// DELETE /api/cart — Vaciar carrito completo
// ──────────────────────────────────────────────
router.delete('/', (req, res) => {
  try {
    const db = getDb();
    const userId = req.user.id || req.user.userId;

    const result = db.prepare('DELETE FROM cart_items WHERE user_id = ?').run(userId);

    res.json({
      message: 'Carrito vaciado',
      data: { deletedCount: result.changes },
    });
  } catch (error) {
    console.error('[cart-service] Error clearing cart:', error);
    res.status(500).json({ error: 'Error al vaciar el carrito' });
  }
});

module.exports = router;
