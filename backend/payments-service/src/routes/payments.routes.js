const express = require('express');
const { body, param, query, validationResult } = require('express-validator');
const { v4: uuidv4 } = require('uuid');
const crypto = require('crypto');
const axios = require('axios');
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

// PayU Configuration (defaults are PayU Sandbox/test credentials)
const PAYU_API_KEY = () => process.env.PAYU_API_KEY || '4Vj8eK4rloUd272L48hsrarnUA';
const PAYU_API_LOGIN = () => process.env.PAYU_API_LOGIN || 'pRRXKOl8ikMmt9u';
const PAYU_MERCHANT_ID = () => process.env.PAYU_MERCHANT_ID || '508029';
const PAYU_ACCOUNT_ID = () => process.env.PAYU_ACCOUNT_ID || '512321';
const PAYU_IS_TEST = () => (process.env.PAYU_IS_TEST || 'true') === 'true';

const PAYU_API_URL = () =>
  PAYU_IS_TEST()
    ? 'https://sandbox.api.payulatam.com/payments-api/4.0/service.cgi'
    : 'https://api.payulatam.com/payments-api/4.0/service.cgi';

const PAYU_CHECKOUT_URL = () =>
  PAYU_IS_TEST()
    ? 'https://sandbox.checkout.payulatam.com/ppp-web-gateway-payu/'
    : 'https://checkout.payulatam.com/ppp-web-gateway-payu/';

const FRONTEND_URL = () => process.env.FRONTEND_URL || 'http://localhost:8080';
const GATEWAY_URL = () => process.env.GATEWAY_URL || 'http://localhost:3000';

const ORDERS_SERVICE_URL = () => process.env.ORDERS_SERVICE_URL || 'http://localhost:3005';

// Notify orders-service about payment status change
async function notifyOrderService(orderId, paymentStatus, paymentId) {
  try {
    // Map payment status to order status
    // Based on PayU official states:
    //   approved → confirmed (payment successful)
    //   declined → cancelled (payment rejected)
    //   expired → cancelled (transaction timed out)
    //   error → cancelled (system error)
    //   abandoned → cancelled (user left checkout)
    //   pending → no update (still processing)
    //   pending_validation → no update (under review)
    const orderStatusMap = {
      approved: 'confirmed',
      declined: 'cancelled',
      expired: 'cancelled',
      error: 'cancelled',
      abandoned: 'cancelled',
    };
    const newOrderStatus = orderStatusMap[paymentStatus];
    if (!newOrderStatus) return; // Don't update order for pending states

    const noteMap = {
      approved: 'Pago aprobado por PayU',
      declined: 'Pago rechazado por la entidad financiera',
      expired: 'La transacción expiró sin completarse',
      error: 'Error en el procesamiento del pago',
      abandoned: 'El usuario abandonó el proceso de pago',
    };

    const url = `${ORDERS_SERVICE_URL()}/api/orders/${orderId}/payment-status`;
    const internalSecret = process.env.INTERNAL_SERVICE_SECRET || 'baseshop-internal-dev';
    await axios.patch(url, {
      status: newOrderStatus,
      payment_id: paymentId,
      payment_status: paymentStatus,
      note: noteMap[paymentStatus] || `Pago ${paymentStatus}`,
    }, {
      headers: { 'X-Internal-Service': internalSecret },
      timeout: 5000,
    });
    console.log(`[payments-service] Notified orders-service: order ${orderId} → ${newOrderStatus}`);
  } catch (err) {
    console.error(`[payments-service] Failed to notify orders-service for order ${orderId}:`, err.message);
  }
}

// PayU signature: MD5(apiKey~merchantId~referenceCode~amount~currency)
function generatePayUSignature(referenceCode, amount, currency) {
  const apiKey = PAYU_API_KEY();
  const merchantId = PAYU_MERCHANT_ID();
  const signatureString = `${apiKey}~${merchantId}~${referenceCode}~${amount}~${currency}`;
  return crypto.createHash('md5').update(signatureString).digest('hex');
}

// Validate incoming PayU webhook signature
function validatePayUWebhookSignature(apiKey, merchantId, referenceCode, amount, currency, statePol) {
  // PayU confirmation signature: MD5(apiKey~merchantId~referenceCode~new_value~currency~state_pol)
  // new_value = amount with one decimal if it ends in .0, otherwise full precision
  let formattedAmount = parseFloat(amount);
  if (formattedAmount % 1 === 0) {
    formattedAmount = formattedAmount.toFixed(1);
  } else {
    formattedAmount = formattedAmount.toString();
  }
  const signatureString = `${apiKey}~${merchantId}~${referenceCode}~${formattedAmount}~${currency}~${statePol}`;
  return crypto.createHash('md5').update(signatureString).digest('hex');
}

// Map PayU transactionState / state_pol to internal status
// Based on official PayU documentation:
//   4 = Transacción aprobada
//   5 = Transacción expirada
//   6 = Transacción rechazada
//   7 = Transacción pendiente
//  104 = Error
//  12 = Transacción abandonada (usuario cerró sin pagar)
//  14 = Transacción pendiente por validar
function mapPayUStatus(statePol) {
  const statePolNum = parseInt(statePol, 10);
  switch (statePolNum) {
    case 4: return 'approved';
    case 6: return 'declined';
    case 5: return 'expired';
    case 7: return 'pending';
    case 104: return 'error';
    case 12: return 'abandoned';
    case 14: return 'pending_validation';
    default: return 'error';
  }
}

// Map PayU lapTransactionState to a human-readable message (Spanish)
function mapPayUMessage(lapState) {
  const messages = {
    'APPROVED': 'Transacción aprobada',
    'ANTIFRAUD_REJECTED': 'Transacción rechazada por el sistema antifraude',
    'PAYMENT_NETWORK_REJECTED': 'Transacción rechazada por la red financiera',
    'ENTITY_DECLINED': 'Transacción rechazada por la entidad bancaria',
    'INTERNAL_PAYMENT_PROVIDER_ERROR': 'Error interno del proveedor de pago',
    'INACTIVE_PAYMENT_PROVIDER': 'Proveedor de pago inactivo',
    'DIGITAL_CERTIFICATE_NOT_FOUND': 'Certificado digital no encontrado',
    'INSUFFICIENT_FUNDS': 'Fondos insuficientes',
    'CREDIT_CARD_NOT_AUTHORIZED': 'Tarjeta de crédito no autorizada para transacciones en línea',
    'INVALID_EXPIRATION_DATE_OR_SECURITY_CODE': 'Fecha de expiración o código de seguridad inválido',
    'INVALID_CARD': 'Tarjeta inválida',
    'EXPIRED_CARD': 'Tarjeta expirada',
    'RESTRICTED_CARD': 'Tarjeta restringida',
    'CONTACT_THE_ENTITY': 'Contactar la entidad financiera',
    'REPEAT_TRANSACTION': 'Reintentar transacción',
    'ENTITY_MESSAGING_ERROR': 'Error de comunicación con la entidad financiera',
    'BANK_UNREACHABLE': 'Banco no disponible',
    'EXPIRED_TRANSACTION': 'Transacción expirada',
    'PENDING_TRANSACTION_REVIEW': 'Transacción pendiente de revisión',
    'PENDING_TRANSACTION_CONFIRMATION': 'Transacción pendiente de confirmación',
    'PENDING_TRANSACTION_TRANSMISSION': 'Transacción pendiente, recibo generado',
    'PAYMENT_NETWORK_BAD_RESPONSE': 'Respuesta incorrecta de la red financiera',
    'PAYMENT_NETWORK_NO_CONNECTION': 'Sin conexión con la red financiera',
    'PAYMENT_NETWORK_NO_RESPONSE': 'Sin respuesta de la red financiera',
    'FIX_NOT_REQUIRED': 'Corrección no requerida',
    'AUTOMATICALLY_FIXED_AND_SUCCESS_REVERSAL': 'Corrección automática y reverso exitoso',
    'AUTOMATICALLY_FIXED_AND_UNSUCCESS_REVERSAL': 'Corrección automática y reverso fallido',
    'AUTOMATIC_FIXED_NOT_SUPPORTED': 'Corrección automática no soportada',
    'NOT_FIXED_FOR_ERROR_STATE': 'No se fijó por estado de error',
    'ERROR_FIXING_AND_REVERSING': 'Error al corregir y reversar',
    'ERROR_FIXING_INCOMPLETE_DATA': 'Error al corregir datos incompletos',
  };
  return messages[lapState] || lapState || '';
}

const VALID_STATUSES = ['pending', 'approved', 'declined', 'expired', 'error', 'refunded', 'abandoned', 'pending_validation'];

// ══════════════════════════════════════════════
//  WEBHOOK ROUTE (no auth — PayU callback)
// ══════════════════════════════════════════════

// ──────────────────────────────────────────────
// POST /api/payments/webhook/payu — PayU confirmation
// ──────────────────────────────────────────────
router.post('/webhook/payu', async (req, res) => {
  try {
    const db = getDb();
    const {
      merchant_id,
      reference_sale,
      value,
      currency,
      state_pol,
      transaction_id,
      sign,
      payment_method_type,
      response_message_pol,
    } = req.body;

    console.log('[payments-service] PayU webhook received:', { reference_sale, state_pol, transaction_id });

    // Validate signature
    const apiKey = PAYU_API_KEY();
    const expectedSignature = validatePayUWebhookSignature(
      apiKey, merchant_id, reference_sale, value, currency, state_pol
    );

    // M7 fix: reject if signature is missing or invalid
    if (!sign || expectedSignature !== sign) {
      console.warn('[payments-service] Invalid PayU webhook signature');
      // Log the attempt anyway
      const payment = db.prepare('SELECT * FROM payments WHERE id = ? OR order_id = ?').get(reference_sale, reference_sale);
      if (payment) {
        db.prepare(
          `INSERT INTO payment_logs (id, payment_id, event, data)
           VALUES (?, ?, 'webhook_signature_invalid', ?)`
        ).run(uuidv4(), payment.id, JSON.stringify(req.body));
      }
      return res.status(400).json({ error: 'Firma inválida' });
    }

    // Find payment by reference (payment id or order_id)
    let payment = db.prepare('SELECT * FROM payments WHERE id = ?').get(reference_sale);
    if (!payment) {
      payment = db.prepare('SELECT * FROM payments WHERE order_id = ?').get(reference_sale);
    }

    if (!payment) {
      console.warn('[payments-service] Payment not found for reference:', reference_sale);
      return res.status(404).json({ error: 'Pago no encontrado' });
    }

    // Map status
    const newStatus = mapPayUStatus(state_pol);

    // Update payment
    db.prepare(
      `UPDATE payments SET status = ?, provider_reference = ?, provider_response = ?, payment_method = CASE WHEN payment_method = '' THEN ? ELSE payment_method END, updated_at = datetime('now')
       WHERE id = ?`
    ).run(newStatus, transaction_id || '', JSON.stringify(req.body), payment_method_type ? String(payment_method_type) : '', payment.id);

    // Log event
    db.prepare(
      `INSERT INTO payment_logs (id, payment_id, event, data)
       VALUES (?, ?, ?, ?)`
    ).run(uuidv4(), payment.id, `webhook_${newStatus}`, JSON.stringify({
      state_pol,
      transaction_id,
      response_message: response_message_pol,
      raw: req.body,
    }));

    console.log(`[payments-service] Payment ${payment.id} updated to ${newStatus}`);

    // Notify orders-service about payment outcome
    await notifyOrderService(payment.order_id, newStatus, payment.id);

    res.json({ message: 'OK' });
  } catch (error) {
    console.error('[payments-service] Error processing PayU webhook:', error);
    res.status(500).json({ error: 'Error al procesar webhook de PayU' });
  }
});

// ══════════════════════════════════════════════
//  AUTHENTICATED ROUTES
// ══════════════════════════════════════════════
router.use(authMiddleware);

// ══════════════════════════════════════════════
//  CLIENT ROUTES (authenticated users)
// ══════════════════════════════════════════════

// ──────────────────────────────────────────────
// POST /api/payments/create — Create payment intent
// ──────────────────────────────────────────────
router.post('/create', [
  body('order_id')
    .notEmpty().withMessage('El ID de la orden es requerido'),
  body('amount')
    .isFloat({ min: 0.01 }).withMessage('El monto debe ser mayor a 0'),
  body('payment_method')
    .optional().isString().withMessage('El método de pago debe ser texto'),
  body('buyer_email')
    .isEmail().withMessage('El email del comprador es requerido'),
  body('buyer_name')
    .notEmpty().withMessage('El nombre del comprador es requerido'),
  body('description')
    .optional().isString(),
], (req, res) => {
  try {
    const validationError = handleValidation(req, res);
    if (validationError) return;

    const db = getDb();
    const userId = req.user.id || req.user.userId;
    const { order_id, amount, payment_method, buyer_email, buyer_name, description } = req.body;
    const currency = req.body.currency || 'COP';

    // Check if a pending payment already exists for this order
    const existingPayment = db.prepare(
      "SELECT * FROM payments WHERE order_id = ? AND status = 'pending'"
    ).get(order_id);

    if (existingPayment) {
      // Return existing payment data with fresh signature
      const referenceCode = existingPayment.id;
      const signature = generatePayUSignature(referenceCode, amount, currency);

      return res.json({
        message: 'Pago pendiente existente',
        data: {
          payment_id: existingPayment.id,
          order_id: existingPayment.order_id,
          amount: existingPayment.amount,
          currency: existingPayment.currency,
          status: existingPayment.status,
          payu_form_data: {
            merchantId: PAYU_MERCHANT_ID(),
            accountId: PAYU_ACCOUNT_ID(),
            referenceCode,
            amount: existingPayment.amount,
            tax: '0',
            taxReturnBase: '0',
            currency: existingPayment.currency,
            signature,
            test: PAYU_IS_TEST() ? '1' : '0',
            buyerEmail: buyer_email,
            buyerFullName: buyer_name,
            description: description || `Pago orden ${order_id}`,
            checkoutUrl: PAYU_CHECKOUT_URL(),
            responseUrl: `${FRONTEND_URL()}/#/payment-result?orderId=${order_id}`,
            confirmationUrl: `${GATEWAY_URL()}/api/payments/webhook/payu`,
          },
        },
      });
    }

    // Create new payment
    const paymentId = uuidv4();
    const referenceCode = paymentId;
    const signature = generatePayUSignature(referenceCode, amount, currency);

    db.prepare(
      `INSERT INTO payments (id, order_id, user_id, amount, currency, status, payment_method, provider, provider_reference, provider_response)
       VALUES (?, ?, ?, ?, ?, 'pending', ?, 'payu', '', '')`
    ).run(paymentId, order_id, userId, amount, currency, payment_method || '');

    // Log creation
    db.prepare(
      `INSERT INTO payment_logs (id, payment_id, event, data)
       VALUES (?, ?, 'payment_created', ?)`
    ).run(uuidv4(), paymentId, JSON.stringify({ order_id, amount, currency, buyer_email, buyer_name }));

    const payment = db.prepare('SELECT * FROM payments WHERE id = ?').get(paymentId);

    res.status(201).json({
      message: 'Intención de pago creada exitosamente',
      data: {
        payment_id: payment.id,
        order_id: payment.order_id,
        amount: payment.amount,
        currency: payment.currency,
        status: payment.status,
        created_at: payment.created_at,
        payu_form_data: {
          merchantId: PAYU_MERCHANT_ID(),
          accountId: PAYU_ACCOUNT_ID(),
          referenceCode,
          amount,
          tax: '0',
          taxReturnBase: '0',
          currency,
          signature,
          test: PAYU_IS_TEST() ? '1' : '0',
          buyerEmail: buyer_email,
          buyerFullName: buyer_name,
          description: description || `Pago orden ${order_id}`,
          checkoutUrl: PAYU_CHECKOUT_URL(),
          responseUrl: `${FRONTEND_URL()}/#/payment-result?orderId=${order_id}`,
          confirmationUrl: `${GATEWAY_URL()}/api/payments/webhook/payu`,
        },
      },
    });
  } catch (error) {
    console.error('[payments-service] Error creating payment:', error);
    res.status(500).json({ error: 'Error al crear la intención de pago' });
  }
});

// ──────────────────────────────────────────────
// GET /api/payments/order/:orderId — Payment status for an order
// ──────────────────────────────────────────────
router.get('/order/:orderId', [
  param('orderId').notEmpty().withMessage('El ID de la orden es requerido'),
], (req, res) => {
  try {
    const validationError = handleValidation(req, res);
    if (validationError) return;

    const db = getDb();
    const userId = req.user.id || req.user.userId;
    const { orderId } = req.params;

    // Users can only see their own payments, admins can see all
    let payment;
    if (req.user.role === 'admin') {
      payment = db.prepare('SELECT * FROM payments WHERE order_id = ? ORDER BY created_at DESC').get(orderId);
    } else {
      payment = db.prepare('SELECT * FROM payments WHERE order_id = ? AND user_id = ? ORDER BY created_at DESC').get(orderId, userId);
    }

    if (!payment) {
      return res.status(404).json({ error: 'Pago no encontrado para esta orden' });
    }

    const logs = db.prepare('SELECT * FROM payment_logs WHERE payment_id = ? ORDER BY created_at DESC').all(payment.id);

    res.json({
      data: { ...payment, logs },
    });
  } catch (error) {
    console.error('[payments-service] Error getting payment by order:', error);
    res.status(500).json({ error: 'Error al obtener el estado del pago' });
  }
});

// ──────────────────────────────────────────────
// POST /api/payments/validate-response — Validate PayU response & update status
// Called by the frontend after PayU redirects back with response params.
// This is essential because PayU's confirmation webhook cannot reach localhost.
// ──────────────────────────────────────────────
router.post('/validate-response', [
  body('orderId').notEmpty().withMessage('El ID de la orden es requerido'),
  body('transactionState').notEmpty().withMessage('El estado de la transacción es requerido'),
], async (req, res) => {
  try {
    const validationError = handleValidation(req, res);
    if (validationError) return;

    const db = getDb();
    const userId = req.user.id || req.user.userId;
    const {
      orderId,
      transactionState,
      polTransactionState,
      referenceCode,
      transactionId,
      TX_VALUE,
      currency,
      signature,
      message,
      lapTransactionState,
    } = req.body;

    console.log('[payments-service] Validate PayU response:', { orderId, transactionState, lapTransactionState });

    // Find the payment
    let payment = db.prepare('SELECT * FROM payments WHERE order_id = ? AND user_id = ? ORDER BY created_at DESC').get(orderId, userId);
    if (!payment) {
      return res.status(404).json({ error: 'Pago no encontrado para esta orden' });
    }

    // Only update if still pending (don't override webhook updates)
    if (payment.status !== 'pending') {
      return res.json({
        message: 'Estado ya actualizado',
        data: { ...payment, status: payment.status },
      });
    }

    // Validate PayU response signature if provided
    // PayU response signature: MD5(apiKey~merchantId~referenceCode~TX_VALUE~currency~transactionState)
    if (signature && referenceCode && TX_VALUE && currency) {
      const apiKey = PAYU_API_KEY();
      const merchantId = PAYU_MERCHANT_ID();
      let formattedAmount = parseFloat(TX_VALUE);
      if (formattedAmount % 1 === 0) {
        formattedAmount = formattedAmount.toFixed(1);
      } else {
        formattedAmount = formattedAmount.toString();
      }
      const signatureString = `${apiKey}~${merchantId}~${referenceCode}~${formattedAmount}~${currency}~${transactionState}`;
      const expectedSignature = crypto.createHash('md5').update(signatureString).digest('hex');

      if (expectedSignature !== signature) {
        console.warn('[payments-service] Invalid PayU response signature. Expected:', expectedSignature, 'Got:', signature);
        // Don't reject — still use the transactionState since it came via the user's browser redirect
      }
    }

    // Map PayU transactionState to internal status (same codes as state_pol)
    const newStatus = mapPayUStatus(transactionState);

    // Update payment
    db.prepare(
      `UPDATE payments SET status = ?, provider_reference = CASE WHEN provider_reference = '' THEN ? ELSE provider_reference END, provider_response = ?, updated_at = datetime('now')
       WHERE id = ?`
    ).run(newStatus, transactionId || '', JSON.stringify(req.body), payment.id);

    // Log event
    db.prepare(
      `INSERT INTO payment_logs (id, payment_id, event, data)
       VALUES (?, ?, ?, ?)`
    ).run(uuidv4(), payment.id, `response_${newStatus}`, JSON.stringify({
      transactionState,
      polTransactionState,
      lapTransactionState,
      transactionId,
      message,
      raw: req.body,
    }));

    console.log(`[payments-service] Payment ${payment.id} updated to ${newStatus} via response validation`);

    // Notify orders-service about payment outcome
    await notifyOrderService(payment.order_id, newStatus, payment.id);

    // Re-fetch updated payment
    const updatedPayment = db.prepare('SELECT * FROM payments WHERE id = ?').get(payment.id);

    res.json({
      message: 'Estado de pago actualizado',
      data: {
        ...updatedPayment,
        status: newStatus,
        payu_message: mapPayUMessage(lapTransactionState),
        lap_transaction_state: lapTransactionState || '',
      },
    });
  } catch (error) {
    console.error('[payments-service] Error validating PayU response:', error);
    res.status(500).json({ error: 'Error al validar la respuesta de PayU' });
  }
});

// ══════════════════════════════════════════════
//  ADMIN ROUTES
// ══════════════════════════════════════════════

// ──────────────────────────────────────────────
// GET /api/payments/stats/summary — Payment statistics
// ──────────────────────────────────────────────
router.get('/stats/summary', roleMiddleware('admin'), (req, res) => {
  try {
    const db = getDb();

    // Total de pagos
    const totalPayments = db.prepare('SELECT COUNT(*) as count FROM payments').get();

    // Pagos por estado
    const byStatus = db.prepare(
      'SELECT status, COUNT(*) as count, COALESCE(SUM(amount), 0) as total_amount FROM payments GROUP BY status'
    ).all();

    // Revenue: hoy
    const revenueToday = db.prepare(
      "SELECT COALESCE(SUM(amount), 0) as revenue, COUNT(*) as count FROM payments WHERE date(created_at) = date('now') AND status = 'approved'"
    ).get();

    // Revenue: esta semana (últimos 7 días)
    const revenueWeek = db.prepare(
      "SELECT COALESCE(SUM(amount), 0) as revenue, COUNT(*) as count FROM payments WHERE created_at >= datetime('now', '-7 days') AND status = 'approved'"
    ).get();

    // Revenue: este mes (últimos 30 días)
    const revenueMonth = db.prepare(
      "SELECT COALESCE(SUM(amount), 0) as revenue, COUNT(*) as count FROM payments WHERE created_at >= datetime('now', '-30 days') AND status = 'approved'"
    ).get();

    // Total refunded
    const totalRefunded = db.prepare(
      "SELECT COALESCE(SUM(amount), 0) as total, COUNT(*) as count FROM payments WHERE status = 'refunded'"
    ).get();

    const statusMap = {};
    for (const s of byStatus) {
      statusMap[s.status] = { count: s.count, total_amount: s.total_amount };
    }

    res.json({
      data: {
        totalPayments: totalPayments ? totalPayments.count : 0,
        byStatus: statusMap,
        revenue: {
          today: { amount: revenueToday ? revenueToday.revenue : 0, payments: revenueToday ? revenueToday.count : 0 },
          week: { amount: revenueWeek ? revenueWeek.revenue : 0, payments: revenueWeek ? revenueWeek.count : 0 },
          month: { amount: revenueMonth ? revenueMonth.revenue : 0, payments: revenueMonth ? revenueMonth.count : 0 },
        },
        refunded: {
          total: totalRefunded ? totalRefunded.total : 0,
          count: totalRefunded ? totalRefunded.count : 0,
        },
      },
    });
  } catch (error) {
    console.error('[payments-service] Error getting stats:', error);
    res.status(500).json({ error: 'Error al obtener estadísticas de pagos' });
  }
});

// ──────────────────────────────────────────────
// GET /api/payments — List all payments (admin)
// ──────────────────────────────────────────────
router.get('/', roleMiddleware('admin'), (req, res) => {
  try {
    const db = getDb();
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.min(50, Math.max(1, parseInt(req.query.limit) || 10));
    const offset = (page - 1) * limit;
    const status = req.query.status;

    let countSql = 'SELECT COUNT(*) as total FROM payments WHERE 1=1';
    let dataSql = 'SELECT * FROM payments WHERE 1=1';
    const params = [];

    if (status && VALID_STATUSES.includes(status)) {
      countSql += ' AND status = ?';
      dataSql += ' AND status = ?';
      params.push(status);
    }

    dataSql += ' ORDER BY created_at DESC LIMIT ? OFFSET ?';

    const countResult = db.prepare(countSql).get(...params);
    const total = countResult ? countResult.total : 0;
    const payments = db.prepare(dataSql).all(...params, limit, offset);

    res.json({
      data: payments,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
      },
    });
  } catch (error) {
    console.error('[payments-service] Error listing payments:', error);
    res.status(500).json({ error: 'Error al listar los pagos' });
  }
});

// ──────────────────────────────────────────────
// GET /api/payments/:id — Payment detail with logs (admin)
// ──────────────────────────────────────────────
router.get('/:id', roleMiddleware('admin'), [
  param('id').notEmpty().withMessage('El ID del pago es requerido'),
], (req, res) => {
  try {
    const validationError = handleValidation(req, res);
    if (validationError) return;

    const db = getDb();
    const { id } = req.params;

    const payment = db.prepare('SELECT * FROM payments WHERE id = ?').get(id);

    if (!payment) {
      return res.status(404).json({ error: 'Pago no encontrado' });
    }

    const logs = db.prepare('SELECT * FROM payment_logs WHERE payment_id = ? ORDER BY created_at DESC').all(id);

    res.json({
      data: { ...payment, logs },
    });
  } catch (error) {
    console.error('[payments-service] Error getting payment detail:', error);
    res.status(500).json({ error: 'Error al obtener el detalle del pago' });
  }
});

// ──────────────────────────────────────────────
// POST /api/payments/:id/refund — Initiate refund (admin)
// ──────────────────────────────────────────────
router.post('/:id/refund', roleMiddleware('admin'), [
  param('id').notEmpty().withMessage('El ID del pago es requerido'),
  body('reason')
    .optional().isString().withMessage('La razón debe ser texto'),
], (req, res) => {
  try {
    const validationError = handleValidation(req, res);
    if (validationError) return;

    const db = getDb();
    const { id } = req.params;
    const { reason } = req.body;
    const adminId = req.user.id || req.user.userId;

    const payment = db.prepare('SELECT * FROM payments WHERE id = ?').get(id);

    if (!payment) {
      return res.status(404).json({ error: 'Pago no encontrado' });
    }

    if (payment.status !== 'approved') {
      return res.status(400).json({
        error: `Solo se pueden reembolsar pagos aprobados. Estado actual: ${payment.status}`,
      });
    }

    // Update payment status to refunded
    db.prepare(
      "UPDATE payments SET status = 'refunded', updated_at = datetime('now') WHERE id = ?"
    ).run(id);

    // Log refund
    db.prepare(
      `INSERT INTO payment_logs (id, payment_id, event, data)
       VALUES (?, ?, 'refund_initiated', ?)`
    ).run(uuidv4(), id, JSON.stringify({
      reason: reason || '',
      refunded_by: adminId,
      original_amount: payment.amount,
      refund_date: new Date().toISOString(),
    }));

    const updatedPayment = db.prepare('SELECT * FROM payments WHERE id = ?').get(id);
    const logs = db.prepare('SELECT * FROM payment_logs WHERE payment_id = ? ORDER BY created_at DESC').all(id);

    res.json({
      message: 'Reembolso iniciado exitosamente',
      data: { ...updatedPayment, logs },
    });
  } catch (error) {
    console.error('[payments-service] Error processing refund:', error);
    res.status(500).json({ error: 'Error al procesar el reembolso' });
  }
});

module.exports = router;
