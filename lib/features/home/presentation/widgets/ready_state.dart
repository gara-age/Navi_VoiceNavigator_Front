import 'package:flutter/material.dart';

import 'text_command_composer.dart';

class ReadyState extends StatelessWidget {
  const ReadyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: const Icon(
                  Icons.mic_none_rounded,
                  size: 48,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Navi: Voice Navigator',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                '준비 완료. 왼쪽의 기능을 선택하여 시작하세요.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              const TextCommandComposer(),
            ],
          ),
        ),
      ),
    );
  }
}
