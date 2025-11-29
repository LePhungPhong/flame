import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flame/config.dart';
import 'package:flame/models/user.model.dart';

class UserServiceApi {
  static String get _baseUrl => AppConfig.userBaseUrl + AppConfig.apiVersion;

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("accessToken");
  }

  static Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    return {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
      "X-API-KEY": AppConfig.xApiKey,
      if (token != null && token.isNotEmpty) "Authorization": "Bearer $token",
    };
  }

  // ============= PROFILE =============
  static Future<UserProfile> getProfile() async {
    final uri = Uri.parse("$_baseUrl/profiles");
    final res = await http.get(uri, headers: await _headers());

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("Không thể lấy hồ sơ: ${res.body}");
    }
    final body = jsonDecode(res.body);
    final data = body["data"] ?? body;
    return UserProfile.fromJson(data);
  }

  static Future<UserProfile> updateProfile(UserProfile p) async {
    final uri = Uri.parse("$_baseUrl/profiles");
    final res = await http.put(
      uri,
      headers: await _headers(),
      body: jsonEncode(p.toUpdateJson()),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final body = jsonDecode(res.body);
      throw Exception(body["message"] ?? "Cập nhật hồ sơ thất bại");
    }

    final body = jsonDecode(res.body);
    final data = body["data"] ?? body;
    return UserProfile.fromJson(data);
  }
}
