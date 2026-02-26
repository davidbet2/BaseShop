const initSql = require('sql.js');
const path = require('path');
const fs = require('fs');

let rawDb;
let db;

const DB_PATH = path.resolve(process.env.DB_PATH || './data/config-service.db');

class Statement {
  constructor(rawDb, sql) {
    this._rawDb = rawDb;
    this._sql = sql;
  }
  run(...params) {
    this._rawDb.run(this._sql, params.length === 1 && typeof params[0] === 'object' ? params[0] : params);
    save();
    return { changes: this._rawDb.getRowsModified() };
  }
  get(...params) {
    const stmt = this._rawDb.prepare(this._sql);
    stmt.bind(params.length === 1 && typeof params[0] === 'object' ? params[0] : params);
    if (stmt.step()) {
      const cols = stmt.getColumnNames();
      const vals = stmt.get();
      stmt.free();
      return cols.reduce((obj, col, i) => ({ ...obj, [col]: vals[i] }), {});
    }
    stmt.free();
    return undefined;
  }
  all(...params) {
    const rows = [];
    const stmt = this._rawDb.prepare(this._sql);
    stmt.bind(params.length === 1 && typeof params[0] === 'object' ? params[0] : params);
    while (stmt.step()) {
      const cols = stmt.getColumnNames();
      const vals = stmt.get();
      rows.push(cols.reduce((obj, col, i) => ({ ...obj, [col]: vals[i] }), {}));
    }
    stmt.free();
    return rows;
  }
}

function save() {
  try {
    const dir = path.dirname(DB_PATH);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
    const data = rawDb.export();
    fs.writeFileSync(DB_PATH, Buffer.from(data));
  } catch (err) {
    console.error('[DB] Error saving:', err.message);
  }
}

const initDatabase = async () => {
  const SQL = await initSql();

  if (fs.existsSync(DB_PATH)) {
    const buffer = fs.readFileSync(DB_PATH);
    rawDb = new SQL.Database(buffer);
  } else {
    rawDb = new SQL.Database();
  }

  rawDb.run('PRAGMA journal_mode=WAL');

  db = {
    prepare: (sql) => new Statement(rawDb, sql),
    exec: (sql) => { rawDb.run(sql); save(); },
    pragma: (p) => {},
    transaction: (fn) => (...args) => { fn(...args); save(); },
    close: () => { save(); rawDb.close(); },
  };

  // ── Tabla de configuración (clave-valor) ──
  rawDb.run(`CREATE TABLE IF NOT EXISTS store_config (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL,
    updated_at TEXT DEFAULT (datetime('now'))
  )`);

  // ── Tabla de banners ──
  rawDb.run(`CREATE TABLE IF NOT EXISTS banners (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    image_path TEXT NOT NULL,
    product_id TEXT DEFAULT NULL,
    custom_price REAL DEFAULT NULL,
    sort_order INTEGER DEFAULT 0,
    created_at TEXT DEFAULT (datetime('now'))
  )`);

  // ── Seed: valores por defecto si no existen ──
  const existing = db.prepare('SELECT COUNT(*) as count FROM store_config').get();
  if (existing.count === 0) {
    const defaults = {
      store_name: 'BaseShop',
      store_logo: '',
      show_header: '1',
      show_footer: '1',
      featured_title: 'Colección destacada',
      featured_desc: 'Los productos más elegidos por nuestros clientes',
      primary_color_hex: 'F97316',
    };
    const insertStmt = db.prepare('INSERT INTO store_config (key, value) VALUES (?, ?)');
    for (const [key, value] of Object.entries(defaults)) {
      insertStmt.run(key, value);
    }
    console.log('[config-service] Default config seeded');
  }

  // Auto-save cada 5 segundos
  setInterval(save, 5000);

  console.log('[config-service] Database initialized:', DB_PATH);
};

const getDb = () => db;
const close = () => { if (db) db.close(); };

module.exports = { initDatabase, getDb, close };
