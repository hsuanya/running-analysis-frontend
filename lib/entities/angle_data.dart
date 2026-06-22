class AngleSample {
  final int frame;
  final double timeSec;
  final Map<String, double?> values;

  AngleSample({
    required this.frame,
    required this.timeSec,
    required this.values,
  });

  factory AngleSample.fromJson(Map<String, dynamic> json) {
    final rawValues = Map<String, dynamic>.from(json['values'] ?? {});
    return AngleSample(
      frame: (json['frame'] as num).toInt(),
      timeSec: (json['timeSec'] as num).toDouble(),
      values: rawValues.map(
        (key, value) =>
            MapEntry(key, value == null ? null : (value as num).toDouble()),
      ),
    );
  }
}

class AngleData {
  final List<String> columns;
  final List<AngleSample> samples;

  AngleData({required this.columns, required this.samples});

  factory AngleData.fromJson(Map<String, dynamic> json) {
    return AngleData(
      columns: List<String>.from(json['columns'] ?? []),
      samples: (json['samples'] as List? ?? [])
          .map((sample) => AngleSample.fromJson(sample))
          .toList(),
    );
  }
}
