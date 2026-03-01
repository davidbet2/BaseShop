// ============================================
// BaseShop Payments Service
// Puerto: 3006 — Gestión de pagos con PayU
// ============================================
console.log('[payments-service] Process starting... PID:', process.pid);
process.on('uncaughtException', (err) => { console.error('UNCAUGHT:', err); process.exit(1); });
process.on('unhandledRejection', (err) => { console.error('UNHANDLED:', err); process.exit(1); });

require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const { initDatabase } = require('./database');

const app = express();
const PORT = process.env.PORT || 3006;

// ── Helmet ──
app.use(helmet());

// ── CORS con whitelist ──
const allowedOrigins = (process.env.ALLOWED_ORIGINS || 'http://localhost:9090,http://localhost:8080,http://localhost:3000').split(',').map(o => o.trim());
app.use(cors({
  origin: (origin, callback) => {
    if (!origin || allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      callback(null, false);
    }
  },
  credentials: true,
}));
app.options('*', cors());

// ── Body parser ──
app.use(express.json({ limit: '10mb' }));

// ── Rate limiting ──
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100, // limit each IP to 100 requests per windowMs
  standardHeaders: true,
  legacyHeaders: false,
  message: { success: false, message: 'Too many requests, please try again later.' }
});
app.use(limiter);

// ── UTF-8 en JSON ──
app.use((req, res, next) => {
  const origJson = res.json.bind(res);
  res.json = (body) => {
    res.setHeader('Content-Type', 'application/json; charset=utf-8');
    return origJson(body);
  };
  next();
});

// ── XSS Sanitization ──
function sanitizeInput(input) {
  if (typeof input !== 'string') return input;
  return input
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#x27;')
    .replace(/\//g, '&#x2F;')
    .replace(/javascript:/gi, '')
    .replace(/on\w+\s*=/gi, '')
    .replace(/data:/gi, 'data-blocked:');
}
app.use((req, res, next) => {
  if (req.body && typeof req.body === 'object') {
    const sanitize = (obj) => {
      for (const key of Object.keys(obj)) {
        if (typeof obj[key] === 'string') {
          obj[key] = sanitizeInput(obj[key]).trim();
        } else if (typeof obj[key] === 'object' && obj[key] !== null) {
          sanitize(obj[key]);
        }
      }
    };
    sanitize(req.body);
  }
  next();
});

// ── Health check ──
app.get('/health', (req, res) => {
  res.json({ service: 'payments-service', status: 'running', timestamp: new Date().toISOString() });
});

async function start() {
  await initDatabase();

  const paymentsRoutes = require('./routes/payments.routes');
  app.use('/api/payments', paymentsRoutes);

  // 404 catch-all
  app.use((req, res) => {
    res.status(404).json({
      error: 'Ruta no encontrada',
      message: `La ruta ${req.method} ${req.originalUrl} no existe en payments-service`,
      statusCode: 404,
    });
  });

  app.listen(PORT, () => console.log(`[payments-service] Running on port ${PORT}`));
}

start().catch(err => { console.error('Failed to start payments-service:', err); process.exit(1); });
