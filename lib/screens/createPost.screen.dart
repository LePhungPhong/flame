import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

import 'package:flame/models/post.model.dart';
import 'package:flame/services/postService/post.service.dart';

const int _kMaxImages = 5;
const int _kMaxImageBytes = 4718592; // ≈ 4.5MB

/// Model local cho 1 ảnh được chọn
class _LocalImage {
  final File file;
  String? url; // URL sau khi upload xong
  bool uploaded;
  bool uploading;

  _LocalImage({
    required this.file,
    this.url,
    this.uploaded = false,
    this.uploading = false,
  });
}

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  // Hashtags (tags)
  final TextEditingController _tagController = TextEditingController();
  final List<String> _hashtags = [];

  final ImagePicker _picker = ImagePicker();

  final List<_LocalImage> _images = [];

  bool _isSubmitting = false;

  // Quyền riêng tư: giống web (public | friends | private)
  String _visibility = 'public';

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  // ================== TAGS (HASHTAGS) ==================

  void _addTag() {
    final raw = _tagController.text.trim().toLowerCase();
    if (raw.isEmpty) return;

    if (raw.length > 20) {
      _showSnack('Tag không được vượt quá 20 ký tự');
      return;
    }
    if (_hashtags.length >= 10) {
      _showSnack('Bạn chỉ có thể thêm tối đa 10 tag');
      return;
    }
    if (_hashtags.contains(raw)) {
      _showSnack('Tag này đã tồn tại');
      return;
    }

    final reg = RegExp(r'^[a-zA-Z0-9\u00C0-\u024F\u1E00-\u1EFF\s]+$');
    if (!reg.hasMatch(raw)) {
      _showSnack('Tag chỉ được chứa chữ cái, số và khoảng trắng');
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

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ================== KIỂM DUYỆT NỘI DUNG ==================

  Future<bool> _checkCensorship(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return true; // không có nội dung thì khỏi check

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
                    '🚨 Nội dung chứa ngôn từ tiêu cực, vui lòng chỉnh sửa trước khi đăng.')
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

  // ================== PICK + UPLOAD MULTI IMAGE ==================

  Future<void> _pickImages() async {
    try {
      final picked = await _picker.pickMultiImage(imageQuality: 90);
      if (picked.isEmpty) return;

      // Kiểm tra tổng số ảnh
      if (_images.length + picked.length > _kMaxImages) {
        _showSnack('Chỉ được chọn tối đa $_kMaxImages ảnh');
        return;
      }

      for (final x in picked) {
        final file = File(x.path);
        final size = await file.length();

        if (size > _kMaxImageBytes) {
          _showSnack('Một số ảnh vượt quá giới hạn 4.5MB, đã bỏ qua');
          continue;
        }

        final local = _LocalImage(file: file, uploading: true);
        setState(() {
          _images.add(local);
        });

        final index = _images.length - 1;
        _uploadSingleImage(index);
      }
    } catch (e) {
      _showSnack('Lỗi chọn ảnh: $e');
    }
  }

  Future<void> _uploadSingleImage(int index) async {
    if (index < 0 || index >= _images.length) return;
    final img = _images[index];

    try {
      final url = await PostService.uploadImage(img.file);
      if (!mounted) return;

      setState(() {
        _images[index] = _LocalImage(
          file: img.file,
          url: url,
          uploaded: true,
          uploading: false,
        );
      });
    } catch (e) {
      if (!mounted) return;
      _showSnack('Upload ảnh thất bại: $e');
      setState(() {
        _images[index] = _LocalImage(
          file: img.file,
          url: img.url,
          uploaded: false,
          uploading: false,
        );
      });
    }
  }

  void _removeImage(int index) {
    if (index < 0 || index >= _images.length) return;
    setState(() {
      _images.removeAt(index);
    });
  }

  Future<void> _ensureAllImagesUploaded() async {
    for (int i = 0; i < _images.length; i++) {
      if (!_images[i].uploaded) {
        setState(() {
          _images[i] = _LocalImage(
            file: _images[i].file,
            url: _images[i].url,
            uploaded: false,
            uploading: true,
          );
        });
        await _uploadSingleImage(i);
      }
    }
  }

  // ================== SUBMIT POST ==================
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Gom nội dung gửi qua API kiểm duyệt
    final textToCheck = [
      _titleController.text.trim(),
      _contentController.text.trim(),
      _hashtags.join(' '),
    ].where((e) => e.isNotEmpty).join('\n');

    final ok = await _checkCensorship(textToCheck);
    if (!ok) return; // toxic thì dừng, không đăng

    setState(() => _isSubmitting = true);

    try {
      // Đảm bảo tất cả ảnh đã upload xong
      await _ensureAllImagesUploaded();

      final media = _images
          .where((img) => img.uploaded && (img.url ?? '').isNotEmpty)
          .map((img) => MediaItem(url: img.url!, type: 'image'))
          .toList();

      final req = CreatePostRequest(
        title: _titleController.text.trim().isEmpty
            ? null
            : _titleController.text.trim(),
        content: _contentController.text.trim(),
        visibility: _visibility,
        hashtags: _hashtags,
        taggedFriends: const [],
        media: media,
      );

      await PostService.createPost(req);

      if (!mounted) return;

      _showSnack('Đăng bài thành công');

      Navigator.pop(context, true);
    } catch (e) {
      _showSnack('Không thể đăng bài: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  // ================== UI ==================
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasImages = _images.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tạo bài viết'),
            Text(
              'Chia sẻ điều gì đó với mọi người',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade500,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Container(
          color: theme.scaffoldBackgroundColor,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ====== Card chứa form ======
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: theme.dividerColor.withOpacity(0.4),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ====== Tiêu đề ======
                              TextFormField(
                                controller: _titleController,
                                decoration: InputDecoration(
                                  labelText: 'Tiêu đề (tuỳ chọn)',
                                  hintText: 'Hôm nay bạn muốn chia sẻ điều gì?',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                maxLength: 100,
                              ),
                              const SizedBox(height: 12),

                              // ====== Nội dung ======
                              TextFormField(
                                controller: _contentController,
                                decoration: InputDecoration(
                                  labelText: 'Nội dung',
                                  hintText:
                                      'Viết cảm nghĩ, câu chuyện hoặc cập nhật trạng thái của bạn...',
                                  alignLabelWithHint: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                maxLines: 5,
                                validator: (value) {
                                  if ((value == null || value.trim().isEmpty) &&
                                      !hasImages) {
                                    return 'Nội dung không được để trống (hoặc phải có ít nhất 1 ảnh)';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // ====== Upload nhiều ảnh ======
                              Row(
                                children: [
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                    ),
                                    onPressed:
                                        _isSubmitting ||
                                            _images.length >= _kMaxImages
                                        ? null
                                        : _pickImages,
                                    icon: const Icon(
                                      Icons.photo_library_outlined,
                                      size: 20,
                                    ),
                                    label: Text(
                                      _images.isEmpty
                                          ? 'Chọn ảnh'
                                          : 'Thêm ảnh (${_images.length}/$_kMaxImages)',
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  if (_images.isNotEmpty)
                                    Text(
                                      'Đã chọn ${_images.length} ảnh',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              if (_images.isNotEmpty) _buildImageGrid(),

                              const SizedBox(height: 16),

                              // ====== Hashtags ======
                              Text(
                                'Tags (Hashtags)',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (_hashtags.isNotEmpty)
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    for (final tag in _hashtags)
                                      Chip(
                                        label: Text('#$tag'),
                                        backgroundColor: theme
                                            .colorScheme
                                            .primary
                                            .withOpacity(0.08),
                                        labelStyle: TextStyle(
                                          color: theme.colorScheme.primary,
                                        ),
                                        deleteIcon: const Icon(
                                          Icons.close,
                                          size: 18,
                                        ),
                                        onDeleted: () => _removeTag(tag),
                                      ),
                                  ],
                                )
                              else
                                Text(
                                  'Bạn có thể thêm từ khoá để mọi người dễ tìm hơn (vd: trường, sự kiện, sở thích...)',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _tagController,
                                      decoration: InputDecoration(
                                        hintText:
                                            'Nhập tag và nhấn + hoặc Enter',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 10,
                                            ),
                                      ),
                                      onSubmitted: (_) => _addTag(),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      shape: const CircleBorder(),
                                      padding: const EdgeInsets.all(10),
                                    ),
                                    onPressed: _addTag,
                                    child: const Icon(Icons.add, size: 20),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // ====== Quyền riêng tư ======
                              Text(
                                'Quyền riêng tư',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: _visibility,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'public',
                                    child: Row(
                                      children: [
                                        Icon(Icons.public, size: 18),
                                        SizedBox(width: 8),
                                        Text('Public'),
                                      ],
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'friends',
                                    child: Row(
                                      children: [
                                        Icon(Icons.group, size: 18),
                                        SizedBox(width: 8),
                                        Text('Friends Only'),
                                      ],
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'private',
                                    child: Row(
                                      children: [
                                        Icon(Icons.lock, size: 18),
                                        SizedBox(width: 8),
                                        Text('Private'),
                                      ],
                                    ),
                                  ),
                                ],
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() => _visibility = value);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ====== Nút Đăng bài ======
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: _isSubmitting ? null : _submit,
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Đăng bài'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _images.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemBuilder: (context, index) {
        final img = _images[index];
        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(img.file, fit: BoxFit.cover),
            ),
            if (img.uploading)
              Container(
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
            Positioned(
              top: 4,
              right: 4,
              child: InkWell(
                onTap: _isSubmitting ? null : () => _removeImage(index),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
