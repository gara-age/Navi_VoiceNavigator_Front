import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/theme/app_theme.dart';
import '../app/theme/colors.dart';
import 'demo_settings_modal.dart';
import '../features/home/presentation/widgets/action_panel.dart';
import '../features/home/presentation/widgets/ready_state.dart';
import '../features/home/presentation/widgets/status_card.dart';
import '../features/home/presentation/widgets/title_bar.dart';
import '../features/notifications/presentation/app_toast.dart';
import '../shared/models/settings_models.dart';
import '../shared/utils/shortcut_utils.dart';

enum DemoScenario {
  youtube,
  naverMap,
  secureInput,
  general,
}

class _DemoResult {
  const _DemoResult({
    required this.summary,
    required this.followUp,
  });

  final String summary;
  final String followUp;
}

class DemoHomePage extends StatefulWidget {
  const DemoHomePage({
    super.key,
    required this.initialSettings,
    required this.onSettingsChanged,
    required this.onSettingsSaved,
  });

  final AppSettings initialSettings;
  final ValueChanged<AppSettings> onSettingsChanged;
  final ValueChanged<AppSettings> onSettingsSaved;

  @override
  State<DemoHomePage> createState() => _DemoHomePageState();
}

class _DemoHomePageState extends State<DemoHomePage> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'demo_home_focus');

  late AppSettings _settings;
  String _micStatus = '대기';
  bool _isRecording = false;
  bool _isBusy = false;
  bool _showSettingsModal = false;
  String? _summary;
  String? _followUp;

  @override
  void initState() {
    super.initState();
    _settings = widget.initialSettings;

    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _focusNode.dispose();
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (ModalRoute.of(context)?.isCurrent != true || event is! KeyDownEvent) {
      return false;
    }

    if (_showSettingsModal) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _closeSettings();
        return true;
      }
      return false;
    }

    if (!_settings.shortcuts.enabled) {
      return false;
    }

    if (ShortcutUtils.matches(event, _settings.shortcuts.listenToggle)) {
      _simulateListen();
      return true;
    }

    if (ShortcutUtils.matches(event, _settings.shortcuts.screenRead)) {
      _simulateScreenRead();
      return true;
    }

    if (ShortcutUtils.matches(event, _settings.shortcuts.openSettings)) {
      _openSettings();
      return true;
    }

    return false;
  }

  void _openSettings() {
    if (_showSettingsModal) {
      return;
    }
    setState(() => _showSettingsModal = true);
  }

  void _closeSettings() {
    if (!_showSettingsModal) {
      return;
    }
    setState(() => _showSettingsModal = false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  void _handleToggleMode(bool secureEnabled) {
    setState(() {
      _settings = _settings.copyWith(
        security: _settings.security.copyWith(
          secureInputMode: secureEnabled,
        ),
      );
    });
  }

  _DemoResult _scenarioResult(DemoScenario scenario) {
    switch (scenario) {
      case DemoScenario.youtube:
        return const _DemoResult(
          summary:
              '유튜브 검색 결과를 준비했습니다. 요청한 키워드와 관련된 상위 영상을 읽어드릴 수 있습니다.',
          followUp: '첫 번째 영상을 재생할까요?',
        );
      case DemoScenario.naverMap:
        return const _DemoResult(
          summary:
              '네이버 지도 검색 결과를 준비했습니다. 현재 위치 기준으로 가장 관련성이 높은 장소를 찾았습니다.',
          followUp: '길찾기 안내를 시작할까요?',
        );
      case DemoScenario.secureInput:
        return const _DemoResult(
          summary:
              '보안 입력 화면으로 판단했습니다. 민감한 입력을 보호하기 위해 읽기와 자동 입력이 제한됩니다.',
          followUp: '보안 입력 모드를 유지한 채 계속 진행할까요?',
        );
      case DemoScenario.general:
        return const _DemoResult(
          summary: '명령을 처리했습니다. 현재 데모 환경에서는 요약된 결과만 표시합니다.',
          followUp: '이어서 다음 작업도 진행할까요?',
        );
    }
  }

  _DemoResult _buildDemoResponse(String text) {
    final normalized = text.trim().toLowerCase();

    if (normalized.contains('유튜브') ||
        normalized.contains('youtube') ||
        normalized.contains('영상') ||
        normalized.contains('동영상')) {
      return _scenarioResult(DemoScenario.youtube);
    }

    if (normalized.contains('지도') ||
        normalized.contains('map') ||
        normalized.contains('길찾기') ||
        normalized.contains('네이버')) {
      return _scenarioResult(DemoScenario.naverMap);
    }

    if (normalized.contains('비밀번호') ||
        normalized.contains('password') ||
        normalized.contains('로그인') ||
        normalized.contains('보안')) {
      return _scenarioResult(DemoScenario.secureInput);
    }

    return _scenarioResult(DemoScenario.general);
  }

  Future<void> _simulateListen() async {
    if (_isBusy) {
      return;
    }

    setState(() {
      _isBusy = true;
      _isRecording = true;
      _micStatus = '듣는 중';
      _summary = '음성을 듣고 있습니다. 잠시 후 자동으로 처리 단계로 넘어갑니다.';
      _followUp = null;
    });
    showAppToast(
      context,
      '음성을 듣고 있습니다. 말씀해주세요.',
      title: '음성 수신 중',
      state: AppToastState.listening,
    );

    await Future<void>.delayed(const Duration(milliseconds: 1200));

    if (!mounted) {
      return;
    }

    setState(() {
      _micStatus = '처리중';
      _isRecording = false;
      _summary = '명령을 분석하고 실행 계획을 준비하고 있습니다.';
    });
    showAppToast(
      context,
      '작업을 처리하고 있습니다.',
      title: '작업 처리 중',
      state: AppToastState.processing,
    );

    await Future<void>.delayed(const Duration(milliseconds: 1500));

    if (!mounted) {
      return;
    }

    final result = _scenarioResult(DemoScenario.youtube);

    setState(() {
      _isBusy = false;
      _micStatus = '대기';
      _summary = result.summary;
      _followUp = result.followUp;
    });
    showAppToast(
      context,
      '결과를 읽어드립니다.',
      title: '작업 완료',
      state: AppToastState.success,
    );
  }

  Future<void> _simulateScreenRead() async {
    if (_isBusy) {
      return;
    }

    setState(() {
      _isBusy = true;
      _micStatus = '처리중';
      _summary = '화면을 읽어드리고 있습니다.';
      _followUp = null;
    });
    showAppToast(
      context,
      '화면을 읽어드리고 있습니다.',
      title: '작업 처리 중',
      state: AppToastState.processing,
    );

    await Future<void>.delayed(const Duration(milliseconds: 1300));

    if (!mounted) {
      return;
    }

    setState(() {
      _isBusy = false;
      _micStatus = '대기';
      _summary =
          '현재 화면은 Navi: Voice Navigator 데모 화면입니다. 왼쪽에는 주요 기능 버튼이 있고 가운데에는 준비 상태와 결과 요약이 표시됩니다.';
      _followUp = '다른 화면도 읽어드릴까요?';
    });
    showAppToast(
      context,
      '화면을 읽어드렸습니다.',
      title: '작업 완료',
      state: AppToastState.success,
    );
  }

  Future<void> _handleTextCommand(String text) async {
    if (_isBusy) {
      return;
    }

    setState(() {
      _isBusy = true;
      _micStatus = '처리중';
      _summary = '텍스트 명령을 처리하고 있습니다.';
      _followUp = null;
    });
    showAppToast(
      context,
      '텍스트 명령을 처리하고 있습니다.',
      title: '작업 처리 중',
      state: AppToastState.processing,
    );

    await Future<void>.delayed(const Duration(milliseconds: 1200));

    if (!mounted) {
      return;
    }

    final result = _buildDemoResponse(text);

    setState(() {
      _isBusy = false;
      _micStatus = '대기';
      _summary = result.summary;
      _followUp = result.followUp;
    });
    showAppToast(
      context,
      '텍스트 명령 처리가 완료되었습니다.',
      title: '작업 완료',
      state: AppToastState.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final surfaceTheme = Theme.of(context).extension<AppSurfaceTheme>()!;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      child: Scaffold(
        backgroundColor: surfaceTheme.shellBackground,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  const AppTitleBar(),
                  Container(
                    height: 88,
                    decoration: BoxDecoration(
                      color: surfaceTheme.surface,
                      border: Border(
                        bottom: BorderSide(color: surfaceTheme.border),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: StatusCard(
                            label: '마이크 상태',
                            value: _micStatus,
                            icon: Icons.mic_none_rounded,
                            iconBackground: _micStatus == '듣는 중'
                                ? AppColors.successSoft
                                : surfaceTheme.contentBackground,
                            iconColor: _micStatus == '듣는 중'
                                ? AppColors.success
                                : surfaceTheme.textMuted,
                            showWave: true,
                          ),
                        ),
                        VerticalDivider(
                          width: 1,
                          thickness: 1,
                          color: surfaceTheme.border,
                        ),
                        Expanded(
                          child: StatusCard(
                            label: '현재 모드',
                            value: '데모 모드',
                            icon: Icons.play_circle_outline_rounded,
                            iconBackground: surfaceTheme.contentBackground,
                            iconColor: surfaceTheme.accent,
                            showDot: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        SizedBox(
                          width: 260,
                          child: ActionPanel(
                            secureModeEnabled: _settings.security.secureInputMode,
                            isRecording: _isRecording,
                            listenShortcut: _settings.shortcuts.listenToggle,
                            screenReadShortcut: _settings.shortcuts.screenRead,
                            settingsShortcut: _settings.shortcuts.openSettings,
                            onListenPressed: _simulateListen,
                            onScreenReadPressed: _simulateScreenRead,
                            onSettingsPressed: _openSettings,
                            onToggleMode: _handleToggleMode,
                          ),
                        ),
                        Expanded(
                          child: ReadyState(
                            summary: _summary,
                            followUp: _followUp,
                            isBusy: _isBusy,
                            onSubmitText: _handleTextCommand,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_showSettingsModal) ...[
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _closeSettings,
                    child: Container(
                      color: const Color(0x66000000),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DemoSettingsModal(
                    initialSettings: _settings,
                    onClose: _closeSettings,
                    onSaved: (next) {
                      setState(() {
                        _settings = next;
                        _showSettingsModal = false;
                      });
                      widget.onSettingsSaved(next);
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
