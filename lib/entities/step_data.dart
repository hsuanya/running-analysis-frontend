class StepSample {
  final int stepIndex;
  final double timeSec;
  final int cam;
  final String? foot;
  final String? eventType;
  final double? stepLengthM;
  final double? cadenceSpm;
  final double? velocityMps;
  final double? worldXM;
  final double? worldYM;

  StepSample({
    required this.stepIndex,
    required this.timeSec,
    required this.cam,
    this.foot,
    this.eventType,
    this.stepLengthM,
    this.cadenceSpm,
    this.velocityMps,
    this.worldXM,
    this.worldYM,
  });

  factory StepSample.fromJson(Map<String, dynamic> json) {
    double? asDouble(dynamic v) => v == null ? null : (v as num).toDouble();
    return StepSample(
      stepIndex: json['stepIndex'] as int,
      timeSec: (json['timeSec'] as num).toDouble(),
      cam: json['cam'] as int,
      foot: json['foot'] as String?,
      eventType: json['eventType'] as String?,
      stepLengthM: asDouble(json['stepLengthM']),
      cadenceSpm: asDouble(json['cadenceSpm']),
      velocityMps: asDouble(json['velocityMps']),
      worldXM: asDouble(json['worldXM']),
      worldYM: asDouble(json['worldYM']),
    );
  }
}

class StepsData {
  final double? avgStepLengthM;
  final double? avgCadenceSpm;
  final List<StepSample> steps;

  StepsData({this.avgStepLengthM, this.avgCadenceSpm, required this.steps});

  factory StepsData.fromJson(Map<String, dynamic> json) {
    double? asDouble(dynamic v) => v == null ? null : (v as num).toDouble();
    return StepsData(
      avgStepLengthM: asDouble(json['avgStepLengthM']),
      avgCadenceSpm: asDouble(json['avgCadenceSpm']),
      steps: (json['steps'] as List)
          .map((e) => StepSample.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
