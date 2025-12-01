// lib/screens/follow_connections.screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_avif/flutter_avif.dart';
import 'package:flutter/foundation.dart';

import '../services/userService/friend.service.dart';

const String kBaseUploadUrl = 'https://flame.id.vn';

/// Helper: build full URL từ path/backend trả về
String buildFullUrl(String? url) {
  if (url == null) return '';
  String u = url.trim();
  if (u.isEmpty) return '';

  // Nếu backend đã trả full http/https thì dùng luôn
  if (u.startsWith('http://') || u.startsWith('https://')) {
    return u;
  }

  if (!u.startsWith('/')) {
    u = '/$u';
  }

  final full = '$kBaseUploadUrl$u';
  return full;
}

/// Trang Friends: Đang theo dõi / Bạn bè / Người theo dõi / Gợi ý kết bạn
class FollowConnectionsScreen extends StatefulWidget {
  const FollowConnectionsScreen({super.key});

  @override
  State<FollowConnectionsScreen> createState() =>
      _FollowConnectionsScreenState();
}

class _FollowConnectionsScreenState extends State<FollowConnectionsScreen> {
  FriendSuggestionsResult? _data;
  bool _loading = false;
  String? _error;

  // phân trang phía client cho từng nhóm
  static const int _pageSize = 6;
  int _followingPage = 1;
  int _mutualPage = 1;
  int _followersPage = 1;
  int _suggestionsPage = 1;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await FriendServiceApi.getFriendSuggestions(onlyMe: true);
      setState(() {
        _data = res;
        _followingPage = 1;
        _mutualPage = 1;
        _followersPage = 1;
        _suggestionsPage = 1;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;

    if (_loading && data == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null && data == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Kết nối bạn bè')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.sentiment_dissatisfied_outlined,
                  size: 40,
                  color: Colors.orangeAccent,
                ),
                const SizedBox(height: 12),
                Text(
                  'Lỗi tải dữ liệu:\n$_error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final result = data ?? FriendSuggestionsResult.empty();

    final following = result.following;
    final mutualFriends = result.mutualFriends;
    final followers = result.followers;
    final suggestions = result.suggestions;

    return Scaffold(
      appBar: AppBar(title: const Text('Kết nối bạn bè'), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Đang theo dõi
              const _SectionHeader(
                title: 'Đang theo dõi',
                subtitle: 'Những người bạn đang theo dõi.',
                icon: Icons.visibility_outlined,
              ),
              const SizedBox(height: 12),
              _UserGrid(
                users: following,
                emptyText: 'Bạn chưa theo dõi ai.',
                page: _followingPage,
                pageSize: _pageSize,
                onLoadMore: () {
                  setState(() {
                    _followingPage += 1;
                  });
                },
                onChanged: _reload,
                labelWhenFollowing: 'Bỏ theo dõi',
                labelWhenNotFollowing: 'Theo dõi',
                isFollowingInitially: true,
              ),
              const SizedBox(height: 32),

              // Bạn bè (mutual)
              const _SectionHeader(
                title: 'Bạn bè',
                subtitle: 'Hai bạn đang theo dõi lẫn nhau.',
                icon: Icons.people_alt_outlined,
              ),
              const SizedBox(height: 12),
              _UserGrid(
                users: mutualFriends,
                emptyText: 'Bạn chưa có bạn bè nào.',
                page: _mutualPage,
                pageSize: _pageSize,
                onLoadMore: () {
                  setState(() {
                    _mutualPage += 1;
                  });
                },
                onChanged: _reload,
                labelWhenFollowing: 'Bỏ theo dõi',
                labelWhenNotFollowing: 'Theo dõi',
                isFollowingInitially: true,
              ),
              const SizedBox(height: 32),

              // Người theo dõi
              const _SectionHeader(
                title: 'Người theo dõi',
                subtitle:
                    'Những người đang theo dõi bạn. Theo dõi lại để kết nối.',
                icon: Icons.person_search_outlined,
              ),
              const SizedBox(height: 12),
              _UserGrid(
                users: followers,
                emptyText: 'Chưa có ai theo dõi bạn.',
                page: _followersPage,
                pageSize: _pageSize,
                onLoadMore: () {
                  setState(() {
                    _followersPage += 1;
                  });
                },
                onChanged: _reload,
                labelWhenFollowing: 'Bỏ theo dõi',
                labelWhenNotFollowing: 'Theo dõi lại',
                isFollowingInitially: false,
              ),
              const SizedBox(height: 32),

              // Gợi ý kết bạn
              const _SectionHeader(
                title: 'Gợi ý kết bạn',
                subtitle: 'Những người bạn có thể quen.',
                icon: Icons.lightbulb_outline,
              ),
              const SizedBox(height: 12),
              _UserGrid(
                users: suggestions,
                emptyText: 'Không có gợi ý nào lúc này.',
                page: _suggestionsPage,
                pageSize: _pageSize,
                onLoadMore: () {
                  setState(() {
                    _suggestionsPage += 1;
                  });
                },
                onChanged: _reload,
                labelWhenFollowing: 'Bỏ theo dõi',
                labelWhenNotFollowing: 'Theo dõi',
                isFollowingInitially: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.textTheme.bodyMedium?.color ?? Colors.black87;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.grey.shade700),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 24),
          child: Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade600,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}

class _UserGrid extends StatelessWidget {
  final List<ProfileSummaryModel> users;
  final String emptyText;
  final int page;
  final int pageSize;
  final VoidCallback? onLoadMore;
  final Future<void> Function()? onChanged;
  final String labelWhenFollowing;
  final String labelWhenNotFollowing;
  final bool isFollowingInitially;

  const _UserGrid({
    required this.users,
    required this.emptyText,
    required this.page,
    required this.pageSize,
    this.onLoadMore,
    this.onChanged,
    required this.labelWhenFollowing,
    required this.labelWhenNotFollowing,
    required this.isFollowingInitially,
  });

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(
          emptyText,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
      );
    }

    final total = users.length;
    final visibleCount = (page * pageSize).clamp(0, total);
    final visibleUsers = users.take(visibleCount).toList();

    final width = MediaQuery.of(context).size.width;
    int crossAxisCount = 2;
    double aspectRatio = 0.75;

    if (width >= 900) {
      crossAxisCount = 4;
      aspectRatio = 0.8;
    } else if (width >= 600) {
      crossAxisCount = 3;
      aspectRatio = 0.78;
    }

    return Column(
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: visibleUsers.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: aspectRatio,
          ),
          itemBuilder: (context, index) {
            final u = visibleUsers[index];
            return _FollowCard(
              user: u,
              onChanged: onChanged,
              labelWhenFollowing: labelWhenFollowing,
              labelWhenNotFollowing: labelWhenNotFollowing,
              isFollowingInitially: isFollowingInitially,
            );
          },
        ),
        if (visibleCount < total && onLoadMore != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton.icon(
              onPressed: onLoadMore,
              icon: const Icon(Icons.expand_more, size: 18),
              label: const Text('Xem thêm'),
            ),
          ),
      ],
    );
  }
}

class _FollowCard extends StatefulWidget {
  final ProfileSummaryModel user;
  final Future<void> Function()? onChanged;
  final String labelWhenFollowing;
  final String labelWhenNotFollowing;
  final bool isFollowingInitially;

  const _FollowCard({
    required this.user,
    this.onChanged,
    required this.labelWhenFollowing,
    required this.labelWhenNotFollowing,
    required this.isFollowingInitially,
  });

  @override
  State<_FollowCard> createState() => _FollowCardState();
}

class _FollowCardState extends State<_FollowCard> {
  bool _isLoading = false;
  late bool _isFollowing;

  @override
  void initState() {
    super.initState();
    _isFollowing = widget.isFollowingInitially;
  }

  Future<void> _toggleFollow() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      final msg = await FriendServiceApi.addOrUnFollowById(widget.user.userId);

      if (mounted) {
        setState(() {
          _isFollowing = !_isFollowing;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }

      await widget.onChanged?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    final avatarUrl = buildFullUrl(u.avatarUrl);
    final displayName = u.displayName;
    final username = u.username;

    final buttonText = _isFollowing
        ? widget.labelWhenFollowing
        : widget.labelWhenNotFollowing;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _FollowAvatarCircle(
            imageUrl: avatarUrl,
            radius: 30,
            fallbackText: displayName.isNotEmpty
                ? displayName[0].toUpperCase()
                : '?',
          ),
          const SizedBox(height: 10),
          Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 2),
          Text(
            '$username',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _isLoading ? null : _toggleFollow,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                backgroundColor: Color(0xFF6D28D9),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isFollowing
                                ? Icons.person_remove_alt_1_outlined
                                : Icons.person_add_alt_1_outlined,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            buttonText,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FollowAvatarCircle extends StatelessWidget {
  final String imageUrl;
  final double radius;
  final String fallbackText;

  const _FollowAvatarCircle({
    required this.imageUrl,
    required this.radius,
    required this.fallbackText,
  });

  bool get _hasImage => imageUrl.isNotEmpty;

  bool get _isAvif {
    final lower = imageUrl.toLowerCase();
    return lower.endsWith('.avif');
  }

  @override
  Widget build(BuildContext context) {
    final double size = radius * 2;

    Widget buildFallback() {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFF1F2933),
        ),
        alignment: Alignment.center,
        child: Text(
          fallbackText,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    if (!_hasImage) return buildFallback();

    final Widget img = _isAvif
        ? AvifImage.network(
            imageUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return buildFallback();
            },
          )
        : Image.network(
            imageUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return buildFallback();
            },
          );

    return ClipOval(child: img);
  }
}
