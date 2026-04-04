import 'package:flutter/material.dart';

class ActionPanel extends StatelessWidget {
  const ActionPanel({
    super.key,
    required this.isRecording,
    required this.onListenPressed,
    required this.onScreenReadPressed,
    required this.onSettingsPressed,
  });

  final bool isRecording;
  final VoidCallback onListenPressed;
  final VoidCallback onScreenReadPressed;
  final VoidCallback onSettingsPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          right: BorderSide(color: Color(0xFFE5E7EB)),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('주요 기능', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 12),
          _ActionButton(
            icon: Icons.mic_rounded,
            title: isRecording ? '듣는 중' : '음성 듣기',
            description: '음성 명령 인식을 시작합니다.',
            onPressed: onListenPressed,
          ),
          const SizedBox(height: 8),
          _ActionButton(
            icon: Icons.visibility_rounded,
            title: '현재 화면 읽기',
            description: '현재 화면 요약과 읽기를 시작합니다.',
            onPressed: onScreenReadPressed,
          ),
          const SizedBox(height: 8),
          _ActionButton(
            icon: Icons.settings_rounded,
            title: '설정',
            description: '기본 설정, 단축키, 보안, 화면 모드',
            onPressed: onSettingsPressed,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.title,
    required this.description,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(description, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
