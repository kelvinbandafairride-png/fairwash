const fs = require('fs');
const path = require('path');
const bcrypt = require('bcryptjs');

const usePg = !!process.env.DATABASE_URL;
let pgPool;

if (usePg) {
  const { Pool } = require('pg');
  pgPool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: { rejectUnauthorized: false }
  });
}

// ---- JSON file storage (local dev) ----
const dbDir = path.join(__dirname, 'data');
if (!fs.existsSync(dbDir)) fs.mkdirSync(dbDir, { recursive: true });
const DB_PATH = path.join(dbDir, 'fairwash.json');

function loadJson() {
  if (!fs.existsSync(DB_PATH)) {
    const init = { users: [], sales: [], nextUserId: 1, nextSaleId: 1 };
    fs.writeFileSync(DB_PATH, JSON.stringify(init, null, 2));
    return init;
  }
  return JSON.parse(fs.readFileSync(DB_PATH, 'utf-8'));
}

let jsonDb = loadJson();

function saveJson() {
  fs.writeFileSync(DB_PATH, JSON.stringify(jsonDb, null, 2));
}

// ---- Unified async API ----
async function initDb() {
  if (usePg) {
    await pgPool.query(`
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY, username VARCHAR(50) UNIQUE NOT NULL,
        password VARCHAR(255) NOT NULL, role VARCHAR(20) DEFAULT 'staff',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    await pgPool.query(`
      CREATE TABLE IF NOT EXISTS sales (
        id SERIAL PRIMARY KEY, vehicle_type VARCHAR(50) NOT NULL,
        vehicle_size VARCHAR(20) NOT NULL, wash_type VARCHAR(50) NOT NULL,
        wash_category VARCHAR(100) NOT NULL, amount DECIMAL(10,2) NOT NULL,
        license_plate VARCHAR(20) DEFAULT '', car_make VARCHAR(100) DEFAULT '',
        car_color VARCHAR(50) DEFAULT '', front_condition TEXT DEFAULT '',
        back_condition TEXT DEFAULT '', front_image TEXT DEFAULT '',
        back_image TEXT DEFAULT '', recorded_by VARCHAR(50) DEFAULT 'staff',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    const { rows } = await pgPool.query('SELECT COUNT(*)::int as count FROM users');
    if (rows[0].count === 0) {
      await pgPool.query(
        `INSERT INTO users (username, password, role) VALUES ($1,$2,$3),($4,$5,$6)`,
        ['admin', bcrypt.hashSync('admin123', 10), 'admin',
         'staff', bcrypt.hashSync('staff123', 10), 'staff']
      );
      console.log('Seed users created');
    }
    console.log('PostgreSQL connected');
  } else {
    if (jsonDb.users.length === 0) {
      jsonDb.users.push({ id: jsonDb.nextUserId++, username: 'admin',
        password: bcrypt.hashSync('admin123', 10), role: 'admin',
        created_at: new Date().toISOString() });
      jsonDb.users.push({ id: jsonDb.nextUserId++, username: 'staff',
        password: bcrypt.hashSync('staff123', 10), role: 'staff',
        created_at: new Date().toISOString() });
      saveJson();
      console.log('Seed users created');
    }
    console.log('JSON database loaded');
  }
}

async function findUser(username) {
  if (usePg) {
    const { rows } = await pgPool.query('SELECT * FROM users WHERE username = $1', [username]);
    return rows[0] || null;
  }
  return jsonDb.users.find(u => u.username === username) || null;
}

async function getAllSales(order = 'DESC') {
  if (usePg) {
    const { rows } = await pgPool.query(`SELECT * FROM sales ORDER BY created_at ${order}`);
    return rows;
  }
  return jsonDb.sales.slice().reverse();
}

function getDateClause(period) {
  if (!period || period === 'all') return '';
  if (period === 'today') return "WHERE created_at >= CURRENT_DATE";
  if (period === 'week') return "WHERE created_at >= date_trunc('week', CURRENT_DATE)";
  if (period === 'month') return "WHERE created_at >= date_trunc('month', CURRENT_DATE)";
  return '';
}

function filterJsonSales(sales, period) {
  const now = new Date();
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  if (period === 'today') return sales.filter(s => new Date(s.created_at) >= today);
  if (period === 'week') {
    const ws = new Date(today); ws.setDate(ws.getDate() - ws.getDay());
    return sales.filter(s => new Date(s.created_at) >= ws);
  }
  if (period === 'month') {
    const ms = new Date(now.getFullYear(), now.getMonth(), 1);
    return sales.filter(s => new Date(s.created_at) >= ms);
  }
  return sales;
}

async function getFilteredSales(period) {
  if (usePg) {
    const clause = getDateClause(period);
    const { rows } = await pgPool.query(`SELECT * FROM sales ${clause} ORDER BY created_at DESC`);
    return rows;
  }
  return filterJsonSales(jsonDb.sales.slice(), period).reverse();
}

async function createSale(data) {
  const { vehicle_type, vehicle_size, wash_type, wash_category, amount,
    license_plate, car_make, car_color, front_condition, back_condition,
    front_image, back_image, recorded_by } = data;

  if (usePg) {
    const { rows } = await pgPool.query(
      `INSERT INTO sales (vehicle_type, vehicle_size, wash_type, wash_category, amount,
        license_plate, car_make, car_color, front_condition, back_condition,
        front_image, back_image, recorded_by)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13) RETURNING *`,
      [vehicle_type, vehicle_size, wash_type, wash_category, parseFloat(amount),
       license_plate || '', car_make || '', car_color || '',
       front_condition || '', back_condition || '',
       front_image || '', back_image || '', recorded_by]
    );
    return rows[0];
  }

  const sale = {
    id: jsonDb.nextSaleId++, vehicle_type, vehicle_size, wash_type, wash_category,
    amount: parseFloat(amount), license_plate: license_plate || '',
    car_make: car_make || '', car_color: car_color || '',
    front_condition: front_condition || '', back_condition: back_condition || '',
    front_image: front_image || '', back_image: back_image || '',
    recorded_by, created_at: new Date().toISOString()
  };
  jsonDb.sales.push(sale);
  saveJson();
  return sale;
}

async function getSummary(period) {
  if (usePg) {
    const clause = getDateClause(period);
    const [tr, vt, wt, ct, vs] = await Promise.all([
      pgPool.query(`SELECT COALESCE(SUM(amount),0)::float as total, COUNT(*)::int as count FROM sales ${clause}`),
      pgPool.query(`SELECT vehicle_type as name, COUNT(*)::int as count, SUM(amount)::float as total FROM sales ${clause} GROUP BY vehicle_type ORDER BY total DESC`),
      pgPool.query(`SELECT wash_type as name, COUNT(*)::int as count, SUM(amount)::float as total FROM sales ${clause} GROUP BY wash_type ORDER BY total DESC`),
      pgPool.query(`SELECT wash_category as name, COUNT(*)::int as count, SUM(amount)::float as total FROM sales ${clause} GROUP BY wash_category ORDER BY total DESC`),
      pgPool.query(`SELECT vehicle_size as name, COUNT(*)::int as count, SUM(amount)::float as total FROM sales ${clause} GROUP BY vehicle_size ORDER BY total DESC`)
    ]);
    return {
      total: tr.rows[0].total, count: tr.rows[0].count,
      breakdowns: { vehicleType: vt.rows, washType: wt.rows, category: ct.rows, vehicleSize: vs.rows }
    };
  }

  const filtered = filterJsonSales(jsonDb.sales, period);
  const total = filtered.reduce((s, v) => s + v.amount, 0);
  const group = (key) => {
    const m = {}; filtered.forEach(s => {
      const k = s[key]; if (!m[k]) m[k] = { name: k, count: 0, total: 0 };
      m[k].count++; m[k].total += s.amount;
    }); return Object.values(m);
  };
  return {
    total, count: filtered.length,
    breakdowns: {
      vehicleType: group('vehicle_type'), washType: group('wash_type'),
      category: group('wash_category'), vehicleSize: group('vehicle_size')
    }
  };
}

module.exports = { initDb, findUser, getAllSales, getFilteredSales, createSale, getSummary };
