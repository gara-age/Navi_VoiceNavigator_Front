import 'package:flutter/material.dart';

import '../demo/demo_home_page.dart';
import '../features/home/presentation/home_page.dart';
import '../shared/models/settings_models.dart';
import '../shared/services/local_settings_store.dart';
import 'theme/colors.dart';

class ModeLauncherPage extends StatelessWidget {
  const ModeLauncherPage({super.key});

  void _openRealMode(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const HomePage(),
      ),
    );
  }

  void _openDemoMode(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DemoHomePage(
          initialSettings: AppSettings.defaults(),
          onSettingsChanged: (_) {},
          onSettingsSaved: (settings) {
            LocalSettingsStore.instance.save(settings);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.border),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 24,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.mic_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Navi: Voice Navigator',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '실행할 모드를 선택하세요.',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: _ModeLaunchCard(
                            title: '실제 모드',
                            subtitle: '실제 홈 화면과 연결되는 기본 앱 흐름입니다.',
                            badge: '서비스',
                            hint: 'UI 연결',
                            icon: Icons.link_rounded,
                            accentColor: AppColors.accent,
                            background: AppColors.accentSoft,
                            onTap: () => _openRealMode(context),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _ModeLaunchCard(
                            title: '데모 모드',
                            subtitle: '백엔드 없이 시나리오 화면 흐름을 확인하는 모드입니다.',
                            badge: '오프라인',
                            hint: '데모',
                            icon: Icons.play_circle_outline_rounded,
                            accentColor: AppColors.warning,
                            background: AppColors.warningSoft,
                            onTap: () => _openDemoMode(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '2일차 목표는 실제 모드와 데모 모드 진입점을 만드는 것입니다.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
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

class _ModeLaunchCard extends StatelessWidget {
  const _ModeLaunchCard({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.hint,
    required this.icon,
    required this.accentColor,
    required this.background,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String badge;
  final String hint;
  final IconData icon;
  final Color accentColor;
  final Color background;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badge,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: accentColor,
                size: 28,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textMuted,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Text(
                  hint,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: accentColor,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
