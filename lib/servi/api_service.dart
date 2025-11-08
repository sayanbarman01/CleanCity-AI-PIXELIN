import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl = 'http://0.0.0.0:8000';

  ApiService();

  /// Call the backend AI assignment API
  Future<Map<String, dynamic>?> assignBins(
      List<Map<String, dynamic>> bins,
      List<Map<String, dynamic>> trucks) async {
    final url = Uri.parse('$baseUrl/ai_assign');

    try {
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"bins": bins, "trucks": trucks}),
      );

      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      } else {
        print('AI API Error: ${res.statusCode}');
        return null;
      }
    } catch (e) {
      print('API Exception: $e');
      return null;
    }
  }
}
