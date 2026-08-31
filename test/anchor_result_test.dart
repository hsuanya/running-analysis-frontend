import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/feature/upload/widget/anchor_point_dialog.dart';

void main() {
  test('serializes six anchor points with derived world coordinates', () {
    const result = AnchorResult(
      points: [
        AnchorPoint(0.10, 0.20),
        AnchorPoint(0.80, 0.20),
        AnchorPoint(0.80, 0.70),
        AnchorPoint(0.10, 0.70),
        AnchorPoint(0.45, 0.20),
        AnchorPoint(0.45, 0.70),
      ],
      leftToMidDistanceM: 10,
      midToRightDistanceM: 12,
      runwayWidthM: 1.22,
    );

    final json = result.toJson();
    final points = json['points'] as List<dynamic>;

    expect(json['leftToMidDistanceM'], 10);
    expect(json['midToRightDistanceM'], 12);
    expect(points, [
      {'x': 0.10, 'y': 0.20, 'world_x_m': 0, 'world_y_m': 0},
      {'x': 0.80, 'y': 0.20, 'world_x_m': 22, 'world_y_m': 0},
      {'x': 0.80, 'y': 0.70, 'world_x_m': 22, 'world_y_m': 1.22},
      {'x': 0.10, 'y': 0.70, 'world_x_m': 0, 'world_y_m': 1.22},
      {'x': 0.45, 'y': 0.20, 'world_x_m': 10, 'world_y_m': 0},
      {'x': 0.45, 'y': 0.70, 'world_x_m': 10, 'world_y_m': 1.22},
    ]);
  });
}
