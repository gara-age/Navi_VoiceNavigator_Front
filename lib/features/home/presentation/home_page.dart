import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/colors.dart';
import '../../../../shared/models/response_models.dart';
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
  bool _showSettings = false;

  void _handleToggleMode(bool secureEnabled) {
    final notifier = ref.read(settingsControllerProvider.notifier);
    notifier.setSecureMode(secureEnabled);
  }

  void _showCommandResultToast(CommandResponseModel response) {
    showAppToast(
      context,
      response.isError ? response.summary : '결과를 읽어드립니다.',
      title: response.isError ? '작업 실패' : '작업 완료',
      state: response.isError ? AppToastState.info : AppToastState.success,
    );
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
          '음성을 듣고 있습니다. 말씀해주세요.',
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
        '작업을 처리하고 있습니다.',
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
        '화면을 읽어드리고 있습니다.',
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

    listeningNotifier.setProcessing();
    if (mounted) {
      showAppToast(
        context,
        '텍스트 명령을 처리하고 있습니다.',
        title: '작업 처리 중',
        state: AppToastState.processing,
      );
    }
    final response = await sessionNotifier.submitTextCommand(text);
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

  @override
  Widget build(BuildContext context) {
    final listeningState = ref.watch(listeningControllerProvider);
    final sessionState = ref.watch(sessionControllerProvider);
    final settings = ref.watch(settingsControllerProvider);
    final surfaceTheme = Theme.of(context).extension<AppSurfaceTheme>()!;

    return Scaffold(
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
                              listeningState.status == ListeningStatus.listening
                              ? AppColors.successSoft
                              : surfaceTheme.contentBackground,
                          iconColor:
                              listeningState.status == ListeningStatus.listening
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
                  onTap: () => setState(() => _showSettings = false),
                  child: Container(
                    color: const Color(0x66000000),
                  ),
                ),
              ),
              Positioned.fill(
                child: SettingsModal(
                  onClose: () {
                    setState(() => _showSettings = false);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
