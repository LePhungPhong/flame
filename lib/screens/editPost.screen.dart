import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flame/models/post.model.dart';
import 'package:flame/services/postService/post.service.dart';

class EditPostScreen extends StatefulWidget {
  final PostModel post;

  const EditPostScreen({super.key, required this.post});

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _contentController;

  // Thêm controller cho Tag
  final TextEditingController _tagController = TextEditingController();

  // Biến local để lưu dữ liệu đang sửa
  List<String> _hashtags = [];
  String _visibility = 'public';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // 1. Load dữ liệu cũ vào form
    _titleController = TextEditingController(text: widget.post.title ?? '');
    _contentController = TextEditingController(text: widget.post.content ?? '');

    // Load hashtags cũ
    _hashtags = List.from(widget.post.hashtags);

    // Load quyền riêng tư cũ
    _visibility = widget.post.visibility;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ================== KIỂM DUYỆT NỘI DUNG ==================
  Future<bool> _checkCensorship(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return true; // không có gì thì bỏ qua

    try {
      final res = await http.post(
        Uri.parse('https://flame.id.vn/censor/predict'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': trimmed}),
      );

      if (res.statusCode != 200) {
        _showSnack('Không kiểm duyệt được nội dung. Vui lòng thử lại.');
        return false;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final label = (data['label'] ?? '').toString().toLowerCase();

      if (label == 'toxic') {
        final msg =
            (data['message'] ??
                    '🚨 Nội dung chứa ngôn từ tiêu cực, vui lòng chỉnh sửa trước khi lưu.')
                .toString();
        _showSnack(msg);
        return false;
      }

      return true;
    } catch (e) {
      _showSnack('Lỗi kiểm duyệt nội dung: $e');
      return false;
    }
  }

  // ================== LOGIC TAGS (Giống CreatePost) ==================
  void _addTag() {
    final raw = _tagController.text.trim().toLowerCase();
    if (raw.isEmpty) return;

    if (raw.length > 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tag không được quá 20 ký tự')),
      );
      return;
    }
    if (_hashtags.contains(raw)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Tag này đã tồn tại')));
      return;
    }

    setState(() {
      _hashtags.add(raw);
      _tagController.clear();
    });
  }

  void _removeTag(String tag) {
    setState(() {
      _hashtags.remove(tag);
    });
  }

  // ================== SUBMIT ==================
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Gom nội dung để gửi qua API kiểm duyệt
    final textToCheck = [
      _titleController.text.trim(),
      _contentController.text.trim(),
      _hashtags.join(' '),
    ].where((e) => e.isNotEmpty).join('\n');

    final ok = await _checkCensorship(textToCheck);
    if (!ok) return; // toxic thì dừng, không call update

    setState(() => _isSubmitting = true);

    try {
      // 2. TẠO REQUEST CẬP NHẬT
      // Quan trọng: Phải truyền lại media cũ (widget.post.media)
      // nếu bạn chưa làm tính năng sửa ảnh, để tránh bị mất ảnh.
      final req = CreatePostRequest(
        title: _titleController.text.trim().isEmpty
            ? null
            : _titleController.text.trim(),
        content: _contentController.text.trim(),
        visibility: _visibility,
        hashtags: _hashtags, // Gửi danh sách tag mới (đã sửa)
        media: widget.post.media, // GIỮ NGUYÊN ẢNH CŨ (Fix lỗi mất ảnh)
      );

      await PostService.updatePost(widget.post.id, req);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cập nhật bài viết thành công')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể cập nhật: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Chỉnh sửa bài viết'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // === TIÊU ĐỀ ===
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Tiêu đề',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  maxLength: 100,
                ),
                const SizedBox(height: 16),

                // === NỘI DUNG ===
                TextFormField(
                  controller: _contentController,
                  decoration: InputDecoration(
                    labelText: 'Nội dung',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 6,
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'Nhập nội dung'
                      : null,
                ),
                const SizedBox(height: 20),

                // === HIỂN THỊ ẢNH CŨ (Chỉ xem, không sửa để tránh phức tạp) ===
                if (widget.post.media.isNotEmpty) ...[
                  Text(
                    'Ảnh đính kèm (${widget.post.media.length})',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.post.media.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            widget.post.media[index].url,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 100,
                              color: Colors.grey[300],
                              child: const Icon(Icons.broken_image),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // === TAGS (HASHTAGS) ===
                Text(
                  'Tags',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final tag in _hashtags)
                      Chip(
                        label: Text('#$tag'),
                        onDeleted: () => _removeTag(tag),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _tagController,
                        decoration: InputDecoration(
                          hintText: 'Thêm tag mới...',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onSubmitted: (_) => _addTag(),
                      ),
                    ),
                    IconButton(
                      onPressed: _addTag,
                      icon: const Icon(
                        Icons.add_circle,
                        size: 32,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // === QUYỀN RIÊNG TƯ ===
                DropdownButtonFormField<String>(
                  value: _visibility,
                  decoration: InputDecoration(
                    labelText: 'Quyền riêng tư',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'public', child: Text('Public')),
                    DropdownMenuItem(
                      value: 'friends',
                      child: Text('Friends Only'),
                    ),
                    DropdownMenuItem(value: 'private', child: Text('Private')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _visibility = val);
                  },
                ),

                const SizedBox(height: 30),

                // === NÚT LƯU ===
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Lưu thay đổi'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
