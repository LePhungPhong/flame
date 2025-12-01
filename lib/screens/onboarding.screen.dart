import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/userService/user.service.dart';
import 'mainApp.screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;

  // ====== Thông tin cá nhân ======
  final _formKeyInfo = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _mssvCtrl = TextEditingController(); // MSSV
  String? _gender; // "Nam" / "Nữ" / "Khác"

  // ====== Sở thích ======
  final List<String> _favorites = [];

  // ====== Avatar ======
  final ImagePicker _picker = ImagePicker();
  File? _avatarFile;
  String? _avatarUrl;
  bool _uploadingAvatar = false;

  // ====== Username + Bio ======
  final _formKeyUser = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _dobCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _mssvCtrl.dispose();
    _usernameCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  void _goNext() {
    setState(() {
      if (_step < 4) _step++;
    });
  }

  void _goPrev() {
    setState(() {
      if (_step > 0) _step--;
    });
  }

  // ================== PICK & UPLOAD AVATAR ==================
  Future<void> _pickAvatar() async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (picked == null) return;

      final file = File(picked.path);

      setState(() {
        _avatarFile = file;
        _uploadingAvatar = true;
        _avatarUrl = null;
      });

      final url = await UserServiceApi.uploadAvatarImage(file);

      if (!mounted) return;

      setState(() {
        _avatarUrl = url;
        _uploadingAvatar = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Upload ảnh đại diện thành công')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadingAvatar = false;
        _avatarUrl = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Upload ảnh thất bại: $e')));
    }
  }

  // ================== SUBMIT PROFILE (STEP 4) ==================
  Future<void> _submitProfile() async {
    if (!_formKeyUser.currentState!.validate()) return;

    if (_favorites.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn ít nhất 1 sở thích')),
      );
      return;
    }

    if (_avatarUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn và upload ảnh đại diện')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      await UserServiceApi.createProfileFromOnboarding(
        username: _usernameCtrl.text.trim(),
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        gender: _gender ?? "Khác",
        dob: _dobCtrl.text.trim(),
        favorites: List<String>.from(_favorites),
        avatarUrl: _avatarUrl!,
        bio: _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        address: _addressCtrl.text.trim().isEmpty
            ? null
            : _addressCtrl.text.trim(),
        mssv: _mssvCtrl.text.trim(),
        course: null,
        major: null,
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainAppScreen()),
      );
    } catch (e, stack) {
      // debug log
      // ignore: avoid_print
      print("====== submitProfile ERROR ======");
      // ignore: avoid_print
      print(e);
      // ignore: avoid_print
      print(stack);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Cập nhật hồ sơ thất bại: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ================== BUILD ==================
  @override
  Widget build(BuildContext context) {
    Widget child;
    switch (_step) {
      case 0:
        child = _buildIntroStep();
        break;
      case 1:
        child = _buildPersonalInfoStep();
        break;
      case 2:
        child = _buildFavoriteStep();
        break;
      case 3:
        child = _buildAvatarStep();
        break;
      default:
        child = _buildUsernameBioStep();
    }

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          'Hoàn thiện hồ sơ',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              _buildStepIndicator(),
              const SizedBox(height: 12),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================== STEP INDICATOR ==================
  Widget _buildStepIndicator() {
    const labels = [
      'Giới thiệu',
      'Thông tin',
      'Sở thích',
      'Ảnh đại diện',
      'Tài khoản',
    ];
    return Row(
      children: List.generate(labels.length, (i) {
        final active = i == _step;
        final done = i < _step;
        final Color color;
        if (active) {
          color = const Color(0xFF2563EB);
        } else if (done) {
          color = Colors.green;
        } else {
          color = Colors.grey.shade400;
        }

        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 3,
                      margin: EdgeInsets.only(
                        left: i == 0 ? 0 : 4,
                        right: i == labels.length - 1 ? 0 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: (active || done) ? color : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                labels[i],
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  color: active ? color : Colors.grey.shade600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      }),
    );
  }

  // ================== STEP 0 - INTRO ==================
  Widget _buildIntroStep() {
    return Center(
      key: const ValueKey('step0'),
      child: SingleChildScrollView(
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chào mừng đến với Flamee 🎓',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tiếp theo bạn hãy hoàn thành việc điền thông tin nhé!!!.\n',
                  style: TextStyle(fontSize: 13.5),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: const Color(0xFFF9FAFB),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: const Text(
                    'Nhấn "Bắt đầu" để điền thông tin cá nhân, chọn sở thích '
                    'và ảnh đại diện. Sau khi hoàn tất, bạn đã có thể '
                    'bắt đầu trải nghiệm.',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _goNext,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: const Color(0xFF6D28D9),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: const Text(
                      'Bắt đầu',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ================== STEP 1 - PERSONAL INFO ==================
  Widget _buildPersonalInfoStep() {
    final theme = Theme.of(context);
    return Center(
      key: const ValueKey('step1'),
      child: SingleChildScrollView(
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Form(
              key: _formKeyInfo,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Thông tin cá nhân',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Giúp bạn bè nhận ra bạn dễ dàng hơn.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _firstNameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Họ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Vui lòng nhập họ'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _lastNameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Tên',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Vui lòng nhập tên'
                        : null,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _mssvCtrl,
                    decoration: InputDecoration(
                      labelText: 'Mã số sinh viên (10 số)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final value = v?.trim() ?? "";
                      if (value.isEmpty) return 'Vui lòng nhập MSSV';
                      if (!RegExp(r'^\d{10}$').hasMatch(value)) {
                        return 'Mã số sinh viên phải là chuỗi 10 chữ số';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _gender,
                    decoration: InputDecoration(
                      labelText: 'Giới tính',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'Nam', child: Text('Nam')),
                      DropdownMenuItem(value: 'Nữ', child: Text('Nữ')),
                      DropdownMenuItem(value: 'Khác', child: Text('Khác')),
                    ],
                    onChanged: (v) => setState(() => _gender = v),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _dobCtrl,
                    decoration: InputDecoration(
                      labelText: 'Ngày sinh (YYYY-MM-DD)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    validator: (v) {
                      final value = v?.trim() ?? "";
                      if (value.isEmpty) return 'Vui lòng nhập ngày sinh';
                      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
                        return 'Ngày sinh phải dạng YYYY-MM-DD';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _phoneCtrl,
                    decoration: InputDecoration(
                      labelText: 'Số điện thoại',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _addressCtrl,
                    decoration: InputDecoration(
                      labelText: 'Địa chỉ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      TextButton(
                        onPressed: _goPrev,
                        child: const Text('Quay lại'),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () {
                          if (_formKeyInfo.currentState!.validate()) {
                            _goNext();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        child: const Text('Tiếp theo'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ================== STEP 2 - FAVORITES ==================
  static const int _kMaxFavorites = 5;

  static const List<_FavoriteItem> _kAllFavorites = [
    _FavoriteItem('Đọc sách', Icons.menu_book_rounded),
    _FavoriteItem('Xem phim', Icons.movie),
    _FavoriteItem('Nghe nhạc', Icons.headphones),
    _FavoriteItem('Chụp ảnh', Icons.camera_alt),
    _FavoriteItem('Game', Icons.sports_esports),
    _FavoriteItem('Thiết kế', Icons.brush),
    _FavoriteItem('Viết', Icons.edit),
    _FavoriteItem('Chia sẻ', Icons.mic),
    _FavoriteItem('Lập trình', Icons.code),
    _FavoriteItem('UI/UX', Icons.design_services),
    _FavoriteItem('Du lịch', Icons.public),
    _FavoriteItem('Nấu ăn', Icons.restaurant),
    _FavoriteItem('Cafe', Icons.local_cafe),
    _FavoriteItem('Handmade', Icons.handyman),
    _FavoriteItem('Thể thao', Icons.fitness_center),
    _FavoriteItem('Yoga', Icons.self_improvement),
    _FavoriteItem('Ngoại ngữ', Icons.language),
    _FavoriteItem('CLB', Icons.group),
    _FavoriteItem('Tình nguyện', Icons.volunteer_activism),
    _FavoriteItem('Kinh doanh', Icons.shopping_cart),
  ];

  Widget _buildFavoriteStep() {
    final count = _favorites.length;
    return Center(
      key: const ValueKey('step2'),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sở thích của bạn',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                'Chọn những sở thích bạn yêu thích nhất. (Đã chọn $count/$_kMaxFavorites)',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _kAllFavorites.map((item) {
                      final selected = _favorites.contains(item.label);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (selected) {
                              _favorites.remove(item.label);
                            } else {
                              if (_favorites.length >= _kMaxFavorites) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Bạn chỉ có thể chọn tối đa $_kMaxFavorites sở thích',
                                    ),
                                  ),
                                );
                                return;
                              }
                              _favorites.add(item.label);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: selected
                                  ? const Color(0xFF8050FF)
                                  : Colors.grey.shade500,
                            ),
                            color: selected
                                ? const Color(0xFF8050FF).withOpacity(0.12)
                                : Colors.transparent,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                item.icon,
                                size: 18,
                                color: selected
                                    ? const Color(0xFF8050FF)
                                    : Colors.grey.shade500,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: selected
                                      ? Colors.black
                                      : Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  TextButton(onPressed: _goPrev, child: const Text('Quay lại')),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () {
                      if (_favorites.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Vui lòng chọn ít nhất 1 sở thích'),
                          ),
                        );
                        return;
                      }
                      _goNext();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: const Text('Tiếp theo'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================== STEP 3 - AVATAR ==================
  Widget _buildAvatarStep() {
    return Center(
      key: const ValueKey('step3'),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chọn ảnh đại diện',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Hãy chọn ảnh rõ mặt để mọi người nhận ra bạn dễ hơn!',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _uploadingAvatar ? null : _pickAvatar,
                child: Container(
                  width: double.infinity,
                  height: 220,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.grey.shade400, width: 1.3),
                  ),
                  child: Center(
                    child: _avatarFile == null
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.camera_alt_outlined, size: 40),
                              SizedBox(height: 12),
                              Text(
                                'Nhấn để tải ảnh từ thiết bị\nhoặc chọn ảnh có sẵn',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13),
                              ),
                            ],
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 56,
                                backgroundImage: FileImage(_avatarFile!),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _avatarUrl != null
                                    ? 'Ảnh đã được upload lên server'
                                    : 'Đang upload ảnh...',
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (_uploadingAvatar) const LinearProgressIndicator(minHeight: 3),
              const SizedBox(height: 10),
              Row(
                children: [
                  TextButton(onPressed: _goPrev, child: const Text('Quay lại')),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: (!_uploadingAvatar && _avatarUrl != null)
                        ? _goNext
                        : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: const Text('Tiếp theo'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================== STEP 4 - USERNAME + BIO ==================
  Widget _buildUsernameBioStep() {
    final theme = Theme.of(context);
    return Center(
      key: const ValueKey('step4'),
      child: SingleChildScrollView(
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Form(
              key: _formKeyUser,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hoàn tất hồ sơ',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Chọn username và giới thiệu ngắn gọn về bạn.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _usernameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    validator: (v) {
                      final value = v?.trim() ?? '';
                      if (value.isEmpty) return 'Vui lòng nhập username';
                      if (value.length < 3) {
                        return 'Username tối thiểu 3 ký tự';
                      }
                      if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(value)) {
                        return 'Chỉ cho phép chữ, số, dấu _ và .';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _bioCtrl,
                    decoration: InputDecoration(
                      labelText: 'Giới thiệu bản thân',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      TextButton(
                        onPressed: _goPrev,
                        child: const Text('Quay lại'),
                      ),
                      const Spacer(),
                      SizedBox(
                        height: 44,
                        child: ElevatedButton(
                          onPressed: _submitting ? null : _submitProfile,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 10,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Hoàn thành'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FavoriteItem {
  final String label;
  final IconData icon;
  const _FavoriteItem(this.label, this.icon);
}
