import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class PatternAutomationRunnerResult {
  const PatternAutomationRunnerResult({
    required this.success,
    required this.status,
    required this.summary,
    required this.raw,
    this.error,
  });

  final bool success;
  final String status;
  final String summary;
  final Map<String, dynamic> raw;
  final String? error;
}

class PatternAutomationRunnerService {
  PatternAutomationRunnerService._();

  static final PatternAutomationRunnerService instance =
      PatternAutomationRunnerService._();

  static const String _compiledProjectRoot = String.fromEnvironment(
    'VOICE_NAVIGATOR_PROJECT_ROOT',
  );

  Future<PatternAutomationRunnerResult> runTask({
    required String rawTask,
  }) async {
    final root = _resolveProjectRoot();
    if (root == null) {
      return const PatternAutomationRunnerResult(
        success: false,
        status: 'error',
        summary: 'Pattern automation project root was not found.',
        raw: {'reason': 'root_not_found'},
        error: 'root_not_found',
      );
    }

    late final Map<String, dynamic> decodedTask;
    try {
      final decoded = jsonDecode(rawTask);
      if (decoded is! Map<String, dynamic>) {
        return const PatternAutomationRunnerResult(
          success: false,
          status: 'error',
          summary: 'Pattern task JSON must be an object.',
          raw: {'reason': 'invalid_json'},
          error: 'invalid_json',
        );
      }
      decodedTask = decoded;
    } catch (_) {
      return const PatternAutomationRunnerResult(
        success: false,
        status: 'error',
        summary: 'Pattern task JSON is invalid.',
        raw: {'reason': 'invalid_json'},
        error: 'invalid_json',
      );
    }

    final invocation = await _prepareInvocation(decodedTask);
    final pythonCommand = _resolvePythonCommand(
      root,
      invocation.moduleName,
      invocation.moduleArguments,
    );
    if (pythonCommand == null) {
      return PatternAutomationRunnerResult(
        success: false,
        status: 'error',
        summary: 'Python executable for pattern automation was not found.',
        raw: {
          'reason': 'python_not_found',
          'module': invocation.moduleName,
        },
        error: 'python_not_found',
      );
    }

    try {
      debugPrint('Pattern automation root = ${root.path}');
      debugPrint('Pattern automation module = ${invocation.moduleName}');
      debugPrint(
        'Pattern automation executable = ${pythonCommand.executable}',
      );
      debugPrint(
        'Pattern automation arguments = ${pythonCommand.arguments}',
      );
      return await _runProcess(
        executable: pythonCommand.executable,
        arguments: pythonCommand.arguments,
        workingDirectory: root.path,
        environment: {
          ...Platform.environment,
          'VOICE_NAVIGATOR_ROOT': root.path,
          'PLAYWRIGHT_HEADLESS': 'false',
          'PYTHONUTF8': '1',
          'PYTHONIOENCODING': 'utf-8',
          'PYTHONHOME': '',
          'PYTHONPATH': '',
        },
      );
    } finally {
      await invocation.dispose();
    }
  }

  Future<PatternAutomationRunnerResult> _runProcess({
    required String executable,
    required List<String> arguments,
    required String workingDirectory,
    required Map<String, String> environment,
  }) async {
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      runInShell: true,
    );

    final stdoutBuffer = StringBuffer();
    final stderrBuffer = StringBuffer();
    final stdoutDone = Completer<void>();
    final stderrDone = Completer<void>();
    Map<String, dynamic>? resultPayload;

    Future<void> handleStdoutLine(String line) async {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        return;
      }
      stdoutBuffer.writeln(trimmed);

      try {
        final envelope = jsonDecode(trimmed) as Map<String, dynamic>;
        final kind = envelope['kind'] as String? ?? '';
        if (kind == 'progress') {
          final payload = Map<String, dynamic>.from(
            envelope['payload'] as Map? ?? const <String, dynamic>{},
          );
          debugPrint('Pattern automation progress = ${jsonEncode(payload)}');
          return;
        }
        if (kind != 'result') {
          return;
        }

        resultPayload = Map<String, dynamic>.from(
          envelope['payload'] as Map? ?? const <String, dynamic>{},
        );
        debugPrint('Pattern automation result = ${jsonEncode(resultPayload)}');
      } catch (_) {
        debugPrint('Pattern automation stdout line = $trimmed');
      }
    }

    final stdoutSub = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          handleStdoutLine,
          onDone: () {
            if (!stdoutDone.isCompleted) {
              stdoutDone.complete();
            }
          },
        );

    final stderrSub = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            final trimmed = line.trim();
            if (trimmed.isNotEmpty) {
              stderrBuffer.writeln(trimmed);
            }
          },
          onDone: () {
            if (!stderrDone.isCompleted) {
              stderrDone.complete();
            }
          },
        );

    final exitCode = await process.exitCode;
    await Future.wait<void>([
      stdoutDone.future.timeout(
        const Duration(milliseconds: 500),
        onTimeout: () {},
      ),
      stderrDone.future.timeout(
        const Duration(milliseconds: 500),
        onTimeout: () {},
      ),
    ]);

    await stdoutSub.cancel();
    await stderrSub.cancel();

    if (exitCode != 0) {
      final detail = stderrBuffer.isNotEmpty
          ? stderrBuffer.toString().trim()
          : stdoutBuffer.toString().trim();
      return PatternAutomationRunnerResult(
        success: false,
        status: 'error',
        summary: detail.isEmpty
            ? 'Pattern automation exited unexpectedly.'
            : 'Pattern automation exited unexpectedly. ${_firstMeaningfulLine(detail) ?? detail}',
        raw: {
          'exit_code': exitCode,
          'stdout': stdoutBuffer.toString(),
          'stderr': stderrBuffer.toString(),
        },
        error: detail.isEmpty ? 'process_exit_$exitCode' : detail,
      );
    }

    if (resultPayload == null) {
      return PatternAutomationRunnerResult(
        success: false,
        status: 'error',
        summary: 'Pattern automation did not return a result payload.',
        raw: {
          'stdout': stdoutBuffer.toString(),
          'stderr': stderrBuffer.toString(),
        },
        error: 'missing_result_payload',
      );
    }

    final isSuccess = resultPayload!['status'] == 'success';
    final summary = _resolveSummary(resultPayload!);
    final reason = (resultPayload!['reason'] as String?)?.trim();

    return PatternAutomationRunnerResult(
      success: isSuccess,
      status: resultPayload!['status'] as String? ?? 'unknown',
      summary: isSuccess
          ? (summary ?? 'Pattern automation completed successfully.')
          : (summary ?? reason ?? 'Pattern automation failed.'),
      raw: resultPayload!,
      error: reason,
    );
  }

  String? _resolveSummary(Map<String, dynamic> payload) {
    final summary = payload['summary']?.toString().trim();
    if (summary != null && summary.isNotEmpty) {
      return summary;
    }

    final steps = payload['steps'];
    if (steps is List) {
      for (final item in steps.reversed) {
        if (item is! Map) {
          continue;
        }
        final detail = item['detail']?.toString().trim();
        if (detail != null && detail.isNotEmpty) {
          return detail;
        }
      }
    }
    return null;
  }

  Future<_AutomationInvocation> _prepareInvocation(
    Map<String, dynamic> rawTask,
  ) async {
    final tempDir = await Directory.systemTemp.createTemp(
      'voice_navigator_pattern_task_',
    );
    final taskFile = File(
      '${tempDir.path}${Platform.pathSeparator}pattern_task.json',
    );
    await taskFile.writeAsString(jsonEncode(rawTask), flush: true);

    return _AutomationInvocation(
      moduleName: 'local_server.app.simulation.pattern_agent_scenario',
      moduleArguments: [taskFile.path],
      onDispose: () async {
        if (taskFile.existsSync()) {
          await taskFile.delete();
        }
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      },
    );
  }

  _PythonCommand? _resolvePythonCommand(
    Directory root,
    String moduleName,
    List<String> moduleArguments,
  ) {
    final projectRoot = root.path;
    final candidates = <_PythonCommand>[
      _PythonCommand(
        executable:
            '$projectRoot${Platform.pathSeparator}.venv-server${Platform.pathSeparator}bin${Platform.pathSeparator}python',
        arguments: ['-m', moduleName, ...moduleArguments],
      ),
      _PythonCommand(
        executable:
            '$projectRoot${Platform.pathSeparator}.venv-server${Platform.pathSeparator}Scripts${Platform.pathSeparator}python.exe',
        arguments: ['-m', moduleName, ...moduleArguments],
      ),
      _PythonCommand(
        executable: 'python3',
        arguments: ['-m', moduleName, ...moduleArguments],
      ),
      _PythonCommand(
        executable: 'python',
        arguments: ['-m', moduleName, ...moduleArguments],
      ),
      _PythonCommand(
        executable: 'py',
        arguments: ['-3', '-m', moduleName, ...moduleArguments],
      ),
    ];

    for (final candidate in candidates) {
      if (_canExecute(candidate.executable)) {
        return candidate;
      }
    }
    return null;
  }

  Directory? _resolveProjectRoot() {
    final root = _resolveCurrentProjectRoot();
    if (root == null) {
      return null;
    }
    return _containsPatternScenario(root) ? root : null;
  }

  Directory? _resolveCurrentProjectRoot() {
    if (_compiledProjectRoot.isNotEmpty) {
      final compiledRoot = Directory(_compiledProjectRoot);
      if (_isFlutterProjectRoot(compiledRoot)) {
        return compiledRoot;
      }
    }

    Directory? findFlutterRoot(String startPath) {
      var dir = Directory(startPath);
      for (var i = 0; i < 14; i++) {
        if (_isFlutterProjectRoot(dir)) {
          return dir;
        }
        final parent = dir.parent;
        if (parent.path == dir.path) {
          break;
        }
        dir = parent;
      }
      return null;
    }

    return findFlutterRoot(Directory.current.path) ??
        findFlutterRoot(File(Platform.resolvedExecutable).parent.path);
  }

  bool _isFlutterProjectRoot(Directory root) {
    if (!root.existsSync()) {
      return false;
    }
    final pubspec = File(
      '${root.path}${Platform.pathSeparator}pubspec.yaml',
    );
    return pubspec.existsSync();
  }

  bool _containsPatternScenario(Directory root) {
    if (!root.existsSync()) {
      return false;
    }
    final scenarioFile = File(
      '${root.path}${Platform.pathSeparator}local_server'
      '${Platform.pathSeparator}app${Platform.pathSeparator}simulation'
      '${Platform.pathSeparator}pattern_agent_scenario.py',
    );
    return scenarioFile.existsSync();
  }

  bool _canExecute(String executable) {
    if (executable.contains(Platform.pathSeparator)) {
      return File(executable).existsSync();
    }
    return true;
  }

  String? _firstMeaningfulLine(String? value) {
    if (value == null) {
      return null;
    }
    final lines = value
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      return null;
    }
    return lines.first;
  }
}

class _PythonCommand {
  const _PythonCommand({
    required this.executable,
    required this.arguments,
  });

  final String executable;
  final List<String> arguments;
}

class _AutomationInvocation {
  const _AutomationInvocation({
    required this.moduleName,
    required this.moduleArguments,
    this.onDispose,
  });

  final String moduleName;
  final List<String> moduleArguments;
  final Future<void> Function()? onDispose;

  Future<void> dispose() async {
    await onDispose?.call();
  }
}
