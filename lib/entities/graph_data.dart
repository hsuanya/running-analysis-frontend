class GraphData {
  String title;
  String yLabel;
  double yMin;
  double yMax;
  List<double> x;
  List<double> y;

  GraphData({
    required this.title,
    required this.yLabel,
    required this.yMin,
    required this.yMax,
    required this.x,
    required this.y,
  });

  factory GraphData.fromJson(Map<String, dynamic> json) {
    return GraphData(
      title: json['title'],
      yLabel: json['yLabel'],
      yMin: json['yMin'],
      yMax: json['yMax'],
      x: List<double>.from(json['x']),
      y: List<double>.from(json['y']),
    );
  }
}
