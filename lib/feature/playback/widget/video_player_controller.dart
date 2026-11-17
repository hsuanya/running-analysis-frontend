import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/utils/api.dart';
import 'package:frontend/utils/net_utils.dart';
import 'package:video_player/video_player.dart';

import 'package:frontend/feature/auth/auth_provider.dart';

class FocusFramePoint {
  final double cx;
  final double cy;
  final double h;
  final int cam;

  const FocusFramePoint({
    required this.cx,
    required this.cy,
    required this.h,
    required this.cam,
  });

  factory FocusFramePoint.fromJson(Map<String, dynamic> json) {
    return FocusFramePoint(
      cx: (json['cx'] as num?)?.toDouble() ?? 0.5,
      cy: (json['cy'] as num?)?.toDouble() ?? 0.5,
      h: (json['h'] as num?)?.toDouble() ?? 0.16,
      cam: (json['cam'] as num?)?.toInt() ?? 1,
    );
  }
}

class FocusTrackData {
  final int width;
  final int height;
  final double fps;
  final double defaultZoom;
  final List<FocusFramePoint> frames;

  const FocusTrackData({
    required this.width,
    required this.height,
    required this.fps,
    required this.defaultZoom,
    required this.frames,
  });

  factory FocusTrackData.fromJson(Map<String, dynamic> json) {
    final rawFrames = (json['frames'] as List?) ?? const [];
    return FocusTrackData(
      width: (json['width'] as num?)?.toInt() ?? 1920,
      height: (json['height'] as num?)?.toInt() ?? 1080,
      fps: (json['fps'] as num?)?.toDouble() ?? 60.0,
      defaultZoom: (json['defaultZoom'] as num?)?.toDouble() ?? 3.2,
      frames: rawFrames
          .whereType<Map>()
          .map((e) => FocusFramePoint.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  (double cx, double cy) centerAtMs(int positionMs) {
    if (frames.isEmpty) return (0.5, 0.5);
    final effectiveFps = fps > 0 ? fps : 60.0;
    final exactIdx = ((positionMs / 1000.0) * effectiveFps).clamp(0.0, (frames.length - 1).toDouble());
    final i0 = exactIdx.floor().clamp(0, frames.length - 1);
    final i1 = exactIdx.ceil().clamp(0, frames.length - 1);
    final p0 = frames[i0];
    final p1 = frames[i1];
    // Do not interpolate across camera switches
    if (i0 == i1 || p0.cam != p1.cam) {
      final nearest = frames[exactIdx.round().clamp(0, frames.length - 1)];
      return (nearest.cx, nearest.cy);
    }
    final t = exactIdx - i0;
    return (
      p0.cx + (p1.cx - p0.cx) * t,
      p0.cy + (p1.cy - p0.cy) * t,
    );
  }
}

final focusTrackProvider = FutureProvider.autoDispose.family<FocusTrackData?, String>((ref, id) async {
  if (id.isEmpty) return null;
  try {
    final endpoint = API.getRunSessionFocusTrack(id);
    final response = await NetUtils().reqeustData(
      endpoint[1],
      method: endpoint[0],
    );
    if (response is Map) {
      final track = FocusTrackData.fromJson(Map<String, dynamic>.from(response));
      if (track.frames.isNotEmpty) {
        return track;
      }
    }
  } catch (_) {
    // Fallback gracefully if focus track is unavailable
  }
  return null;
});

class VideoControllerManager {
  late final VideoPlayerController controller;
  VideoPlayerController? focusController;
  bool hasFocusVideo = false;
  bool isFocusActive = false;

  VideoControllerManager(String videoUrl, {String? focusVideoUrl}) {
    controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
    if (focusVideoUrl != null && focusVideoUrl.isNotEmpty) {
      focusController = VideoPlayerController.networkUrl(Uri.parse(focusVideoUrl));
    }
  }

  VideoPlayerController get activeController =>
      (isFocusActive && hasFocusVideo && focusController != null) ? focusController! : controller;

  Future<void> initializeAll() async {
    await controller.initialize();
    await controller.seekTo(Duration.zero);
    if (focusController != null) {
      try {
        await focusController!.initialize();
        await focusController!.setVolume(0.0);
        await focusController!.seekTo(Duration.zero);
        hasFocusVideo = true;
      } catch (_) {
        hasFocusVideo = false;
      }
    }
  }

  Future<void> switchFocusMode(bool enableFocus, {int? targetPositionMs}) async {
    if (enableFocus == isFocusActive) return;
    final prev = activeController;
    final wasPlaying = prev.value.isPlaying;
    final pos = targetPositionMs != null
        ? Duration(milliseconds: targetPositionMs)
        : prev.value.position;

    if (wasPlaying) {
      await prev.pause();
    }
    isFocusActive = enableFocus;
    final next = activeController;
    await next.seekTo(pos);
    if (wasPlaying) {
      await next.play();
    }
  }

  void play() {
    activeController.play();
  }

  void pause() {
    controller.pause();
    focusController?.pause();
  }

  void dispose() {
    controller.dispose();
    focusController?.dispose();
  }

  void seek(Duration position) {
    activeController.seekTo(position);
    // Keep inactive controller roughly in sync when paused for instant switching
    final inactive = (activeController == controller) ? focusController : controller;
    if (inactive != null && inactive.value.isInitialized) {
      inactive.seekTo(position);
    }
  }
}

final videoManagerProvider = FutureProvider.family<VideoControllerManager, String>((ref, id) async {
  final authState = ref.watch(authProvider);
  final token = authState.token;
  var fullUrl = API.getRunSessionVideo(id)[1] as String;
  var focusUrl = API.getRunSessionFocusVideo(id)[1] as String;
  if (token != null && token.isNotEmpty) {
    final sep1 = fullUrl.contains('?') ? '&' : '?';
    fullUrl = '$fullUrl${sep1}token=$token';
    final sep2 = focusUrl.contains('?') ? '&' : '?';
    focusUrl = '$focusUrl${sep2}token=$token';
  }

  final manager = VideoControllerManager(fullUrl, focusVideoUrl: focusUrl);
  await manager.initializeAll();
  return manager;
});
