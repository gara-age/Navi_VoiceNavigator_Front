import 'package:flutter/material.dart';

import '../features/home/presentation/widgets/action_panel.dart';
import '../features/notifications/presentation/app_toast.dart';
import '../features/home/presentation/widgets/ready_state.dart';
import '../features/home/presentation/widgets/status_card.dart';
import '../features/home/presentation/widgets/title_bar.dart';

class DemoHomePage extends StatefulWidget {
  const DemoHomePage({super.key});

  @override
  State<DemoHomePage> createState() => _DemoHomePageState();
}

class _DemoHomePageState extends State<DemoHomePage> {
  String _micStatus = '대기';
  bool _isRecording = false;
  bool _isBusy = false;
  String? _summary;
  String? _followUp;

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

    setState(() {
      _isBusy = false;
      _micStatus = '대기';
      _summary = '유튜브 검색 결과를 준비했습니다.';
      _followUp = '첫 번째 결과를 재생할까요?';
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

    setState(() {
      _isBusy = false;
      _micStatus = '대기';
      _summary = '텍스트 명령 "$text" 처리 결과입니다.';
      _followUp = '이어서 다음 작업도 진행할까요?';
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
                      value: _micStatus,
                      icon: Icons.mic_none_rounded,
                    ),
                  ),
                  const VerticalDivider(width: 1, thickness: 1),
                  const Expanded(
                    child: StatusCard(
                      label: '현재 모드',
                      value: '데모 모드',
                      icon: Icons.play_circle_outline_rounded,
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
                      isRecording: _isRecording,
                      onListenPressed: _simulateListen,
                      onScreenReadPressed: _simulateScreenRead,
                      onSettingsPressed: () {},
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
      ),
    );
  }
}
