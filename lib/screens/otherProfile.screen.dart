// lib/screens/otherProfile.screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_avif/flutter_avif.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flame/models/post.model.dart';
import 'package:flame/services/searchService/search.service.dart';
import 'package:flame/services/userSevice/friend.service.dart';
import 'package:flame/widgets/postCard.dart';

const String kBaseUploadUrl = 'https://flame.id.vn';

String buildFullUrl(String? url) {
  if (url == null) return '';
  String u = url.trim();
  if (u.isEmpty || u == 'null') return '';

  if (u.startsWith('http://') || u.startsWith('https://')) {
    return u;
  }
  if (!u.startsWith('/')) {
    u = '/$u';
  }
  return '$kBaseUploadUrl$u';
}

class FollowUser {
  final String id;
  final String displayName;
  final String username;
  final String avatarUrl;
  final bool isMutual;

  FollowUser({
    required this.id,
    required this.displayName,
    required this.username,
    required this.avatarUrl,
    this.isMutual = false,
  });
}

class AvatarCircle extends StatelessWidget {
  final String imageUrl;
  final double radius;
  final String fallbackText;

  const AvatarCircle({
    super.key,
    required this.imageUrl,
    required this.radius,
    required this.fallbackText,
  });

  bool get _hasImage => imageUrl.isNotEmpty;
  bool get _isAvif => imageUrl.toLowerCase().endsWith('.avif');

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;
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
          fallbackText,
          style: const TextStyle(
            fontSize: 20,
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
            errorBuilder: (_, __, ___) => buildFallback(),
          )
        : Image.network(
            imageUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => buildFallback(),
          );

    return ClipOval(child: img);
  }
}

class OtherProfileScreen extends StatefulWidget {
  final String userId;
  final String username; // <--- THÊM username để lấy Follow
  final String displayName;
  final String? avatarUrl;

  const OtherProfileScreen({
    super.key,
    required this.userId,
    required this.username, // <--- THÊM
    required this.displayName,
    this.avatarUrl,
  });

  @override
  State<OtherProfileScreen> createState() => _OtherProfileScreenState();
}

class _OtherProfileScreenState extends State<OtherProfileScreen> {
  bool _isInitLoading = false;
  String? _currentUserId;

  // Posts
  List<PostModel> _posts = [];
  bool _isLoadingPosts = false;
  bool _isLoadingMorePosts = false;
  bool _hasMorePosts = true;
  int _currentPostPage = 1;

  // viewMode: 0 = grid, 1 = list
  int _viewMode = 0;

  // Stats
  int _followersCount = 0;
  int _followingCount = 0;
  bool _loadingFollowCounts = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isInitLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      _currentUserId = prefs.getString("user_id");
      debugPrint(
        "[🐛 PROFILE DEBUG] Viewing profile of: ${widget.userId} (${widget.username})",
      );

      await Future.wait([_loadUserPostsInitial(), _loadFollowCounts()]);
    } finally {
      if (mounted) {
        setState(() {
          _isInitLoading = false;
        });
      }
    }
  }

  Future<void> _loadUserPostsInitial() async {
    setState(() {
      _isLoadingPosts = true;
      _currentPostPage = 1;
      _hasMorePosts = true;
    });

    try {
      // API Post vẫn dùng userId (UUID)
      final items = await FeedService.getUserPosts(
        userId: widget.userId,
        page: 1,
        onlyMe: false,
      );
      if (!mounted) return;

      setState(() {
        _posts = items;
        _hasMorePosts = items.length == FeedService.pageSize;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint("Lỗi load posts: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPosts = false;
        });
      }
    }
  }

  Future<void> _loadMoreUserPosts() async {
    if (_isLoadingMorePosts || !_hasMorePosts) return;

    setState(() {
      _isLoadingMorePosts = true;
    });

    try {
      final nextPage = _currentPostPage + 1;
      final items = await FeedService.getUserPosts(
        userId: widget.userId,
        page: nextPage,
        onlyMe: false,
      );
      if (!mounted) return;

      setState(() {
        _currentPostPage = nextPage;
        _posts.addAll(items);
        _hasMorePosts = items.length == FeedService.pageSize;
      });
    } catch (e) {
      // ignore error
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMorePosts = false;
        });
      }
    }
  }

  Future<void> _loadFollowCounts() async {
    setState(() {
      _loadingFollowCounts = true;
    });

    try {
      debugPrint(
        "[🐛 PROFILE DEBUG] Fetching Follow Counts for ${widget.username}...",
      );

      // API Friend dùng USERNAME
      final followers = await FriendServiceApi.getFollowers(
        username: widget.username, // <--- Dùng username
        onlyMe: false,
      );
      final following = await FriendServiceApi.getFollowing(
        username: widget.username, // <--- Dùng username
        onlyMe: false,
      );

      debugPrint(
        '[OtherProfile] Stats Loaded -> Followers: ${followers.length}, Following: ${following.length}',
      );

      if (!mounted) return;
      setState(() {
        _followersCount = followers.length;
        _followingCount = following.length;
      });
    } catch (e) {
      if (!mounted) return;
      debugPrint('[OtherProfile] loadFollowCounts error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loadingFollowCounts = false;
        });
      }
    }
  }

  Future<List<FollowUser>> _fetchFollowers() async {
    final list = await FriendServiceApi.getFollowers(
      username: widget.username, // <--- Dùng username
      onlyMe: false,
    );
    return list
        .map(
          (u) => FollowUser(
            id: u.id,
            displayName: u.displayName,
            username: u.username,
            avatarUrl: u.avatar,
            isMutual: u.isMutual,
          ),
        )
        .toList();
  }

  Future<List<FollowUser>> _fetchFollowing() async {
    final list = await FriendServiceApi.getFollowing(
      username: widget.username, // <--- Dùng username
      onlyMe: false,
    );
    return list
        .map(
          (u) => FollowUser(
            id: u.id,
            displayName: u.displayName,
            username: u.username,
            avatarUrl: u.avatar,
            isMutual: u.isMutual,
          ),
        )
        .toList();
  }

  void _openFollowersBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return _FollowListSheet(title: 'Followers', loader: _fetchFollowers);
      },
    );
  }

  void _openFollowingBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return _FollowListSheet(title: 'Following', loader: _fetchFollowing);
      },
    );
  }

  // ================= UI PARTS =================

  Widget _buildHeader() {
    final displayName = widget.displayName.trim().isEmpty
        ? 'Người dùng'
        : widget.displayName.trim();

    String avatarPath = widget.avatarUrl ?? '';
    // Nếu avatar rỗng, thử lấy từ bài post đầu tiên
    if (avatarPath.trim().isEmpty && _posts.isNotEmpty) {
      avatarPath = _posts.first.authorAvatar ?? '';
    }
    final avatarUrl = buildFullUrl(avatarPath);

    final int postCount = _posts
        .where((p) => p.authorId == widget.userId)
        .length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          AvatarCircle(
            imageUrl: avatarUrl,
            radius: 40,
            fallbackText: displayName.isNotEmpty
                ? displayName[0].toUpperCase()
                : '?',
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  label: 'Posts',
                  value: postCount,
                  onTap: () => setState(() => _viewMode = 0),
                ),
                _buildStatItem(
                  label: 'Followers',
                  value: _followersCount,
                  onTap: _openFollowersBottomSheet,
                ),
                _buildStatItem(
                  label: 'Following',
                  value: _followingCount,
                  onTap: _openFollowingBottomSheet,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required int value,
    VoidCallback? onTap,
  }) {
    final content = Column(
      children: [
        Text(
          value.toString(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
    if (onTap == null) return content;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: content,
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tính năng Follow đang phát triển'),
                  ),
                );
              },
              child: const Text('Follow'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tính năng Message đang phát triển'),
                  ),
                );
              },
              child: const Text('Message'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(
          icon: Icon(
            Icons.grid_on,
            size: 24,
            color: _viewMode == 0 ? Colors.white : Colors.grey,
          ),
          style: IconButton.styleFrom(
            backgroundColor: _viewMode == 0 ? Colors.black : Colors.transparent,
          ),
          onPressed: () => setState(() => _viewMode = 0),
        ),
        IconButton(
          icon: Icon(
            Icons.article_outlined,
            size: 24,
            color: _viewMode == 1 ? Colors.white : Colors.grey,
          ),
          style: IconButton.styleFrom(
            backgroundColor: _viewMode == 1 ? Colors.black : Colors.transparent,
          ),
          onPressed: () => setState(() => _viewMode = 1),
        ),
      ],
    );
  }

  Widget _buildPostsSection() {
    if (_isLoadingPosts) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_posts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Chưa có bài viết nào.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    // Grid mode
    if (_viewMode == 0) {
      final mediaPosts = _posts
          .where((p) => p.authorId == widget.userId && p.media.isNotEmpty)
          .toList();

      if (mediaPosts.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              'Không có ảnh/video.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        );
      }

      return Column(
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 1,
              mainAxisSpacing: 1,
              childAspectRatio: 1,
            ),
            itemCount: mediaPosts.length,
            itemBuilder: (context, index) {
              final post = mediaPosts[index];
              final String title = (post.title ?? '').trim();
              final String mediaUrl = buildFullUrl(post.media.first.url);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _viewMode = 1;
                  });
                },
                child: Container(
                  color: Colors.grey.shade200,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.network(
                          mediaUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.error),
                        ),
                      ),
                      if (title.isNotEmpty)
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            color: Colors.black54,
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          if (_hasMorePosts)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 8),
              child: TextButton.icon(
                onPressed: _isLoadingMorePosts ? null : _loadMoreUserPosts,
                icon: _isLoadingMorePosts
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more),
                label: Text(_isLoadingMorePosts ? 'Đang tải...' : 'Tải thêm'),
              ),
            ),
        ],
      );
    }

    // List mode
    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _posts.length,
          itemBuilder: (context, index) {
            final post = _posts[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: PostCard(
                post: post,
                currentUserId: _currentUserId,
                onChanged: () async {
                  await _loadUserPostsInitial();
                },
              ),
            );
          },
        ),
        if (_hasMorePosts)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            child: TextButton.icon(
              onPressed: _isLoadingMorePosts ? null : _loadMoreUserPosts,
              icon: _isLoadingMorePosts
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.expand_more),
              label: Text(_isLoadingMorePosts ? 'Đang tải...' : 'Tải thêm'),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.displayName.trim().isEmpty
              ? 'Profile'
              : widget.displayName.trim(),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: _isInitLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadInitialData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    _buildActionButtons(),
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    _buildViewToggle(),
                    const Divider(height: 1),
                    if (_loadingFollowCounts)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Center(
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 1.8),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: _buildPostsSection(),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }
}

class _FollowListSheet extends StatefulWidget {
  final String title;
  final Future<List<FollowUser>> Function() loader;

  const _FollowListSheet({required this.title, required this.loader});

  @override
  State<_FollowListSheet> createState() => _FollowListSheetState();
}

class _FollowListSheetState extends State<_FollowListSheet> {
  late Future<List<FollowUser>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.loader();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.7;

    return SafeArea(
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const Divider(),
            Expanded(
              child: FutureBuilder<List<FollowUser>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Lỗi: ${snapshot.error}'));
                  }
                  final items = snapshot.data ?? [];
                  if (items.isEmpty) {
                    return const Center(
                      child: Text(
                        'Danh sách trống.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final u = items[index];
                      final avatarUrl = buildFullUrl(u.avatarUrl);

                      return ListTile(
                        leading: AvatarCircle(
                          imageUrl: avatarUrl,
                          radius: 20,
                          fallbackText: u.displayName.isNotEmpty
                              ? u.displayName[0].toUpperCase()
                              : '?',
                        ),
                        title: Text(
                          u.displayName,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          '${u.username}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: u.isMutual
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Mutual',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blue.shade600,
                                  ),
                                ),
                              )
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
