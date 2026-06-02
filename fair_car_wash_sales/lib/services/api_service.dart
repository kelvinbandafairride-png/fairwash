import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/sale.dart';

class ApiService {
  static String? _baseUrl;
  static String? _token;
  static String? _username;
  static String? _role;

  static bool get isConfigured => _baseUrl != null && _baseUrl!.isNotEmpty;

  static void configure(String baseUrl) {
    _baseUrl = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
  }

  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  static Future<bool> login(String username, String password) async {
    if (_baseUrl == null) return false;
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _token = data['token'];
        _username = data['user']['username'];
        _role = data['user']['role'];
        return true;
      }
    } catch (e) {
      debugPrint('API login error: $e');
    }
    return false;
  }

  static Future<List<Sale>> fetchSales() async {
    if (_token == null) return [];
    try {
      final res = await http.get(Uri.parse('$_baseUrl/api/sales'), headers: _headers);
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body) as List;
        return list.map((e) => Sale(
          id: e['id'].toString(),
          amount: (e['amount'] as num).toDouble(),
          timestamp: DateTime.parse(e['created_at'] ?? DateTime.now().toIso8601String()),
        )).toList();
      }
    } catch (e) {
      debugPrint('API fetch error: $e');
    }
    return [];
  }

  static Future<bool> addSale(Sale sale) async {
    if (_token == null) return false;
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/api/sales'),
        headers: _headers,
        body: jsonEncode({'amount': sale.amount}),
      );
      return res.statusCode == 201;
    } catch (e) {
      debugPrint('API add error: $e');
      return false;
    }
  }

  static void logout() {
    _token = null;
    _username = null;
    _role = null;
  }

  static String? get username => _username;
  static String? get role => _role;
}
