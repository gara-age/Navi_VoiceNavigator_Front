import 'package:flutter/material.dart';

import 'text_command_composer.dart';

class ReadyState extends StatelessWidget {
  const ReadyState({
    super.key,
    required this.summary,
    required this.followUp,
    required this.isBusy,
    required this.onSubmitText,
  });

  final String? summary;
  final String? followUp;
  final bool isBusy;
  final ValueChanged<String> onSubmitText;

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
                child: Icon(
                  isBusy ? Icons.hourglass_top_rounded : Icons.mic_none_rounded,
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
              Text(
                isBusy
                    ? '명령을 처리하고 있습니다. 잠시만 기다려 주세요.'
                    : '준비 완료. 왼쪽의 기능을 선택하여 시작하세요.',
                textAlign: TextAlign.center,
              ),
              if (summary != null) ...[
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('결과 요약', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 6),
                      Text(summary!),
                      if (followUp != null) ...[
                        const SizedBox(height: 10),
                        Text(followUp!, style: const TextStyle(color: Colors.grey)),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),
              TextCommandComposer(
                isBusy: isBusy,
                onSubmit: onSubmitText,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
