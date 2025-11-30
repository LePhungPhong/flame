import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
    final hasImages = _images.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Tạo bài viết')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ====== Tiêu đề ======
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Tiêu đề (tuỳ chọn)',
                  border: OutlineInputBorder(),
                ),
                maxLength: 100,
              ),
              const SizedBox(height: 12),

              // ====== Nội dung ======
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(
                  labelText: 'Nội dung',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
                validator: (value) {
                  if ((value == null || value.trim().isEmpty) && !hasImages) {
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
                    onPressed: _isSubmitting || _images.length >= _kMaxImages
                        ? null
                        : _pickImages,
                    icon: const Icon(Icons.photo_library_outlined),
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
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              if (_images.isNotEmpty) _buildImageGrid(),

              const SizedBox(height: 16),

              // ====== Hashtags ======
              const Text(
                'Tags (Hashtags)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final tag in _hashtags)
                    Chip(
                      label: Text('#$tag'),
                      deleteIcon: const Icon(Icons.close, size: 18),
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
                      decoration: const InputDecoration(
                        hintText: 'Nhập tag và nhấn + hoặc Enter',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _addTag(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(onPressed: _addTag, child: const Text('+')),
                ],
              ),
              const SizedBox(height: 16),

              // ====== Quyền riêng tư ======
              const Text(
                'Quyền riêng tư',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _visibility,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'public', child: Text('Public')),
                  DropdownMenuItem(
                    value: 'friends',
                    child: Text('Friends Only'),
                  ),
                  DropdownMenuItem(value: 'private', child: Text('Private')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _visibility = value);
                },
              ),

              const SizedBox(height: 24),

              // ====== Nút Đăng bài ======
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Đăng bài'),
                ),
              ),
            ],
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
              borderRadius: BorderRadius.circular(8),
              child: Image.file(img.file, fit: BoxFit.cover),
            ),
            if (img.uploading)
              const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
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
