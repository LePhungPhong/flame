// lib/screens/profile.screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_avif/flutter_avif.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/authService/auth.service.dart';
import '../services/userSevice/user.service.dart';
import '../services/searchService/search.service.dart';
import '../services/userSevice/friend.service.dart';

import '../models/user.model.dart';
import '../models/post.model.dart';

import '../widgets/postCard.dart';
import 'login.screen.dart';

/// Base URL domain; path BE trả về sẽ được ghép thêm vào
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

  // Đảm bảo path bắt đầu bằng '/'
  if (!u.startsWith('/')) {
    u = '/$u';
  }

  final full = '$kBaseUploadUrl$u';
  debugPrint('[buildFullUrl] input="$url" -> "$full"');
  return full;
}

/// Model đơn giản cho 1 user trong list Followers/Following
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

/// Widget avatar, xử lý AVIF bằng flutter_avif + fallback chữ cái đầu
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

  bool get _isAvif {
    final lower = imageUrl.toLowerCase();
    return lower.endsWith('.avif');
  }

  @override
  Widget build(BuildContext context) {
    final size = radius * 2;

    Widget buildFallback() {
      return Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
          ),
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

    if (!_hasImage) {
      return buildFallback();
    }

    final Widget img = _isAvif
        ? AvifImage.network(
            imageUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('[AvatarCircle] AVIF load error: $error');
              return buildFallback();
            },
          )
        : Image.network(
            imageUrl,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('[AvatarCircle] Image load error: $error');
              return buildFallback();
            },
          );

    return ClipOval(child: img);
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isInitLoading = false;
  bool _isSavingProfile = false;

  UserProfile? _profile;

  // Posts (chỉ lấy bài của chính mình)
  List<PostModel> _posts = [];
  bool _isLoadingPosts = false;
  bool _isLoadingMorePosts = false;
  bool _hasMorePosts = true;
  int _currentPostPage = 1;

  // viewMode: 0 = grid, 1 = list
  int _viewMode = 0;

  // ID người dùng hiện tại để truyền vào PostCard
  String? _currentUserId;

  // Override số followers / following (tự tính từ API)
  int? _followersCountOverride;
  int? _followingCountOverride;

  // Form edit profile
  final _usernameCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _avatarCtrl = TextEditingController();
  final _genderCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _dobCtrl = TextEditingController(); // YYYY-MM-DD

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadProfile();
  }

  // Lấy ID từ SharedPreferences
  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getString("user_id");
    });
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _bioCtrl.dispose();
    _avatarCtrl.dispose();
    _genderCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  // ================= LOAD PROFILE + POSTS =================

  Future<void> _loadProfile() async {
    setState(() {
      _isInitLoading = true;
    });

    try {
      final p = await UserServiceApi.getProfile();
      if (!mounted) return;

      setState(() {
        _profile = p;
        _usernameCtrl.text = p.username;
        _firstNameCtrl.text = p.firstName;
        _lastNameCtrl.text = p.lastName;
        _bioCtrl.text = p.bio ?? "";
        _avatarCtrl.text = p.avatar ?? "";
        _genderCtrl.text = p.gender ?? "";
        _addressCtrl.text = p.address ?? "";
        _phoneCtrl.text = p.phone ?? "";
        _dobCtrl.text = p.dob ?? "";
      });

      await _loadUserPostsInitial();
      await _refreshFollowStats();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi tải hồ sơ: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isInitLoading = false;
        });
      }
    }
  }

  /// Chỉ lấy bài viết của chính mình
  Future<void> _loadUserPostsInitial() async {
    final p = _profile;
    if (p == null) return;

    setState(() {
      _isLoadingPosts = true;
      _currentPostPage = 1;
      _hasMorePosts = true;
    });

    try {
      final items = await FeedService.getUserPosts(userId: p.id, page: 1);
      if (!mounted) return;

      setState(() {
        _posts = items;
        _hasMorePosts = items.length == FeedService.pageSize;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể tải bài viết của bạn: $e')),
      );
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
    final p = _profile;
    if (p == null) return;

    setState(() {
      _isLoadingMorePosts = true;
    });

    try {
      final nextPage = _currentPostPage + 1;
      final items = await FeedService.getUserPosts(
        userId: p.id,
        page: nextPage,
      );
      if (!mounted) return;

      setState(() {
        _currentPostPage = nextPage;
        _posts.addAll(items);
        _hasMorePosts = items.length == FeedService.pageSize;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể tải thêm bài viết: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMorePosts = false;
        });
      }
    }
  }

  // ================= FOLLOW STATS =================
  Future<void> _refreshFollowStats() async {
    final p = _profile;
    if (p == null) return;

    try {
      // Vì là Profile của mình, gọi onlyMe: true
      final followers = await FriendServiceApi.getFollowers(onlyMe: true);
      final following = await FriendServiceApi.getFollowing(onlyMe: true);

      if (!mounted) return;

      setState(() {
        _followersCountOverride = followers.length;
        _followingCountOverride = following.length;
      });
    } catch (e) {
      debugPrint('[Profile] refresh follow stats error: $e');
    }
  }
  // ================= SAVE PROFILE =================

  Future<bool> _saveProfile() async {
    if (_profile == null) return false;

    final updated = UserProfile(
      id: _profile!.id,
      email: _profile!.email,
      username: _usernameCtrl.text.trim(),
      firstName: _firstNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim(),
      bio: _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
      avatar: _avatarCtrl.text.trim().isEmpty ? null : _avatarCtrl.text.trim(),
      gender: _genderCtrl.text.trim().isEmpty ? null : _genderCtrl.text.trim(),
      address: _addressCtrl.text.trim().isEmpty
          ? null
          : _addressCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      dob: _dobCtrl.text.trim().isEmpty ? null : _dobCtrl.text.trim(),
      friendsCount: _profile!.friendsCount,
      postsCount: _profile!.postsCount,
      followersCount: _followersCountOverride ?? _profile!.followersCount,
      followingCount: _followingCountOverride ?? _profile!.followingCount,
    );

    setState(() {
      _isSavingProfile = true;
    });

    try {
      final newP = await UserServiceApi.updateProfile(updated);
      if (!mounted) return false;

      setState(() {
        _profile = newP;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cập nhật hồ sơ thành công')),
      );
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Cập nhật thất bại: $e')));
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isSavingProfile = false;
        });
      }
    }
  }

  // ================= LOGOUT =================

  Future<void> _handleLogout() async {
    final res = await AuthService.logout();

    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(res.message)));

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  // ================= POPUP EDIT PROFILE =================

  void _openEditProfileDialog() {
    if (_profile == null) return;

    showDialog(
      context: context,
      barrierDismissible: !_isSavingProfile,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Chỉnh sửa hồ sơ'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _usernameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.alternate_email),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _firstNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'First name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _lastNameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Last name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _bioCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Bio',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                    prefixIcon: Icon(Icons.info_outline),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _avatarCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Avatar URL (path hoặc full URL)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.image_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _genderCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Giới tính',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.wc),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _dobCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Ngày sinh (YYYY-MM-DD)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.cake_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _addressCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Địa chỉ',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.place_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Số điện thoại',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone),
                  ),
                  keyboardType: TextInputType.phone,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isSavingProfile
                  ? null
                  : () => Navigator.of(ctx).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: _isSavingProfile
                  ? null
                  : () async {
                      final ok = await _saveProfile();
                      if (ok && ctx.mounted) {
                        Navigator.of(ctx).pop();
                      }
                    },
              child: _isSavingProfile
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Lưu'),
            ),
          ],
        );
      },
    );
  }

  // ================= FOLLOWERS / FOLLOWING POPUP =================

  Future<List<FollowUser>> _fetchFollowers(String userId) async {
    // Không dùng userId nữa, dùng onlyMe: true
    final list = await FriendServiceApi.getFollowers(onlyMe: true);

    if (mounted) setState(() => _followersCountOverride = list.length);

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

  Future<List<FollowUser>> _fetchFollowing(String userId) async {
    final list = await FriendServiceApi.getFollowing(onlyMe: true);

    if (mounted) setState(() => _followingCountOverride = list.length);

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
    final p = _profile;
    if (p == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return _FollowListSheet(
          title: 'Followers',
          loader: () => _fetchFollowers(p.id),
        );
      },
    );
  }

  void _openFollowingBottomSheet() {
    final p = _profile;
    if (p == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return _FollowListSheet(
          title: 'Following',
          loader: () => _fetchFollowing(p.id),
        );
      },
    );
  }

  // ================= UI HELPERS =================

  Widget _buildHeader(UserProfile p) {
    final fullName = '${p.lastName} ${p.firstName}'.trim().isEmpty
        ? null
        : '${p.lastName} ${p.firstName}'.trim();
    final displayName = fullName ?? p.username;
    final avatarUrl = buildFullUrl(p.avatar);

    // Posts: dùng số từ BE; nếu BE trả 0 mà đã load bài thì fallback _posts.length
    final int postCount = (p.postsCount > 0) ? p.postsCount : _posts.length;

    // Followers / Following: ưu tiên số đã tự tính
    final int followersCount = _followersCountOverride ?? p.followersCount;
    final int followingCount = _followingCountOverride ?? p.followingCount;

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
                  onTap: () {
                    setState(() {
                      _viewMode = 0;
                    });
                  },
                ),
                _buildStatItem(
                  label: 'Followers',
                  value: followersCount,
                  onTap: _openFollowersBottomSheet,
                ),
                _buildStatItem(
                  label: 'Following',
                  value: followingCount,
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

  Widget _buildNameAndBio(UserProfile p) {
    final fullName = '${p.lastName} ${p.firstName}'.trim().isEmpty
        ? null
        : '${p.lastName} ${p.firstName}'.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (fullName != null && fullName.isNotEmpty)
            Text(
              fullName,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          if ((p.bio ?? '').isNotEmpty) const SizedBox(height: 4),
          if ((p.bio ?? '').isNotEmpty)
            Text(p.bio!, style: const TextStyle(fontSize: 13)),
          if ((p.address ?? '').isNotEmpty) const SizedBox(height: 4),
          if ((p.address ?? '').isNotEmpty)
            Text(
              p.address!,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(UserProfile p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _openEditProfileDialog,
              child: const Text('Edit profile'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                // TODO: share profile
              },
              child: const Text('Share profile'),
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
          onPressed: () {
            if (_viewMode != 0) {
              setState(() {
                _viewMode = 0;
              });
            }
          },
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
          onPressed: () {
            if (_viewMode != 1) {
              setState(() {
                _viewMode = 1;
              });
            }
          },
        ),
      ],
    );
  }

  /// Helper build thumb media cho grid (chỉ dùng bài có media)
  Widget _buildMediaThumb(MediaItem media) {
    final url = buildFullUrl(media.url);
    final isAvif = url.toLowerCase().endsWith('.avif');

    Widget baseImage;
    if (isAvif) {
      baseImage = AvifImage.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, error, __) {
          debugPrint('[ProfileGrid] AVIF error: $error');
          return const Icon(Icons.error, color: Colors.black54);
        },
      );
    } else {
      baseImage = Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, error, __) {
          debugPrint('[ProfileGrid] Image error: $error');
          return const Icon(Icons.error, color: Colors.black54);
        },
      );
    }

    if (media.type == 'video') {
      return Stack(
        fit: StackFit.expand,
        children: [
          baseImage,
          const Align(
            alignment: Alignment.center,
            child: Icon(
              Icons.play_circle_fill,
              size: 32,
              color: Colors.white70,
            ),
          ),
        ],
      );
    }

    return baseImage;
  }

  /// Phần bài viết
  Widget _buildPostsSection(UserProfile p) {
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

    // GRID MODE – chỉ hiển thị bài có media (image / video)
    if (_viewMode == 0) {
      final postsWithMedia = _posts
          .where((post) => post.media.isNotEmpty)
          .toList();

      if (postsWithMedia.isEmpty) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: Text(
              'Chưa có bài viết nào có hình/video.',
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
            itemCount: postsWithMedia.length,
            itemBuilder: (context, index) {
              final post = postsWithMedia[index];
              final String title = (post.title ?? '').trim();

              // Lấy media đầu tiên có type image/video
              final MediaItem firstMedia = post.media.first;

              return GestureDetector(
                onTap: () {
                  // Chuyển sang mode list để xem chi tiết
                  setState(() {
                    _viewMode = 1;
                  });
                },
                child: Container(
                  color: Colors.grey.shade200,
                  child: Stack(
                    children: [
                      Positioned.fill(child: _buildMediaThumb(firstMedia)),
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

    // LIST MODE – dùng PostCard
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

  // ================= BUILD =================

  @override
  Widget build(BuildContext context) {
    final p = _profile;

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          p?.username ?? 'Profile',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Chỉnh sửa hồ sơ',
            icon: const Icon(Icons.edit_outlined),
            onPressed: p == null ? null : _openEditProfileDialog,
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.menu),
            onPressed: _handleLogout,
          ),
        ],
      ),
      body: _isInitLoading && p == null
          ? const Center(child: CircularProgressIndicator())
          : p == null
          ? Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.refresh),
                onPressed: _loadProfile,
                label: const Text('Thử tải lại hồ sơ'),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadProfile,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(p),
                    _buildNameAndBio(p),
                    _buildActionButtons(p),
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    _buildViewToggle(),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: _buildPostsSection(p),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }
}

/// Bottom sheet hiển thị danh sách followers / following
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
                    return Center(
                      child: Text(
                        'Lỗi tải danh sách: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  final items = snapshot.data ?? [];

                  if (items.isEmpty) {
                    return Center(
                      child: Text(
                        widget.title == 'Followers'
                            ? 'Chưa có ai follow bạn.'
                            : 'Bạn chưa follow ai.',
                        style: const TextStyle(color: Colors.grey),
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
                                  'Bạn bè',
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
