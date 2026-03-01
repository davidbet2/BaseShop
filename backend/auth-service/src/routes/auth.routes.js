const express = require('express');
const { body, validationResult } = require('express-validator');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const { v4: uuidv4 } = require('uuid');
const { getDb } = require('../database');
const { authMiddleware, roleMiddleware } = require('../middleware/auth');
const { verifyRecaptcha } = require('../middleware/recaptcha');
const { generateCode, sendVerificationEmail, sendPasswordResetEmail } = require('../services/brevo');

// C1 fix: fail fast if JWT_SECRET is not set (no hardcoded fallback)
if (!process.env.JWT_SECRET) {
  console.error('FATAL: JWT_SECRET environment variable is required');
  process.exit(1);
}
const JWT_SECRET = process.env.JWT_SECRET;
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
  const { password, verification_code, verification_code_expires, reset_code, reset_code_expires, ...safe } = user;
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

        // Verificar si ya existe como usuario verificado
        const existing = db.prepare('SELECT id, email_verified, provider FROM users WHERE email = ?').get(email);
        if (existing) {
          return res.status(400).json({ error: 'Este email ya está registrado' });
        }

        const hashedPassword = await bcrypt.hash(password, 10);
        const id = uuidv4();
        const verificationCode = generateCode();
        const verificationExpires = new Date(Date.now() + 30 * 60 * 1000).toISOString();

        // Remove any previous pending registration for this email
        db.prepare('DELETE FROM pending_registrations WHERE email = ?').run(email);

        // Insert into pending_registrations (NOT users)
        db.prepare(`INSERT INTO pending_registrations (id, email, password, first_name, last_name, phone, verification_code, verification_code_expires)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)`).run(id, email, hashedPassword, first_name, last_name, phone || '', verificationCode, verificationExpires);

        // Send verification email via Brevo
        await sendVerificationEmail(email, first_name, verificationCode);

        res.status(201).json({
          message: 'Registro exitoso. Revisa tu correo para verificar tu cuenta.',
          email,
          requiresVerification: true,
        });
      } catch (error) {
        console.error('[auth] Register error:', error);
        res.status(500).json({ error: 'Error al registrar usuario' });
      }
    }
  );

  // ══════════════════════════════════════
  // POST /api/auth/verify-email
  // ══════════════════════════════════════
  router.post('/verify-email',
    authLimiter,
    [
      body('email').isEmail().normalizeEmail().withMessage('Email inválido'),
      body('code').isLength({ min: 6, max: 6 }).isNumeric().withMessage('Código de 6 dígitos requerido'),
    ],
    async (req, res) => {
      try {
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
          return res.status(400).json({ error: errors.array()[0].msg });
        }

        const { email, code } = req.body;
        const db = getDb();

        // Check if already verified (exists in users table)
        const existingUser = db.prepare('SELECT id FROM users WHERE email = ?').get(email);
        if (existingUser) {
          return res.status(400).json({ error: 'Este correo ya está verificado' });
        }

        // Look up in pending_registrations
        const pending = db.prepare('SELECT * FROM pending_registrations WHERE email = ?').get(email);

        if (!pending || !pending.verification_code) {
          return res.status(400).json({ error: 'Código inválido' });
        }

        // Check expiration
        if (pending.verification_code_expires && new Date(pending.verification_code_expires) < new Date()) {
          return res.status(400).json({ error: 'Código expirado. Solicita uno nuevo.' });
        }

        // Timing-safe comparison
        const codeMatch = pending.verification_code.length === code.length &&
          crypto.timingSafeEqual(Buffer.from(pending.verification_code), Buffer.from(code));

        if (!codeMatch) {
          return res.status(400).json({ error: 'Código inválido' });
        }

        // Code is valid — create the real user
        const userId = uuidv4();
        db.prepare(`INSERT INTO users (id, email, password, first_name, last_name, phone, role, email_verified)
          VALUES (?, ?, ?, ?, ?, ?, ?, ?)`).run(userId, pending.email, pending.password, pending.first_name, pending.last_name, pending.phone || '', 'client', 1);

        // Remove from pending
        db.prepare('DELETE FROM pending_registrations WHERE id = ?').run(pending.id);

        const verified = db.prepare('SELECT * FROM users WHERE id = ?').get(userId);
        const { token, refreshToken } = generateTokens(verified);

        res.json({
          token,
          refreshToken,
          user: sanitizeUser(verified),
          message: 'Correo verificado exitosamente',
        });
      } catch (error) {
        console.error('[auth] Verify email error:', error);
        res.status(500).json({ error: 'Error al verificar correo' });
      }
    }
  );

  // ══════════════════════════════════════
  // POST /api/auth/resend-verification
  // ══════════════════════════════════════
  router.post('/resend-verification',
    authLimiter,
    [body('email').isEmail().normalizeEmail().withMessage('Email inválido')],
    async (req, res) => {
      try {
        const { email } = req.body;
        const db = getDb();
        const pending = db.prepare('SELECT * FROM pending_registrations WHERE email = ?').get(email);

        // Always respond 200 to not leak emails
        if (!pending) {
          return res.json({ message: 'Si el correo existe y no está verificado, recibirás un nuevo código.' });
        }

        const newCode = generateCode();
        const expires = new Date(Date.now() + 30 * 60 * 1000).toISOString();
        db.prepare('UPDATE pending_registrations SET verification_code = ?, verification_code_expires = ? WHERE id = ?')
          .run(newCode, expires, pending.id);

        await sendVerificationEmail(email, pending.first_name, newCode);

        res.json({ message: 'Si el correo existe y no está verificado, recibirás un nuevo código.' });
      } catch (error) {
        console.error('[auth] Resend verification error:', error);
        res.status(500).json({ error: 'Error al reenviar código' });
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
          // Check if there's a pending registration
          const pending = db.prepare('SELECT email FROM pending_registrations WHERE email = ?').get(email);
          if (pending) {
            return res.status(403).json({
              error: 'Debes verificar tu correo electrónico antes de iniciar sesión.',
              requiresVerification: true,
              email: pending.email,
            });
          }
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

        if (!user) {
          return res.json({ sent: false, message: 'No existe una cuenta con ese correo electrónico' });
        }

        // Google-only accounts can't reset password
        if (user.provider === 'google' && !user.password) {
          return res.json({ sent: false, message: 'Esta cuenta usa inicio de sesión con Google. No se puede restablecer la contraseña.' });
        }

        const resetCode = generateCode();
        const expires = new Date(Date.now() + 30 * 60 * 1000).toISOString(); // 30 min

        db.prepare('UPDATE users SET reset_code = ?, reset_code_expires = ?, updated_at = datetime("now") WHERE id = ?')
          .run(resetCode, expires, user.id);

        // Send password reset email via Brevo
        await sendPasswordResetEmail(email, user.first_name, resetCode);
        console.log(`[auth] Reset code generated for ${email}`);

        res.json({ sent: true, message: 'Te hemos enviado un código de recuperación a tu correo' });
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
      body('code').isLength({ min: 6, max: 6 }).isNumeric().withMessage('Código de 6 dígitos requerido'),
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
        if (!user || !user.reset_code || user.reset_code.length !== code.length ||
            !crypto.timingSafeEqual(Buffer.from(user.reset_code), Buffer.from(code))) {
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
