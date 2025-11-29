// lib/screens/mainApp.screen.dart
import 'package:flutter/material.dart';

import 'feed.screen.dart';
import 'profile.screen.dart';
import 'createPost.screen.dart';
import 'followConnections.screen.dart'; // màn Friends/Follow

class MainAppScreen extends StatefulWidget {
  const MainAppScreen({super.key});

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  int _index = 0;

  // Trang hiển thị dưới (không dùng CreatePostScreen ở đây)
  final List<Widget> _pages = const [
    FeedScreen(), // 0 - Bảng tin
    FollowConnectionsScreen(), // 1 - Friends / Follow
    SizedBox.shrink(), // 2 - Đăng bài (placeholder, không dùng)
    ProfileScreen(), // 3 - Hồ sơ
  ];

  Future<void> _onItemTapped(int i) async {
    if (i == 2) {
      // 👉 Tab Đăng bài: mở màn tạo bài viết
      final created = await Navigator.of(
        context,
      ).push<bool>(MaterialPageRoute(builder: (_) => const CreatePostScreen()));

      // Nếu tạo bài viết thành công -> chuyển về tab Feed
      if (created == true) {
        setState(() {
          _index = 0; // 0 = FeedScreen
        });
      }

      return; // không đổi _index theo i
    }

    setState(() {
      _index = i;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _index,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: "Bảng tin",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_alt_outlined),
            label: "Bạn bè",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: "Đăng bài",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: "Hồ sơ",
          ),
        ],
      ),
    );
  }
}
