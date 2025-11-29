// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import '../services/authService/auth.service.dart';
import '../theme.dart';
import 'login.screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Flamee"),
        backgroundColor: FlameeTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService.logout();
              // về login
              // ignore: use_build_context_synchronously
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      body: const Center(
        child: Text("Home (sau này bạn gắn feed, chat, v.v.)"),
      ),
    );
  }
}
