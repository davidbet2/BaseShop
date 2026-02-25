// ============================================
// BaseShop Config Service
// Puerto: 3009 — Configuración global de la tienda
// ============================================
console.log('[config-service] Process starting... PID:', process.pid);
process.on('uncaughtException', (err) => { console.error('UNCAUGHT:', err); process.exit(1); });
process.on('unhandledRejection', (err) => { console.error('UNHANDLED:', err); process.exit(1); });

require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { initDatabase } = require('./database');

const app = express();
const PORT = process.env.PORT || 3009;

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

// ── UTF-8 en JSON ──
app.use((req, res, next) => {
  const origJson = res.json.bind(res);
  res.json = (body) => {
    res.setHeader('Content-Type', 'application/json; charset=utf-8');
    return origJson(body);
  };
  next();
});

// ── Health check ──
app.get('/health', (req, res) => {
  res.json({ service: 'config-service', status: 'running', timestamp: new Date().toISOString() });
});

async function start() {
  await initDatabase();

  const { configRouter } = require('./routes/config.routes');
  app.use('/api/config', configRouter);

  // 404 catch-all
  app.use((req, res) => {
    res.status(404).json({
      error: 'Ruta no encontrada',
      message: `La ruta ${req.method} ${req.originalUrl} no existe en config-service`,
      statusCode: 404,
    });
  });

  app.listen(PORT, () => console.log(`[config-service] Running on port ${PORT}`));
}

start().catch(err => { console.error('Failed to start config-service:', err); process.exit(1); });
