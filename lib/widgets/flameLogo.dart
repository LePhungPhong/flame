// lib/widgets/flamee_logo.dart
import 'package:flutter/material.dart';

class FlameeLogo extends StatelessWidget {
  final double size;
  const FlameeLogo({super.key, this.size = 52});

  @override
  Widget build(BuildContext context) {
    return Image.asset('assets/images/logo.png', height: size);
  }
}
