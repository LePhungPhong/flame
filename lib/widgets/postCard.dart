import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_avif/flutter_avif.dart';
import 'package:video_player/video_player.dart';

import 'package:flame/models/post.model.dart';
import 'package:flame/services/postService/post.service.dart';
import 'package:flame/screens/editPost.screen.dart';
import 'package:flame/screens/otherProfile.screen.dart';

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

/// Helper avatar: AVIF + fallback chữ cái đầu kiểu vòng tròn xanh
Widget buildAvatar({
  required String? rawUrl,
  required String displayName,
  required double radius,
}) {
  // Lấy chữ cái đầu để vẽ khi không có avatar
  final String initial =
      (displayName.trim().isNotEmpty ? displayName.trim()[0] : '?')
          .toUpperCase();

  final url = buildFullUrl(rawUrl);
  debugPrint('[Avatar] raw="$rawUrl" -> url="$url" for user="$displayName"');

  // 1. Không có URL -> avatar mặc định
  if (url.isEmpty || url == 'null') {
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF2563EB),
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

  // 2. AVIF
  if (url.toLowerCase().endsWith('.avif')) {
    return ClipOval(
      child: SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: AvifImage.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            debugPrint('[Avatar] AVIF error: $error');
            return CircleAvatar(
              radius: radius,
              backgroundColor: const Color(0xFF2563EB),
              child: Text(
                initial,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: radius * 0.9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // 3. Ảnh thường
  return ClipOval(
    child: SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('[Avatar] image error: $error');
          return CircleAvatar(
            radius: radius,
            backgroundColor: const Color(0xFF2563EB),
            child: Text(
              initial,
              style: TextStyle(
                color: Colors.white,
                fontSize: radius * 0.9,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        },
      ),
    ),
  );
}

class PostCard extends StatefulWidget {
  final PostModel post;
  final String? currentUserId; // user đang đăng nhập
  final VoidCallback?
  onChanged; // để feed reload sau khi sửa / xoá / cmt / like

  const PostCard({
    super.key,
    required this.post,
    this.currentUserId,
    this.onChanged,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late int likeCount;
  late int commentCount;
  late int shareCount;
  bool isLiked = false;
  bool isShared = false;

  bool isLiking = false;
  bool isSharing = false;
  bool isDeleting = false;
  bool loadingInteractions = false;

  List<CommentModel> comments = [];

  // ==== VIDEO STATE ====
  VideoPlayerController? _videoController;
  Future<void>? _videoInitFuture;
  String? _currentVideoUrl;

  // ==== MEDIA CAROUSEL STATE ====
  late PageController _mediaPageController;
  int _currentMediaIndex = 0;

  @override
  void initState() {
    super.initState();

    likeCount = widget.post.likeCount;
    commentCount = widget.post.commentCount;
    shareCount = widget.post.shareCount;

    _mediaPageController = PageController();

    _loadInteractions();
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _mediaPageController.dispose();
    super.dispose();
  }

  void _openAuthorProfile() {
    final p = widget.post;

    if (widget.currentUserId != null && widget.currentUserId == p.authorId) {
      return;
    }

    if (p.authorId.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OtherProfileScreen(
          userId: p.authorId,
          // Truyền authorName làm username (hoặc lấy từ model nếu có field username riêng)
          username: p.authorUsername,
          displayName: p.authorName,
          avatarUrl: p.authorAvatar,
        ),
      ),
    );
  }

  Future<void> _loadInteractions() async {
    setState(() {
      loadingInteractions = true;
    });

    try {
      final map = await PostService.getPostInteractions(widget.post.id);

      setState(() {
        likeCount = (map['likeCount'] as int?) ?? likeCount;
        commentCount = (map['commentCount'] as int?) ?? commentCount;
        shareCount = (map['shareCount'] as int?) ?? shareCount;
        isLiked = (map['isLiked'] as bool?) ?? isLiked;
        isShared = (map['isShared'] as bool?) ?? isShared;

        final dynamic c = map['comments'];
        if (c is List<CommentModel>) {
          comments = c;
        }
      });
    } catch (_) {
      // optional: log
    } finally {
      if (!mounted) return;
      setState(() {
        loadingInteractions = false;
      });
    }
  }

  Future<void> _toggleLike() async {
    if (isLiking) return;
    setState(() {
      isLiking = true;
      isLiked = !isLiked;
      likeCount += isLiked ? 1 : -1;
    });

    try {
      await PostService.toggleLike(widget.post.id);
    } catch (_) {
      setState(() {
        isLiked = !isLiked;
        likeCount += isLiked ? 1 : -1;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        isLiking = false;
      });
      widget.onChanged?.call();
    }
  }

  Future<void> _sharePost() async {
    if (isSharing) return;
    setState(() {
      isSharing = true;
    });

    try {
      await PostService.sharePost(widget.post.id);
      final content = widget.post.content ?? widget.post.title ?? '';
      if (content.isNotEmpty) {
        await Share.share(content);
      }

      setState(() {
        isShared = true;
        shareCount += 1;
      });
    } catch (_) {
      // ignore
    } finally {
      if (!mounted) return;
      setState(() {
        isSharing = false;
      });
      widget.onChanged?.call();
    }
  }

  Future<void> _deletePost() async {
    if (isDeleting) return;
    setState(() {
      isDeleting = true;
    });
    try {
      await PostService.deletePost(widget.post.id);
      widget.onChanged?.call();
    } catch (_) {
      // show error if needed
    } finally {
      if (!mounted) return;
      setState(() {
        isDeleting = false;
      });
    }
  }

  /// Mở màn chỉnh sửa bài viết
  Future<void> _editPost() async {
    final bool? updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditPostScreen(post: widget.post)),
    );

    if (!mounted) return;

    if (updated == true) {
      await _loadInteractions();
      widget.onChanged?.call();
    }
  }

  String _formatTime(DateTime createdAt) {
    return '${createdAt.day.toString().padLeft(2, '0')}/'
        '${createdAt.month.toString().padLeft(2, '0')}/'
        '${createdAt.year}';
  }

  Future<void> _openComments() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final height = MediaQuery.of(ctx).size.height * 0.75;
        return SizedBox(
          height: height,
          child: _CommentSheet(
            postId: widget.post.id,
            currentUserId: widget.currentUserId,
          ),
        );
      },
    );

    // Sau khi đóng sheet: reload lại tương tác
    _loadInteractions();
    widget.onChanged?.call();
  }

  /// Helper: chọn widget image phù hợp (có hỗ trợ AVIF)
  Widget _buildPostImage(String url) {
    final lower = url.toLowerCase();

    if (lower.endsWith('.avif')) {
      debugPrint('[PostCard] Using AvifImage for media: $url');
      return AvifImage.network(
        url,
        fit: BoxFit.contain, // resize vừa khung, có thể crop nhẹ cho đẹp
        alignment: Alignment.center,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('[PostCard] AVIF error: $error');
          return const Center(child: Icon(Icons.broken_image));
        },
      );
    }

    debugPrint('[PostCard] Using Image.network for media: $url');
    return Image.network(
      url,
      fit: BoxFit.cover,
      alignment: Alignment.center,
      errorBuilder: (_, __, ___) =>
          const Center(child: Icon(Icons.broken_image)),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return const Center(child: CircularProgressIndicator(strokeWidth: 2));
      },
    );
  }

  /// Init video controller cho URL mới
  void _setupVideo(String url) {
    if (_currentVideoUrl == url && _videoController != null) return;

    _videoController?.dispose();
    _currentVideoUrl = url;

    _videoController = VideoPlayerController.network(url);
    _videoInitFuture = _videoController!
        .initialize()
        .then((_) {
          _videoController!.setLooping(true);
          if (mounted) setState(() {});
        })
        .catchError((e) {
          debugPrint('[PostCard] video init error for $url: $e');
        });
  }

  Widget _buildPostVideo(String url) {
    if (_currentVideoUrl != url || _videoController == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _setupVideo(url);
      });
    }

    return FutureBuilder<void>(
      future: _videoInitFuture,
      builder: (context, snapshot) {
        if (_videoController == null ||
            snapshot.connectionState != ConnectionState.done ||
            !_videoController!.value.isInitialized) {
          return const Center(child: CircularProgressIndicator(strokeWidth: 2));
        }

        final ctrl = _videoController!;
        return GestureDetector(
          onTap: () {
            setState(() {
              if (ctrl.value.isPlaying) {
                ctrl.pause();
              } else {
                ctrl.play();
              }
            });
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              AspectRatio(
                aspectRatio: ctrl.value.aspectRatio == 0
                    ? 16 / 9
                    : ctrl.value.aspectRatio,
                child: VideoPlayer(ctrl),
              ),
              if (!ctrl.value.isPlaying)
                Container(
                  color: Colors.black26,
                  child: const Icon(
                    Icons.play_circle_fill,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Build toàn bộ phần media (nhiều ảnh / video) với khung cố định
  Widget? _buildMediaSection(PostModel p) {
    // Lọc media có URL hợp lệ
    final validMedia = p.media
        .where((m) => (m.url).toString().trim().isNotEmpty)
        .toList();

    debugPrint(
      '[PostCard] ==== MEDIA DEBUG for postId=${p.id}, author=${p.authorName} ====',
    );
    debugPrint('[PostCard] mediaCount = ${validMedia.length}');
    for (int i = 0; i < validMedia.length; i++) {
      final m = validMedia[i];
      final fullUrl = buildFullUrl(m.url);
      debugPrint(
        '[PostCard] media[$i] type=${m.type} rawUrl="${m.url}" fullUrl="$fullUrl"',
      );
    }
    debugPrint('[PostCard] ===========================================');

    if (validMedia.isEmpty) return null;

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: double.infinity,
            height: 260, // 👈 khung cố định: ảnh/video resize vừa khung này
            child: PageView.builder(
              controller: _mediaPageController,
              itemCount: validMedia.length,
              onPageChanged: (index) {
                setState(() => _currentMediaIndex = index);
              },
              itemBuilder: (context, index) {
                final m = validMedia[index];
                final fullUrl = buildFullUrl(m.url);

                if (m.type == 'video') {
                  return _buildPostVideo(fullUrl);
                }

                return _buildPostImage(fullUrl);
              },
            ),
          ),
        ),
        if (validMedia.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(validMedia.length, (i) {
                final isActive = i == _currentMediaIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 8 : 6,
                  height: isActive ? 8 : 6,
                  decoration: BoxDecoration(
                    color: isActive ? Colors.blueAccent : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final bool isOwner =
        widget.currentUserId != null && widget.currentUserId == p.authorId;

    final mediaSection = _buildMediaSection(p);
    final List<String> tags = (p.hashtags ?? const <String>[])
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== HEADER =====
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar + tên bấm để vào trang profile người khác
                Expanded(
                  child: InkWell(
                    onTap: _openAuthorProfile,
                    borderRadius: BorderRadius.circular(999),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        buildAvatar(
                          rawUrl: p.authorAvatar,
                          displayName: p.authorName,
                          radius: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.authorName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _formatTime(p.createdAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                if (isOwner)
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        _editPost();
                      } else if (value == 'delete') {
                        await _deletePost();
                      }
                    },
                    itemBuilder: (ctx) => const [
                      PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa')),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Xoá bài viết'),
                      ),
                    ],
                  ),
              ],
            ),

            const SizedBox(height: 8),

            // ===== TITLE =====
            if ((p.title ?? '').isNotEmpty) ...[
              Text(
                p.title!,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
            ],

            // ===== CONTENT =====
            if ((p.content ?? '').isNotEmpty)
              Text(p.content!, style: const TextStyle(fontSize: 14)),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: -4,
                children: tags
                    .map(
                      (t) => Text(
                        '#$t',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            // ===== MEDIA (IMAGE / VIDEO) =====
            if (mediaSection != null) ...[
              const SizedBox(height: 8),
              mediaSection,
            ],

            const SizedBox(height: 8),

            // ===== COUNTERS =====
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (likeCount > 0)
                  Text(
                    '$likeCount lượt thích',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  )
                else
                  const SizedBox.shrink(),
                Row(
                  children: [
                    if (commentCount > 0)
                      Text(
                        '$commentCount bình luận',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    if (commentCount > 0 && shareCount > 0)
                      const SizedBox(width: 8),
                    if (shareCount > 0)
                      Text(
                        '$shareCount lượt chia sẻ',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                  ],
                ),
              ],
            ),

            const Divider(height: 16),

            // ===== ACTION BAR =====
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // LIKE
                InkWell(
                  onTap: _toggleLike,
                  child: Row(
                    children: [
                      Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 20,
                        color: isLiked ? Colors.red : Colors.grey.shade700,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Thích',
                        style: TextStyle(
                          color: isLiked ? Colors.red : Colors.grey.shade800,
                          fontWeight: isLiked
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),

                // COMMENT
                InkWell(
                  onTap: _openComments,
                  child: Row(
                    children: [
                      Icon(
                        Icons.mode_comment_outlined,
                        size: 20,
                        color: Colors.grey.shade700,
                      ),
                      const SizedBox(width: 4),
                      const Text('Bình luận'),
                    ],
                  ),
                ),

                // SHARE
                InkWell(
                  onTap: _sharePost,
                  child: Row(
                    children: [
                      Icon(
                        Icons.share_outlined,
                        size: 20,
                        color: isShared
                            ? Colors.blueAccent
                            : Colors.grey.shade700,
                      ),
                      const SizedBox(width: 4),
                      const Text('Chia sẻ'),
                    ],
                  ),
                ),
              ],
            ),

            if (loadingInteractions) ...[
              const SizedBox(height: 6),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 1.8),
                  ),
                  SizedBox(width: 6),
                  Text("Đang tải tương tác...", style: TextStyle(fontSize: 11)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// ======================
/// COMMENT SHEET
/// ======================

class _CommentSheet extends StatefulWidget {
  final String postId;
  final String? currentUserId;

  const _CommentSheet({required this.postId, this.currentUserId});

  @override
  State<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<_CommentSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<CommentModel> _comments = [];
  bool _loading = true;
  bool _sending = false;
  CommentModel? _replyTo;
  final Map<String, bool> _expandedRoots = {};

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _loading = true);
    try {
      final list = await PostService.getComments(widget.postId);
      if (mounted) setState(() => _comments = list);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi tải comment: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}p';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  Future<void> _addComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      final cmt = await PostService.addComment(
        widget.postId,
        text,
        parentId: _replyTo?.id,
      );
      if (!mounted) return;
      _controller.clear();
      _replyTo = null;
      _focusNode.unfocus();
      setState(() => _comments.add(cmt));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi gửi comment: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteComment(CommentModel target) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xoá bình luận'),
        content: const Text('Bạn có chắc muốn xoá?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xoá', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await PostService.deleteComment(target.id);
      if (!mounted) return;

      setState(() {
        final idsToDelete = <String>{target.id};
        bool foundNew = true;
        while (foundNew) {
          foundNew = false;
          for (final c in _comments) {
            if (c.parentId != null && idsToDelete.contains(c.parentId)) {
              if (!idsToDelete.contains(c.id)) {
                idsToDelete.add(c.id);
                foundNew = true;
              }
            }
          }
        }
        _comments.removeWhere((c) => idsToDelete.contains(c.id));
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi xoá comment: $e')));
      }
    }
  }

  // --- LOGIC CÂY ---
  List<CommentModel> get _rootComments =>
      _comments.where((c) => c.parentId == null || c.parentId!.isEmpty).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  Map<String, List<CommentModel>> get _replyMap {
    final map = <String, List<CommentModel>>{};
    for (final c in _comments) {
      if (c.parentId?.isNotEmpty ?? false) {
        map.putIfAbsent(c.parentId!, () => []).add(c);
      }
    }
    for (final l in map.values) {
      l.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
    return map;
  }

  Widget _buildBubble(CommentModel c, {bool isRoot = true}) {
    final theme = Theme.of(context);

    final String myId = (widget.currentUserId ?? "").toString().trim();
    final String cmtUserId = (c.userId).toString().trim();
    final bool isMyComment = myId.isNotEmpty && myId == cmtUserId;

    final avatarUrl = buildFullUrl(c.avatar);
    debugPrint(
      '[CommentSheet] avatarRaw="${c.avatar}" full="$avatarUrl" '
      'for commentId=${c.id}, userId=${c.userId}',
    );

    return GestureDetector(
      onLongPress: isMyComment ? () => _deleteComment(c) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildAvatar(
            rawUrl: c.avatar,
            displayName: c.username,
            radius: isRoot ? 16 : 12,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.dark
                        ? Colors.grey[800]
                        : Colors.grey[200],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.username,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(c.content, style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 4),
                  child: Row(
                    children: [
                      Text(
                        _timeAgo(c.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: () {
                          setState(() => _replyTo = c);
                          _focusNode.requestFocus();
                        },
                        child: const Text(
                          'Trả lời',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNode(
    CommentModel c,
    Map<String, List<CommentModel>> replies,
    int depth,
  ) {
    final children = replies[c.id] ?? [];
    final isRoot = c.parentId == null || c.parentId!.isEmpty;

    List<Widget> childrenWidgets = [];
    if (children.isNotEmpty) {
      if (isRoot && !(_expandedRoots[c.id] ?? false)) {
        childrenWidgets.add(
          Padding(
            padding: const EdgeInsets.only(left: 12, top: 4),
            child: InkWell(
              onTap: () => setState(() => _expandedRoots[c.id] = true),
              child: Text(
                'Xem ${children.length} câu trả lời',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
        );
      } else {
        for (final child in children) {
          childrenWidgets.add(_buildNode(child, replies, depth + 1));
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: _buildBubble(c, isRoot: isRoot),
        ),
        if (childrenWidgets.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(left: depth < 4 ? 32.0 : 0),
            child: Column(children: childrenWidgets),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final roots = _rootComments;
    final replies = _replyMap;
    final theme = Theme.of(context);

    return SafeArea(
      child: Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Bình luận',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Divider(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _comments.isEmpty
                  ? const Center(child: Text('Chưa có bình luận nào'))
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: roots
                          .map((r) => _buildNode(r, replies, 0))
                          .toList(),
                    ),
            ),
            if (_replyTo != null)
              Container(
                color: Colors.grey.withOpacity(0.1),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Expanded(child: Text('Đang trả lời ${_replyTo!.username}')),
                    IconButton(
                      onPressed: () => setState(() => _replyTo = null),
                      icon: const Icon(Icons.close, size: 16),
                    ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        hintText: 'Viết bình luận...',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        filled: true,
                        fillColor: theme.brightness == Brightness.dark
                            ? Colors.grey[800]
                            : Colors.grey[200],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      minLines: 1,
                      maxLines: 4,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sending ? null : _addComment,
                    icon: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send, color: Colors.blue),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
