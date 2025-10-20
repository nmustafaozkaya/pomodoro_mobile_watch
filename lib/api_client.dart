import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  final String baseUrl;
  final String userId;

  const ApiClient({required this.baseUrl, required this.userId});

  Future<bool> postSession({
    required String source,
    required int minutes,
    required int timestampMs,
  }) async {
    final uri = Uri.parse('$baseUrl/session');
    final body = jsonEncode({
      'userId': userId,
      'source': source,
      'minutes': minutes,
      'ts': timestampMs,
    });
    final res = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
    return res.statusCode >= 200 && res.statusCode < 300;
  }

  Future<int> fetchTotalMinutes() async {
    final uri = Uri.parse('$baseUrl/stats?userId=$userId');
    final res = await http.get(uri);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final total = data['totalMinutes'];
      if (total is int) return total;
    }
    return 0;
  }

  Future<Map<String, dynamic>> fetchStats() async {
    final uri = Uri.parse('$baseUrl/stats?userId=$userId');
    final res = await http.get(uri);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data;
    }
    return {'totalMinutes': 0, 'recent': []};
  }
}
