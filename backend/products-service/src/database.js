const initSql = require('sql.js');
const path = require('path');
const fs = require('fs');
const { v4: uuidv4 } = require('uuid');

let rawDb;
let db;

const DB_PATH = path.resolve(process.env.DB_PATH || './data/products.db');

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

  // ── Tabla de categorías ──
  rawDb.run(`CREATE TABLE IF NOT EXISTS categories (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    slug TEXT UNIQUE,
    description TEXT DEFAULT '',
    image TEXT DEFAULT '',
    parent_id TEXT DEFAULT NULL,
    sort_order INTEGER DEFAULT 0,
    is_active INTEGER DEFAULT 1,
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (parent_id) REFERENCES categories(id) ON DELETE SET NULL
  )`);

  // ── Tabla de productos ──
  rawDb.run(`CREATE TABLE IF NOT EXISTS products (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    slug TEXT UNIQUE,
    description TEXT DEFAULT '',
    short_description TEXT DEFAULT '',
    price REAL NOT NULL DEFAULT 0,
    compare_price REAL DEFAULT 0,
    sku TEXT UNIQUE,
    stock INTEGER DEFAULT 0,
    category_id TEXT,
    images TEXT DEFAULT '[]',
    is_active INTEGER DEFAULT 1,
    is_featured INTEGER DEFAULT 0,
    weight REAL DEFAULT 0,
    dimensions TEXT DEFAULT '',
    tags TEXT DEFAULT '',
    created_at TEXT DEFAULT (datetime('now')),
    updated_at TEXT DEFAULT (datetime('now')),
    FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL
  )`);

  // ── Índices ──
  rawDb.run('CREATE INDEX IF NOT EXISTS idx_products_category ON products(category_id)');
  rawDb.run('CREATE INDEX IF NOT EXISTS idx_products_active ON products(is_active)');
  rawDb.run('CREATE INDEX IF NOT EXISTS idx_products_featured ON products(is_featured)');
  rawDb.run('CREATE INDEX IF NOT EXISTS idx_products_price ON products(price)');
  rawDb.run('CREATE INDEX IF NOT EXISTS idx_categories_parent ON categories(parent_id)');
  rawDb.run('CREATE INDEX IF NOT EXISTS idx_categories_slug ON categories(slug)');
  rawDb.run('CREATE INDEX IF NOT EXISTS idx_products_slug ON products(slug)');

  save();

  // ── Seed: categorías por defecto ──
  const existing = db.prepare('SELECT COUNT(*) as count FROM categories').get();
  if (existing.count === 0) {
    const defaultCategories = [
      { name: 'Electrónica', slug: 'electronica', description: 'Dispositivos y gadgets electrónicos', sort_order: 1 },
      { name: 'Ropa', slug: 'ropa', description: 'Moda y accesorios', sort_order: 2 },
      { name: 'Hogar', slug: 'hogar', description: 'Artículos para el hogar y decoración', sort_order: 3 },
      { name: 'Deportes', slug: 'deportes', description: 'Equipamiento y ropa deportiva', sort_order: 4 },
      { name: 'Belleza', slug: 'belleza', description: 'Cuidado personal y cosmética', sort_order: 5 },
    ];

    for (const cat of defaultCategories) {
      db.prepare(`INSERT INTO categories (id, name, slug, description, sort_order) VALUES (?, ?, ?, ?, ?)`)
        .run(uuidv4(), cat.name, cat.slug, cat.description, cat.sort_order);
    }

    console.log('[products-service] Default categories seeded');
  }

  // Auto-save cada 5 segundos
  setInterval(save, 5000);

  console.log('[products-service] Database initialized:', DB_PATH);
};

const getDb = () => db;
const close = () => { if (db) db.close(); };

module.exports = { initDatabase, getDb, close };
