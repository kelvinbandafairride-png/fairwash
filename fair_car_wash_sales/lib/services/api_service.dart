import 'dart:convert';
import 'package:http/http.dart' as http;

// Change this to your deployed Railway URL when live
const String baseUrl = 'http://10.0.2.2:3000';

class ApiService {
  static Future<Map<String, dynamic>> login(String username, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (res.statusCode != 200) throw Exception('Invalid credentials');
    return jsonDecode(res.body);
  }

  static Future<List<dynamic>> getSales(String token) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/sales'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200) throw Exception('Failed to load sales');
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> createSale(String token, Map<String, dynamic> data) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/sales'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode(data),
    );
    if (res.statusCode != 201) throw Exception('Failed to create sale');
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getSummary(String token, {String period = 'all'}) async {
    final res = await http.get(
      Uri.parse('$baseUrl/api/sales/summary?period=$period'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode != 200) throw Exception('Failed to load summary');
    return jsonDecode(res.body);
  }
}
