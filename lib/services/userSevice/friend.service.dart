import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flame/config.dart';

class ProfileSummaryModel {
  final String userId;
  final String username;
  final String? firstName;
  final String? lastName;
  final String? avatarUrl;

  ProfileSummaryModel({
    required this.userId,
    required this.username,
    this.firstName,
    this.lastName,
    this.avatarUrl,
  });

  factory ProfileSummaryModel.fromJson(Map<String, dynamic> json) {
    return ProfileSummaryModel(
      userId: (json['user_id'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      firstName: json['firstName'],
      lastName: json['lastName'],
      avatarUrl: json['avatar_url'],
    );
  }

  String get displayName {
    final ln = (lastName ?? '').trim();
    final fn = (firstName ?? '').trim();
    if (ln.isNotEmpty || fn.isNotEmpty) return ('$ln $fn').trim();
    if (username.isNotEmpty) return username;
    return 'Người dùng';
  }
}

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

  factory FriendSuggestionsResult.empty() {
    return FriendSuggestionsResult(
      page: 1,
      mutualFriends: [],
      followers: [],
      following: [],
      suggestions: [],
    );
  }

  factory FriendSuggestionsResult.fromJson(Map<String, dynamic> json) {
    int _toInt(dynamic v) => int.tryParse(v.toString()) ?? 1;
    List<ProfileSummaryModel> _parse(dynamic v) => (v is List)
        ? v
              .whereType<Map<String, dynamic>>()
              .map(ProfileSummaryModel.fromJson)
              .toList()
        : [];

    return FriendSuggestionsResult(
      page: _toInt(json['page']),
      mutualFriends: _parse(json['mutualFriends']),
      followers: _parse(json['followers']),
      following: _parse(json['following']),
      suggestions: _parse(json['suggestions']),
    );
  }
}

class FriendUser {
  final String id;
  final String username;
  final String displayName;
  final String avatar;
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
  static String get _baseUrl => AppConfig.userBaseUrl + AppConfig.apiVersion;
  static Future<String?> _getToken() async =>
      (await SharedPreferences.getInstance()).getString("accessToken");
  static Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    return {
      "Content-Type": "application/json",
      "X-API-KEY": AppConfig.xApiKey,
      if (token != null) "Authorization": "Bearer $token",
    };
  }

  static Future<String> addOrUnFollowById(String userId) async {
    final uri = Uri.parse("$_baseUrl/follows");
    final body = jsonEncode({"followerId": userId});

    debugPrint("[👥 FRIEND API] POST $uri, body=$body");

    final res = await http.post(uri, headers: await _headers(), body: body);

    Map<String, dynamic> jsonBody = {};
    try {
      jsonBody = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {}

    if (res.statusCode < 200 || res.statusCode >= 300) {
      final msg = (jsonBody['message'] ?? 'Thao tác follow thất bại')
          .toString();
      debugPrint("[❌ FRIEND API] $msg");
      throw Exception(msg);
    }

    final msg = (jsonBody['message'] ?? 'Thành công').toString();
    debugPrint("[✅ FRIEND API] $msg");
    return msg;
  }

  // --- SỬA CHÍNH: Nhận `username` thay vì `userId` ---
  static Future<FriendSuggestionsResult> getFriendSuggestions({
    String? username,
    int page = 1,
    bool onlyMe = true,
  }) async {
    Uri uri;
    if (onlyMe) {
      // Của tôi: Dùng Token
      uri = Uri.parse("$_baseUrl/follows/friend_suggestions?page=$page");
    } else {
      // Của người khác: Truyền username vào Path
      if (username == null || username.isEmpty)
        return FriendSuggestionsResult.empty();
      uri = Uri.parse(
        "$_baseUrl/follows/friend_suggestions/$username?page=$page",
      );
    }

    debugPrint('[🔍 FRIEND API] GET $uri');
    final res = await http.get(uri, headers: await _headers());

    // Xử lý 404 là rỗng để không crash
    if (res.statusCode == 404) return FriendSuggestionsResult.empty();

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("Lỗi API Friend: ${res.statusCode}");
    }

    final body = jsonDecode(res.body);
    return FriendSuggestionsResult.fromJson(body['data'] ?? {});
  }

  static Future<List<FriendUser>> getFollowers({
    String? username,
    int page = 1,
    bool onlyMe = true,
  }) async {
    try {
      final res = await getFriendSuggestions(
        username: username,
        page: page,
        onlyMe: onlyMe,
      );
      List<FriendUser> list = [];
      for (var u in [...res.mutualFriends, ...res.followers]) {
        list.add(
          FriendUser(
            id: u.userId,
            username: u.username,
            displayName: u.displayName,
            avatar: u.avatarUrl ?? '',
            isMutual: res.mutualFriends.contains(u),
          ),
        );
      }
      return list;
    } catch (e) {
      debugPrint("Lỗi getFollowers: $e");
      return [];
    }
  }

  static Future<List<FriendUser>> getFollowing({
    String? username,
    int page = 1,
    bool onlyMe = true,
  }) async {
    try {
      final res = await getFriendSuggestions(
        username: username,
        page: page,
        onlyMe: onlyMe,
      );
      List<FriendUser> list = [];
      for (var u in [...res.mutualFriends, ...res.following]) {
        list.add(
          FriendUser(
            id: u.userId,
            username: u.username,
            displayName: u.displayName,
            avatar: u.avatarUrl ?? '',
            isMutual: res.mutualFriends.contains(u),
          ),
        );
      }
      return list;
    } catch (e) {
      debugPrint("Lỗi getFollowing: $e");
      return [];
    }
  }
}
