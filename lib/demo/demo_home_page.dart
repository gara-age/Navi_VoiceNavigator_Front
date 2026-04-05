import 'package:flutter/material.dart';

class DemoHomePage extends StatelessWidget {
  const DemoHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('데모 모드'),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '데모 모드 화면입니다.\n3일차부터 이 화면에 데모 시나리오 UI를 붙입니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              height: 1.6,
            ),
          ),
        ),
      ),
    );
  }
}
