import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../listening/application/listening_controller.dart';
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

  Future<void> _handleListen() async {
    final session = ref.read(sessionControllerProvider);
    final sessionNotifier = ref.read(sessionControllerProvider.notifier);
    final listeningNotifier = ref.read(listeningControllerProvider.notifier);

    if (!session.isRecording) {
      listeningNotifier.startListening();
      await sessionNotifier.startListening();
      return;
    }

    listeningNotifier.setProcessing();
    await sessionNotifier.stopListeningAndProcess();
    listeningNotifier.reset();
  }

  Future<void> _handleScreenRead() async {
    final listeningNotifier = ref.read(listeningControllerProvider.notifier);
    final sessionNotifier = ref.read(sessionControllerProvider.notifier);

    listeningNotifier.setProcessing();
    await sessionNotifier.triggerScreenRead();
    listeningNotifier.reset();
  }

  Future<void> _handleSubmitText(String text) async {
    final listeningNotifier = ref.read(listeningControllerProvider.notifier);
    final sessionNotifier = ref.read(sessionControllerProvider.notifier);

    listeningNotifier.setProcessing();
    await sessionNotifier.submitTextCommand(text);
    listeningNotifier.reset();
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
                          isRecording: sessionState.isRecording,
                          onListenPressed: _handleListen,
                          onScreenReadPressed: _handleScreenRead,
                          onSettingsPressed: () {
                            setState(() => _showSettings = true);
                          },
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
