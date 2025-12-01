// lib/screens/profile.screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_avif/flutter_avif.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/authService/auth.service.dart';
import '../services/userService/user.service.dart';
import '../services/searchService/search.service.dart';
import '../services/userService/friend.service.dart';

import '../models/user.model.dart';
import '../models/post.model.dart';

import '../widgets/postCard.dart';
import 'login.screen.dart';
import 'otherProfile.screen.dart';

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

  // Thông tin sinh viên
  final _mssvCtrl = TextEditingController();
  final _courseCtrl = TextEditingController();
  final _majorCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

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
    _mssvCtrl.dispose();
    _courseCtrl.dispose();
    _majorCtrl.dispose();
    _emailCtrl.dispose();
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

        // Hiển thị @username cho đẹp, nhưng dữ liệu gốc vẫn là p.username
        final rawUsername = p.username.trim();
        _usernameCtrl.text = rawUsername.startsWith('@')
            ? rawUsername
            : '@$rawUsername';

        _firstNameCtrl.text = p.firstName;
        _lastNameCtrl.text = p.lastName;
        _emailCtrl.text = p.email;
        _bioCtrl.text = p.bio ?? "";
        _avatarCtrl.text = p.avatar ?? "";
        _genderCtrl.text = p.gender ?? "";
        _addressCtrl.text = p.address ?? "";
        _phoneCtrl.text = p.phone ?? "";
        _dobCtrl.text = p.dob ?? "";
        _mssvCtrl.text = p.mssv ?? "";
        _courseCtrl.text = p.course ?? "";
        _majorCtrl.text = p.major ?? "";
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

    // 1. Lấy dữ liệu từ form (trừ username)
    final cleanedUsername = _profile!.username.trim();

    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();

    final bio = _bioCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final dob = _dobCtrl.text.trim();
    final mssv = _mssvCtrl.text.trim();
    final course = _courseCtrl.text.trim();
    final major = _majorCtrl.text.trim();

    // 2. GIỮ LẠI TOÀN BỘ THÔNG TIN ĐÃ CÓ TỪ SERVER (avatar, gender, favorites, ...)
    String? genderFromServer = _profile!.gender;
    String genderTextCtrl = _genderCtrl.text.trim();
    String? finalGender = genderTextCtrl.isNotEmpty
        ? genderTextCtrl
        : genderFromServer;

    String normalizeGender(String? g) {
      final v = (g ?? '').trim();
      if (v == 'Nam' || v == 'Nữ' || v == 'Khác') return v;
      return 'Khác';
    }

    finalGender = normalizeGender(finalGender);

    String avatarFromServer = (_profile!.avatar ?? '').trim();
    String avatarTextCtrl = _avatarCtrl.text.trim();
    final String finalAvatar = avatarTextCtrl.isNotEmpty
        ? avatarTextCtrl
        : avatarFromServer;

    // ========= VALIDATE FIELD BẮT BUỘC =========
    if (cleanedUsername.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username không được để trống.')),
      );
      return false;
    }

    if (firstName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập Họ (firstName).')),
      );
      return false;
    }

    if (lastName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập Tên (lastName).')),
      );
      return false;
    }

    // ========= TẠO USERPROFILE MỚI (KHÔNG LÀM MẤT DATA CŨ) =========
    final updated = UserProfile(
      id: _profile!.id,
      email: _profile!.email,

      username: cleanedUsername, // 👈 luôn dùng username từ server
      firstName: firstName,
      lastName: lastName,

      gender: finalGender, // 'Nam' | 'Nữ' | 'Khác'
      avatar: finalAvatar, // luôn là string (có thể "")

      bio: bio.isEmpty ? _profile!.bio : bio,
      address: address.isEmpty ? _profile!.address : address,
      phone: phone.isEmpty ? _profile!.phone : phone,
      dob: dob.isEmpty ? _profile!.dob : dob,
      mssv: mssv.isEmpty ? _profile!.mssv : mssv,
      course: course.isEmpty ? _profile!.course : course,
      major: major.isEmpty ? _profile!.major : major,

      friendsCount: _profile!.friendsCount,
      postsCount: _profile!.postsCount,
      followersCount: _followersCountOverride ?? _profile!.followersCount,
      followingCount: _followingCountOverride ?? _profile!.followingCount,

      // 👇 GIỮ NGUYÊN favorites ĐỂ KHÔNG BỊ MẤT VÀ ĐỂ GỬI LÊN CHO BE
      favorites: _profile!.favorites,
    );

    setState(() => _isSavingProfile = true);

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
      ).showSnackBar(SnackBar(content: Text('Lỗi cập nhật hồ sơ: $e')));
      return false;
    } finally {
      if (mounted) {
        setState(() => _isSavingProfile = false);
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

  Future<void> _openEditProfileDialog() async {
    final theme = Theme.of(context);

    InputDecoration _dec(String label, {IconData? icon, String? hint}) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon, size: 18) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.4),
        ),
        filled: true,
        fillColor: theme.cardColor.withOpacity(
          theme.brightness == Brightness.dark ? 0.6 : 0.9,
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
      );
    }

    await showDialog(
      context: context,
      barrierDismissible: !_isSavingProfile,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chỉnh sửa hồ sơ',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Thông tin này sẽ hiển thị trên trang cá nhân của bạn.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ===== Tài khoản =====
                  Text(
                    'Tài khoản',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    controller: _usernameCtrl,
                    readOnly: true,
                    enabled: false,
                    decoration: _dec(
                      'Username (không thể thay đổi)',
                      icon: Icons.alternate_email,
                    ),
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: _emailCtrl,
                    readOnly: true,
                    enabled: false,
                    decoration: _dec('Email', icon: Icons.email_outlined),
                  ),

                  const SizedBox(height: 18),
                  Divider(color: theme.dividerColor.withOpacity(0.6)),
                  const SizedBox(height: 8),

                  // ===== Thông tin cá nhân =====
                  Text(
                    'Thông tin cá nhân',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _firstNameCtrl,
                          decoration: _dec('Họ (firstName)'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _lastNameCtrl,
                          decoration: _dec('Tên (lastName)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  TextField(
                    controller: _bioCtrl,
                    maxLines: 3,
                    decoration: _dec('Tiểu sử'),
                  ),

                  const SizedBox(height: 18),
                  Divider(color: theme.dividerColor.withOpacity(0.6)),
                  const SizedBox(height: 8),

                  // ===== Thông tin học tập =====
                  Text(
                    'Thông tin học tập',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    controller: _mssvCtrl,
                    decoration: _dec('MSSV', icon: Icons.badge_outlined),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _courseCtrl,
                          decoration: _dec('Khóa (Course)', icon: Icons.school),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _majorCtrl,
                          decoration: _dec(
                            'Chuyên ngành (Major)',
                            icon: Icons.menu_book_outlined,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),
                  Divider(color: theme.dividerColor.withOpacity(0.6)),
                  const SizedBox(height: 8),

                  // ===== Thông tin liên hệ =====
                  Text(
                    'Thông tin liên hệ',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    controller: _addressCtrl,
                    decoration: _dec(
                      'Địa điểm',
                      icon: Icons.location_on_outlined,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _isSavingProfile ? null : () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: _isSavingProfile
                  ? null
                  : () async {
                      final ok = await _saveProfile();
                      if (ok && ctx.mounted) Navigator.pop(ctx);
                    },
              child: _isSavingProfile
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Lưu thay đổi'),
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
    final theme = Theme.of(context);

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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withOpacity(0.08),
            theme.colorScheme.primary.withOpacity(0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          AvatarCircle(
            imageUrl: avatarUrl,
            radius: 36,
            fallbackText: displayName.isNotEmpty
                ? displayName[0].toUpperCase()
                : '?',
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@${p.username}', // hiển thị thêm @ cho đồng bộ
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildStatItem(
                      label: 'Bài viết',
                      value: postCount,
                      onTap: () {
                        setState(() {
                          _viewMode = 0;
                        });
                      },
                    ),
                    const SizedBox(width: 16),
                    _buildStatItem(
                      label: 'Followers',
                      value: followersCount,
                      onTap: _openFollowersBottomSheet,
                    ),
                    const SizedBox(width: 16),
                    _buildStatItem(
                      label: 'Following',
                      value: followingCount,
                      onTap: _openFollowingBottomSheet,
                    ),
                  ],
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
      crossAxisAlignment: CrossAxisAlignment.start,
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
    final theme = Theme.of(context);

    final fullName = '${p.lastName} ${p.firstName}'.trim().isEmpty
        ? null
        : '${p.lastName} ${p.firstName}'.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (fullName != null && fullName.isNotEmpty)
            Text(
              fullName,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          if ((p.bio ?? '').isNotEmpty) const SizedBox(height: 4),
          if ((p.bio ?? '').isNotEmpty)
            Text(p.bio!, style: theme.textTheme.bodyMedium),
          if ((p.address ?? '').isNotEmpty) const SizedBox(height: 4),
          if ((p.address ?? '').isNotEmpty)
            Row(
              children: [
                const Icon(Icons.place_outlined, size: 14),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    p.address!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(UserProfile p) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              onPressed: _openEditProfileDialog,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Chỉnh sửa hồ sơ'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                side: BorderSide(color: theme.colorScheme.error),
              ),
              onPressed: _handleLogout,
              icon: Icon(
                Icons.logout,
                size: 18,
                color: theme.colorScheme.error,
              ),
              label: Text(
                'Đăng xuất',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggle() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            Expanded(
              child: _SegmentButton(
                icon: Icons.grid_on,
                label: 'Lưới',
                selected: _viewMode == 0,
                onTap: () {
                  if (_viewMode != 0) {
                    setState(() {
                      _viewMode = 0;
                    });
                  }
                },
              ),
            ),
            Expanded(
              child: _SegmentButton(
                icon: Icons.article_outlined,
                label: 'Danh sách',
                selected: _viewMode == 1,
                onTap: () {
                  if (_viewMode != 1) {
                    setState(() {
                      _viewMode = 1;
                    });
                  }
                },
              ),
            ),
          ],
        ),
      ),
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

  /// Popup xem chi tiết 1 bài viết khi bấm vào ô trong grid
  void _openPostPopup(PostModel post) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.all(8),
          backgroundColor: Theme.of(ctx).scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: PostCard(
                post: post,
                currentUserId: _currentUserId,
                onChanged: () async {
                  // reload lại list bài viết sau khi sửa / xoá / like...
                  await _loadUserPostsInitial();
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop(); // đóng popup
                  }
                },
              ),
            ),
          ),
        );
      },
    );
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

              // Lấy media đầu tiên
              final MediaItem firstMedia = post.media.first;

              return GestureDetector(
                onTap: () => _openPostPopup(post),
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        title: Text(
          'Trang cá nhân',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
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

/// Segmented button nhỏ dùng cho toggle grid/list
class _SegmentButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? Colors.white : Colors.grey.shade700,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet hiển thị danh sách followers / following
class _FollowListSheet extends StatefulWidget {
  final String title; // "Followers" hoặc "Following"
  final Future<List<FollowUser>> Function() loader;

  const _FollowListSheet({required this.title, required this.loader});

  @override
  State<_FollowListSheet> createState() => _FollowListSheetState();
}

class _FollowListSheetState extends State<_FollowListSheet> {
  late Future<List<FollowUser>> _future;

  // lưu danh sách để có thể remove khi unfollow
  List<FollowUser>? _items;

  // trạng thái mình đang follow user đó hay không
  final Map<String, bool> _followState = {};

  // id đang loading (nhấn nút follow/unfollow)
  final Set<String> _loadingIds = {};

  @override
  void initState() {
    super.initState();
    _future = widget.loader();
  }

  bool get _isFollowersSheet => widget.title == 'Followers';
  bool get _isFollowingSheet => widget.title == 'Following';

  Future<void> _onToggleFollow(String userId) async {
    if (_loadingIds.contains(userId)) return;

    setState(() {
      _loadingIds.add(userId);
    });

    try {
      final msg = await FriendServiceApi.addOrUnFollowById(userId);

      if (!mounted) return;

      final current =
          _followState[userId] ?? (_isFollowingSheet ? true : false);
      final newVal = !current;

      setState(() {
        _followState[userId] = newVal;

        // Nếu đang ở tab "Đang theo dõi" và bấm unfollow -> xoá khỏi list
        if (_isFollowingSheet && !newVal) {
          _items?.removeWhere((e) => e.id == userId);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _loadingIds.remove(userId);
        });
      }
    }
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

                  final fetched = snapshot.data ?? [];

                  // Khởi tạo _items & _followState lần đầu
                  if (_items == null) {
                    _items = List<FollowUser>.from(fetched);
                    for (final u in _items!) {
                      bool isFollowing;
                      if (_isFollowersSheet) {
                        // nếu mutual thì mình đã follow họ
                        isFollowing = u.isMutual;
                      } else {
                        // tab Following: chắc chắn mình đang follow họ
                        isFollowing = true;
                      }
                      _followState[u.id] = isFollowing;
                    }
                  }

                  final items = _items ?? [];

                  if (items.isEmpty) {
                    return Center(
                      child: Text(
                        _isFollowersSheet
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
                      final isFollowing =
                          _followState[u.id] ??
                          (_isFollowingSheet ? true : false);
                      final isLoading = _loadingIds.contains(u.id);

                      Widget? trailing;

                      if (u.isMutual && isFollowing) {
                        // Hai bên follow nhau
                        trailing = const _FriendChip();
                      } else {
                        trailing = _FollowActionButton(
                          text: isFollowing ? 'Bỏ theo dõi' : 'Theo dõi',
                          loading: isLoading,
                          onPressed: () => _onToggleFollow(u.id),
                        );
                      }

                      return ListTile(
                        onTap: () {
                          // đóng bottom sheet rồi push sang trang cá nhân
                          final navigator = Navigator.of(context);
                          navigator.pop();
                          navigator.push(
                            MaterialPageRoute(
                              builder: (_) => OtherProfileScreen(
                                userId: u.id,
                                username: u.username,
                                displayName: u.displayName,
                                avatarUrl: u.avatarUrl,
                              ),
                            ),
                          );
                        },
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
                          u.username,
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: trailing,
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

/// Chip "Bạn bè" (mutual)
class _FriendChip extends StatelessWidget {
  const _FriendChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Bạn bè',
        style: TextStyle(
          fontSize: 11,
          color: Colors.blue.shade600,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Nút Follow / Bỏ theo dõi
class _FollowActionButton extends StatelessWidget {
  final String text;
  final bool loading;
  final VoidCallback onPressed;

  const _FollowActionButton({
    required this.text,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: loading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        side: BorderSide(color: Colors.blue.shade400),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      ),
      child: loading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              text,
              style: TextStyle(fontSize: 11, color: Colors.blue.shade600),
            ),
    );
  }
}
