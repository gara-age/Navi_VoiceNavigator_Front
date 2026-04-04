import 'package:flutter/material.dart';

import '../features/home/presentation/home_page.dart';

class ModeLauncherPage extends StatelessWidget {
  const ModeLauncherPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Navi: Voice Navigator',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text('개발용으로 확인할 모드를 선택'),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const HomePage(),
                        ),
                      );
                    },
                    child: const Text('실제 모드로 이동'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
