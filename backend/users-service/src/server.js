// ============================================
// BaseShop Users Service
// Puerto: 3002 — Gestión de perfiles y direcciones de usuarios
// ============================================
console.log('[users-service] Process starting... PID:', process.pid);
process.on('uncaughtException', (err) => { console.error('UNCAUGHT:', err); process.exit(1); });
process.on('unhandledRejection', (err) => { console.error('UNHANDLED:', err); process.exit(1); });

require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { initDatabase } = require('./database');

const app = express();
const PORT = process.env.PORT || 3002;

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
app.use(express.json({ limit: '10kb' }));

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
app.use((req, res, next) => {
  if (req.body && typeof req.body === 'object') {
    const sanitize = (obj) => {
      for (const key of Object.keys(obj)) {
        if (typeof obj[key] === 'string') {
          obj[key] = obj[key].replace(/<[^>]*>/g, '').trim();
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
  res.json({ service: 'users-service', status: 'running', timestamp: new Date().toISOString() });
});

async function start() {
  await initDatabase();

  const usersRoutes = require('./routes/users.routes');
  app.use('/api/users', usersRoutes);

  // 404 catch-all
  app.use((req, res) => {
    res.status(404).json({
      error: 'Ruta no encontrada',
      message: `La ruta ${req.method} ${req.originalUrl} no existe en users-service`,
      statusCode: 404,
    });
  });

  app.listen(PORT, () => console.log(`[users-service] Running on port ${PORT}`));
}

start().catch(err => { console.error('Failed to start users-service:', err); process.exit(1); });
