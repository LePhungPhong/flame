import 'package:flutter/material.dart';
import '../services/authService/auth.service.dart';
import 'login.screen.dart';
import 'package:flame/widgets/flameLogo.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController passwordCtrl = TextEditingController();
  final TextEditingController confirmCtrl = TextEditingController();

  bool isLoading = false;
  bool showPassword = false;
  bool showConfirmPassword = false;
  bool agreePolicy = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!agreePolicy) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng đồng ý với chính sách bảo mật")),
      );
      return;
    }

    setState(() => isLoading = true);

    final res = await AuthService.register(
      email: emailCtrl.text.trim(),
      password: passwordCtrl.text,
    );

    if (!mounted) return;
    setState(() => isLoading = false);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(res.message)));

    if (res.ok) {
      // Sau khi đăng ký thành công -> quay về login
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
    }
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
                      "Đăng ký",
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

                    // Password
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
                        if (value.length < 8) {
                          return "Mật khẩu tối thiểu 8 ký tự";
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Confirm password
                    const Text(
                      "Xác nhận mật khẩu",
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: confirmCtrl,
                      obscureText: !showConfirmPassword,
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
                            showConfirmPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () {
                            setState(
                              () => showConfirmPassword = !showConfirmPassword,
                            );
                          },
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return "Vui lòng nhập lại mật khẩu";
                        }
                        if (value != passwordCtrl.text) {
                          return "Mật khẩu xác nhận không khớp";
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Đồng ý chính sách
                    Row(
                      children: [
                        Checkbox(
                          value: agreePolicy,
                          onChanged: (v) =>
                              setState(() => agreePolicy = v ?? false),
                        ),
                        const Expanded(
                          child: Text("Tôi đồng ý với chính sách bảo mật"),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Button Đăng ký
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
                                "Đăng ký",
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Link sang Đăng nhập
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Đã có tài khoản? "),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const LoginScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            "Đăng nhập",
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
