const express = require('express');
const db = require('../db');
const { authenticate } = require('../middleware/auth');

const router = express.Router();

router.get('/', authenticate, async (req, res) => {
  try {
    const sales = await db.getAllSales();
    res.json(sales);
  } catch (err) {
    console.error('Get sales error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

router.get('/filter', authenticate, async (req, res) => {
  try {
    const sales = await db.getFilteredSales(req.query.period);
    res.json(sales);
  } catch (err) {
    console.error('Filter sales error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

router.post('/', authenticate, async (req, res) => {
  const { vehicle_type, vehicle_size, wash_type, wash_category, amount } = req.body;
  if (!vehicle_type || !vehicle_size || !wash_type || !wash_category || amount === undefined) {
    return res.status(400).json({ error: 'Missing required fields' });
  }
  try {
    const sale = await db.createSale({ ...req.body, recorded_by: req.user.username });
    res.status(201).json(sale);
  } catch (err) {
    console.error('Create sale error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

router.get('/summary', authenticate, async (req, res) => {
  try {
    const summary = await db.getSummary(req.query.period);
    res.json(summary);
  } catch (err) {
    console.error('Summary error:', err);
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
