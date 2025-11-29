import 'package:flutter/material.dart';

import 'feed.screen.dart';
import 'profile.screen.dart';
import 'createPost.screen.dart';

class MainAppScreen extends StatefulWidget {
  const MainAppScreen({super.key});

  @override
  State<MainAppScreen> createState() => _MainAppScreenState();
}

class _MainAppScreenState extends State<MainAppScreen> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const FeedScreen(),
      const CreatePostScreen(), // Bảng tin
      const ProfileScreen(), // Hồ sơ
    ];

    return Scaffold(
      body: pages[index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i) => setState(() => index = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: "Bảng tin",
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
