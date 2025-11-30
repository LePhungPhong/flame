import 'package:flutter/foundation.dart';

class MediaItem {
  final String url;
  final String type; // image | video | file

  MediaItem({required this.url, required this.type});

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    final rawUrl =
        json['mediaUrl'] ??
        json['media_url'] ??
        json['url'] ??
        json['path'] ??
        '';
    final rawType =
        json['mediaType'] ?? json['media_type'] ?? json['type'] ?? 'image';

    final url = rawUrl.toString();
    final type = rawType.toString();
    return MediaItem(url: url, type: type);
  }
}

class PostModel {
  final String id;
  final String authorId;
  final String authorName;
  final String authorUsername;
  final String? authorAvatar;
  final String? title;
  final String? content;
  final String visibility;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final DateTime createdAt;
  final List<MediaItem> media;

  PostModel({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.authorUsername,
    this.authorAvatar,
    this.title,
    this.content,
    required this.visibility,
    required this.likeCount,
    required this.commentCount,
    required this.shareCount,
    required this.createdAt,
    required this.media,
  });

  static int _toInt(dynamic v, {int defaultValue = 0}) {
    if (v == null) return defaultValue;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? defaultValue;
    return defaultValue;
  }

  static String? _clean(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty || s == 'null') return null;
    return s;
  }

  static List<dynamic> _asList(dynamic v) {
    if (v is List) return v;
    return const [];
  }

  factory PostModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    final String parsedUsername = json['author_username'] ?? '';
    // ==== AVATAR AUTHOR ====
    String? authorAvatar;
    for (final c in [
      json['author_avatar'],
      json['authorAvatar'],
      json['avatar'],
      json['avatarUrl'],
      json['avatar_url'],
      user?['avatar'],
      user?['avatarUrl'],
      user?['avatar_url'],
    ]) {
      final s = _clean(c);
      if (s != null) {
        authorAvatar = s;
        break;
      }
    }

    // ==== GOM MEDIA ====
    final List<dynamic> mediaRaw = [];
    mediaRaw
      ..addAll(_asList(json['mediaUrls']))
      ..addAll(_asList(json['media']))
      ..addAll(_asList(json['media_urls']))
      ..addAll(_asList(json['images']))
      ..addAll(_asList(json['videos']))
      ..addAll(_asList(json['files']));

    // 🔥 QUAN TRỌNG: ƯU TIÊN author_id / authorId TRƯỚC, rồi mới fallback userId
    final String authorId =
        json['author_id']?.toString() ??
        json['authorId']?.toString() ??
        json['userId']?.toString() ??
        json['user_id']?.toString() ??
        '';

    return PostModel(
      id: json['id']?.toString() ?? '',
      authorId: authorId,
      authorName:
          json['author_fullname'] ??
          json['author_username'] ??
          json['username'] ??
          user?['username'] ??
          user?['fullname'] ??
          user?['name'] ??
          'Người dùng',
      authorUsername: parsedUsername,
      authorAvatar: authorAvatar,
      title: json['title']?.toString(),
      content: json['content']?.toString(),
      visibility: json['visibility']?.toString() ?? 'public',
      likeCount: _toInt(
        json['like_count'] ?? json['likes'] ?? json['likeCount'],
      ),
      commentCount: _toInt(
        json['comment_count'] ?? json['comments'] ?? json['commentCount'],
      ),
      shareCount: _toInt(
        json['share_count'] ?? json['shares'] ?? json['shareCount'],
      ),
      createdAt:
          DateTime.tryParse(
            json['created_at']?.toString() ??
                json['createdAt']?.toString() ??
                '',
          ) ??
          DateTime.now(),
      media: mediaRaw
          .whereType<Map<String, dynamic>>()
          .map((m) => MediaItem.fromJson(m))
          .toList(),
    );
  }
}

class CommentModel {
  final String id;
  final String postId;
  final String userId;
  final String username;
  final String? avatar;
  final String content;
  final String? parentId;
  final DateTime createdAt;

  CommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.username,
    this.avatar,
    required this.content,
    this.parentId,
    required this.createdAt,
  });

  factory CommentModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;

    String? _clean(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      if (s.isEmpty || s == 'null') return null;
      return s;
    }

    String? pickedAvatar;
    for (final c in [
      json['avatar'],
      json['avatarUrl'],
      json['avatar_url'],
      json['userAvatar'],
      json['user_avatar'],
      user?['avatar'],
      user?['avatarUrl'],
      user?['avatar_url'],
      user?['profileImage'],
      user?['profile_image'],
    ]) {
      final s = _clean(c);
      if (s != null) {
        pickedAvatar = s;
        break;
      }
    }

    final createdAtRaw =
        json['created_at'] ??
        json['createdAt'] ??
        json['created_at_time'] ??
        '';

    return CommentModel(
      id: json['id']?.toString() ?? '',
      postId: json['postId']?.toString() ?? json['post_id']?.toString() ?? '',
      userId: json['userId']?.toString() ?? json['user_id']?.toString() ?? '',
      username:
          json['username'] ??
          user?['username'] ??
          user?['fullname'] ??
          user?['name'] ??
          'Người dùng',
      avatar: pickedAvatar,
      content: json['content']?.toString() ?? '',
      parentId: json['parentId']?.toString() ?? json['parent_id']?.toString(),
      createdAt: DateTime.tryParse(createdAtRaw.toString()) ?? DateTime.now(),
    );
  }
}

class CreatePostRequest {
  final String? title;
  final String? content;
  final String visibility; // public | private | friends
  final List<String> hashtags;
  final List<String> taggedFriends;
  final List<MediaItem> media;

  CreatePostRequest({
    this.title,
    this.content,
    this.visibility = 'public',
    this.hashtags = const [],
    this.taggedFriends = const [],
    this.media = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      "title": title,
      "content": content,
      "visibility": visibility,
      "hashtags": hashtags,
      "tagged_friends": taggedFriends,
      "mediaUrls": media
          .map((m) => {"mediaUrl": m.url, "mediaType": m.type})
          .toList(),
      "postType": "post",
    };
  }
}
