import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  static const String baseUrl = "https://sb0101-chatbot.hf.space";

  static Future<String> askCleanCityAI(String msg) async {
    try {
      final url = Uri.parse("$baseUrl/chat");

      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"message": msg}),
      );

      if (res.statusCode == 200) {
        return jsonDecode(res.body)["reply"];
      } else {
        return "Server error: ${res.statusCode}";
      }
    } catch (e) {
      return "Error: $e";
    }
  }
}
