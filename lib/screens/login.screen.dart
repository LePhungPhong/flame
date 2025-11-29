import 'package:flutter/material.dart';
import '../services/authService/auth.service.dart';
import 'singnup.screen.dart';
import '../widgets/flameLogo.dart';
import 'mainApp.screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController passwordCtrl = TextEditingController();

  bool rememberMe = false;
  bool showPassword = false;
  bool isLoading = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    final res = await AuthService.login(
      email: emailCtrl.text.trim(),
      password: passwordCtrl.text,
      rememberMe: rememberMe,
    );

    if (!mounted) return;
    setState(() => isLoading = false);

    // Hiển thị thông báo từ backend
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(res.message)));

    // Nếu login thất bại thì dừng lại
    if (!res.ok) return;

    // Login thành công -> chuyển sang MainAppScreen
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const MainAppScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FlameeLogo(size: 52),
                    const SizedBox(height: 24),
                    const Text(
                      "Đăng nhập",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Email
                    const Text(
                      "Email",
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        hintText: "you@example.com",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return "Vui lòng nhập email";
                        }
                        if (!value.contains("@")) {
                          return "Email không hợp lệ";
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      "Mật khẩu",
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: passwordCtrl,
                      obscureText: !showPassword,
                      decoration: InputDecoration(
                        hintText: "••••••••••",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            showPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () {
                            setState(() => showPassword = !showPassword);
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Vui lòng nhập mật khẩu";
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 12),

                    // Remember me
                    Row(
                      children: [
                        Switch(
                          value: rememberMe,
                          onChanged: (v) => setState(() => rememberMe = v),
                        ),
                        const Text("Ghi nhớ tôi"),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Button Đăng nhập
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _submit,
                        child: isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : const Text(
                                "Đăng nhập",
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Link sang Đăng ký
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Bạn chưa có tài khoản? "),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SignupScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            "Đăng ký",
                            style: TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
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
      ),
    );
  }
}
