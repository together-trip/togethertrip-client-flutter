import 'package:flutter/material.dart';

class MainPlaceholderScreen extends StatelessWidget {
  const MainPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Center(
          child: Text(
            '메인페이지 입니다.',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ),
      ),
    );
  }
}
