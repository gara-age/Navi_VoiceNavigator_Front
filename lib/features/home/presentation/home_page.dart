import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/colors.dart';
import '../../../../shared/models/response_models.dart';
import '../../../../shared/services/local_background_event_service.dart';
import '../../../../shared/utils/shortcut_utils.dart';
import '../../listening/application/listening_controller.dart';
import '../../notifications/presentation/app_toast.dart';
import '../../session/application/session_controller.dart';
import '../../settings/application/settings_controller.dart';
import '../../settings/presentation/settings_modal.dart';
import 'widgets/action_panel.dart';
import 'widgets/ready_state.dart';
import 'widgets/status_card.dart';
import 'widgets/title_bar.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'home_page_focus');
  bool _showSettings = false;
  Timer? _backgroundEventTimer;
  bool _handlingBackgroundEvent = false;
  String? _lastHandledEventId;
  int _lastHandledEventAtMs = 0;

  @override
  void initState() {
    super.initState();
    _backgroundEventTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _pollBackgroundEvent(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _backgroundEventTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleToggleMode(bool secureEnabled) {
    final notifier = ref.read(settingsControllerProvider.notifier);
    notifier.setSecureMode(secureEnabled);
  }

  void _showCommandResultToast(CommandResponseModel response) {
    switch (response.status) {
      case CommandResponseStatus.success:
        showAppToast(
          context,
          response.followUp ?? '결과를 준비했습니다. 이어서 다음 작업도 안내할 수 있습니다.',
          title: '작업 완료',
          state: AppToastState.success,
        );
        break;
      case CommandResponseStatus.warning:
        showAppToast(
          context,
          response.summary,
          title: '확인 필요',
          state: AppToastState.warning,
        );
        break;
      case CommandResponseStatus.error:
        showAppToast(
          context,
          response.summary,
          title: '작업 실패',
          state: AppToastState.error,
        );
        break;
    }
  }

  Future<void> _handleListen() async {
    final session = ref.read(sessionControllerProvider);
    final sessionNotifier = ref.read(sessionControllerProvider.notifier);
    final listeningNotifier = ref.read(listeningControllerProvider.notifier);

    if (!session.isRecording) {
      listeningNotifier.startListening();
      await sessionNotifier.startListening();
      if (mounted) {
        showAppToast(
          context,
          '음성을 듣고 있습니다. 요청을 받는 중입니다.',
          title: '음성 수신 중',
          state: AppToastState.listening,
        );
      }
      return;
    }

    listeningNotifier.setProcessing();
    if (mounted) {
      showAppToast(
        context,
        '요청을 분석하고 다음 작업을 준비하고 있습니다.',
        title: '작업 처리 중',
        state: AppToastState.processing,
      );
    }
    final response = await sessionNotifier.stopListeningAndProcess();
    listeningNotifier.reset();
    if (mounted) {
      _showCommandResultToast(response);
    }
  }

  Future<void> _handleScreenRead() async {
    final listeningNotifier = ref.read(listeningControllerProvider.notifier);
    final sessionNotifier = ref.read(sessionControllerProvider.notifier);

    listeningNotifier.setProcessing();
    if (mounted) {
      showAppToast(
        context,
        '현재 화면을 읽고 핵심 내용을 정리하고 있습니다.',
        title: '작업 처리 중',
        state: AppToastState.processing,
      );
    }
    final response = await sessionNotifier.triggerScreenRead();
    listeningNotifier.reset();
    if (mounted) {
      _showCommandResultToast(response);
    }
  }

  Future<void> _handleSubmitText(String text) async {
    final listeningNotifier = ref.read(listeningControllerProvider.notifier);
    final sessionNotifier = ref.read(sessionControllerProvider.notifier);
    final normalizedText = ShortcutUtils.normalizeCommandText(text);

    listeningNotifier.setProcessing();
    if (mounted) {
      showAppToast(
        context,
        '요청을 분석하고 다음 작업을 준비하고 있습니다.',
        title: '작업 처리 중',
        state: AppToastState.processing,
      );
    }
    final response = _shouldTreatAsFollowUp(normalizedText)
        ? await sessionNotifier.submitFollowUpResponse(normalizedText)
        : await sessionNotifier.submitTextCommand(normalizedText);
    listeningNotifier.reset();
    if (mounted) {
      _showCommandResultToast(response);
    }
  }

  String _micLabel(ListeningState state) {
    switch (state.status) {
      case ListeningStatus.idle:
        return '대기';
      case ListeningStatus.listening:
        return '듣는 중';
      case ListeningStatus.processing:
        return '처리중';
    }
  }

  void _closeSettingsModal() {
    if (!_showSettings) {
      return;
    }

    setState(() => _showSettings = false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  bool _shouldTreatAsFollowUp(String text) {
    final sessionNotifier = ref.read(sessionControllerProvider.notifier);
    if (!sessionNotifier.hasPendingFollowUp()) {
      return false;
    }

    return ShortcutUtils.isAffirmativeResponse(text);
  }

  bool _canHandleBackgroundEvent(BackgroundEvent event) {
    final now = DateTime.now().millisecondsSinceEpoch;

    if (_lastHandledEventId == event.id) {
      return false;
    }

    if (now - _lastHandledEventAtMs < 350) {
      return false;
    }

    final sessionState = ref.read(sessionControllerProvider);

    switch (event.type) {
      case 'START_LISTENING':
        return !sessionState.isBusy && !_showSettings;
      case 'START_SCREEN_READ':
        return !sessionState.isBusy && !_showSettings;
      case 'OPEN_SETTINGS':
        return !_showSettings;
      default:
        return false;
    }
  }

  void _markBackgroundEventHandled(BackgroundEvent event) {
    _lastHandledEventId = event.id;
    _lastHandledEventAtMs = DateTime.now().millisecondsSinceEpoch;
  }

  Future<void> _pollBackgroundEvent() async {
    if (!mounted || _handlingBackgroundEvent) {
      return;
    }

    _handlingBackgroundEvent = true;
    try {
      final event = await LocalBackgroundEventService.instance.pollEvent();
      if (!mounted || event == null) {
        return;
      }

      if (!_canHandleBackgroundEvent(event)) {
        return;
      }

      switch (event.type) {
        case 'START_LISTENING':
          _markBackgroundEventHandled(event);
          await _handleListen();
          break;
        case 'START_SCREEN_READ':
          _markBackgroundEventHandled(event);
          await _handleScreenRead();
          break;
        case 'OPEN_SETTINGS':
          _markBackgroundEventHandled(event);
          if (!_showSettings) {
            setState(() => _showSettings = true);
          }
          break;
      }
    } finally {
      _handlingBackgroundEvent = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final listeningState = ref.watch(listeningControllerProvider);
    final sessionState = ref.watch(sessionControllerProvider);
    final settings = ref.watch(settingsControllerProvider);
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
                    height: 92,
                    color: surfaceTheme.surface,
                    child: Row(
                      children: [
                        Expanded(
                          child: StatusCard(
                            label: '마이크 상태',
                            value: _micLabel(listeningState),
                            icon: Icons.mic_none_rounded,
                            iconBackground:
                                listeningState.status ==
                                    ListeningStatus.listening
                                ? AppColors.successSoft
                                : surfaceTheme.contentBackground,
                            iconColor:
                                listeningState.status ==
                                    ListeningStatus.listening
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
                            value: settings.security.secureInputMode
                                ? '보안 입력 모드'
                                : '일반 모드',
                            icon: settings.security.secureInputMode
                                ? Icons.lock_outline_rounded
                                : Icons.volume_up_outlined,
                            iconBackground: settings.security.secureInputMode
                                ? AppColors.warningSoft
                                : surfaceTheme.contentBackground,
                            iconColor: settings.security.secureInputMode
                                ? AppColors.warning
                                : surfaceTheme.textMuted,
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
                          width: 290,
                          child: ActionPanel(
                            secureModeEnabled: settings.security.secureInputMode,
                            isRecording: sessionState.isRecording,
                            listenShortcut: settings.shortcuts.listenToggle,
                            screenReadShortcut: settings.shortcuts.screenRead,
                            settingsShortcut: settings.shortcuts.openSettings,
                            onListenPressed: _handleListen,
                            onScreenReadPressed: _handleScreenRead,
                            onSettingsPressed: () {
                              setState(() => _showSettings = true);
                            },
                            onToggleMode: _handleToggleMode,
                          ),
                        ),
                        Expanded(
                          child: ReadyState(
                            summary: sessionState.lastSummary,
                            followUp: sessionState.lastFollowUp,
                            isBusy: sessionState.isBusy,
                            onSubmitText: _handleSubmitText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_showSettings) ...[
                Positioned.fill(
                  child: GestureDetector(
                    onTap: _closeSettingsModal,
                    child: Container(
                      color: const Color(0x66000000),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: SettingsModal(
                    onClose: _closeSettingsModal,
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
