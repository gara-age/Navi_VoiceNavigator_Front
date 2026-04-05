import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

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
    final surfaceTheme = Theme.of(context).extension<AppSurfaceTheme>()!;

    return Container(
      color: surfaceTheme.surface,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            '주요 기능',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: surfaceTheme.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          // Text(
          //   '실행할 기능을 선택하면 오른쪽 패널에 결과가 정리됩니다.',
          //   style: TextStyle(
          //     fontSize: 13,
          //     height: 1.5,
          //     color: surfaceTheme.textMuted,
          //   ),
          // ),
          const SizedBox(height: 18),
          _ActionButton(
            icon: Icons.mic_rounded,
            title: isRecording ? '듣는 중' : '음성 듣기',
            description: '음성 명령 인식을 시작하고 중지합니다.',
            onPressed: onListenPressed,
            accentColor: surfaceTheme.accent,
            surfaceTheme: surfaceTheme,
          ),
          const SizedBox(height: 10),
          _ActionButton(
            icon: Icons.visibility_rounded,
            title: '현재 화면 읽기',
            description: '현재 화면의 구조와 내용을 요약합니다.',
            onPressed: onScreenReadPressed,
            accentColor: surfaceTheme.accent,
            surfaceTheme: surfaceTheme,
          ),
          const SizedBox(height: 10),
          _ActionButton(
            icon: Icons.settings_rounded,
            title: '설정',
            description: '단축키, 보안, 화면 설정을 조정합니다.',
            onPressed: onSettingsPressed,
            accentColor: surfaceTheme.accent,
            surfaceTheme: surfaceTheme,
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
    required this.accentColor,
    required this.surfaceTheme,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onPressed;
  final Color accentColor;
  final AppSurfaceTheme surfaceTheme;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.all(16),
        side: BorderSide(color: surfaceTheme.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: surfaceTheme.contentBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: accentColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: surfaceTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: surfaceTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
