// lib/screens/otherProfile.screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_avif/flutter_avif.dart';

import '../models/post.model.dart';
import '../widgets/postCard.dart';

/// Base URL domain; path BE trả về sẽ được ghép thêm vào
const String kBaseUploadUrl = 'https://flame.id.vn';

/// Helper: build full URL từ path/backend trả về
String buildFullUrl(String? url) {
  if (url == null) return '';
  String u = url.trim();
  if (u.isEmpty || u == 'null') return '';

  // Nếu backend đã trả full http/https thì dùng luôn
  if (u.startsWith('http://') || u.startsWith('https://')) {
    return u;
  }

  // Đảm bảo path bắt đầu bằng '/'
  if (!u.startsWith('/')) {
    u = '/$u';
  }

  return '$kBaseUploadUrl$u';
}

/// Avatar cho user khác (hỗ trợ AVIF + fallback chữ cái đầu)
class OtherAvatarCircle extends StatelessWidget {
  final String? rawUrl;
  final double radius;
  final String displayName;

  const OtherAvatarCircle({
    super.key,
    required this.rawUrl,
    required this.radius,
    required this.displayName,
  });

  @override
  Widget build(BuildContext context) {
    final String initial =
        (displayName.trim().isNotEmpty ? displayName.trim()[0] : '?')
            .toUpperCase();

    final String url = buildFullUrl(rawUrl);
    final double size = radius * 2;

    Widget buildFallback() {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF2563EB),
        ),
        alignment: Alignment.center,
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontSize: radius * 0.9,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (url.isEmpty) {
      return buildFallback();
    }

    if (url.toLowerCase().endsWith('.avif')) {
      return ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: AvifImage.network(
            url,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => buildFallback(),
          ),
        ),
      );
    }

    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => buildFallback(),
        ),
      ),
    );
  }
}

/// Trang hồ sơ PUBLIC của người khác
class OtherProfileScreen extends StatelessWidget {
  final String userId;
  final String username;
  final String? fullname;
  final String? avatarUrl;

  /// tạm thời truyền list post từ ngoài vào cho đơn giản
  /// (sau này bạn muốn thì gọi API để load post của user này cũng được)
  final List<PostModel> posts;

  const OtherProfileScreen({
    super.key,
    required this.userId,
    required this.username,
    this.fullname,
    this.avatarUrl,
    this.posts = const [],
  });

  @override
  Widget build(BuildContext context) {
    final displayName = (fullname != null && fullname!.trim().isNotEmpty)
        ? fullname!
        : username;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          displayName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // TODO: nếu bạn có API riêng để load profile + bài viết user khác thì gọi ở đây
          await Future.delayed(const Duration(milliseconds: 400));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    OtherAvatarCircle(
                      rawUrl: avatarUrl,
                      radius: 36,
                      displayName: displayName,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '@$username',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.lock_open, size: 14),
                              const SizedBox(width: 4),
                              const Text(
                                'Public profile',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Posts section
              if (posts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      'Người này chưa có bài viết (hoặc bạn chưa load).',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    return PostCard(
                      post: post,
                      currentUserId: null, // bạn không phải chủ, nên để null
                    );
                  },
                ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
