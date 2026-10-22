import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'camera_level_model.dart';

class CameraLevelHelper {
  static final CameraLevelHelper instance = CameraLevelHelper._();
  CameraLevelHelper._();

  StreamController<CameraLevelData>? _controller;
  StreamSubscription<AccelerometerEvent>? _sub;

  double _smoothRoll = 0.0;
  double _smoothPitch = 0.0;
  bool _initialized = false;

  Stream<CameraLevelData> get levelStream {
    _controller ??= StreamController<CameraLevelData>.broadcast(
      onListen: _startListening,
      onCancel: _stopListening,
    );
    return _controller!.stream;
  }

  void _startListening() {
    _sub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 33), // ~30 fps
    ).listen((event) {
      final ax = event.x;
      final ay = event.y;
      final az = event.z;

      final norm = sqrt(ax * ax + ay * ay + az * az);
      if (norm < 1.0) return;

      double rawRoll = 0.0;
      double rawPitch = 0.0;

      if (ax.abs() > ay.abs()) {
        if (ax > 0) {
          rawRoll = -atan2(ay, ax.abs()) * 180.0 / pi;
        } else {
          rawRoll = atan2(ay, ax.abs()) * 180.0 / pi;
        }
      } else {
        rawRoll = atan2(ax, ay.abs()) * 180.0 / pi;
      }

      rawPitch = atan2(az, sqrt(ax * ax + ay * ay)) * 180.0 / pi;

      if (!_initialized) {
        _smoothRoll = rawRoll;
        _smoothPitch = rawPitch;
        _initialized = true;
      } else {
        const alpha = 0.25;
        _smoothRoll = _smoothRoll + alpha * (rawRoll - _smoothRoll);
        _smoothPitch = _smoothPitch + alpha * (rawPitch - _smoothPitch);
      }

      final isLevel = _smoothRoll.abs() <= 0.8;

      _controller?.add(CameraLevelData(
        roll: _smoothRoll,
        pitch: _smoothPitch,
        isLevel: isLevel,
        isAvailable: true,
      ));
    }, onError: (_) {
      _controller?.add(const CameraLevelData(isAvailable: false));
    });
  }

  void _stopListening() {
    _sub?.cancel();
    _sub = null;
    _initialized = false;
  }

  Future<bool> requestPermission() async => true;
}
