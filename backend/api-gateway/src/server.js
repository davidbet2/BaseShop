// ============================================
// BaseShop API Gateway
// Puerto: 3000 — Proxy reverso a todos los servicios
// ============================================
console.log('[api-gateway] Process starting... PID:', process.pid);
process.on('uncaughtException', (err) => { console.error('UNCAUGHT:', err); process.exit(1); });
process.on('unhandledRejection', (err) => { console.error('UNHANDLED:', err); process.exit(1); });

require('dotenv').config();
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
const { createProxyMiddleware } = require('http-proxy-middleware');

const app = express();
const PORT = process.env.PORT || 3000;

// ── Trust proxy (Railway / reverse proxies) ──
app.set('trust proxy', 1);

// ── Helmet ──
app.use(helmet({
  contentSecurityPolicy: false,
  crossOriginEmbedderPolicy: false,
}));

// ── CORS con whitelist ──
const allowedOrigins = (process.env.ALLOWED_ORIGINS || 'http://localhost:9090,http://localhost:8080,http://localhost:3000').split(',').map(o => o.trim());
app.use(cors({
  origin: (origin, callback) => {
    if (!origin || allowedOrigins.includes(origin)) {
      callback(null, true);
    } else {
      console.warn(`[CORS] Blocked origin: ${origin}`);
      callback(null, false);
    }
  },
  credentials: true,
}));
app.options('*', cors());

// ── Morgan logging ──
app.use(morgan('combined'));

// ── Rate limiting global ──
app.use(rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 500,
  message: { error: 'Demasiadas solicitudes. Intenta más tarde.' },
  standardHeaders: true,
  legacyHeaders: false,
}));

// ── Health check (M2 fix: don't expose internal URLs) ──
app.get('/health', (req, res) => {
  res.json({
    service: 'api-gateway',
    status: 'running',
    timestamp: new Date().toISOString(),
  });
});

// ── Proxy helper ──
const proxyOptions = (target) => ({
  target,
  changeOrigin: true,
  timeout: 30000,
  proxyTimeout: 30000,
  onError: (err, req, res) => {
    console.error(`[Proxy] Error connecting to ${target}:`, err.message);
    if (!res.headersSent) {
      res.status(503).json({ error: 'Servicio no disponible temporalmente' });
    }
  },
  onProxyRes: (proxyRes) => {
    const contentType = proxyRes.headers['content-type'] || '';
    if (contentType.includes('application/json') && !contentType.includes('charset')) {
      proxyRes.headers['content-type'] = 'application/json; charset=utf-8';
    }
  },
});

// ── Proxies a microservicios ──
app.use('/api/auth', createProxyMiddleware({
  ...proxyOptions(process.env.AUTH_SERVICE_URL || 'http://localhost:3001'),
  pathRewrite: { '^/': '/api/auth/' },
}));

app.use('/api/users', createProxyMiddleware({
  ...proxyOptions(process.env.USERS_SERVICE_URL || 'http://localhost:3002'),
  pathRewrite: { '^/': '/api/users/' },
}));

app.use('/api/products', createProxyMiddleware({
  ...proxyOptions(process.env.PRODUCTS_SERVICE_URL || 'http://localhost:3003'),
  pathRewrite: { '^/': '/api/products/' },
}));

// Static uploads from products-service
app.use('/uploads', createProxyMiddleware({
  ...proxyOptions(process.env.PRODUCTS_SERVICE_URL || 'http://localhost:3003'),
  pathRewrite: { '^/': '/uploads/' },
}));

app.use('/api/categories', createProxyMiddleware({
  ...proxyOptions(process.env.PRODUCTS_SERVICE_URL || 'http://localhost:3003'),
  pathRewrite: { '^/': '/api/categories/' },
}));

app.use('/api/cart', createProxyMiddleware({
  ...proxyOptions(process.env.CART_SERVICE_URL || 'http://localhost:3004'),
  pathRewrite: { '^/': '/api/cart/' },
}));

app.use('/api/orders', createProxyMiddleware({
  ...proxyOptions(process.env.ORDERS_SERVICE_URL || 'http://localhost:3005'),
  pathRewrite: { '^/': '/api/orders/' },
}));

app.use('/api/payments', createProxyMiddleware({
  ...proxyOptions(process.env.PAYMENTS_SERVICE_URL || 'http://localhost:3006'),
  pathRewrite: { '^/': '/api/payments/' },
}));

app.use('/api/reviews', createProxyMiddleware({
  ...proxyOptions(process.env.REVIEWS_SERVICE_URL || 'http://localhost:3007'),
  pathRewrite: { '^/': '/api/reviews/' },
}));

app.use('/api/favorites', createProxyMiddleware({
  ...proxyOptions(process.env.FAVORITES_SERVICE_URL || 'http://localhost:3008'),
  pathRewrite: { '^/': '/api/favorites/' },
}));

app.use('/api/config', createProxyMiddleware({
  ...proxyOptions(process.env.CONFIG_SERVICE_URL || 'http://localhost:3009'),
  pathRewrite: { '^/': '/api/config/' },
}));

// ── 404 catch-all ──
app.use((req, res) => {
  res.status(404).json({
    error: 'Ruta no encontrada',
    message: `La ruta ${req.method} ${req.originalUrl} no existe en api-gateway`,
    statusCode: 404,
  });
});

app.listen(PORT, () => {
  console.log(`[api-gateway] Running on port ${PORT}`);
  if (process.env.NODE_ENV !== 'production') {
    console.log(`[api-gateway] Services:`, {
      auth: process.env.AUTH_SERVICE_URL || 'http://localhost:3001',
      users: process.env.USERS_SERVICE_URL || 'http://localhost:3002',
      products: process.env.PRODUCTS_SERVICE_URL || 'http://localhost:3003',
      cart: process.env.CART_SERVICE_URL || 'http://localhost:3004',
      orders: process.env.ORDERS_SERVICE_URL || 'http://localhost:3005',
      payments: process.env.PAYMENTS_SERVICE_URL || 'http://localhost:3006',
      reviews: process.env.REVIEWS_SERVICE_URL || 'http://localhost:3007',
      favorites: process.env.FAVORITES_SERVICE_URL || 'http://localhost:3008',
      config: process.env.CONFIG_SERVICE_URL || 'http://localhost:3009',
    });
  }
});
