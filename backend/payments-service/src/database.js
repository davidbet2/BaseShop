const initSql = require('sql.js');
const path = require('path');
const fs = require('fs');

let rawDb;
let db;

const DB_PATH = path.resolve(process.env.DB_PATH || './data/payments.db');

class Statement {
  constructor(rawDb, sql) {
    this._rawDb = rawDb;
    this._sql = sql;
  }
  run(...params) {
    this._rawDb.run(this._sql, params.length === 1 && typeof params[0] === 'object' ? params[0] : params);
    const changes = this._rawDb.getRowsModified();
    save();
    return { changes };
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

  // ── Tabla de pagos ──
  rawDb.run(`CREATE TABLE IF NOT EXISTS payments (
    id TEXT PRIMARY KEY,
    order_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    amount REAL NOT NULL,
    currency TEXT DEFAULT 'COP',
    status TEXT DEFAULT 'pending',
    payment_method TEXT DEFAULT '',
    provider TEXT DEFAULT 'payu',
    provider_reference TEXT DEFAULT '',
    provider_response TEXT DEFAULT '',
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
  )`);

  // ── Tabla de logs de pago ──
  rawDb.run(`CREATE TABLE IF NOT EXISTS payment_logs (
    id TEXT PRIMARY KEY,
    payment_id TEXT NOT NULL,
    event TEXT NOT NULL,
    data TEXT DEFAULT '',
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (payment_id) REFERENCES payments(id) ON DELETE CASCADE
  )`);

  // ── Índices ──
  rawDb.run('CREATE INDEX IF NOT EXISTS idx_payments_order ON payments(order_id)');
  rawDb.run('CREATE INDEX IF NOT EXISTS idx_payments_user ON payments(user_id)');
  rawDb.run('CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status)');
  rawDb.run('CREATE INDEX IF NOT EXISTS idx_payments_created ON payments(created_at)');
  rawDb.run('CREATE INDEX IF NOT EXISTS idx_payment_logs_payment ON payment_logs(payment_id)');

  save();

  // Auto-save cada 5 segundos
  setInterval(save, 5000);

  console.log('[payments-service] Database initialized:', DB_PATH);
};

const getDb = () => db = db || {
  prepare: (sql) => new Statement(rawDb, sql),
  exec: (sql) => { rawDb.run(sql); save(); },
  pragma: (p) => {},
  transaction: (fn) => (...args) => { fn(...args); save(); },
  close: () => { save(); rawDb.close(); },
};

const close = () => { if (db) db.close(); };

module.exports = { initDatabase, getDb, close };
