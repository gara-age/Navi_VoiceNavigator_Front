class CommandResponseModel {
  const CommandResponseModel({
    required this.transcript,
    required this.summary,
    this.followUp,
    this.isError = false,
    this.pendingAction,
    this.pendingTarget,
  });

  final String transcript;
  final String summary;
  final String? followUp;
  final bool isError;
  final String? pendingAction;
  final String? pendingTarget;
}

class AgentCommandPayload {
  const AgentCommandPayload({
    this.transcript,
    this.summary,
    this.followUp,
    this.isError,
    this.pendingAction,
    this.pendingTarget,
    this.rawText,
  });

  final String? transcript;
  final String? summary;
  final String? followUp;
  final bool? isError;
  final String? pendingAction;
  final String? pendingTarget;
  final String? rawText;

  factory AgentCommandPayload.fromJson(Map<String, dynamic> json) {
    return AgentCommandPayload(
      transcript: json['transcript'] as String?,
      summary: json['summary'] as String?,
      followUp: json['follow_up'] as String? ?? json['followUp'] as String?,
      isError: json['is_error'] as bool? ?? json['isError'] as bool?,
      pendingAction:
          json['pending_action'] as String? ?? json['pendingAction'] as String?,
      pendingTarget:
          json['pending_target'] as String? ?? json['pendingTarget'] as String?,
      rawText: json['raw_text'] as String? ?? json['rawText'] as String?,
    );
  }
}
