class RunSessionInfo {
  String runSessionId;
  String runnerId;
  String runnerName;
  DateTime date;
  int cameraCount;
  int fps;
  double? trackWidth;
  String runningDirection;
  double? avgVelocity;
  double? avgAcceleration;
  double? avgStepLength;
  double? totalTime;
  String note;
  String status;
  int progress;

  RunSessionInfo({
    required this.runSessionId,
    required this.runnerId,
    required this.runnerName,
    required this.date,
    required this.cameraCount,
    required this.fps,
    this.trackWidth,
    this.runningDirection = 'left_to_right',
    this.avgVelocity,
    this.avgAcceleration,
    this.avgStepLength,
    this.totalTime,
    required this.note,
    required this.status,
    required this.progress,
  });

  factory RunSessionInfo.fromJson(Map<String, dynamic> json) {
    return RunSessionInfo(
      runSessionId: json['runSessionId'],
      runnerId: json['runnerId'],
      runnerName: json['runnerName'],
      date: DateTime.parse(json['date']),
      cameraCount: json['cameraCount'],
      fps: json['fps'],
      trackWidth: json['trackWidth'] != null ? (json['trackWidth'] as num).toDouble() : 1.22,
      runningDirection: json['runningDirection'] ?? 'left_to_right',
      avgVelocity: json['avgVelocity'],
      avgAcceleration: json['avgAcceleration'],
      avgStepLength: json['avgStepLength'],
      totalTime: json['totalTime'],
      note: json['note'],
      status: json['status'],
      progress: json['progress'] ?? 0,
    );
  }
}
