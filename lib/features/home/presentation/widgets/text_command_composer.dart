import 'package:flutter/material.dart';

class TextCommandComposer extends StatefulWidget {
  const TextCommandComposer({super.key});

  @override
  State<TextCommandComposer> createState() => _TextCommandComposerState();
}

class _TextCommandComposerState extends State<TextCommandComposer> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('입력한 명령: $text')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          minLines: 2,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: '메시지 입력을 통해서도 명령을 내릴 수 있습니다',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('텍스트 명령 실행'),
        ),
      ],
    );
  }
}
