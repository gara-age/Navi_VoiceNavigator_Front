enum CommandResponseStatus {
  success,
  warning,
  error,
}

class CommandResponseModel {
  const CommandResponseModel({
    required this.transcript,
    required this.summary,
    this.followUp,
    this.isError = false,
    this.pendingAction,
    this.pendingTarget,
    this.status = CommandResponseStatus.success,
    this.completesFollowUp = false,
  });

  final String transcript;
  final String summary;
  final String? followUp;
  final bool isError;
  final String? pendingAction;
  final String? pendingTarget;
  final CommandResponseStatus status;
  final bool completesFollowUp;
}

class AgentCommandPayload {
  const AgentCommandPayload({
    this.transcript,
    this.summary,
    this.followUp,
    this.isError,
    this.pendingAction,
    this.pendingTarget,
    this.status,
    this.completesFollowUp,
    this.rawText,
  });

  final String? transcript;
  final String? summary;
  final String? followUp;
  final bool? isError;
  final String? pendingAction;
  final String? pendingTarget;
  final String? status;
  final bool? completesFollowUp;
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
      status: json['status'] as String?,
      completesFollowUp:
          json['completes_follow_up'] as bool? ??
          json['completesFollowUp'] as bool?,
      rawText: json['raw_text'] as String? ?? json['rawText'] as String?,
    );
  }
}
