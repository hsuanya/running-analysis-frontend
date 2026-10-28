// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'package:camera/camera.dart';

class RealCameraSpecs {
  final int? width;
  final int? height;
  final int? fps;
  final String specsText;

  RealCameraSpecs({this.width, this.height, this.fps, required this.specsText});
}

class CameraSpecsHelper {
  /// 透過 WebRTC MediaStreamTrack.getSettings() 讀取瀏覽器與鏡頭實際協商的真實解析度與真實 FPS
  static Future<RealCameraSpecs> getRealSpecs(CameraController controller) async {
    // 稍候 200ms 確保 video element 的 MediaStream 與 Track metadata 已經綁定
    await Future.delayed(const Duration(milliseconds: 200));

    try {
      final videoEl = _findActiveVideoElement();
      int? realWidth;
      int? realHeight;
      int? realFps;

      if (videoEl != null) {
        final dynamic srcObject = js_util.getProperty(videoEl, 'srcObject');
        if (srcObject != null) {
          final tracks = js_util.callMethod(srcObject, 'getVideoTracks', []) as List;
          if (tracks.isNotEmpty) {
            final track = tracks[0];
            final dynamic settings = js_util.callMethod(track, 'getSettings', []);
            if (settings != null) {
              final dynamic w = js_util.getProperty(settings, 'width');
              final dynamic h = js_util.getProperty(settings, 'height');
              final dynamic fr = js_util.getProperty(settings, 'frameRate');

              if (w is num) realWidth = w.toInt();
              if (h is num) realHeight = h.toInt();
              if (fr is num) realFps = fr.round();
            }
          }
        }

        // 若 Track 尚未回報寬高，使用 videoElement 實際解碼像素
        if ((realWidth == null || realWidth == 0) && videoEl.videoWidth > 0) {
          realWidth = videoEl.videoWidth;
          realHeight = videoEl.videoHeight;
        }
      }

      // 若仍未取得寬高，使用 Controller 的 previewSize
      if (realWidth == null || realWidth == 0) {
        final size = controller.value.previewSize;
        if (size != null) {
          realWidth = size.width.toInt();
          realHeight = size.height.toInt();
        }
      }

      // 解析度格式化
      String res = '1080p';
      if (realWidth != null && realHeight != null && realWidth > 0 && realHeight > 0) {
        final shortSide = realWidth < realHeight ? realWidth : realHeight;
        final longSide = realWidth > realHeight ? realWidth : realHeight;
        if (shortSide >= 1000 && shortSide <= 1120) {
          res = '1080p';
        } else if (shortSide >= 700 && shortSide <= 750) {
          res = '720p';
        } else if (shortSide >= 450 && shortSide <= 500) {
          res = '480p';
        } else {
          res = '${longSide}×$shortSide';
        }
      }

      // 真實 FPS：若瀏覽器/硬體未回報，手機或標準相機通常預設為 30 FPS
      final fpsVal = realFps ?? 30;
      final specsText = '$res • $fpsVal FPS';

      return RealCameraSpecs(
        width: realWidth,
        height: realHeight,
        fps: fpsVal,
        specsText: specsText,
      );
    } catch (_) {
      return RealCameraSpecs(specsText: '1080p • 30 FPS');
    }
  }

  static html.VideoElement? _findActiveVideoElement() {
    // 1. 直尋全域 video
    final videos = html.document.querySelectorAll('video');
    for (final v in videos) {
      if (v is html.VideoElement && v.srcObject != null) {
        return v;
      }
    }
    if (videos.isNotEmpty && videos.first is html.VideoElement) {
      return videos.first as html.VideoElement;
    }

    // 2. 搜尋 shadowRoot（Flutter CanvasKit platform view）
    for (final el in html.document.querySelectorAll('*')) {
      if (el.shadowRoot != null) {
        final shadowVideos = el.shadowRoot!.querySelectorAll('video');
        for (final v in shadowVideos) {
          if (v is html.VideoElement && v.srcObject != null) {
            return v;
          }
        }
        if (shadowVideos.isNotEmpty && shadowVideos.first is html.VideoElement) {
          return shadowVideos.first as html.VideoElement;
        }
      }
    }

    return null;
  }
}
