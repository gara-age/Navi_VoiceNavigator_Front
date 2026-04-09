import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
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
    final surfaceTheme = Theme.of(context).extension<AppSurfaceTheme>()!;

    return Container(
      color: surfaceTheme.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxContentWidth = switch (constraints.maxWidth) {
            > 1200 => 780.0,
            > 980 => 700.0,
            > 760 => 620.0,
            _ => constraints.maxWidth,
          };

          return SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 64),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxContentWidth),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          color: surfaceTheme.contentBackground,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: surfaceTheme.border),
                        ),
                        child: Icon(
                          isBusy
                              ? Icons.hourglass_top_rounded
                              : Icons.mic_none_rounded,
                          size: 48,
                          color: isBusy
                              ? surfaceTheme.accent
                              : surfaceTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Navi: Voice Navigator',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: surfaceTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isBusy
                            ? '요청을 분석하고 다음 작업을 준비하고 있습니다. 잠시만 기다려 주세요.'
                            : '준비 완료. 음성 듣기, 화면 읽기, 텍스트 입력 중 원하는 방식으로 작업을 시작할 수 있습니다.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: surfaceTheme.textMuted,
                        ),
                      ),
                      if (summary != null) ...[
                        const SizedBox(height: 26),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: surfaceTheme.contentBackground,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: surfaceTheme.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '결과 요약',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: surfaceTheme.textMuted,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                summary!,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  height: 1.6,
                                  color: surfaceTheme.textPrimary,
                                ),
                              ),
                              if (followUp != null) ...[
                                const SizedBox(height: 14),
                                Text(
                                  '다음 제안',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: surfaceTheme.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: surfaceTheme.surface,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: surfaceTheme.border),
                                  ),
                                  child: Text(
                                    followUp!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.5,
                                      color: surfaceTheme.textMuted,
                                    ),
                                  ),
                                ),
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
            ),
          );
        },
      ),
    );
  }
}
