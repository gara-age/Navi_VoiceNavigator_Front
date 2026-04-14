import 'dart:convert';

import 'response_models.dart';

enum AgentApiAutomationKind {
  message,
  legacyPlan,
  patternTask,
}

class AgentApiPatternIntent {
  const AgentApiPatternIntent({
    required this.taskType,
    required this.slots,
    required this.riskLevel,
    required this.confidence,
    this.domainHint,
  });

  final String taskType;
  final Map<String, dynamic> slots;
  final String riskLevel;
  final double confidence;
  final String? domainHint;

  factory AgentApiPatternIntent.fromJson(Map<String, dynamic> json) {
    return AgentApiPatternIntent(
      taskType: json['task_type']?.toString() ?? '',
      slots: _asStringDynamicMap(json['slots']),
      riskLevel: json['risk_level']?.toString() ?? 'low',
      confidence: _asDouble(json['confidence']),
      domainHint: json['domain_hint']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'task_type': taskType,
      'slots': slots,
      'risk_level': riskLevel,
      'confidence': confidence,
      if (domainHint != null) 'domain_hint': domainHint,
    };
  }
}

class AgentApiHostBias {
  const AgentApiHostBias({
    this.host,
    this.preferPanelUi,
    this.autocompleteConfirmWeight,
    this.timeoutMultiplier,
    this.preferredResultLandmarks = const [],
    this.primaryActionLabelPreferences = const [],
  });

  final String? host;
  final double? preferPanelUi;
  final double? autocompleteConfirmWeight;
  final double? timeoutMultiplier;
  final List<String> preferredResultLandmarks;
  final List<String> primaryActionLabelPreferences;

  factory AgentApiHostBias.fromJson(Map<String, dynamic> json) {
    return AgentApiHostBias(
      host: json['host']?.toString(),
      preferPanelUi: _asNullableDouble(json['prefer_panel_ui']),
      autocompleteConfirmWeight:
          _asNullableDouble(json['autocomplete_confirm_weight']),
      timeoutMultiplier: _asNullableDouble(json['timeout_multiplier']),
      preferredResultLandmarks:
          _asStringList(json['preferred_result_landmarks']),
      primaryActionLabelPreferences:
          _asStringList(json['primary_action_label_preferences']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (host != null) 'host': host,
      if (preferPanelUi != null) 'prefer_panel_ui': preferPanelUi,
      if (autocompleteConfirmWeight != null)
        'autocomplete_confirm_weight': autocompleteConfirmWeight,
      if (timeoutMultiplier != null)
        'timeout_multiplier': timeoutMultiplier,
      if (preferredResultLandmarks.isNotEmpty)
        'preferred_result_landmarks': preferredResultLandmarks,
      if (primaryActionLabelPreferences.isNotEmpty)
        'primary_action_label_preferences': primaryActionLabelPreferences,
    };
  }
}

class AgentApiPatternTask {
  const AgentApiPatternTask({
    required this.site,
    required this.userRequest,
    this.intent,
    this.hostBias,
    this.metadata = const {},
  });

  final String site;
  final String userRequest;
  final AgentApiPatternIntent? intent;
  final AgentApiHostBias? hostBias;
  final Map<String, dynamic> metadata;

  factory AgentApiPatternTask.fromJson(Map<String, dynamic> json) {
    return AgentApiPatternTask(
      site: json['site']?.toString() ?? '',
      userRequest:
          json['user_request']?.toString() ??
          json['userRequest']?.toString() ??
          '',
      intent: json['intent'] is Map<String, dynamic>
          ? AgentApiPatternIntent.fromJson(json['intent'] as Map<String, dynamic>)
          : (json['intent'] is Map
              ? AgentApiPatternIntent.fromJson(
                  _asStringDynamicMap(json['intent']),
                )
              : null),
      hostBias: json['host_bias'] is Map<String, dynamic>
          ? AgentApiHostBias.fromJson(json['host_bias'] as Map<String, dynamic>)
          : (json['hostBias'] is Map<String, dynamic>
              ? AgentApiHostBias.fromJson(json['hostBias'] as Map<String, dynamic>)
              : (json['host_bias'] is Map
                  ? AgentApiHostBias.fromJson(
                      _asStringDynamicMap(json['host_bias']),
                    )
                  : (json['hostBias'] is Map
                      ? AgentApiHostBias.fromJson(
                          _asStringDynamicMap(json['hostBias']),
                        )
                      : null))),
      metadata: _asStringDynamicMap(json['metadata']),
    );
  }

  bool get isMeaningful =>
      site.trim().isNotEmpty ||
      userRequest.trim().isNotEmpty ||
      intent != null;

  Map<String, dynamic> toJson() {
    return {
      if (site.isNotEmpty) 'site': site,
      if (userRequest.isNotEmpty) 'user_request': userRequest,
      if (intent != null) 'intent': intent!.toJson(),
      if (hostBias != null) 'host_bias': hostBias!.toJson(),
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }
}

class AgentApiLegacyPlan {
  const AgentApiLegacyPlan({
    required this.taskId,
    required this.site,
    required this.steps,
    this.goal,
    this.raw = const {},
  });

  final String taskId;
  final String site;
  final List<Map<String, dynamic>> steps;
  final String? goal;
  final Map<String, dynamic> raw;

  factory AgentApiLegacyPlan.fromJson(Map<String, dynamic> json) {
    final rawSteps = json['steps'];
    final steps = <Map<String, dynamic>>[];
    if (rawSteps is List) {
      for (final item in rawSteps) {
        if (item is Map<String, dynamic>) {
          steps.add(item);
        } else if (item is Map) {
          steps.add(_asStringDynamicMap(item));
        }
      }
    }
    return AgentApiLegacyPlan(
      taskId: json['task_id']?.toString() ?? '',
      site: json['site']?.toString() ?? '',
      goal: json['goal']?.toString(),
      steps: steps,
      raw: _asStringDynamicMap(json),
    );
  }

  bool get isMeaningful => taskId.trim().isNotEmpty && steps.isNotEmpty;
}

class AgentApiResponseEnvelope {
  const AgentApiResponseEnvelope._({
    required this.kind,
    this.message,
    this.legacyPlan,
    this.patternTask,
    this.raw = const {},
  });

  final AgentApiAutomationKind kind;
  final AgentCommandPayload? message;
  final AgentApiLegacyPlan? legacyPlan;
  final AgentApiPatternTask? patternTask;
  final Map<String, dynamic> raw;

  factory AgentApiResponseEnvelope.message(
    AgentCommandPayload payload, {
    Map<String, dynamic> raw = const {},
  }) {
    return AgentApiResponseEnvelope._(
      kind: AgentApiAutomationKind.message,
      message: payload,
      raw: raw,
    );
  }

  factory AgentApiResponseEnvelope.legacyPlan(
    AgentApiLegacyPlan plan, {
    Map<String, dynamic> raw = const {},
  }) {
    return AgentApiResponseEnvelope._(
      kind: AgentApiAutomationKind.legacyPlan,
      legacyPlan: plan,
      raw: raw,
    );
  }

  factory AgentApiResponseEnvelope.patternTask(
    AgentApiPatternTask task, {
    Map<String, dynamic> raw = const {},
  }) {
    return AgentApiResponseEnvelope._(
      kind: AgentApiAutomationKind.patternTask,
      patternTask: task,
      raw: raw,
    );
  }

  static AgentApiResponseEnvelope parse(String rawResponse) {
    try {
      final decoded = jsonDecode(rawResponse);
      if (decoded is Map<String, dynamic>) {
        return _parseMap(decoded);
      }
      if (decoded is Map) {
        return _parseMap(_asStringDynamicMap(decoded));
      }
    } catch (_) {
      return AgentApiResponseEnvelope.message(
        AgentCommandPayload(rawText: rawResponse),
      );
    }

    return AgentApiResponseEnvelope.message(
      AgentCommandPayload(rawText: rawResponse),
    );
  }

  static AgentApiResponseEnvelope _parseMap(Map<String, dynamic> map) {
    final raw = _asStringDynamicMap(map);

    final legacyPlan = AgentApiLegacyPlan.fromJson(raw);
    if (legacyPlan.isMeaningful) {
      return AgentApiResponseEnvelope.legacyPlan(legacyPlan, raw: raw);
    }

    final nestedTask = raw['task'];
    final kind = raw['kind']?.toString();
    final automationMode = raw['automation_mode']?.toString();
    if ((kind == 'pattern_task' || automationMode == 'pattern_task') &&
        nestedTask is Map) {
      final task = AgentApiPatternTask.fromJson(_asStringDynamicMap(nestedTask));
      if (task.isMeaningful) {
        return AgentApiResponseEnvelope.patternTask(task, raw: raw);
      }
    }

    final directTask = AgentApiPatternTask.fromJson(raw);
    if (directTask.isMeaningful &&
        (directTask.intent != null ||
            directTask.userRequest.isNotEmpty ||
            directTask.site.isNotEmpty)) {
      return AgentApiResponseEnvelope.patternTask(directTask, raw: raw);
    }

    return AgentApiResponseEnvelope.message(
      AgentCommandPayload.fromJson(raw),
      raw: raw,
    );
  }
}

Map<String, dynamic> _asStringDynamicMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (key, val) => MapEntry(key.toString(), val),
    );
  }
  return const <String, dynamic>{};
}

List<String> _asStringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value.map((item) => item.toString()).toList(growable: false);
}

double _asDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0.0;
}

double? _asNullableDouble(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value.toString());
}
