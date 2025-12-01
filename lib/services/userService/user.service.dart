import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
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
      print("Status: ${res.statusCode}");
      print("Body  : ${res.body}");
      throw Exception("Tạo hồ sơ thất bại: ${res.body}");
    }

    final body = jsonDecode(res.body);
    final data = body["data"] ?? body;
    return UserProfile.fromJson(data);
  }

  static Future<bool> hasProfile() async {
    try {
      final profile = await getProfile();
      // Điều kiện tối thiểu: có username là coi như đã onboarding
      return profile.username.isNotEmpty;
    } catch (e) {
      // Nếu 404 hoặc lỗi -> coi như chưa có profile
      return false;
    }
  }

  static Future<String> uploadAvatarImage(File file) async {
    final uri = Uri.parse('${AppConfig.userBaseUrl}/api/upload-local');

    // Lấy token nếu có (giống PostService)
    String? token;
    try {
      token = await _getToken();
    } catch (_) {}

    final request = http.MultipartRequest("POST", uri);

    if (token != null) {
      request.headers["Authorization"] = "Bearer $token";
    }

    // Lấy mime type (image/jpeg, image/png, …)
    final mimeType = lookupMimeType(file.path) ?? "image/jpeg";
    final parts = mimeType.split("/");

    final multipartFile = await http.MultipartFile.fromPath(
      "file",
      file.path,
      contentType: MediaType(parts[0], parts[1]),
    );

    request.files.add(multipartFile);

    final streamedRes = await request.send();
    final res = await http.Response.fromStream(streamedRes);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body);
      final url = data["url"]?.toString();
      if (url == null || url.isEmpty) {
        throw Exception("Server không trả về url file");
      }
      return url;
    } else {
      throw Exception(
        "Upload avatar thất bại: ${res.statusCode} - ${res.body}",
      );
    }
  }

  // ============ TẠO HỒ SƠ LẦN ĐẦU (ONBOARDING) ============
  static Future<void> createProfileFromOnboarding({
    required String username,
    required String firstName,
    required String lastName,
    required String gender,
    required String dob, // dạng YYYY-MM-DD
    required List<String> favorites,
    required String avatarUrl,
    String? bio,
    String? phone,
    String? address,
    String? mssv, // user không nhập -> null
    String? course, // user không nhập -> null
    String? major, // user không nhập -> null
  }) async {
    final uri = Uri.parse("$_baseUrl/profiles");

    // 🔁 Nếu null thì tự gán giá trị mặc định hợp lệ
    final String effectiveMssv = (mssv == null || mssv.isEmpty) ? "" : mssv;
    final String effectiveCourse = (course == null || course.isEmpty)
        ? ""
        : course;
    final String effectiveMajor = (major == null || major.isEmpty) ? "" : major;

    final Map<String, dynamic> body = {
      "username": username,
      "firstName": firstName,
      "lastName": lastName,
      "gender": gender,
      "dob": dob,
      "favorites": favorites,
      "avatar_url": avatarUrl,
      "mssv": effectiveMssv,
      "course": effectiveCourse,
      "major": effectiveMajor,
      if (bio != null && bio.isNotEmpty) "bio": bio,
      if (phone != null && phone.isNotEmpty) "phone": phone,
      if (address != null && address.isNotEmpty) "address": address,
    };

    print("====== createProfileFromOnboarding REQUEST ======");
    print("POST $uri");
    print("Body: ${body.toString()}");

    final res = await http.post(
      uri,
      headers: await _headers(),
      body: jsonEncode(body),
    );

    print("====== createProfileFromOnboarding RESPONSE ======");
    print("Status: ${res.statusCode}");
    print("Body  : ${res.body}");

    if (res.statusCode < 200 || res.statusCode >= 300) {
      try {
        final bodyRes = jsonDecode(res.body);
        throw Exception(bodyRes["message"] ?? "Tạo hồ sơ thất bại");
      } catch (_) {
        throw Exception("Tạo hồ sơ thất bại: ${res.body}");
      }
    }
  }
}
