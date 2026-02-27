const express = require('express');
const { body, validationResult } = require('express-validator');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { v4: uuidv4 } = require('uuid');
const { getDb } = require('../database');
const { authMiddleware, roleMiddleware } = require('../middleware/auth');
const { verifyRecaptcha } = require('../middleware/recaptcha');

// C1 fix: fail fast if JWT_SECRET is not set (no hardcoded fallback)
const JWT_SECRET = process.env.JWT_SECRET || 'baseshop-dev-secret-change-in-production';
if (!process.env.JWT_SECRET) {
  console.warn('[auth] ⚠️  WARNING: JWT_SECRET not set — using insecure default. Set JWT_SECRET env var in production!');
}
const JWT_EXPIRATION = process.env.JWT_EXPIRATION || '24h';
const REFRESH_EXPIRATION_DAYS = 30;

// Genera tokens JWT (L3 fix: specify algorithm explicitly)
function generateTokens(user) {
  const token = jwt.sign(
    { id: user.id, email: user.email, role: user.role },
    JWT_SECRET,
    { expiresIn: JWT_EXPIRATION, algorithm: 'HS256' }
  );

  const refreshToken = uuidv4();
  const expiresAt = new Date(Date.now() + REFRESH_EXPIRATION_DAYS * 24 * 60 * 60 * 1000).toISOString();

  const db = getDb();
  db.prepare('INSERT INTO refresh_tokens (id, user_id, token, expires_at) VALUES (?, ?, ?, ?)')
    .run(uuidv4(), user.id, refreshToken, expiresAt);

  return { token, refreshToken };
}

// Sanitiza datos del usuario (sin password)
function sanitizeUser(user) {
  const { password, verification_code, reset_code, reset_code_expires, ...safe } = user;
  return safe;
}

module.exports = (authLimiter) => {
  const router = express.Router();

  // ══════════════════════════════════════
  // POST /api/auth/register
  // ══════════════════════════════════════
  router.post('/register',
    authLimiter,
    verifyRecaptcha,
    [
      body('email').isEmail().normalizeEmail().withMessage('Email inválido'),
      body('password').isLength({ min: 8 }).withMessage('La contraseña debe tener al menos 8 caracteres')
        .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/)
        .withMessage('La contraseña debe incluir mayúscula, minúscula y número'),
      body('first_name').notEmpty().trim().withMessage('Nombre requerido'),
      body('last_name').notEmpty().trim().withMessage('Apellido requerido'),
    ],
    async (req, res) => {
      try {
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
          return res.status(400).json({ error: errors.array()[0].msg });
        }

        const { email, password, first_name, last_name, phone } = req.body;
        const db = getDb();

        // Verificar email único
        const existing = db.prepare('SELECT id FROM users WHERE email = ?').get(email);
        if (existing) {
          return res.status(400).json({ error: 'Este email ya está registrado' });
        }

        const hashedPassword = await bcrypt.hash(password, 10);
        const id = uuidv4();
        const verificationCode = crypto.randomBytes(4).toString('hex').toUpperCase();

        db.prepare(`INSERT INTO users (id, email, password, first_name, last_name, phone, role, verification_code)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)`).run(id, email, hashedPassword, first_name, last_name, phone || '', 'client', verificationCode);

        const user = db.prepare('SELECT * FROM users WHERE id = ?').get(id);
        const { token, refreshToken } = generateTokens(user);

        res.status(201).json({
          token,
          refreshToken,
          user: sanitizeUser(user),
          message: 'Registro exitoso',
        });
      } catch (error) {
        console.error('[auth] Register error:', error);
        res.status(500).json({ error: 'Error al registrar usuario' });
      }
    }
  );

  // ══════════════════════════════════════
  // POST /api/auth/login
  // ══════════════════════════════════════
  router.post('/login',
    authLimiter,
    verifyRecaptcha,
    [
      body('email').isEmail().normalizeEmail().withMessage('Email inválido'),
      body('password').notEmpty().withMessage('Contraseña requerida'),
    ],
    async (req, res) => {
      try {
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
          return res.status(400).json({ error: errors.array()[0].msg });
        }

        const { email, password } = req.body;
        const db = getDb();

        const user = db.prepare('SELECT * FROM users WHERE email = ?').get(email);
        if (!user) {
          return res.status(401).json({ error: 'Credenciales inválidas' });
        }

        if (!user.is_active) {
          return res.status(403).json({ error: 'Cuenta desactivada. Contacta al administrador.' });
        }

        if (!user.password) {
          return res.status(401).json({ error: 'Esta cuenta usa inicio de sesión con Google' });
        }

        const validPassword = await bcrypt.compare(password, user.password);
        if (!validPassword) {
          return res.status(401).json({ error: 'Credenciales inválidas' });
        }

        const { token, refreshToken } = generateTokens(user);

        res.json({
          token,
          refreshToken,
          user: sanitizeUser(user),
          message: 'Inicio de sesión exitoso',
        });
      } catch (error) {
        console.error('[auth] Login error:', error);
        res.status(500).json({ error: 'Error al iniciar sesión' });
      }
    }
  );

  // ══════════════════════════════════════
  // POST /api/auth/google
  // ══════════════════════════════════════
  router.post('/google',
    authLimiter,
    verifyRecaptcha,
    async (req, res) => {
      try {
        const { id_token, access_token } = req.body;
        if (!id_token && !access_token) {
          return res.status(400).json({ error: 'Token de Google requerido' });
        }

        // Verificar token con Google (id_token o access_token)
        const axios = require('axios');
        let googleData;
        if (id_token) {
          const resp = await axios.get(`https://oauth2.googleapis.com/tokeninfo?id_token=${id_token}`);
          googleData = resp.data;
        } else {
          const resp = await axios.get('https://www.googleapis.com/oauth2/v3/userinfo', {
            headers: { Authorization: `Bearer ${access_token}` },
          });
          googleData = resp.data;
        }
        const email = googleData.email;
        const given_name = googleData.given_name || googleData.name || '';
        const family_name = googleData.family_name || '';
        const picture = googleData.picture || '';
        const sub = googleData.sub || '';

        if (!email) {
          return res.status(400).json({ error: 'No se pudo obtener el email de Google' });
        }

        const db = getDb();
        let user = db.prepare('SELECT * FROM users WHERE email = ?').get(email);

        if (!user) {
          // Crear cuenta nueva
          const id = uuidv4();
          db.prepare(`INSERT INTO users (id, email, first_name, last_name, avatar, provider, provider_id, email_verified, role)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`).run(
            id, email, given_name || '', family_name || '', picture || '', 'google', sub, 1, 'client'
          );
          user = db.prepare('SELECT * FROM users WHERE id = ?').get(id);
        } else {
          // Actualizar datos de Google si cambió
          db.prepare('UPDATE users SET avatar = ?, provider = ?, provider_id = ?, email_verified = 1, updated_at = datetime("now") WHERE id = ?')
            .run(picture || user.avatar, 'google', sub, user.id);
          user = db.prepare('SELECT * FROM users WHERE id = ?').get(user.id);
        }

        if (!user.is_active) {
          return res.status(403).json({ error: 'Cuenta desactivada' });
        }

        const { token, refreshToken } = generateTokens(user);

        res.json({
          token,
          refreshToken,
          user: sanitizeUser(user),
          message: 'Inicio de sesión con Google exitoso',
        });
      } catch (error) {
        console.error('[auth] Google sign-in error:', error);
        res.status(500).json({ error: 'Error al iniciar sesión con Google' });
      }
    }
  );

  // ══════════════════════════════════════
  // POST /api/auth/refresh
  // ══════════════════════════════════════
  router.post('/refresh', async (req, res) => {
    try {
      const { refreshToken } = req.body;
      if (!refreshToken) {
        return res.status(400).json({ error: 'Refresh token requerido' });
      }

      const db = getDb();
      const stored = db.prepare('SELECT * FROM refresh_tokens WHERE token = ?').get(refreshToken);

      if (!stored) {
        return res.status(401).json({ error: 'Refresh token inválido' });
      }

      if (new Date(stored.expires_at) < new Date()) {
        db.prepare('DELETE FROM refresh_tokens WHERE id = ?').run(stored.id);
        return res.status(401).json({ error: 'Refresh token expirado' });
      }

      const user = db.prepare('SELECT * FROM users WHERE id = ?').get(stored.user_id);
      if (!user || !user.is_active) {
        return res.status(401).json({ error: 'Usuario no encontrado o desactivado' });
      }

      // Eliminar refresh token usado
      db.prepare('DELETE FROM refresh_tokens WHERE id = ?').run(stored.id);

      // Generar nuevos tokens
      const tokens = generateTokens(user);

      res.json({
        token: tokens.token,
        refreshToken: tokens.refreshToken,
        user: sanitizeUser(user),
      });
    } catch (error) {
      console.error('[auth] Refresh error:', error);
      res.status(500).json({ error: 'Error al refrescar token' });
    }
  });

  // ══════════════════════════════════════
  // GET /api/auth/me — usuario actual
  // ══════════════════════════════════════
  router.get('/me', authMiddleware, (req, res) => {
    try {
      const db = getDb();
      const user = db.prepare('SELECT * FROM users WHERE id = ?').get(req.user.id);
      if (!user) {
        return res.status(404).json({ error: 'Usuario no encontrado' });
      }
      res.json({ user: sanitizeUser(user) });
    } catch (error) {
      res.status(500).json({ error: 'Error al obtener usuario' });
    }
  });

  // ══════════════════════════════════════
  // POST /api/auth/logout
  // ══════════════════════════════════════
  router.post('/logout', authMiddleware, (req, res) => {
    try {
      const db = getDb();
      db.prepare('DELETE FROM refresh_tokens WHERE user_id = ?').run(req.user.id);
      res.json({ message: 'Sesión cerrada exitosamente' });
    } catch (error) {
      res.status(500).json({ error: 'Error al cerrar sesión' });
    }
  });

  // ══════════════════════════════════════
  // POST /api/auth/change-password
  // ══════════════════════════════════════
  router.post('/change-password',
    authMiddleware,
    [
      body('currentPassword').notEmpty().withMessage('Contraseña actual requerida'),
      body('newPassword').isLength({ min: 8 }).withMessage('La contraseña debe tener al menos 8 caracteres')
        .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/)
        .withMessage('La contraseña debe incluir mayúscula, minúscula y número'),
    ],
    async (req, res) => {
      try {
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
          return res.status(400).json({ error: errors.array()[0].msg });
        }

        const { currentPassword, newPassword } = req.body;
        const db = getDb();
        const user = db.prepare('SELECT * FROM users WHERE id = ?').get(req.user.id);

        if (!user || !user.password) {
          return res.status(400).json({ error: 'No se puede cambiar la contraseña de una cuenta de Google' });
        }

        const valid = await bcrypt.compare(currentPassword, user.password);
        if (!valid) {
          return res.status(401).json({ error: 'Contraseña actual incorrecta' });
        }

        const hashed = await bcrypt.hash(newPassword, 10);
        db.prepare('UPDATE users SET password = ?, updated_at = datetime("now") WHERE id = ?').run(hashed, user.id);

        res.json({ message: 'Contraseña actualizada exitosamente' });
      } catch (error) {
        res.status(500).json({ error: 'Error al cambiar contraseña' });
      }
    }
  );

  // ══════════════════════════════════════
  // POST /api/auth/forgot-password
  // ══════════════════════════════════════
  router.post('/forgot-password',
    authLimiter,
    [body('email').isEmail().normalizeEmail()],
    async (req, res) => {
      try {
        const { email } = req.body;
        const db = getDb();
        const user = db.prepare('SELECT * FROM users WHERE email = ?').get(email);

        // Siempre responder 200 para no filtrar emails
        if (!user) {
          return res.json({ message: 'Si el email existe, recibirás un código de recuperación' });
        }

        const resetCode = crypto.randomBytes(4).toString('hex').toUpperCase();
        const expires = new Date(Date.now() + 30 * 60 * 1000).toISOString(); // 30 min

        db.prepare('UPDATE users SET reset_code = ?, reset_code_expires = ?, updated_at = datetime("now") WHERE id = ?')
          .run(resetCode, expires, user.id);

        // L4 fix: don't log reset codes
        console.log(`[auth] Reset code generated for ${email}`);

        res.json({ message: 'Si el email existe, recibirás un código de recuperación' });
      } catch (error) {
        res.status(500).json({ error: 'Error al procesar solicitud' });
      }
    }
  );

  // ══════════════════════════════════════
  // POST /api/auth/reset-password
  // ══════════════════════════════════════
  router.post('/reset-password',
    authLimiter,
    [
      body('email').isEmail().normalizeEmail(),
      body('code').notEmpty().withMessage('Código requerido'),
      body('newPassword').isLength({ min: 8 }).withMessage('La contraseña debe tener al menos 8 caracteres')
        .matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/)
        .withMessage('La contraseña debe incluir mayúscula, minúscula y número'),
    ],
    async (req, res) => {
      try {
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
          return res.status(400).json({ error: errors.array()[0].msg });
        }

        const { email, code, newPassword } = req.body;
        const db = getDb();
        const user = db.prepare('SELECT * FROM users WHERE email = ?').get(email);

        // H5 fix: use timing-safe comparison for reset code
        if (!user || !user.reset_code || !crypto.timingSafeEqual(Buffer.from(user.reset_code), Buffer.from(code.toUpperCase().padEnd(user.reset_code.length)))) {
          return res.status(400).json({ error: 'Código inválido' });
        }

        if (new Date(user.reset_code_expires) < new Date()) {
          return res.status(400).json({ error: 'Código expirado' });
        }

        const hashed = await bcrypt.hash(newPassword, 10);
        db.prepare('UPDATE users SET password = ?, reset_code = "", reset_code_expires = "", updated_at = datetime("now") WHERE id = ?')
          .run(hashed, user.id);

        res.json({ message: 'Contraseña restablecida exitosamente' });
      } catch (error) {
        res.status(500).json({ error: 'Error al restablecer contraseña' });
      }
    }
  );

  // ══════════════════════════════════════
  // GET /api/auth/users — Admin: listar usuarios
  // ══════════════════════════════════════
  router.get('/users', authMiddleware, roleMiddleware('admin'), (req, res) => {
    try {
      const db = getDb();
      const page = parseInt(req.query.page) || 1;
      const limit = parseInt(req.query.limit) || 20;
      const search = req.query.search || '';
      const offset = (page - 1) * limit;

      let users, total;
      if (search) {
        users = db.prepare('SELECT * FROM users WHERE email LIKE ? OR first_name LIKE ? OR last_name LIKE ? ORDER BY created_at DESC LIMIT ? OFFSET ?')
          .all(`%${search}%`, `%${search}%`, `%${search}%`, limit, offset);
        total = db.prepare('SELECT COUNT(*) as count FROM users WHERE email LIKE ? OR first_name LIKE ? OR last_name LIKE ?')
          .get(`%${search}%`, `%${search}%`, `%${search}%`).count;
      } else {
        users = db.prepare('SELECT * FROM users ORDER BY created_at DESC LIMIT ? OFFSET ?').all(limit, offset);
        total = db.prepare('SELECT COUNT(*) as count FROM users').get().count;
      }

      res.json({
        data: users.map(sanitizeUser),
        total,
        page,
        limit,
      });
    } catch (error) {
      res.status(500).json({ error: 'Error al listar usuarios' });
    }
  });

  return router;
};
