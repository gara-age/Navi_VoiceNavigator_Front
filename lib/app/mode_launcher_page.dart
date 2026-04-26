import 'package:flutter/material.dart';

import '../demo/demo_app.dart';
import '../features/home/presentation/home_page.dart';
import '../features/pattern_api_test/presentation/pattern_api_test_page.dart';
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
        builder: (_) => const VoiceNavigatorDemoApp(),
      ),
    );
  }

  void _openPatternApiTestMode(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const PatternApiTestPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
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
                      '실행할 모드를 선택해 주세요.',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Wrap(
                      spacing: 20,
                      runSpacing: 20,
                      children: [
                        SizedBox(
                          width: 340,
                          child: _ModeLaunchCard(
                            title: '실제 모드',
                            subtitle:
                                '기존 연결형 UI 화면에서 실제 명령 흐름을 테스트합니다.',
                            badge: '서비스',
                            hint: '기본 UI',
                            icon: Icons.link_rounded,
                            accentColor: AppColors.accent,
                            background: AppColors.accentSoft,
                            onTap: () => _openRealMode(context),
                          ),
                        ),
                        SizedBox(
                          width: 340,
                          child: _ModeLaunchCard(
                            title: '데모 모드',
                            subtitle:
                                '백엔드 없이 시나리오와 화면 흐름만 확인하는 모드입니다.',
                            badge: '오프라인',
                            hint: '데모',
                            icon: Icons.play_circle_outline_rounded,
                            accentColor: AppColors.warning,
                            background: AppColors.warningSoft,
                            onTap: () => _openDemoMode(context),
                          ),
                        ),
                        SizedBox(
                          width: 340,
                          child: _ModeLaunchCard(
                            title: 'Pattern API 테스트',
                            subtitle:
                                'endpoint, instruction, prompt를 직접 입력하고 API 응답으로 Pattern Task 실행까지 확인합니다.',
                            badge: 'API',
                            hint: '패턴 테스트',
                            icon: Icons.api_rounded,
                            accentColor: AppColors.success,
                            background: AppColors.successSoft,
                            onTap: () => _openPatternApiTestMode(context),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      '새 테스트 모드는 instruction/prompt 기반 API를 GUI에서 바로 확인하기 위한 전용 화면입니다.',
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
