import 'camera_level_model.dart';

class CameraLevelHelper {
  static final CameraLevelHelper instance = CameraLevelHelper._();
  CameraLevelHelper._();

  Stream<CameraLevelData> get levelStream =>
      Stream.value(const CameraLevelData(isAvailable: false));

  Future<bool> requestPermission() async => true;
}
