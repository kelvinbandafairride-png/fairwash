import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'home_page.dart';
import 'report_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _serverCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscure = true;
  bool _loading = false;

  static const _accounts = {
    'user': {'password': 'user123', 'role': 'user'},
    'admin': {'password': 'admin123', 'role': 'admin'},
  };

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    final username = _usernameCtrl.text.trim().toLowerCase();
    final password = _passwordCtrl.text.trim();
    final serverUrl = _serverCtrl.text.trim();

    bool cloudAuth = false;
    if (serverUrl.isNotEmpty) {
      ApiService.configure(serverUrl);
      cloudAuth = await ApiService.login(username, password);
    }

    if (!cloudAuth) {
      final account = _accounts[username];
      if (account == null || account['password'] != password) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid username or password'), backgroundColor: Colors.red),
          );
          setState(() => _loading = false);
        }
        return;
      }
    }

    final resolvedRole = cloudAuth ? ApiService.role! : _accounts[username]!['role']!;
    final resolvedUser = cloudAuth ? ApiService.username! : username;

    final target = resolvedRole == 'admin'
        ? ReportPage(role: resolvedRole, username: resolvedUser)
        : HomePage(role: resolvedRole, username: resolvedUser);

    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => target));
    }
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _serverCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity, height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1A2980), Color(0xFF26D0CE)]),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.local_car_wash, size: 72, color: Colors.white),
                const SizedBox(height: 12),
                const Text('Fair Car Wash', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Sales Management System', style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 48),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20)]),
                  child: Form(
                    key: _formKey,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const Text('Login', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A2980))),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _serverCtrl,
                        decoration: InputDecoration(
                          labelText: 'Server URL (optional)', hintText: 'https://your-app.onrender.com',
                          prefixIcon: const Icon(Icons.cloud_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _usernameCtrl,
                        decoration: InputDecoration(labelText: 'Username', prefixIcon: const Icon(Icons.person), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Enter username' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordCtrl,
                        obscureText: _obscure,
                        decoration: InputDecoration(
                          labelText: 'Password', prefixIcon: const Icon(Icons.lock), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscure = !_obscure)),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Enter password' : null,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _login,
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A2980), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: _loading
                              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                  child: Column(children: [
                    const Text('Demo Accounts', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 4),
                    const Text('User: user / user123', style: TextStyle(color: Colors.white60, fontSize: 12)),
                    const Text('Admin: admin / admin123', style: TextStyle(color: Colors.white60, fontSize: 12)),
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
