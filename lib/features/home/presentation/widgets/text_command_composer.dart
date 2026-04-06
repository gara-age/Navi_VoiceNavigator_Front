import 'package:flutter/material.dart';

class TextCommandComposer extends StatefulWidget {
  const TextCommandComposer({
    super.key,
    required this.onSubmit,
    required this.isBusy,
  });

  final ValueChanged<String> onSubmit;
  final bool isBusy;

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
    if (text.isEmpty || widget.isBusy) return;
    widget.onSubmit(text);
    _controller.clear();
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
          onSubmitted: (_) => _submit(),
          decoration: const InputDecoration(
            hintText: '예: 유튜브에서 고양이 영상 찾아줘',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: widget.isBusy ? null : _submit,
          child: Text(widget.isBusy ? '요청 준비 중...' : '텍스트 명령 실행'),
        ),
      ],
    );
  }
}
