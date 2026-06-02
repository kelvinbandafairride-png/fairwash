const express = require('express');
const cors = require('cors');

const { initDb } = require('./db');
const authRoutes = require('./routes/auth');
const salesRoutes = require('./routes/sales');

const app = express();
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json({ limit: '50mb' }));

app.use('/api/auth', authRoutes);
app.use('/api/sales', salesRoutes);

app.get('/health', (req, res) => res.json({ status: 'ok' }));

initDb().then(() => {
  app.listen(PORT, '0.0.0.0', () => {
    console.log(`\n🚗 Fair Car Wash Backend running!`);
    console.log(`   Local:    http://localhost:${PORT}`);
    console.log(`   API:      http://localhost:${PORT}/api`);
    console.log(`   Website:  http://localhost:${PORT}\n`);
  });
}).catch(err => {
  console.error('Failed to initialize database:', err);
  process.exit(1);
});
