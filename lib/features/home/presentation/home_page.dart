import 'package:flutter/material.dart';

import 'widgets/action_panel.dart';
import 'widgets/ready_state.dart';
import 'widgets/status_card.dart';
import 'widgets/title_bar.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

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
              child: const Row(
                children: [
                  Expanded(
                    child: StatusCard(
                      label: '마이크 상태',
                      value: '대기',
                      icon: Icons.mic_none_rounded,
                    ),
                  ),
                  VerticalDivider(width: 1, thickness: 1),
                  Expanded(
                    child: StatusCard(
                      label: '현재 모드',
                      value: '일반 모드',
                      icon: Icons.volume_up_outlined,
                    ),
                  ),
                ],
              ),
            ),
            const Expanded(
              child: Row(
                children: [
                  SizedBox(
                    width: 260,
                    child: ActionPanel(),
                  ),
                  Expanded(
                    child: ReadyState(),
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
