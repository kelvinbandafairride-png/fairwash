const fs = require('fs');
const path = require('path');
const bcrypt = require('bcryptjs');

const usePg = !!process.env.DATABASE_URL;
let pgPool;

if (usePg) {
  const { Pool } = require('pg');
  pgPool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: { rejectUnauthorized: false },
    family: 4
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
        id SERIAL PRIMARY KEY, amount DECIMAL(10,2) NOT NULL,
        recorded_by VARCHAR(50) DEFAULT 'staff',
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
  const { amount, recorded_by } = data;

  if (usePg) {
    const { rows } = await pgPool.query(
      `INSERT INTO sales (amount, recorded_by) VALUES ($1,$2) RETURNING *`,
      [parseFloat(amount), recorded_by]
    );
    return rows[0];
  }

  const sale = {
    id: jsonDb.nextSaleId++,
    amount: parseFloat(amount),
    recorded_by, created_at: new Date().toISOString()
  };
  jsonDb.sales.push(sale);
  saveJson();
  return sale;
}

async function getSummary(period) {
  if (usePg) {
    const clause = getDateClause(period);
    const { rows } = await pgPool.query(`SELECT COALESCE(SUM(amount),0)::float as total, COUNT(*)::int as count FROM sales ${clause}`);
    return { total: rows[0].total, count: rows[0].count };
  }

  const filtered = filterJsonSales(jsonDb.sales, period);
  const total = filtered.reduce((s, v) => s + v.amount, 0);
  return { total, count: filtered.length };
}

module.exports = { initDb, findUser, getAllSales, getFilteredSales, createSale, getSummary };
