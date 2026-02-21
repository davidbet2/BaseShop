const express = require('express');
const { body, param, query, validationResult } = require('express-validator');
const { v4: uuidv4 } = require('uuid');
const { getDb } = require('../database');
const { authMiddleware, roleMiddleware } = require('../middleware/auth');

const router = express.Router();

// Todas las rutas requieren autenticación
router.use(authMiddleware);

// ══════════════════════════════════════
// GET /api/users/me/profile
// Obtener perfil del usuario autenticado
// ══════════════════════════════════════
router.get('/me/profile', (req, res) => {
  try {
    const db = getDb();
    let profile = db.prepare('SELECT * FROM users_profiles WHERE user_id = ?').get(req.user.id);

    if (!profile) {
      // Crear perfil vacío automáticamente
      const id = uuidv4();
      db.prepare(`INSERT INTO users_profiles (id, user_id) VALUES (?, ?)`).run(id, req.user.id);
      profile = db.prepare('SELECT * FROM users_profiles WHERE id = ?').get(id);
    }

    res.json({ profile });
  } catch (error) {
    console.error('[users] Get profile error:', error);
    res.status(500).json({ error: 'Error al obtener perfil' });
  }
});

// ══════════════════════════════════════
// PUT /api/users/me/profile
// Actualizar perfil del usuario autenticado
// ══════════════════════════════════════
router.put('/me/profile',
  [
    body('first_name').optional().trim().isLength({ max: 100 }).withMessage('Nombre muy largo'),
    body('last_name').optional().trim().isLength({ max: 100 }).withMessage('Apellido muy largo'),
    body('phone').optional().trim().isLength({ max: 20 }).withMessage('Teléfono muy largo'),
    body('avatar').optional().trim(),
    body('address').optional().trim().isLength({ max: 255 }).withMessage('Dirección muy larga'),
    body('city').optional().trim().isLength({ max: 100 }).withMessage('Ciudad muy larga'),
    body('state').optional().trim().isLength({ max: 100 }).withMessage('Estado/Departamento muy largo'),
    body('zip_code').optional().trim().isLength({ max: 20 }).withMessage('Código postal muy largo'),
    body('country').optional().trim().isLength({ max: 100 }).withMessage('País muy largo'),
  ],
  (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ error: errors.array()[0].msg });
      }

      const db = getDb();
      let profile = db.prepare('SELECT * FROM users_profiles WHERE user_id = ?').get(req.user.id);

      if (!profile) {
        const id = uuidv4();
        db.prepare(`INSERT INTO users_profiles (id, user_id) VALUES (?, ?)`).run(id, req.user.id);
        profile = db.prepare('SELECT * FROM users_profiles WHERE id = ?').get(id);
      }

      const allowedFields = ['first_name', 'last_name', 'phone', 'avatar', 'address', 'city', 'state', 'zip_code', 'country'];
      const updates = [];
      const values = [];

      for (const field of allowedFields) {
        if (req.body[field] !== undefined) {
          updates.push(`${field} = ?`);
          values.push(req.body[field]);
        }
      }

      if (updates.length === 0) {
        return res.status(400).json({ error: 'No se proporcionaron campos para actualizar' });
      }

      updates.push("updated_at = datetime('now')");
      values.push(req.user.id);

      db.prepare(`UPDATE users_profiles SET ${updates.join(', ')} WHERE user_id = ?`).run(...values);

      const updated = db.prepare('SELECT * FROM users_profiles WHERE user_id = ?').get(req.user.id);
      res.json({ profile: updated, message: 'Perfil actualizado exitosamente' });
    } catch (error) {
      console.error('[users] Update profile error:', error);
      res.status(500).json({ error: 'Error al actualizar perfil' });
    }
  }
);

// ══════════════════════════════════════
// GET /api/users/me/addresses
// Listar direcciones del usuario autenticado
// ══════════════════════════════════════
router.get('/me/addresses', (req, res) => {
  try {
    const db = getDb();
    const addresses = db.prepare('SELECT * FROM addresses WHERE user_id = ? ORDER BY is_default DESC, created_at DESC').all(req.user.id);
    res.json({ addresses });
  } catch (error) {
    console.error('[users] List addresses error:', error);
    res.status(500).json({ error: 'Error al obtener direcciones' });
  }
});

// ══════════════════════════════════════
// POST /api/users/me/addresses
// Agregar dirección
// ══════════════════════════════════════
router.post('/me/addresses',
  [
    body('label').optional().trim().isLength({ max: 50 }).withMessage('Etiqueta muy larga'),
    body('address').notEmpty().trim().withMessage('Dirección requerida'),
    body('city').notEmpty().trim().withMessage('Ciudad requerida'),
    body('state').optional().trim(),
    body('zip_code').optional().trim(),
    body('country').optional().trim(),
    body('is_default').optional().isBoolean(),
  ],
  (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ error: errors.array()[0].msg });
      }

      const db = getDb();
      const { label, address, city, state, zip_code, country, is_default } = req.body;
      const id = uuidv4();

      // Si es default, quitar default de las demás
      if (is_default) {
        db.prepare('UPDATE addresses SET is_default = 0 WHERE user_id = ?').run(req.user.id);
      }

      // Si es la primera dirección, hacerla default automáticamente
      const existingAddresses = db.prepare('SELECT COUNT(*) as count FROM addresses WHERE user_id = ?').get(req.user.id);
      const setDefault = is_default || existingAddresses.count === 0 ? 1 : 0;

      db.prepare(`INSERT INTO addresses (id, user_id, label, address, city, state, zip_code, country, is_default)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`).run(
        id, req.user.id,
        label || '', address, city,
        state || '', zip_code || '', country || 'Colombia',
        setDefault
      );

      const newAddress = db.prepare('SELECT * FROM addresses WHERE id = ?').get(id);
      res.status(201).json({ address: newAddress, message: 'Dirección agregada exitosamente' });
    } catch (error) {
      console.error('[users] Add address error:', error);
      res.status(500).json({ error: 'Error al agregar dirección' });
    }
  }
);

// ══════════════════════════════════════
// PUT /api/users/me/addresses/:id
// Actualizar dirección
// ══════════════════════════════════════
router.put('/me/addresses/:id',
  [
    param('id').isUUID().withMessage('ID de dirección inválido'),
    body('label').optional().trim().isLength({ max: 50 }),
    body('address').optional().trim(),
    body('city').optional().trim(),
    body('state').optional().trim(),
    body('zip_code').optional().trim(),
    body('country').optional().trim(),
    body('is_default').optional().isBoolean(),
  ],
  (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ error: errors.array()[0].msg });
      }

      const db = getDb();
      const existing = db.prepare('SELECT * FROM addresses WHERE id = ? AND user_id = ?').get(req.params.id, req.user.id);
      if (!existing) {
        return res.status(404).json({ error: 'Dirección no encontrada' });
      }

      const allowedFields = ['label', 'address', 'city', 'state', 'zip_code', 'country'];
      const updates = [];
      const values = [];

      for (const field of allowedFields) {
        if (req.body[field] !== undefined) {
          updates.push(`${field} = ?`);
          values.push(req.body[field]);
        }
      }

      // Manejar is_default
      if (req.body.is_default !== undefined) {
        if (req.body.is_default) {
          db.prepare('UPDATE addresses SET is_default = 0 WHERE user_id = ?').run(req.user.id);
        }
        updates.push('is_default = ?');
        values.push(req.body.is_default ? 1 : 0);
      }

      if (updates.length === 0) {
        return res.status(400).json({ error: 'No se proporcionaron campos para actualizar' });
      }

      updates.push("updated_at = datetime('now')");
      values.push(req.params.id);
      values.push(req.user.id);

      db.prepare(`UPDATE addresses SET ${updates.join(', ')} WHERE id = ? AND user_id = ?`).run(...values);

      const updated = db.prepare('SELECT * FROM addresses WHERE id = ?').get(req.params.id);
      res.json({ address: updated, message: 'Dirección actualizada exitosamente' });
    } catch (error) {
      console.error('[users] Update address error:', error);
      res.status(500).json({ error: 'Error al actualizar dirección' });
    }
  }
);

// ══════════════════════════════════════
// DELETE /api/users/me/addresses/:id
// Eliminar dirección
// ══════════════════════════════════════
router.delete('/me/addresses/:id',
  [param('id').isUUID().withMessage('ID de dirección inválido')],
  (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ error: errors.array()[0].msg });
      }

      const db = getDb();
      const existing = db.prepare('SELECT * FROM addresses WHERE id = ? AND user_id = ?').get(req.params.id, req.user.id);
      if (!existing) {
        return res.status(404).json({ error: 'Dirección no encontrada' });
      }

      db.prepare('DELETE FROM addresses WHERE id = ? AND user_id = ?').run(req.params.id, req.user.id);

      // Si era la default, asignar default a la primera dirección restante
      if (existing.is_default) {
        const first = db.prepare('SELECT id FROM addresses WHERE user_id = ? ORDER BY created_at ASC LIMIT 1').get(req.user.id);
        if (first) {
          db.prepare('UPDATE addresses SET is_default = 1 WHERE id = ?').run(first.id);
        }
      }

      res.json({ message: 'Dirección eliminada exitosamente' });
    } catch (error) {
      console.error('[users] Delete address error:', error);
      res.status(500).json({ error: 'Error al eliminar dirección' });
    }
  }
);

// ══════════════════════════════════════
// GET /api/users (admin)
// Listar todos los usuarios con paginación
// ══════════════════════════════════════
router.get('/',
  roleMiddleware('admin'),
  [
    query('page').optional().isInt({ min: 1 }).toInt(),
    query('limit').optional().isInt({ min: 1, max: 100 }).toInt(),
    query('search').optional().trim(),
  ],
  (req, res) => {
    try {
      const db = getDb();
      const page = req.query.page || 1;
      const limit = req.query.limit || 20;
      const offset = (page - 1) * limit;
      const search = req.query.search || '';

      let countSql = 'SELECT COUNT(*) as total FROM users_profiles';
      let dataSql = 'SELECT * FROM users_profiles';
      const params = [];

      if (search) {
        const where = ' WHERE first_name LIKE ? OR last_name LIKE ? OR user_id LIKE ?';
        countSql += where;
        dataSql += where;
        const term = `%${search}%`;
        params.push(term, term, term);
      }

      dataSql += ' ORDER BY created_at DESC LIMIT ? OFFSET ?';

      const countResult = db.prepare(countSql).get(...params);
      const total = countResult ? countResult.total : 0;

      const dataParams = [...params, limit, offset];
      const users = db.prepare(dataSql).all(...dataParams);

      res.json({
        users,
        pagination: {
          page,
          limit,
          total,
          pages: Math.ceil(total / limit),
        },
      });
    } catch (error) {
      console.error('[users] List users error:', error);
      res.status(500).json({ error: 'Error al listar usuarios' });
    }
  }
);

// ══════════════════════════════════════
// GET /api/users/:id (admin)
// Obtener usuario por ID
// ══════════════════════════════════════
router.get('/:id',
  roleMiddleware('admin'),
  [param('id').isUUID().withMessage('ID de usuario inválido')],
  (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ error: errors.array()[0].msg });
      }

      const db = getDb();
      const profile = db.prepare('SELECT * FROM users_profiles WHERE user_id = ?').get(req.params.id);
      if (!profile) {
        return res.status(404).json({ error: 'Usuario no encontrado' });
      }

      const addresses = db.prepare('SELECT * FROM addresses WHERE user_id = ? ORDER BY is_default DESC, created_at DESC').all(req.params.id);

      res.json({ profile, addresses });
    } catch (error) {
      console.error('[users] Get user error:', error);
      res.status(500).json({ error: 'Error al obtener usuario' });
    }
  }
);

// ══════════════════════════════════════
// PATCH /api/users/:id/status (admin)
// Activar/desactivar usuario (marca en perfil)
// ══════════════════════════════════════
router.patch('/:id/status',
  roleMiddleware('admin'),
  [
    param('id').isUUID().withMessage('ID de usuario inválido'),
    body('is_active').isBoolean().withMessage('is_active debe ser booleano'),
  ],
  (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ error: errors.array()[0].msg });
      }

      const db = getDb();
      const profile = db.prepare('SELECT * FROM users_profiles WHERE user_id = ?').get(req.params.id);
      if (!profile) {
        return res.status(404).json({ error: 'Usuario no encontrado' });
      }

      // Nota: El estado activo/inactivo real se gestiona en auth-service.
      // Aquí se puede registrar una marca local o notificar al auth-service.
      res.json({
        message: req.body.is_active ? 'Usuario activado' : 'Usuario desactivado',
        user_id: req.params.id,
        is_active: req.body.is_active,
      });
    } catch (error) {
      console.error('[users] Update status error:', error);
      res.status(500).json({ error: 'Error al actualizar estado del usuario' });
    }
  }
);

// ══════════════════════════════════════
// POST /api/users/device-tokens
// Registrar token de dispositivo (FCM)
// ══════════════════════════════════════
router.post('/device-tokens',
  [
    body('token').notEmpty().trim().withMessage('Token de dispositivo requerido'),
    body('platform').optional().trim().isIn(['android', 'ios', 'web']).withMessage('Plataforma inválida'),
  ],
  (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ error: errors.array()[0].msg });
      }

      const db = getDb();
      const { token, platform } = req.body;

      // Verificar si ya existe el token
      const existing = db.prepare('SELECT id FROM device_tokens WHERE token = ?').get(token);
      if (existing) {
        // Actualizar user_id si cambió
        db.prepare('UPDATE device_tokens SET user_id = ?, platform = ? WHERE token = ?').run(req.user.id, platform || '', token);
        return res.json({ message: 'Token de dispositivo actualizado' });
      }

      const id = uuidv4();
      db.prepare('INSERT INTO device_tokens (id, user_id, token, platform) VALUES (?, ?, ?, ?)').run(id, req.user.id, token, platform || '');

      res.status(201).json({ message: 'Token de dispositivo registrado' });
    } catch (error) {
      console.error('[users] Register device token error:', error);
      res.status(500).json({ error: 'Error al registrar token de dispositivo' });
    }
  }
);

// ══════════════════════════════════════
// DELETE /api/users/device-tokens
// Eliminar token de dispositivo
// ══════════════════════════════════════
router.delete('/device-tokens',
  [body('token').notEmpty().trim().withMessage('Token de dispositivo requerido')],
  (req, res) => {
    try {
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        return res.status(400).json({ error: errors.array()[0].msg });
      }

      const db = getDb();
      const { token } = req.body;

      const result = db.prepare('DELETE FROM device_tokens WHERE token = ? AND user_id = ?').run(token, req.user.id);

      if (result.changes === 0) {
        return res.status(404).json({ error: 'Token no encontrado' });
      }

      res.json({ message: 'Token de dispositivo eliminado' });
    } catch (error) {
      console.error('[users] Delete device token error:', error);
      res.status(500).json({ error: 'Error al eliminar token de dispositivo' });
    }
  }
);

module.exports = router;
