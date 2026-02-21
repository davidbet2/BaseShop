const initSql = require('sql.js');
const path = require('path');
const fs = require('fs');

let rawDb;
let db;

const DB_PATH = path.resolve(process.env.DB_PATH || './data/favorites.db');

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
  rawDb.run('PRAGMA foreign_keys=ON');

  db = {
    prepare: (sql) => new Statement(rawDb, sql),
    exec: (sql) => { rawDb.run(sql); save(); },
    pragma: (p) => {},
    transaction: (fn) => (...args) => { fn(...args); save(); },
    close: () => { save(); rawDb.close(); },
  };

  // ── Tabla de favoritos ──
  rawDb.run(`CREATE TABLE IF NOT EXISTS favorites (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    product_id TEXT NOT NULL,
    product_name TEXT DEFAULT '',
    product_price REAL DEFAULT 0,
    product_image TEXT DEFAULT '',
    created_at TEXT DEFAULT (datetime('now')),
    UNIQUE(user_id, product_id)
  )`);

  // ── Índices ──
  rawDb.run('CREATE INDEX IF NOT EXISTS idx_favorites_user ON favorites(user_id)');
  rawDb.run('CREATE INDEX IF NOT EXISTS idx_favorites_product ON favorites(product_id)');

  save();

  // Auto-save cada 5 segundos
  setInterval(save, 5000);

  console.log('[favorites-service] Database initialized:', DB_PATH);
};

const getDb = () => db;
const close = () => { if (db) db.close(); };

module.exports = { initDatabase, getDb, close };
