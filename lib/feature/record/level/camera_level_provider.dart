import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'camera_level_helper.dart';
import 'camera_level_model.dart';

/// 控制是否在相機畫面上開啟/顯示水平儀
final showCameraLevelProvider = StateProvider<bool>((ref) => true);

/// 即時讀取相機水平儀感測器數據
final cameraLevelStreamProvider = StreamProvider.autoDispose<CameraLevelData>((ref) {
  return CameraLevelHelper.instance.levelStream;
});
