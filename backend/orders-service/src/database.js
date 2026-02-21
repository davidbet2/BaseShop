const initSql = require('sql.js');
const path = require('path');
const fs = require('fs');

let rawDb;
let db;

const DB_PATH = path.resolve(process.env.DB_PATH || './data/orders.db');

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

function generateOrderNumber() {
  const result = rawDb.exec("SELECT order_number FROM orders ORDER BY order_number DESC LIMIT 1");
  let nextNum = 1;
  if (result.length > 0 && result[0].values.length > 0) {
    const lastNumber = result[0].values[0][0]; // e.g. "BS-000042"
    const num = parseInt(lastNumber.replace('BS-', ''), 10);
    if (!isNaN(num)) nextNum = num + 1;
  }
  return `BS-${String(nextNum).padStart(6, '0')}`;
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

  // ── Tabla de pedidos ──
  rawDb.run(`CREATE TABLE IF NOT EXISTS orders (
    id TEXT PRIMARY KEY,
    order_number TEXT UNIQUE NOT NULL,
    user_id TEXT NOT NULL,
    status TEXT DEFAULT 'pending',
    subtotal REAL DEFAULT 0,
    shipping_cost REAL DEFAULT 0,
    tax REAL DEFAULT 0,
    total REAL DEFAULT 0,
    shipping_address TEXT DEFAULT '',
    billing_address TEXT DEFAULT '',
    payment_method TEXT DEFAULT '',
    payment_id TEXT DEFAULT '',
    notes TEXT DEFAULT '',
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now'))
  )`);

  // ── Tabla de items del pedido ──
  rawDb.run(`CREATE TABLE IF NOT EXISTS order_items (
    id TEXT PRIMARY KEY,
    order_id TEXT NOT NULL,
    product_id TEXT NOT NULL,
    product_name TEXT,
    product_price REAL,
    product_image TEXT,
    quantity INTEGER DEFAULT 1,
    subtotal REAL DEFAULT 0,
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
  )`);

  // ── Tabla de historial de estados ──
  rawDb.run(`CREATE TABLE IF NOT EXISTS order_status_history (
    id TEXT PRIMARY KEY,
    order_id TEXT NOT NULL,
    status TEXT NOT NULL,
    note TEXT DEFAULT '',
    changed_by TEXT DEFAULT '',
    created_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (order_id) REFERENCES orders(id) ON DELETE CASCADE
  )`);

  // ── Índices ──
  rawDb.run('CREATE INDEX IF NOT EXISTS idx_orders_user ON orders(user_id)');
  rawDb.run('CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status)');
  rawDb.run('CREATE INDEX IF NOT EXISTS idx_orders_number ON orders(order_number)');
  rawDb.run('CREATE INDEX IF NOT EXISTS idx_orders_created ON orders(created_at)');
  rawDb.run('CREATE INDEX IF NOT EXISTS idx_order_items_order ON order_items(order_id)');
  rawDb.run('CREATE INDEX IF NOT EXISTS idx_order_status_history_order ON order_status_history(order_id)');

  save();

  // Auto-save cada 5 segundos
  setInterval(save, 5000);

  console.log('[orders-service] Database initialized:', DB_PATH);
};

const getDb = () => db = db || {
  prepare: (sql) => new Statement(rawDb, sql),
  exec: (sql) => { rawDb.run(sql); save(); },
  pragma: (p) => {},
  transaction: (fn) => (...args) => { fn(...args); save(); },
  close: () => { save(); rawDb.close(); },
};

const close = () => { if (db) db.close(); };

module.exports = { initDatabase, getDb, close, generateOrderNumber };
