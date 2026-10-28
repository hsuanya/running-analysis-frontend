import 'package:camera/camera.dart';

class RealCameraSpecs {
  final int? width;
  final int? height;
  final int? fps;
  final String specsText;

  RealCameraSpecs({this.width, this.height, this.fps, required this.specsText});
}

class CameraSpecsHelper {
  static Future<RealCameraSpecs> getRealSpecs(CameraController controller) async {
    final size = controller.value.previewSize;
    String res = '1080p';
    if (size != null) {
      final shortSide = size.width < size.height ? size.width.toInt() : size.height.toInt();
      final longSide = size.width > size.height ? size.width.toInt() : size.height.toInt();
      if (shortSide >= 1000 && shortSide <= 1120) {
        res = '1080p';
      } else if (shortSide >= 700 && shortSide <= 750) {
        res = '720p';
      } else {
        res = '${longSide}×$shortSide';
      }
    }
    return RealCameraSpecs(specsText: '$res • 30 FPS');
  }
}
