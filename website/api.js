const API_BASE = window.location.origin;

const api = {
  async login(username, password) {
    const res = await fetch(`${API_BASE}/api/auth/login`, {
      method: 'POST', headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username, password })
    });
    if (!res.ok) throw new Error('Invalid credentials');
    return res.json();
  },

  async getSales(token) {
    const res = await fetch(`${API_BASE}/api/sales`, {
      headers: { Authorization: `Bearer ${token}` }
    });
    return res.json();
  },

  async getFilteredSales(token, period) {
    const res = await fetch(`${API_BASE}/api/sales/filter?period=${period}`, {
      headers: { Authorization: `Bearer ${token}` }
    });
    return res.json();
  },

  async createSale(token, data) {
    const res = await fetch(`${API_BASE}/api/sales`, {
      method: 'POST', headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${token}` },
      body: JSON.stringify(data)
    });
    return res.json();
  },

  async getSummary(token, period) {
    const res = await fetch(`${API_BASE}/api/sales/summary?period=${period}`, {
      headers: { Authorization: `Bearer ${token}` }
    });
    return res.json();
  }
};
