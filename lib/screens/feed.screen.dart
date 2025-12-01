// lib/screens/feed.screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flame/models/post.model.dart';
import 'package:flame/widgets/postCard.dart';
import 'package:flame/services/searchService/search.service.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final ScrollController _scrollController = ScrollController();

  List<PostModel> _posts = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;

  // Lưu ID người đang đăng nhập
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadInitial();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 200 &&
          !_isLoadingMore &&
          !_isLoading &&
          _hasMore) {
        _loadMore();
      }
    });
  }

  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getString("user_id");
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isLoading = true;
      _currentPage = 1;
      _hasMore = true;
    });

    try {
      final items = await FeedService.getHotPosts(page: _currentPage);
      if (!mounted) return;

      setState(() {
        _posts = items;
        _hasMore = items.length == FeedService.pageSize;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể tải bài viết: $e')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final nextPage = _currentPage + 1;
      final items = await FeedService.getHotPosts(page: nextPage);
      if (!mounted) return;

      setState(() {
        _currentPage = nextPage;
        _posts.addAll(items);
        _hasMore = items.length == FeedService.pageSize;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể tải thêm bài viết: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _onRefresh() async {
    await _loadInitial();
  }

  void _onPostChanged() {
    _loadInitial();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget content;

    if (_isLoading && _posts.isEmpty) {
      // Đang loading lần đầu
      content = const Center(child: CircularProgressIndicator());
    } else if (_posts.isEmpty) {
      // Không có bài viết nào
      content = ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          Icon(
            Icons.local_fire_department_rounded,
            size: 48,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              "Chưa có bài viết nào",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              "Hãy là người đầu tiên chia sẻ điều gì đó hôm nay ✨",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    } else {
      // Có bài viết
      content = ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        itemCount: _posts.length + 1,
        itemBuilder: (context, index) {
          if (index == _posts.length) {
            if (_isLoadingMore) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            return const SizedBox.shrink();
          }

          final post = _posts[index];
          return PostCard(
            post: post,
            currentUserId: _currentUserId,
            onChanged: _onPostChanged,
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Icon(
              Icons.local_fire_department_rounded,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              "Flame",
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: "Làm mới bảng tin",
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _onRefresh,
          ),
        ],
      ),
      body: Container(
        color: theme.scaffoldBackgroundColor,
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: content,
          ),
        ),
      ),
    );
  }
}
