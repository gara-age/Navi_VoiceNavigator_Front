import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../listening/application/listening_controller.dart';
import '../../session/application/session_controller.dart';
import 'widgets/action_panel.dart';
import 'widgets/ready_state.dart';
import 'widgets/status_card.dart';
import 'widgets/title_bar.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  Future<void> _handleListen(WidgetRef ref) async {
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

  Future<void> _handleScreenRead(WidgetRef ref) async {
    final listeningNotifier = ref.read(listeningControllerProvider.notifier);
    final sessionNotifier = ref.read(sessionControllerProvider.notifier);

    listeningNotifier.setProcessing();
    await sessionNotifier.triggerScreenRead();
    listeningNotifier.reset();
  }

  Future<void> _handleSubmitText(WidgetRef ref, String text) async {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final listeningState = ref.watch(listeningControllerProvider);
    final sessionState = ref.watch(sessionControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const AppTitleBar(),
            Container(
              height: 88,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: StatusCard(
                      label: '마이크 상태',
                      value: _micLabel(listeningState),
                      icon: Icons.mic_none_rounded,
                    ),
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  const Expanded(
                    child: StatusCard(
                      label: '현재 모드',
                      value: '일반 모드',
                      icon: Icons.volume_up_outlined,
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
                      isRecording: sessionState.isRecording,
                      onListenPressed: () => _handleListen(ref),
                      onScreenReadPressed: () => _handleScreenRead(ref),
                      onSettingsPressed: () {},
                    ),
                  ),
                  Expanded(
                    child: ReadyState(
                      summary: sessionState.lastSummary,
                      followUp: sessionState.lastFollowUp,
                      isBusy: sessionState.isBusy,
                      onSubmitText: (text) => _handleSubmitText(ref, text),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
