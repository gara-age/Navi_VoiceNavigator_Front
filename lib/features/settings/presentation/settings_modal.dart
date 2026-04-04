import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/settings_controller.dart';

class SettingsModal extends ConsumerWidget {
  const SettingsModal({
    super.key,
    required this.onClose,
  });

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final notifier = ref.read(settingsControllerProvider.notifier);

    return Center(
      child: Container(
        width: 720,
        height: 560,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '설정',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SwitchListTile(
              title: const Text('보안 입력 모드'),
              value: settings.security.secureInputMode,
              onChanged: notifier.setSecureMode,
            ),
            SwitchListTile(
              title: const Text('다크 테마'),
              value: settings.display.darkTheme,
              onChanged: notifier.setDarkTheme,
            ),
            SwitchListTile(
              title: const Text('큰 글씨'),
              value: settings.display.largeText,
              onChanged: notifier.setLargeText,
            ),
            const SizedBox(height: 20),
            TextField(
              controller: TextEditingController(
                text: settings.shortcuts.listenToggle,
              ),
              decoration: const InputDecoration(
                labelText: '음성 듣기 단축키',
                border: OutlineInputBorder(),
              ),
              onChanged: notifier.setListenToggleShortcut,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: TextEditingController(
                text: settings.shortcuts.screenRead,
              ),
              decoration: const InputDecoration(
                labelText: '화면 읽기 단축키',
                border: OutlineInputBorder(),
              ),
              onChanged: notifier.setScreenReadShortcut,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: TextEditingController(
                text: settings.shortcuts.openSettings,
              ),
              decoration: const InputDecoration(
                labelText: '설정 열기 단축키',
                border: OutlineInputBorder(),
              ),
              onChanged: notifier.setOpenSettingsShortcut,
            ),
            const Spacer(),
            Row(
              children: [
                const Spacer(),
                OutlinedButton(
                  onPressed: onClose,
                  child: const Text('닫기'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () async {
                    await notifier.save();
                    if (context.mounted) {
                      onClose();
                    }
                  },
                  child: const Text('저장'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
