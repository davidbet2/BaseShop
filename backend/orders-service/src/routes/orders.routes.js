const express = require('express');
const { body, param, query, validationResult } = require('express-validator');
const { v4: uuidv4 } = require('uuid');
const { getDb, generateOrderNumber } = require('../database');
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

// Transiciones de estado válidas
const VALID_TRANSITIONS = {
  pending: ['confirmed', 'cancelled'],
  confirmed: ['processing', 'cancelled'],
  processing: ['shipped', 'cancelled'],
  shipped: ['delivered'],
  delivered: ['refunded'],
  cancelled: [],
  refunded: [],
};

const VALID_STATUSES = Object.keys(VALID_TRANSITIONS);

// ══════════════════════════════════════════════
//  INTERNAL SERVICE-TO-SERVICE ROUTES (no JWT)
// ══════════════════════════════════════════════

// ──────────────────────────────────────────────
// PATCH /api/orders/:id/payment-status — Update order status from payments-service
// ──────────────────────────────────────────────
router.patch('/:id/payment-status', [
  param('id').notEmpty().withMessage('El ID del pedido es requerido'),
  body('status').notEmpty().isIn(VALID_STATUSES).withMessage('Estado inválido'),
  body('payment_id').optional().isString(),
  body('payment_status').optional().isString(),
  body('note').optional().isString(),
], (req, res) => {
  try {
    // H1 fix: verify internal service secret, not just header presence
    const internalHeader = req.headers['x-internal-service'];
    const expectedSecret = process.env.INTERNAL_SERVICE_SECRET || 'baseshop-internal-dev';
    if (!internalHeader || internalHeader !== expectedSecret) {
      return res.status(403).json({ error: 'Acceso no autorizado' });
    }

    const validationError = handleValidation(req, res);
    if (validationError) return;

    const db = getDb();
    const { id } = req.params;
    const { status: newStatus, payment_id, payment_status, note } = req.body;

    const order = db.prepare('SELECT * FROM orders WHERE id = ?').get(id);
    if (!order) {
      return res.status(404).json({ error: 'Pedido no encontrado' });
    }

    // Validate transition
    const allowedTransitions = VALID_TRANSITIONS[order.status] || [];
    if (!allowedTransitions.includes(newStatus)) {
      return res.status(400).json({
        error: `Transición no permitida: ${order.status} → ${newStatus}`,
      });
    }

    // Update order status and payment_id
    db.prepare(
      "UPDATE orders SET status = ?, payment_id = CASE WHEN ? != '' THEN ? ELSE payment_id END, updated_at = datetime('now') WHERE id = ?"
    ).run(newStatus, payment_id || '', payment_id || '', id);

    // Log in status history
    db.prepare(
      `INSERT INTO order_status_history (id, order_id, status, note, changed_by)
       VALUES (?, ?, ?, ?, 'payments-service')`
    ).run(uuidv4(), id, newStatus, note || `Pago ${payment_status || newStatus}`);

    const updatedOrder = db.prepare('SELECT * FROM orders WHERE id = ?').get(id);
    console.log(`[orders-service] Order ${id} updated to ${newStatus} by payments-service`);

    res.json({
      message: `Estado actualizado a '${newStatus}'`,
      data: updatedOrder,
    });
  } catch (error) {
    console.error('[orders-service] Error updating order from payment:', error);
    res.status(500).json({ error: 'Error al actualizar el pedido' });
  }
});

// Todas las rutas siguientes requieren autenticación
router.use(authMiddleware);

// ══════════════════════════════════════════════
//  CLIENT ROUTES (authenticated users)
// ══════════════════════════════════════════════

// ──────────────────────────────────────────────
// POST /api/orders — Crear pedido
// ──────────────────────────────────────────────
router.post('/', [
  body('items')
    .isArray({ min: 1 }).withMessage('Debe incluir al menos un producto'),
  body('items.*.product_id')
    .notEmpty().withMessage('El ID del producto es requerido'),
  body('items.*.product_name')
    .notEmpty().withMessage('El nombre del producto es requerido'),
  body('items.*.product_price')
    .isFloat({ min: 0 }).withMessage('El precio debe ser un número positivo'),
  body('items.*.quantity')
    .optional().isInt({ min: 1 }).withMessage('La cantidad debe ser al menos 1'),
  body('shipping_address')
    .notEmpty().withMessage('La dirección de envío es requerida'),
  body('billing_address')
    .optional(),
  body('payment_method')
    .optional().isString(),
  body('customer_name')
    .optional().isString(),
  body('customer_email')
    .optional().isEmail(),
  body('customer_phone')
    .optional().isString(),
  body('notes')
    .optional().isString(),
], (req, res) => {
  try {
    const validationError = handleValidation(req, res);
    if (validationError) return;

    const db = getDb();
    const userId = req.user.id || req.user.userId;
    const userEmail = req.user.email || '';
    const { items, shipping_address, billing_address, payment_method, notes, customer_name, customer_email, customer_phone } = req.body;

    // Calcular totales
    let subtotal = 0;
    const processedItems = items.map(item => {
      const qty = item.quantity || 1;
      const itemSubtotal = (item.product_price || 0) * qty;
      subtotal += itemSubtotal;
      return { ...item, quantity: qty, subtotal: Math.round(itemSubtotal * 100) / 100 };
    });

    subtotal = Math.round(subtotal * 100) / 100;
    const shippingCost = 0; // puede configurarse después
    const tax = Math.round(subtotal * 0.19 * 100) / 100;
    const total = Math.round((subtotal + shippingCost + tax) * 100) / 100;

    // Generar order_number e ID
    const orderId = uuidv4();
    const orderNumber = generateOrderNumber();

    // Serializar direcciones como JSON
    const shippingAddrStr = typeof shipping_address === 'object' ? JSON.stringify(shipping_address) : (shipping_address || '');
    const billingAddrStr = typeof billing_address === 'object' ? JSON.stringify(billing_address) : (billing_address || '');

    // Resolver nombre del cliente
    const resolvedName = customer_name || '';
    const resolvedEmail = customer_email || userEmail || '';
    const resolvedPhone = customer_phone || '';

    // Insertar pedido
    db.prepare(
      `INSERT INTO orders (id, order_number, user_id, customer_name, customer_email, customer_phone, status, subtotal, shipping_cost, tax, total, shipping_address, billing_address, payment_method, payment_id, notes)
       VALUES (?, ?, ?, ?, ?, ?, 'pending', ?, ?, ?, ?, ?, ?, ?, '', ?)`
    ).run(orderId, orderNumber, userId, resolvedName, resolvedEmail, resolvedPhone, subtotal, shippingCost, tax, total, shippingAddrStr, billingAddrStr, payment_method || '', notes || '');

    // Insertar items del pedido
    for (const item of processedItems) {
      const itemId = uuidv4();
      db.prepare(
        `INSERT INTO order_items (id, order_id, product_id, product_name, product_price, product_image, quantity, subtotal)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
      ).run(itemId, orderId, item.product_id, item.product_name, item.product_price, item.product_image || '', item.quantity, item.subtotal);
    }

    // Registrar estado inicial en historial
    db.prepare(
      `INSERT INTO order_status_history (id, order_id, status, note, changed_by)
       VALUES (?, ?, 'pending', 'Pedido creado', ?)`
    ).run(uuidv4(), orderId, userId);

    // Obtener pedido completo
    const order = db.prepare('SELECT * FROM orders WHERE id = ?').get(orderId);
    const orderItems = db.prepare('SELECT * FROM order_items WHERE order_id = ? ORDER BY created_at').all(orderId);

    res.status(201).json({
      message: 'Pedido creado exitosamente',
      data: { ...order, items: orderItems },
    });
  } catch (error) {
    console.error('[orders-service] Error creating order:', error);
    res.status(500).json({ error: 'Error al crear el pedido' });
  }
});

// ──────────────────────────────────────────────
// GET /api/orders/me — Listar mis pedidos
// ──────────────────────────────────────────────
router.get('/me', (req, res) => {
  try {
    const db = getDb();
    const userId = req.user.id || req.user.userId;
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(50, Math.max(1, parseInt(req.query.limit) || 10));
    const offset = (page - 1) * limit;
    const status = req.query.status;

    let countSql = 'SELECT COUNT(*) as total FROM orders WHERE user_id = ?';
    let dataSql = 'SELECT * FROM orders WHERE user_id = ?';
    const params = [userId];

    if (status && VALID_STATUSES.includes(status)) {
      countSql += ' AND status = ?';
      dataSql += ' AND status = ?';
      params.push(status);
    }

    dataSql += ' ORDER BY created_at DESC LIMIT ? OFFSET ?';

    const countResult = db.prepare(countSql).get(...params);
    const total = countResult ? countResult.total : 0;
    const orders = db.prepare(dataSql).all(...params, limit, offset);

    // Enrich orders with items from order_items table
    const enriched = orders.map(order => {
      const items = db.prepare(
        'SELECT product_id, product_name, product_price, product_image, quantity, subtotal FROM order_items WHERE order_id = ? ORDER BY created_at'
      ).all(order.id);
      return { ...order, items, items_count: items.length };
    });

    res.json({
      data: enriched,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    });
  } catch (error) {
    console.error('[orders-service] Error listing my orders:', error);
    res.status(500).json({ error: 'Error al listar los pedidos' });
  }
});

// ──────────────────────────────────────────────
// GET /api/orders/me/:id — Detalle de mi pedido
// ──────────────────────────────────────────────
router.get('/me/:id', [
  param('id').notEmpty().withMessage('El ID del pedido es requerido'),
], (req, res) => {
  try {
    const validationError = handleValidation(req, res);
    if (validationError) return;

    const db = getDb();
    const userId = req.user.id || req.user.userId;
    const { id } = req.params;

    const order = db.prepare('SELECT * FROM orders WHERE id = ? AND user_id = ?').get(id, userId);

    if (!order) {
      return res.status(404).json({ error: 'Pedido no encontrado' });
    }

    const items = db.prepare('SELECT * FROM order_items WHERE order_id = ? ORDER BY created_at').all(id);
    const statusHistory = db.prepare('SELECT * FROM order_status_history WHERE order_id = ? ORDER BY created_at').all(id);

    res.json({
      data: { ...order, items, status_history: statusHistory },
    });
  } catch (error) {
    console.error('[orders-service] Error getting order detail:', error);
    res.status(500).json({ error: 'Error al obtener el detalle del pedido' });
  }
});

// ══════════════════════════════════════════════
//  ADMIN ROUTES
// ══════════════════════════════════════════════

// ──────────────────────────────────────────────
// GET /api/orders/stats/summary — Estadísticas
// ──────────────────────────────────────────────
router.get('/stats/summary', roleMiddleware('admin'), (req, res) => {
  try {
    const db = getDb();

    // Total de pedidos
    const totalOrders = db.prepare('SELECT COUNT(*) as count FROM orders').get();

    // Pedidos por estado
    const byStatus = db.prepare(
      'SELECT status, COUNT(*) as count FROM orders GROUP BY status'
    ).all();

    // Revenue: hoy
    const revenueToday = db.prepare(
      "SELECT COALESCE(SUM(total), 0) as revenue, COUNT(*) as count FROM orders WHERE date(created_at) = date('now') AND status != 'cancelled'"
    ).get();

    // Revenue: esta semana (últimos 7 días)
    const revenueWeek = db.prepare(
      "SELECT COALESCE(SUM(total), 0) as revenue, COUNT(*) as count FROM orders WHERE created_at >= datetime('now', '-7 days') AND status != 'cancelled'"
    ).get();

    // Revenue: este mes (últimos 30 días)
    const revenueMonth = db.prepare(
      "SELECT COALESCE(SUM(total), 0) as revenue, COUNT(*) as count FROM orders WHERE created_at >= datetime('now', '-30 days') AND status != 'cancelled'"
    ).get();

    const statusMap = {};
    for (const s of byStatus) {
      statusMap[s.status] = s.count;
    }

    res.json({
      data: {
        totalOrders: totalOrders ? totalOrders.count : 0,
        byStatus: statusMap,
        revenue: {
          today: { amount: revenueToday ? revenueToday.revenue : 0, orders: revenueToday ? revenueToday.count : 0 },
          week: { amount: revenueWeek ? revenueWeek.revenue : 0, orders: revenueWeek ? revenueWeek.count : 0 },
          month: { amount: revenueMonth ? revenueMonth.revenue : 0, orders: revenueMonth ? revenueMonth.count : 0 },
        },
      },
    });
  } catch (error) {
    console.error('[orders-service] Error getting stats:', error);
    res.status(500).json({ error: 'Error al obtener estadísticas' });
  }
});

// ──────────────────────────────────────────────
// GET /api/orders — Listar TODOS los pedidos (admin)
// ──────────────────────────────────────────────
router.get('/', roleMiddleware('admin'), (req, res) => {
  try {
    const db = getDb();
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(50, Math.max(1, parseInt(req.query.limit) || 10));
    const offset = (page - 1) * limit;
    const status = req.query.status;
    const search = req.query.search;

    let countSql = 'SELECT COUNT(*) as total FROM orders WHERE 1=1';
    let dataSql = 'SELECT * FROM orders WHERE 1=1';
    const params = [];

    if (status && VALID_STATUSES.includes(status)) {
      countSql += ' AND status = ?';
      dataSql += ' AND status = ?';
      params.push(status);
    }

    if (search) {
      countSql += " AND (order_number LIKE ? OR customer_name LIKE ? OR customer_email LIKE ?)";
      dataSql += " AND (order_number LIKE ? OR customer_name LIKE ? OR customer_email LIKE ?)";
      params.push(`%${search}%`, `%${search}%`, `%${search}%`);
    }

    dataSql += ' ORDER BY created_at DESC LIMIT ? OFFSET ?';

    const countResult = db.prepare(countSql).get(...params);
    const total = countResult ? countResult.total : 0;
    const orders = db.prepare(dataSql).all(...params, limit, offset);

    // Enrich orders with items count
    const enriched = orders.map(order => {
      const itemsCount = db.prepare('SELECT COUNT(*) as cnt FROM order_items WHERE order_id = ?').get(order.id);
      return { ...order, items_count: itemsCount ? itemsCount.cnt : 0 };
    });

    res.json({
      data: enriched,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    });
  } catch (error) {
    console.error('[orders-service] Error listing all orders:', error);
    res.status(500).json({ error: 'Error al listar los pedidos' });
  }
});

// ──────────────────────────────────────────────
// GET /api/orders/:id — Detalle de cualquier pedido (admin)
// ──────────────────────────────────────────────
router.get('/:id', roleMiddleware('admin'), [
  param('id').notEmpty().withMessage('El ID del pedido es requerido'),
], (req, res) => {
  try {
    const validationError = handleValidation(req, res);
    if (validationError) return;

    const db = getDb();
    const { id } = req.params;

    const order = db.prepare('SELECT * FROM orders WHERE id = ?').get(id);

    if (!order) {
      return res.status(404).json({ error: 'Pedido no encontrado' });
    }

    const items = db.prepare('SELECT * FROM order_items WHERE order_id = ? ORDER BY created_at').all(id);
    const statusHistory = db.prepare('SELECT * FROM order_status_history WHERE order_id = ? ORDER BY created_at').all(id);

    res.json({
      data: { ...order, items, status_history: statusHistory },
    });
  } catch (error) {
    console.error('[orders-service] Error getting order detail:', error);
    res.status(500).json({ error: 'Error al obtener el detalle del pedido' });
  }
});

// ──────────────────────────────────────────────
// PATCH /api/orders/:id/status — Actualizar estado (admin)
// ──────────────────────────────────────────────
router.patch('/:id/status', roleMiddleware('admin'), [
  param('id').notEmpty().withMessage('El ID del pedido es requerido'),
  body('status')
    .notEmpty().withMessage('El estado es requerido')
    .isIn(VALID_STATUSES).withMessage(`Estado inválido. Valores permitidos: ${VALID_STATUSES.join(', ')}`),
  body('note')
    .optional().isString(),
], (req, res) => {
  try {
    const validationError = handleValidation(req, res);
    if (validationError) return;

    const db = getDb();
    const { id } = req.params;
    const { status: newStatus, note } = req.body;
    const changedBy = req.user.id || req.user.userId;

    const order = db.prepare('SELECT * FROM orders WHERE id = ?').get(id);

    if (!order) {
      return res.status(404).json({ error: 'Pedido no encontrado' });
    }

    // Validar transición de estado
    const allowedTransitions = VALID_TRANSITIONS[order.status] || [];
    if (!allowedTransitions.includes(newStatus)) {
      return res.status(400).json({
        error: `Transición de estado no permitida: ${order.status} → ${newStatus}. Transiciones válidas: ${allowedTransitions.join(', ') || 'ninguna'}`,
      });
    }

    // Actualizar estado del pedido
    db.prepare(
      "UPDATE orders SET status = ?, updated_at = datetime('now') WHERE id = ?"
    ).run(newStatus, id);

    // Registrar en historial
    db.prepare(
      `INSERT INTO order_status_history (id, order_id, status, note, changed_by)
       VALUES (?, ?, ?, ?, ?)`
    ).run(uuidv4(), id, newStatus, note || '', changedBy);

    // Crear notificación para el usuario
    const statusLabels = {
      'pending': 'Pendiente',
      'confirmed': 'Confirmado',
      'processing': 'En proceso',
      'shipped': 'Enviado',
      'delivered': 'Entregado',
      'cancelled': 'Cancelado',
      'refunded': 'Reembolsado',
    };
    const statusLabel = statusLabels[newStatus] || newStatus;
    const notifTitle = `Pedido ${order.order_number} actualizado`;
    const notifMessage = `Tu pedido #${order.order_number} cambió a estado: ${statusLabel}`;
    db.prepare(
      `INSERT INTO notifications (id, user_id, order_id, order_number, type, title, message)
       VALUES (?, ?, ?, ?, 'order_status', ?, ?)`
    ).run(uuidv4(), order.user_id, id, order.order_number, notifTitle, notifMessage);

    const updatedOrder = db.prepare('SELECT * FROM orders WHERE id = ?').get(id);
    const statusHistory = db.prepare('SELECT * FROM order_status_history WHERE order_id = ? ORDER BY created_at').all(id);

    res.json({
      message: `Estado actualizado a '${newStatus}'`,
      data: { ...updatedOrder, status_history: statusHistory },
    });
  } catch (error) {
    console.error('[orders-service] Error updating order status:', error);
    res.status(500).json({ error: 'Error al actualizar el estado del pedido' });
  }
});

// ══════════════════════════════════════════════
//  NOTIFICATION ROUTES
// ══════════════════════════════════════════════

// ──────────────────────────────────────────────
// GET /api/orders/notifications/me — Mis notificaciones
// ──────────────────────────────────────────────
router.get('/notifications/me', (req, res) => {
  try {
    const db = getDb();
    const userId = req.user.id || req.user.userId;
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(50, Math.max(1, parseInt(req.query.limit) || 20));
    const offset = (page - 1) * limit;

    const countResult = db.prepare(
      'SELECT COUNT(*) as total FROM notifications WHERE user_id = ?'
    ).get(userId);
    const total = countResult ? countResult.total : 0;

    const unreadResult = db.prepare(
      'SELECT COUNT(*) as unread FROM notifications WHERE user_id = ? AND is_read = 0'
    ).get(userId);
    const unread = unreadResult ? unreadResult.unread : 0;

    const notifications = db.prepare(
      'SELECT * FROM notifications WHERE user_id = ? ORDER BY created_at DESC LIMIT ? OFFSET ?'
    ).all(userId, limit, offset);

    res.json({
      data: notifications,
      unread,
      pagination: { page, limit, total, totalPages: Math.ceil(total / limit) },
    });
  } catch (error) {
    console.error('[orders-service] Error listing notifications:', error);
    res.status(500).json({ error: 'Error al listar notificaciones' });
  }
});

// ──────────────────────────────────────────────
// GET /api/orders/notifications/me/unread-count
// ──────────────────────────────────────────────
router.get('/notifications/me/unread-count', (req, res) => {
  try {
    const db = getDb();
    const userId = req.user.id || req.user.userId;
    const result = db.prepare(
      'SELECT COUNT(*) as unread FROM notifications WHERE user_id = ? AND is_read = 0'
    ).get(userId);
    res.json({ unread: result ? result.unread : 0 });
  } catch (error) {
    res.status(500).json({ error: 'Error al obtener conteo' });
  }
});

// ──────────────────────────────────────────────
// PATCH /api/orders/notifications/me/read-all — Marcar todas como leídas
// ──────────────────────────────────────────────
router.patch('/notifications/me/read-all', (req, res) => {
  try {
    const db = getDb();
    const userId = req.user.id || req.user.userId;
    db.prepare(
      'UPDATE notifications SET is_read = 1 WHERE user_id = ? AND is_read = 0'
    ).run(userId);
    res.json({ message: 'Todas las notificaciones marcadas como leídas' });
  } catch (error) {
    res.status(500).json({ error: 'Error al actualizar notificaciones' });
  }
});

// ──────────────────────────────────────────────
// DELETE /api/orders/notifications/me/:id — Eliminar una notificación
// ──────────────────────────────────────────────
router.delete('/notifications/me/:id', (req, res) => {
  try {
    const db = getDb();
    const userId = req.user.id || req.user.userId;
    const { id } = req.params;

    const notif = db.prepare(
      'SELECT * FROM notifications WHERE id = ? AND user_id = ?'
    ).get(id, userId);

    if (!notif) {
      return res.status(404).json({ error: 'Notificación no encontrada' });
    }

    db.prepare('DELETE FROM notifications WHERE id = ? AND user_id = ?').run(id, userId);
    res.json({ message: 'Notificación eliminada' });
  } catch (error) {
    res.status(500).json({ error: 'Error al eliminar notificación' });
  }
});

// ──────────────────────────────────────────────
// DELETE /api/orders/notifications/me — Eliminar todas
// ──────────────────────────────────────────────
router.delete('/notifications/me', (req, res) => {
  try {
    const db = getDb();
    const userId = req.user.id || req.user.userId;
    db.prepare('DELETE FROM notifications WHERE user_id = ?').run(userId);
    res.json({ message: 'Todas las notificaciones eliminadas' });
  } catch (error) {
    res.status(500).json({ error: 'Error al eliminar notificaciones' });
  }
});

module.exports = router;
