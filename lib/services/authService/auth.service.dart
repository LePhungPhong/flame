import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flame/config.dart';
import 'api_response.dart';

class AuthService {
  static const String _tokenKey = "accessToken";
  static const String _rememberKey = "rememberMe";
  // [QUAN TRỌNG] Key này dùng để lưu ID, phải khớp với key lấy ra ở FeedScreen
  static const String _userIdKey = "user_id";

  static String get _baseUrl => AppConfig.authBaseUrl;
  static String get _apiVersion => AppConfig.apiVersion;

  static Uri _uri(String path) => Uri.parse("$_baseUrl$_apiVersion$path");

  static Map<String, dynamic> _decodeBody(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      return {"raw": decoded};
    } catch (_) {
      return {"raw": body};
    }
  }

  static Future<Map<String, String>> _publicHeaders() async {
    return {"X-API-KEY": AppConfig.xApiKey, "Content-Type": "application/json"};
  }

  static Future<Map<String, String>> _privateHeaders() async {
    final token = await _getToken();
    return {
      "X-API-KEY": AppConfig.xApiKey,
      "Content-Type": "application/json",
      if (token != null && token.isNotEmpty) "Authorization": "Bearer $token",
    };
  }

  // ================== TOKEN / SESSION ==================

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  static Future<void> _saveSession({
    required String token,
    required bool rememberMe,
    String? explicitUserId, // ID lấy trực tiếp từ API response
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_tokenKey, token);
    await prefs.setBool(_rememberKey, rememberMe);

    // 1. Ưu tiên lưu ID lấy từ API response (Chính xác nhất)
    if (explicitUserId != null && explicitUserId.isNotEmpty) {
      await prefs.setString(_userIdKey, explicitUserId);
      print("AuthService: Saved user_id from API: $explicitUserId");
      return;
    }

    // 2. Nếu không có, decode JWT để tìm ID (Fallback)
    try {
      final parts = token.split('.');
      if (parts.length == 3) {
        final payload = parts[1];
        final normalized = base64Url.normalize(payload);
        final payloadMap =
            jsonDecode(utf8.decode(base64Url.decode(normalized)))
                as Map<String, dynamic>;

        // Tìm các key ID phổ biến
        final userId =
            payloadMap['id'] ??
            payloadMap['userId'] ??
            payloadMap['user_id'] ??
            payloadMap['sub'];

        if (userId != null) {
          await prefs.setString(_userIdKey, userId.toString());
          print("AuthService: Saved user_id from JWT: $userId");
        }
      }
    } catch (e) {
      print("AuthService: Error decoding JWT: $e");
    }
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_rememberKey);
    await prefs.remove(_userIdKey);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool(_rememberKey) ?? false;
    final token = await _getToken();

    if (token == null) return false;

    final expired = _isJwtExpired(token);
    if (expired) {
      await clearSession();
      return false;
    }
    return rememberMe;
  }

  static bool _isJwtExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;

      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final payloadMap = jsonDecode(decoded) as Map<String, dynamic>;

      final exp = payloadMap['exp'];
      if (exp == null) return false;

      final expiryDate = DateTime.fromMillisecondsSinceEpoch(
        (exp as int) * 1000,
      );
      return DateTime.now().isAfter(expiryDate);
    } catch (_) {
      return true;
    }
  }

  // ================== AUTH API ==================

  static Future<ApiResponse<void>> login({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    final res = await http.post(
      _uri("/auth/login"),
      headers: await _publicHeaders(),
      body: jsonEncode({
        "email": email,
        "password": password,
        "rememberMe": rememberMe,
      }),
    );

    final data = _decodeBody(res.body);
    final ok = res.statusCode >= 200 && res.statusCode < 300;

    if (ok) {
      // Logic bóc tách dữ liệu linh hoạt
      String? token = data["token"]?.toString();
      Map<String, dynamic>? userData;

      // Case 1: { "token": "...", "user": {...} }
      if (token != null) {
        if (data["user"] is Map<String, dynamic>) {
          userData = data["user"];
        }
      }
      // Case 2: { "data": { "token": "...", "user": {...} } }
      else if (data["data"] is Map<String, dynamic>) {
        final innerData = data["data"];
        token = innerData["token"]?.toString();
        if (innerData["user"] is Map<String, dynamic>) {
          userData = innerData["user"];
        }
      }

      // Tìm User ID từ dữ liệu user
      String? userIdFromApi;
      if (userData != null) {
        userIdFromApi =
            userData["id"]?.toString() ??
            userData["userId"]?.toString() ??
            userData["user_id"]?.toString();
      }

      if (token != null) {
        await _saveSession(
          token: token,
          rememberMe: rememberMe,
          explicitUserId: userIdFromApi,
        );
      }
    }

    return ApiResponse<void>(
      ok: ok,
      message:
          data["message"]?.toString() ??
          (ok ? "Đăng nhập thành công" : "Đăng nhập thất bại"),
    );
  }

  static Future<ApiResponse<void>> logout() async {
    try {
      final res = await http.post(
        _uri("/auth/logout"),
        headers: await _privateHeaders(),
      );
      final data = _decodeBody(res.body);
      final ok = res.statusCode >= 200 && res.statusCode < 300;
      await clearSession();
      return ApiResponse<void>(
        ok: ok,
        message: data["message"]?.toString() ?? "Đăng xuất",
      );
    } catch (e) {
      await clearSession();
      return ApiResponse<void>(ok: false, message: "Lỗi đăng xuất: $e");
    }
  }

  // Các hàm khác giữ nguyên (Register, RefreshToken, Password...)
  static Future<ApiResponse<void>> register({
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      _uri("/auth/register"),
      headers: await _publicHeaders(),
      body: jsonEncode({"email": email, "password": password, "role": "user"}),
    );
    final data = _decodeBody(res.body);
    final ok = res.statusCode >= 200 && res.statusCode < 300;
    return ApiResponse<void>(
      ok: ok,
      message: data["message"]?.toString() ?? "Đăng ký thất bại",
    );
  }

  static Future<ApiResponse<void>> refreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool(_rememberKey) ?? false;
    final res = await http.post(
      _uri("/auth/refresh-token"),
      headers: await _publicHeaders(),
    );
    final data = _decodeBody(res.body);
    final ok = res.statusCode >= 200 && res.statusCode < 300;
    if (ok) {
      final token =
          data["token"]?.toString() ??
          (data["data"] is Map ? data["data"]["token"]?.toString() : null);
      if (token != null) {
        await _saveSession(token: token, rememberMe: rememberMe);
      }
    }
    return ApiResponse<void>(
      ok: ok,
      message: ok ? "Refresh thành công" : "Refresh thất bại",
    );
  }

  static Future<ApiResponse<void>> sendVerifyEmail(String email) async {
    final res = await http.post(
      _uri("/auth/send-email/$email"),
      headers: await _publicHeaders(),
    );
    final ok = res.statusCode >= 200 && res.statusCode < 300;
    return ApiResponse<void>(
      ok: ok,
      message: _decodeBody(res.body)["message"]?.toString() ?? "Lỗi",
    );
  }

  static Future<ApiResponse<void>> verifyEmail(String token) async {
    final res = await http.get(
      _uri("/auth/verify-email/$token"),
      headers: await _publicHeaders(),
    );
    final ok = res.statusCode >= 200 && res.statusCode < 300;
    return ApiResponse<void>(
      ok: ok,
      message: _decodeBody(res.body)["message"]?.toString() ?? "Lỗi",
    );
  }

  static Future<ApiResponse<void>> sendResetPassword(String email) async {
    final res = await http.post(
      _uri("/auth/reset-password/$email"),
      headers: await _publicHeaders(),
    );
    final ok = res.statusCode >= 200 && res.statusCode < 300;
    return ApiResponse<void>(
      ok: ok,
      message: _decodeBody(res.body)["message"]?.toString() ?? "Lỗi",
    );
  }

  static Future<ApiResponse<void>> changePassword({
    required String token,
    required String newPassword,
  }) async {
    final res = await http.post(
      _uri("/auth/change-password/$token"),
      headers: await _publicHeaders(),
      body: jsonEncode({"password": newPassword}),
    );
    final ok = res.statusCode >= 200 && res.statusCode < 300;
    return ApiResponse<void>(
      ok: ok,
      message: _decodeBody(res.body)["message"]?.toString() ?? "Lỗi",
    );
  }
}
