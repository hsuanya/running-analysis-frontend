// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'dart:math';
import 'camera_level_model.dart';

class CameraLevelHelper {
  static final CameraLevelHelper instance = CameraLevelHelper._();
  CameraLevelHelper._();

  StreamController<CameraLevelData>? _controller;
  StreamSubscription? _motionSub;
  StreamSubscription? _orientationSub;
  bool _hasReceivedEvent = false;

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

  Future<bool> requestPermission() async {
    try {
      final dynamic deviceOrientationEvent =
          js_util.getProperty(html.window, 'DeviceOrientationEvent');
      if (deviceOrientationEvent != null &&
          js_util.hasProperty(deviceOrientationEvent, 'requestPermission')) {
        final result = await js_util.promiseToFuture<dynamic>(
          js_util.callMethod(deviceOrientationEvent, 'requestPermission', []),
        );
        return result == 'granted';
      }

      final dynamic deviceMotionEvent =
          js_util.getProperty(html.window, 'DeviceMotionEvent');
      if (deviceMotionEvent != null &&
          js_util.hasProperty(deviceMotionEvent, 'requestPermission')) {
        final result = await js_util.promiseToFuture<dynamic>(
          js_util.callMethod(deviceMotionEvent, 'requestPermission', []),
        );
        return result == 'granted';
      }
    } catch (_) {}
    return true;
  }

  void _startListening() {
    // 優先監聽加速度計（包含重力向量）
    try {
      _motionSub = html.window.onDeviceMotion.listen((event) {
        final accel = event.accelerationIncludingGravity;
        if (accel != null &&
            accel.x != null &&
            accel.y != null &&
            accel.z != null) {
          final ax = accel.x!.toDouble();
          final ay = accel.y!.toDouble();
          final az = accel.z!.toDouble();

          final norm = sqrt(ax * ax + ay * ay + az * az);
          if (norm > 1.0) {
            _hasReceivedEvent = true;
            _processAccel(ax, ay, az);
            return;
          }
        }
      });
    } catch (_) {}

    // 備援監聽方向角 (Euler angles)
    try {
      _orientationSub = html.window.onDeviceOrientation.listen((event) {
        if (_hasReceivedEvent) return;
        if (event.beta != null && event.gamma != null) {
          _hasReceivedEvent = true;
          _processOrientation(event.beta!.toDouble(), event.gamma!.toDouble());
        }
      });
    } catch (_) {}

    // 延遲檢測是否有讀取到硬體感測器
    Future.delayed(const Duration(seconds: 2), () {
      if (!_hasReceivedEvent && (_controller?.hasListener ?? false)) {
        _controller?.add(const CameraLevelData(isAvailable: false));
      }
    });
  }

  void _processAccel(double ax, double ay, double az) {
    double rawRoll = 0.0;
    double rawPitch = 0.0;

    if (ax.abs() > ay.abs()) {
      // 橫式 (Landscape)
      if (ax > 0) {
        rawRoll = -atan2(ay, ax.abs()) * 180.0 / pi;
      } else {
        rawRoll = atan2(ay, ax.abs()) * 180.0 / pi;
      }
    } else {
      // 直式 (Portrait)
      rawRoll = atan2(ax, ay.abs()) * 180.0 / pi;
    }

    rawPitch = atan2(az, sqrt(ax * ax + ay * ay)) * 180.0 / pi;

    _emitSmoothed(rawRoll, rawPitch);
  }

  void _processOrientation(double beta, double gamma) {
    double rawRoll = 0.0;
    double rawPitch = 0.0;

    if (gamma.abs() > 45) {
      if (gamma < 0) {
        rawRoll = -beta;
      } else {
        rawRoll = beta;
      }
      rawPitch = (gamma.abs() - 90.0);
    } else {
      rawRoll = gamma;
      rawPitch = (beta.abs() - 90.0);
    }

    _emitSmoothed(rawRoll, rawPitch);
  }

  void _emitSmoothed(double rawRoll, double rawPitch) {
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
  }

  void _stopListening() {
    _motionSub?.cancel();
    _motionSub = null;
    _orientationSub?.cancel();
    _orientationSub = null;
    _hasReceivedEvent = false;
    _initialized = false;
  }
}
