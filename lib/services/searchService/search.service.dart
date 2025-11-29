import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flame/config.dart';
import 'package:flame/models/post.model.dart';

class FeedService {
  static String get _baseUrl => AppConfig.searchBaseUrl + AppConfig.apiVersion;
  static const int pageSize = 10;

  // Lấy token đã lưu khi đăng nhập
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("accessToken");
  }

  // Header chung cho mọi request
  static Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    return {
      "Authorization": "Bearer $token",
      "Content-Type": "application/json",
      "X-API-KEY": AppConfig.xApiKey,
      if (token != null && token.isNotEmpty) "Authorization": "Bearer $token",
    };
  }

  // Parse danh sách PostModel từ bất kỳ kiểu data nào
  static List<PostModel> _parsePostList(dynamic data) {
    if (data is List) {
      return data
          .map((e) => PostModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Lấy danh sách bài viết hot
  static Future<List<PostModel>> getHotPosts({required int page}) async {
    final start = (page - 1) * pageSize;

    final uri = Uri.parse("$_baseUrl/search/hot?start=$start&limit=$pageSize");

    final res = await http.get(uri, headers: await _headers());

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("Không thể lấy danh sách bài viết: ${res.body}");
    }

    final body = jsonDecode(res.body);
    final items = body["items"] ?? body["data"] ?? [];
    return _parsePostList(items);
  }

  /// SỬA: Thêm tham số `onlyMe` (mặc định true để giữ tương thích code cũ)
  /// Nếu xem profile người khác -> truyền onlyMe: false
  static Future<List<PostModel>> getUserPosts({
    required String userId,
    int page = 1,
    int limit = pageSize,
    bool onlyMe = true, // <--- SỬA TẠI ĐÂY
  }) async {
    final start = (page - 1) * limit;

    // Convert bool sang int (1 hoặc 0)
    final int onlyMeVal = onlyMe ? 1 : 0;

    final uri = Uri.parse(
      "$_baseUrl/search/posts"
      "?userId=$userId"
      "&onlyMe=$onlyMeVal" // <--- Dùng biến dynamic
      "&start=$start"
      "&limit=$limit",
    );

    final res = await http.get(uri, headers: await _headers());

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("Không thể lấy bài viết theo user: ${res.body}");
    }

    final body = jsonDecode(res.body);
    final items = body["items"] ?? body["data"] ?? [];
    return _parsePostList(items);
  }
}
