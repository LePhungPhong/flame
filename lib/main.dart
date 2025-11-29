import 'package:flutter/material.dart';
import 'services/authService/auth.service.dart';
import 'screens/login.screen.dart';
import 'screens/mainApp.screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  await dotenv.load();
  runApp(const FlameeApp());
}

class FlameeApp extends StatelessWidget {
  const FlameeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flamee',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true),
      home: FutureBuilder<bool>(
        future: AuthService.isLoggedIn(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // Đã đăng nhập (token còn hạn + rememberMe == true)
          if (snapshot.data == true) {
            return const MainAppScreen();
          }

          // Chưa đăng nhập / token hết hạn
          return const LoginScreen();
        },
      ),
    );
  }
}
