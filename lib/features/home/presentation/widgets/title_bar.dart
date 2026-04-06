import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import 'title_bar_macos.dart';

class AppTitleBar extends StatelessWidget {
  const AppTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    if (Platform.isMacOS) {
      return const AppTitleBarMacos();
    }

    final surfaceTheme = Theme.of(context).extension<AppSurfaceTheme>()!;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: surfaceTheme.surface,
        border: Border(
          bottom: BorderSide(color: surfaceTheme.border),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: surfaceTheme.accent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.mic_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Navi: Voice Navigator',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: surfaceTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'AI Voice Assistant for Accessibility',
                  style: TextStyle(
                    fontSize: 11,
                    color: surfaceTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          _TitleIconButton(
            icon: Icons.remove_rounded,
            color: surfaceTheme.textMuted,
          ),
          const SizedBox(width: 6),
          _TitleIconButton(
            icon: Icons.crop_square_rounded,
            color: surfaceTheme.textMuted,
          ),
          const SizedBox(width: 6),
          _TitleIconButton(
            icon: Icons.close_rounded,
            color: surfaceTheme.textMuted,
          ),
        ],
      ),
    );
  }
}

class _TitleIconButton extends StatelessWidget {
  const _TitleIconButton({
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        icon,
        size: 18,
        color: color,
      ),
    );
  }
}
