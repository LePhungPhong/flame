// lib/services/friendService/friend.service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flame/config.dart';

class ProfileSummaryModel {
  final String userId;
  final String username;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;
  final String? bio;
  final String? course;
  final String? major;
  final String? mssv;

  ProfileSummaryModel({
    required this.userId,
    required this.username,
    this.firstName,
    this.lastName,
    this.avatarUrl,
    this.bio,
    this.course,
    this.major,
    this.mssv,
  });

  factory ProfileSummaryModel.fromJson(Map<String, dynamic> json) {
    return ProfileSummaryModel(
      userId: (json['user_id'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      bio: json['bio'] as String?,
      course: json['course'] as String?,
      major: json['major'] as String?,
      mssv: json['mssv'] as String?,
    );
  }

  /// Dùng để hiển thị tên cho đẹp
  String get displayName {
    final ln = (lastName ?? '').trim();
    final fn = (firstName ?? '').trim();

    if (ln.isNotEmpty || fn.isNotEmpty) {
      return ('$ln $fn').trim();
    }

    if (username.isNotEmpty) return username;
    return 'Người dùng';
  }
}

/// Kết quả friend suggestions từ BE
class FriendSuggestionsResult {
  final int page;
  final List<ProfileSummaryModel> mutualFriends;
  final List<ProfileSummaryModel> followers;
  final List<ProfileSummaryModel> following;
  final List<ProfileSummaryModel> suggestions;

  FriendSuggestionsResult({
    required this.page,
    required this.mutualFriends,
    required this.followers,
    required this.following,
    required this.suggestions,
  });

  factory FriendSuggestionsResult.fromJson(Map<String, dynamic> json) {
    int _toInt(dynamic v, {int defaultValue = 1}) {
      if (v == null) return defaultValue;
      if (v is int) return v;
      if (v is double) return v.toInt();
      if (v is String) {
        final parsed = int.tryParse(v);
        return parsed ?? defaultValue;
      }
      return defaultValue;
    }

    List<ProfileSummaryModel> _parseList(dynamic v) {
      if (v is List) {
        return v
            .whereType<Map<String, dynamic>>()
            .map(ProfileSummaryModel.fromJson)
            .toList();
      }
      return [];
    }

    return FriendSuggestionsResult(
      page: _toInt(json['page'], defaultValue: 1),
      mutualFriends: _parseList(json['mutualFriends']),
      followers: _parseList(json['followers']),
      following: _parseList(json['following']),
      suggestions: _parseList(json['suggestions']),
    );
  }
}

/// Model cho list friend hiển thị ở UI (Followers/Following)
class FriendUser {
  final String id;
  final String username;
  final String displayName;
  final String avatar; // path hoặc full URL
  final bool isMutual;

  FriendUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.avatar,
    this.isMutual = false,
  });
}

class FriendServiceApi {
  /// Base URL giống UserServiceApi
  /// = AppConfig.userBaseUrl + AppConfig.apiVersion  (ví dụ: https://flame.id.vn + /api/v1)
  static String get _baseUrl => AppConfig.userBaseUrl + AppConfig.apiVersion;

  // Lấy token đã lưu khi đăng nhập
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("accessToken");
  }

  static Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    return {
      "Content-Type": "application/json",
      "X-API-KEY": AppConfig.xApiKey,
      if (token != null && token.isNotEmpty) "Authorization": "Bearer $token",
    };
  }

  /// Gọi đúng API BE: GET /api/v1/follows/friend_suggestions?userId=&page=
  static Future<FriendSuggestionsResult> getFriendSuggestions({
    required String userId,
    int page = 1,
  }) async {
    final uri = Uri.parse(
      "$_baseUrl/follows/friend_suggestions",
    ).replace(queryParameters: {"userId": userId, "page": page.toString()});

    final res = await http.get(uri, headers: await _headers());

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("Không thể lấy danh sách gợi ý bạn bè: ${res.body}");
    }

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw Exception("Dữ liệu friend_suggestions không đúng định dạng");
    }

    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception("Thiếu trường data trong friend_suggestions");
    }

    return FriendSuggestionsResult.fromJson(data);
  }

  /// Lấy danh sách Followers để hiển thị trong popup
  /// Followers tab = mutualFriends (isMutual=true) + followers (isMutual=false)
  static Future<List<FriendUser>> getFollowers({
    required String userId,
    int page = 1,
  }) async {
    final result = await getFriendSuggestions(userId: userId, page: page);

    final List<FriendUser> list = [];

    // mutualFriends: follow 2 chiều
    for (final p in result.mutualFriends) {
      list.add(
        FriendUser(
          id: p.userId,
          username: p.username,
          displayName: p.displayName,
          avatar: p.avatarUrl ?? '',
          isMutual: true,
        ),
      );
    }

    // followers: họ follow mình, mình chưa follow
    for (final p in result.followers) {
      list.add(
        FriendUser(
          id: p.userId,
          username: p.username,
          displayName: p.displayName,
          avatar: p.avatarUrl ?? '',
          isMutual: false,
        ),
      );
    }

    return list;
  }

  /// Lấy danh sách Following để hiển thị trong popup
  /// Following tab = mutualFriends (isMutual=true) + following (isMutual=false)
  static Future<List<FriendUser>> getFollowing({
    required String userId,
    int page = 1,
  }) async {
    final result = await getFriendSuggestions(userId: userId, page: page);

    final List<FriendUser> list = [];

    // mutualFriends
    for (final p in result.mutualFriends) {
      list.add(
        FriendUser(
          id: p.userId,
          username: p.username,
          displayName: p.displayName,
          avatar: p.avatarUrl ?? '',
          isMutual: true,
        ),
      );
    }

    // following: mình follow họ, họ chưa follow lại
    for (final p in result.following) {
      list.add(
        FriendUser(
          id: p.userId,
          username: p.username,
          displayName: p.displayName,
          avatar: p.avatarUrl ?? '',
          isMutual: false,
        ),
      );
    }

    return list;
  }
}
