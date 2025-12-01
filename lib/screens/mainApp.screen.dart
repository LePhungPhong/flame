// lib/screens/mainApp.screen.dart
import 'package:flutter/material.dart';

import 'feed.screen.dart';
import 'profile.screen.dart';
import 'createPost.screen.dart';
import 'followConnections.screen.dart';

class MainAppScreen extends StatefulWidget {
  const MainAppScreen({super.key});

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  int _index = 0;

  // Trang hiển thị dưới
  final List<Widget> _pages = const [
    FeedScreen(), // 0 - Bảng tin
    FollowConnectionsScreen(), // 1 - Friends / Follow
    SizedBox.shrink(), // 2 - Đăng bài (placeholder, không dùng)
    ProfileScreen(), // 3 - Hồ sơ
  ];

  Future<void> _onItemTapped(int i) async {
    if (i == 2) {
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
    final theme = Theme.of(context);

    return Scaffold(
      body: _pages[_index],

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              offset: const Offset(0, -2),
              blurRadius: 12,
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
            ),
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _index,
              onTap: _onItemTapped,
              backgroundColor: theme.colorScheme.surface,
              elevation: 0,
              selectedItemColor: theme.colorScheme.primary,
              unselectedItemColor: Colors.grey.shade500,
              selectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              unselectedLabelStyle: const TextStyle(fontSize: 11),
              showUnselectedLabels: true,
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
          ),
        ),
      ),
    );
  }
}
