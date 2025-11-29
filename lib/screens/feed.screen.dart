import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import

import 'package:flame/models/post.model.dart';
import 'package:flame/widgets/postCard.dart';
import 'package:flame/screens/createPost.screen.dart';
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

  // [BIẾN QUAN TRỌNG] Lưu ID người đang đăng nhập
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser(); // Lấy ID ngay khi màn hình mở
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

  // Hàm lấy ID từ SharedPreferences (đã được AuthService lưu)
  Future<void> _loadCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // 'user_id' phải khớp với key trong AuthService
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

  Future<void> _openCreatePost() async {
    final created = await Navigator.of(
      context,
    ).push<bool>(MaterialPageRoute(builder: (_) => const CreatePostScreen()));

    if (created == true) {
      await _loadInitial();
    }
  }

  void _onPostChanged() {
    _loadInitial();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Bảng tin")),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: _isLoading && _posts.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _posts.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 200),
                  Center(child: Text("Chưa có bài viết nào")),
                ],
              )
            : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                itemCount: _posts.length + 1,
                itemBuilder: (context, index) {
                  if (index == _posts.length) {
                    if (_isLoadingMore) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }

                  final post = _posts[index];
                  // [QUAN TRỌNG] Truyền currentUserId xuống PostCard
                  return PostCard(
                    post: post,
                    currentUserId: _currentUserId,
                    onChanged: _onPostChanged,
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreatePost,
        icon: const Icon(Icons.add),
        label: const Text("Đăng bài"),
      ),
    );
  }
}
