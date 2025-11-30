import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flame/config.dart';
import 'package:flame/models/post.model.dart';
import 'dart:io';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

class PostService {
  static String get _baseUrl => AppConfig.postBaseUrl;
  static String get _apiVersion => AppConfig.apiVersion;

  static Uri _uri(String path) => Uri.parse("$_baseUrl$_apiVersion$path");

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
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) "Authorization": "Bearer $token",
    };
  }

  // ================= HELPER: LÀM PHẲNG COMMENT & GÁN CHA CON =================

  /// Hàm đệ quy này làm 2 việc:
  /// 1. Lôi hết comment lồng nhau ra thành 1 danh sách phẳng.
  /// 2. [QUAN TRỌNG] Tự động điền parentId cho con dựa trên ID của cha đang duyệt.
  static List<CommentModel> _flattenComments(
    List<dynamic> sourceList, {
    String? forcedParentId, // ID của comment cha (nếu đang duyệt con)
  }) {
    List<CommentModel> flatList = [];

    for (var item in sourceList) {
      if (item is! Map<String, dynamic>) continue;

      // --- BƯỚC SỬA LỖI: Gán ID cha nếu JSON thiếu ---
      if (forcedParentId != null) {
        // Gán vào map trước khi convert sang Model
        item['parentId'] = forcedParentId;
        item['parent_id'] = forcedParentId;
      }

      // 1. Convert comment hiện tại
      CommentModel currentComment;
      try {
        currentComment = CommentModel.fromJson(item);
        flatList.add(currentComment);
      } catch (e) {
        continue;
      }

      // 2. Tìm danh sách con (replies/children)
      final nestedList =
          item['replies'] ?? item['children'] ?? item['comments'];

      // 3. Đệ quy: Truyền ID của comment hiện tại xuống làm cha cho đám con
      if (nestedList != null && nestedList is List && nestedList.isNotEmpty) {
        final childrenFlat = _flattenComments(
          nestedList,
          forcedParentId: currentComment.id, // <--- CHÌA KHÓA Ở ĐÂY
        );
        flatList.addAll(childrenFlat);
      }
    }

    // (Tuỳ chọn) Sắp xếp theo thời gian
    flatList.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return flatList;
  }

  // ================= CRUD POST =================

  static Future<PostModel> createPost(CreatePostRequest req) async {
    final res = await http.post(
      _uri("/posts"),
      headers: await _headers(),
      body: jsonEncode(req.toJson()),
    );
    if (res.statusCode >= 300) throw Exception("Lỗi: ${res.body}");
    final json = jsonDecode(res.body);
    return PostModel.fromJson(json["data"] ?? json);
  }

  static Future<PostModel> updatePost(
    String postId,
    CreatePostRequest req,
  ) async {
    final res = await http.put(
      _uri("/posts/$postId"),
      headers: await _headers(),
      body: jsonEncode(req.toJson()),
    );
    if (res.statusCode >= 300) throw Exception("Lỗi: ${res.body}");
    final json = jsonDecode(res.body);
    return PostModel.fromJson(json["data"] ?? json);
  }

  static Future<void> deletePost(String postId) async {
    final res = await http.delete(
      _uri("/posts/$postId"),
      headers: await _headers(),
    );
    if (res.statusCode >= 300) throw Exception("Lỗi: ${res.body}");
  }

  // ================= INTERACTIONS =================

  static Future<void> toggleLike(String postId) async {
    final res = await http.post(
      _uri("/interactions/like/$postId"),
      headers: await _headers(),
    );
    if (res.statusCode >= 300) throw Exception("Lỗi like");
  }

  static Future<void> sharePost(String postId) async {
    final res = await http.post(
      _uri("/interactions/share/$postId"),
      headers: await _headers(),
    );
    if (res.statusCode >= 300) throw Exception("Lỗi share");
  }

  static Future<CommentModel> addComment(
    String postId,
    String content, {
    String? parentId,
  }) async {
    final body = <String, dynamic>{"content": content};
    if (parentId != null && parentId.isNotEmpty) {
      body["parentId"] = parentId;
      body["parent_id"] = parentId;
    }

    final res = await http.post(
      _uri("/interactions/comment/$postId"),
      headers: await _headers(),
      body: jsonEncode(body),
    );

    if (res.statusCode >= 300) throw Exception("Lỗi comment");
    final data = jsonDecode(res.body)["data"];
    return CommentModel.fromJson(data);
  }

  static Future<void> deleteComment(String commentId) async {
    final res = await http.delete(
      _uri("/interactions/comment/$commentId"),
      headers: await _headers(),
    );
    if (res.statusCode >= 300) throw Exception("Lỗi xoá comment");
  }

  static Future<List<CommentModel>> getComments(String postId) async {
    final res = await http.get(
      _uri("/interactions/$postId"),
      headers: await _headers(),
    );
    if (res.statusCode >= 300) throw Exception("Lỗi tải comment");

    final json = jsonDecode(res.body);
    final data = (json["data"] ?? {}) as Map<String, dynamic>;
    final List<dynamic> rawComments = (data["comments"] as List?) ?? const [];

    // Gọi hàm flatten đã sửa
    return _flattenComments(rawComments);
  }

  static Future<Map<String, dynamic>> getPostInteractions(String postId) async {
    final res = await http.get(
      _uri("/interactions/$postId"),
      headers: await _headers(),
    );
    if (res.statusCode >= 300) throw Exception("Lỗi tải tương tác");

    final json = jsonDecode(res.body);
    final data = (json["data"] ?? {}) as Map<String, dynamic>;

    final List<dynamic> likes = (data["likes"] as List?) ?? const [];
    final List<dynamic> rawComments = (data["comments"] as List?) ?? const [];
    final List<dynamic> shares = (data["shares"] as List?) ?? const [];

    // Flatten comment để đếm đúng số lượng
    final flattenedComments = _flattenComments(rawComments);

    final prefs = await SharedPreferences.getInstance();
    final currentUserId = prefs.getString("user_id");

    bool isLiked = false;
    bool isShared = false;

    if (currentUserId != null && currentUserId.isNotEmpty) {
      isLiked = likes.any((item) => _checkUser(item, currentUserId));
      isShared = shares.any((item) => _checkUser(item, currentUserId));
    }

    return {
      "likeCount": likes.length,
      "commentCount": flattenedComments.length,
      "shareCount": shares.length,
      "isLiked": isLiked,
      "isShared": isShared,
      "comments": flattenedComments,
    };
  }

  static bool _checkUser(dynamic item, String currentUserId) {
    if (item is! Map<String, dynamic>) return false;
    final userMap = item["user"] as Map<String, dynamic>?;
    final uid = item["userId"] ?? item["user_id"] ?? userMap?["id"];
    return uid != null && uid.toString() == currentUserId;
  }

  //
  static Future<List<PostModel>> getPostsByUser(String userId) async {
    // 1. Gọi API (Lưu ý: nên thêm User-Agent vào _headers() nếu có thể)
    final res = await http.get(
      _uri("/posts/userId/$userId"), // Hoặc đường dẫn bạn đang dùng
      headers: await _headers(),
    );

    // 2. --- ĐÂY LÀ CHỖ BẠN THÊM CODE VÀO ---
    if (res.statusCode == 200) {
      // Kiểm tra xem server có trả về JSON không
      String? contentType = res.headers['content-type'];

      if (contentType != null && contentType.contains('application/json')) {
        // --- NẾU LÀ JSON (OK) ---
        final json = jsonDecode(res.body);

        // Xử lý dữ liệu như bình thường
        final List<dynamic> rawList = (json['data'] is List)
            ? json['data']
            : (json is List ? json : []);

        final allPosts = rawList.map((e) => PostModel.fromJson(e)).toList();

        // Lọc bài viết của user (Client-side filtering)
        return allPosts.where((p) => p.authorId == userId).toList();
      } else {
        // --- NẾU LÀ HTML (Cloudflare chặn hoặc lỗi server) ---
        // In ra log để debug
        print("LOG: Server trả về HTML: ${res.body}");

        throw Exception(
          "Server đang chặn truy cập (Cloudflare). Vui lòng thử lại sau.",
        );
      }
    } else {
      // Xử lý các lỗi khác (404, 500...)
      throw Exception("Lỗi tải bài viết: ${res.statusCode} - ${res.body}");
    }
  }

  // ================= UPLOAD ẢNH =================
  /// Upload 1 file ảnh và trả về URL (string) do server trả về
  static Future<String> uploadImage(File file) async {
    // ❗ ĐỔI PATH NÀY CHO ĐÚNG VỚI ROUTE NEXT.JS
    // Nếu file route ở: app/api/upload/route.ts  → "/upload"
    // Nếu ở: app/api/v1/upload/route.ts          → dùng _uri("/upload")
    final uri = _uri("/api/upload-local");

    final token = await _getToken();

    final request = http.MultipartRequest("POST", uri);

    if (token != null) {
      request.headers["Authorization"] = "Bearer $token";
    }

    // Lấy mime type từ extension (vd: image/jpeg, image/png)
    final mimeType = lookupMimeType(file.path) ?? "image/jpeg";
    final parts = mimeType.split("/");

    final multipartFile = await http.MultipartFile.fromPath(
      "file", // 👈 PHẢI ĐÚNG TÊN "file" như backend form.get("file")
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
      throw Exception("Upload thất bại: ${res.statusCode} - ${res.body}");
    }
  }
}
