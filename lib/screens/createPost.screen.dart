import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:flame/models/post.model.dart';
import 'package:flame/services/postService/post.service.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  File? _imageFile; // File local để preview
  String? _imageUrl; // URL trả về từ backend sau khi upload
  bool _uploadingImage = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  // ================== PICK + UPLOAD IMAGE ==================
  Future<void> _pickAndUploadImage() async {
    try {
      // 1. Chọn ảnh từ gallery
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (picked == null) return;

      final file = File(picked.path);

      setState(() {
        _uploadingImage = true;
        _imageFile = file; // để preview
      });

      // 2. Upload lên server qua PostService.uploadImage
      final url = await PostService.uploadImage(file);

      setState(() {
        _imageUrl = url; // url do backend trả về, ví dụ: /uploads/xxx.avif
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Upload ảnh thành công')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload ảnh thất bại: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _uploadingImage = false;
        });
      }
    }
  }

  // ================== SUBMIT POST ==================
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      // Build media list từ _imageUrl (nếu có)
      final List<MediaItem> media = [];
      if (_imageUrl != null && _imageUrl!.isNotEmpty) {
        media.add(MediaItem(url: _imageUrl!, type: 'image'));
      }

      final req = CreatePostRequest(
        title: _titleController.text.trim().isEmpty
            ? null
            : _titleController.text.trim(),
        content: _contentController.text.trim(),
        visibility: 'public', // hoặc dùng dropdown nếu sau này cần
        hashtags: const [],
        taggedFriends: const [],
        media: media,
      );

      await PostService.createPost(req);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đăng bài thành công')));

      // Pop với result = true để feed biết mà refresh
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể đăng bài: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  if (value == null || value.trim().isEmpty) {
                    return 'Nội dung không được để trống';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ====== Nút chọn ảnh + trạng thái upload ======
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _uploadingImage ? null : _pickAndUploadImage,
                    icon: _uploadingImage
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.image_outlined),
                    label: const Text('Chọn ảnh'),
                  ),
                  const SizedBox(width: 12),
                  if (_imageUrl != null)
                    Row(
                      children: const [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 4),
                        Text('Đã upload ảnh'),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // ====== Preview ảnh từ file local ======
              if (_imageFile != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    _imageFile!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
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
}
