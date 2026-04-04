class CommandResponseModel {
  const CommandResponseModel({
    required this.transcript,
    required this.summary,
    this.followUp,
  });

  final String transcript;
  final String summary;
  final String? followUp;
}
