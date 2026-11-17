import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/backend/backend_provider.dart';
import 'package:frontend/backend/video_playback_state_provider.dart';
import 'package:frontend/feature/playback/playback_provider.dart';
import 'package:frontend/feature/playback/shimmer/video_player_shimmer.dart';
import 'package:frontend/feature/playback/widget/video_player_controller.dart';
import 'package:frontend/feature/playback/widget/video_slider_item.dart';
import 'package:frontend/utils/locale_provider.dart';
import 'package:frontend/widget/async_value_widget.dart';
import 'package:frontend/widget/processing_progress_widget.dart';
import 'package:frontend/widget/rounded_box_widget.dart';
import 'package:video_player/video_player.dart';

class VideoPlayerView extends ConsumerStatefulWidget {
  const VideoPlayerView({super.key});

  @override
  ConsumerState<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends ConsumerState<VideoPlayerView> {
  @override
  Widget build(BuildContext context) {
    final selectedVideoId = ref.watch(playbackSelectedRunSessionIdProvider);

    if (selectedVideoId == null || selectedVideoId.isEmpty) {
      return Container(
        height: 250,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          color: Theme.of(context).primaryColor,
        ),
        child: const Center(child: Icon(Icons.ondemand_video_rounded, size: 64, color: Colors.white)),
      );
    }

    final videoInfo = ref.watch(videoInfoProvider(selectedVideoId));
    return AsyncValueWidget(
      value: videoInfo,
      loading: RoundedBoxWidget(
        child: Padding(padding: const EdgeInsets.all(12), child: const VideoPlayerShimmer()),
      ),
      data: (info) {
        if (info.status == 'failed') {
          return Container(
            height: 250,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              color: Theme.of(context).primaryColor,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      color: Colors.black.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                Container(
                  width: 300,
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 40),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              context.l10n.noVideoData,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            context.l10n.statusFailed,
                            style: const TextStyle(
                              color: Colors.redAccent,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: const LinearProgressIndicator(
                          value: 1.0,
                          minHeight: 8,
                          backgroundColor: Colors.white10,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.redAccent),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        if (info.status == 'processing') {
          return RoundedBoxWidget(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const VideoPlayerShimmer(),
                  ProcessingProgressWidget(progress: info.progress),
                ],
              ),
            ),
          );
        }

        // 只有狀態不是 processing 時，才顯示真正的影片內容組件
        return _VideoContentPlayer(
          key: ValueKey(selectedVideoId),
          videoId: selectedVideoId,
          fps: info.fps > 0 ? info.fps : 60,
        );
      },
    );
  }
}

class _VideoContentPlayer extends ConsumerStatefulWidget {
  final String videoId;
  final int fps;

  const _VideoContentPlayer({
    super.key,
    required this.videoId,
    required this.fps,
  });

  @override
  ConsumerState<_VideoContentPlayer> createState() => _VideoContentPlayerState();
}

class _VideoContentPlayerState extends ConsumerState<_VideoContentPlayer> {
  VideoControllerManager? _manager;

  // Optimistic target position (ms) for rapid frame-by-frame stepping
  double? _virtualPositionMs;
  DateTime? _lastManualStepTime;
  bool _isSeeking = false;
  int? _pendingSeekMs;

  // Runner Focus (cropped video) state
  bool _isRunnerFocus = false;
  int _zoomPresetIdx = 0; // 0: Standard (1.0x), 1: Close-up (1.2x), 2: Telephoto (1.4x)
  static const List<double> _zoomMultipliers = [1.0, 1.2, 1.4];

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    // 切換影片時重置播放狀態
    Future.microtask(() {
      ref.invalidate(videoPlaybackStateProvider);
    });
  }

  bool _isEditableTextFocused() {
    final focus = FocusManager.instance.primaryFocus;
    final context = focus?.context;
    if (context == null) return false;
    if (context.widget is EditableText) return true;
    return context.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  double _effectiveZoom(FocusTrackData? track) {
    final base = track?.defaultZoom ?? 3.0;
    return (base * _zoomMultipliers[_zoomPresetIdx]).clamp(2.0, 4.8);
  }

  Future<void> _toggleRunnerFocus() async {
    final manager = _manager;
    final track = ref.read(focusTrackProvider(widget.videoId)).asData?.value;
    final canFocus = (manager != null && manager.hasFocusVideo) ||
        (track != null && track.frames.isNotEmpty);
    if (!canFocus) return;

    final nextFocus = !_isRunnerFocus;
    final targetMs = (_virtualPositionMs ??
            ref.read(videoPlaybackStateProvider).position.toDouble())
        .round();
    if (manager != null && manager.hasFocusVideo) {
      await manager.switchFocusMode(nextFocus, targetPositionMs: targetMs);
    }
    if (mounted) {
      setState(() {
        _isRunnerFocus = nextFocus;
      });
    }
  }

  void _cycleFocusZoom() {
    setState(() {
      _zoomPresetIdx = (_zoomPresetIdx + 1) % _zoomMultipliers.length;
    });
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (!mounted || _manager == null) return false;
    if (!_manager!.activeController.value.isInitialized) return false;
    if (_isEditableTextFocused()) return false;

    final key = event.logicalKey;
    if (event is KeyDownEvent && key == LogicalKeyboardKey.space) {
      _togglePlayPause();
      return true;
    }
    if (event is KeyDownEvent && key == LogicalKeyboardKey.keyF) {
      _toggleRunnerFocus();
      return true;
    }

    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final isShift = HardwareKeyboard.instance.isShiftPressed;
      final stepFrames = isShift ? 10 : 1;
      if (key == LogicalKeyboardKey.arrowLeft) {
        _stepByFrames(-stepFrames);
        return true;
      } else if (key == LogicalKeyboardKey.arrowRight) {
        _stepByFrames(stepFrames);
        return true;
      }
    }
    return false;
  }

  void _togglePlayPause() {
    final manager = _manager;
    if (manager == null) return;
    if (manager.activeController.value.isPlaying) {
      manager.pause();
    } else {
      _virtualPositionMs = null;
      manager.play();
    }
    if (mounted) setState(() {});
  }

  void _stepByFrames(int deltaFrames) {
    final manager = _manager;
    if (manager == null || !manager.activeController.value.isInitialized) return;

    if (manager.activeController.value.isPlaying) {
      manager.pause();
    }

    final durationMs = manager.activeController.value.duration.inMilliseconds;
    if (durationMs <= 0) return;

    final effectiveFps = widget.fps > 0 ? widget.fps : 60;
    final frameDurationMs = 1000.0 / effectiveFps;

    final currentPosMs = _virtualPositionMs ??
        ref.read(videoPlaybackStateProvider).position.toDouble();
    final nextPosMs = (currentPosMs + deltaFrames * frameDurationMs)
        .clamp(0.0, durationMs.toDouble());

    _virtualPositionMs = nextPosMs;
    _lastManualStepTime = DateTime.now();

    final targetMs = nextPosMs.round();
    final targetFrame = ((targetMs / 1000.0) * effectiveFps).round();

    final notifier = ref.read(videoPlaybackStateProvider.notifier);
    final state = ref.read(videoPlaybackStateProvider);
    notifier.setResult(
      state.copyWith(
        position: targetMs,
        duration: durationMs,
        currentFrame: targetFrame,
      ),
    );

    _enqueueSeek(targetMs);
    if (mounted) setState(() {});
  }

  void _seekToPositionMs(int positionMs) {
    final manager = _manager;
    if (manager == null || !manager.activeController.value.isInitialized) return;

    final durationMs = manager.activeController.value.duration.inMilliseconds;
    final clampedMs = positionMs.clamp(0, durationMs > 0 ? durationMs : positionMs);
    _virtualPositionMs = clampedMs.toDouble();
    _lastManualStepTime = DateTime.now();

    final effectiveFps = widget.fps > 0 ? widget.fps : 60;
    final targetFrame = ((clampedMs / 1000.0) * effectiveFps).round();
    final notifier = ref.read(videoPlaybackStateProvider.notifier);
    final state = ref.read(videoPlaybackStateProvider);
    notifier.setResult(
      state.copyWith(
        position: clampedMs,
        duration: durationMs > 0 ? durationMs : state.duration,
        currentFrame: targetFrame,
      ),
    );

    _enqueueSeek(clampedMs);
  }

  Future<void> _enqueueSeek(int targetMs) async {
    _pendingSeekMs = targetMs;
    if (_isSeeking) return;
    _isSeeking = true;
    try {
      while (_pendingSeekMs != null && mounted && _manager != null) {
        final ms = _pendingSeekMs!;
        _pendingSeekMs = null;
        await _manager!.activeController.seekTo(Duration(milliseconds: ms));
      }
      // Sync inactive controller once seeking settles so mode switch is instant
      if (mounted && _manager != null) {
        final inactive = (_manager!.activeController == _manager!.controller)
            ? _manager!.focusController
            : _manager!.controller;
        if (inactive != null && inactive.value.isInitialized) {
          final settleMs = (_virtualPositionMs ??
                  _manager!.activeController.value.position.inMilliseconds.toDouble())
              .round();
          inactive.seekTo(Duration(milliseconds: settleMs));
        }
      }
    } finally {
      _isSeeking = false;
    }
  }

  void _onVideoTick() {
    if (_manager == null || !mounted) return;
    final value = _manager!.activeController.value;
    final notifier = ref.read(videoPlaybackStateProvider.notifier);
    final state = ref.read(videoPlaybackStateProvider);
    if (state.isDragging) return;

    // While paused and recently stepped manually, keep the exact virtual position
    // so asynchronous decoder lag doesn't snap the slider backwards.
    if (!value.isPlaying &&
        _virtualPositionMs != null &&
        _lastManualStepTime != null &&
        DateTime.now().difference(_lastManualStepTime!).inMilliseconds < 600) {
      return;
    }

    if (value.isPlaying) {
      _virtualPositionMs = null;
    }

    final posMs = value.position.inMilliseconds;
    final durMs = value.duration.inMilliseconds;
    final effectiveFps = widget.fps > 0 ? widget.fps : 60;
    final frameIdx = ((posMs / 1000.0) * effectiveFps).round();

    notifier.setResult(
      state.copyWith(
        position: posMs,
        duration: durMs > 0 ? durMs : state.duration,
        currentFrame: frameIdx,
      ),
    );
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _manager?.controller.removeListener(_onVideoTick);
    _manager?.focusController?.removeListener(_onVideoTick);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final managerProvider = ref.watch(videoManagerProvider(widget.videoId));
    final focusTrackAsync = ref.watch(focusTrackProvider(widget.videoId));
    final focusTrack = focusTrackAsync.asData?.value;
    final hasFocusTrack = ( _manager?.hasFocusVideo ?? false ) ||
        (focusTrack != null && focusTrack.frames.isNotEmpty);
    final currentZoom = _effectiveZoom(focusTrack);
    final extraScale = _zoomMultipliers[_zoomPresetIdx];
    final isZh = Localizations.localeOf(context).languageCode.startsWith('zh');

    managerProvider.whenData((manager) {
      if (_manager != manager) {
        Future.microtask(() {
          if (!mounted) return;
          _manager?.controller.removeListener(_onVideoTick);
          _manager?.focusController?.removeListener(_onVideoTick);
          _manager = manager;
          _manager!.controller.addListener(_onVideoTick);
          _manager!.focusController?.addListener(_onVideoTick);
          _onVideoTick();
        });
      }
    });

    final activeCtrl = _manager?.activeController;
    final isPlaying = activeCtrl?.value.isPlaying ?? false;

    return Column(
      children: [
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(25),
              topRight: Radius.circular(25),
            ),
            color: Theme.of(context).primaryColor,
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: AsyncValueWidget(
                value: managerProvider,
                loading: const VideoPlayerShimmer(),
                error: (error, stack) {
                  return Container(
                    height: 250,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.close, size: 64, color: Colors.white.withValues(alpha: 0.8)),
                        Text(
                          'Error loading video',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                        ),
                      ],
                    ),
                  );
                },
                data: (manager) {
                  final canFocusThisSession = manager.hasFocusVideo || hasFocusTrack;
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      GestureDetector(
                        onTap: _togglePlayPause,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            AbsorbPointer(
                              child: AspectRatio(
                                aspectRatio: manager.controller.value.aspectRatio,
                                child: ClipRect(
                                  child: manager.hasFocusVideo && manager.focusController != null
                                      ? Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            Opacity(
                                              opacity: _isRunnerFocus ? 0.0 : 1.0,
                                              child: VideoPlayer(manager.controller),
                                            ),
                                            Opacity(
                                              opacity: _isRunnerFocus ? 1.0 : 0.0,
                                              child: Transform.scale(
                                                scale: _isRunnerFocus ? extraScale : 1.0,
                                                alignment: Alignment.center,
                                                child: VideoPlayer(manager.focusController!),
                                              ),
                                            ),
                                          ],
                                        )
                                      : VideoPlayer(manager.controller),
                                ),
                              ),
                            ),
                            ValueListenableBuilder<VideoPlayerValue>(
                              valueListenable: manager.activeController,
                              builder: (context, value, _) {
                                return AnimatedOpacity(
                                  duration: const Duration(milliseconds: 200),
                                  opacity: value.isPlaying ? 0.0 : 1.0,
                                  child: const Icon(
                                    Icons.play_arrow,
                                    size: 64,
                                    color: Color.fromARGB(123, 255, 255, 255),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      if (canFocusThisSession)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isRunnerFocus) ...[
                                Material(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(18),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(18),
                                    onTap: _cycleFocusZoom,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      child: Text(
                                        '${currentZoom.toStringAsFixed(1)}x',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Material(
                                color: _isRunnerFocus
                                    ? Colors.amber.shade700.withValues(alpha: 0.9)
                                    : Colors.black.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(18),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: _toggleRunnerFocus,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _isRunnerFocus
                                              ? Icons.center_focus_strong_rounded
                                              : Icons.crop_free_rounded,
                                          size: 16,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          _isRunnerFocus
                                              ? (isZh ? '跑者聚焦' : 'Runner Focus')
                                              : (isZh ? '全畫面' : 'Full Video'),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        if (_manager != null)
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: _manager!.activeController,
            builder: (context, value, _) {
              return VideoSliderView(
                fps: widget.fps,
                isPlaying: value.isPlaying,
                onTogglePlay: _togglePlayPause,
                onStepFrames: _stepByFrames,
                onSeek: _seekToPositionMs,
                canToggleFocus: _manager!.hasFocusVideo || hasFocusTrack,
                isRunnerFocus: _isRunnerFocus,
                onToggleFocus: _toggleRunnerFocus,
                focusZoom: currentZoom,
                onCycleZoom: _cycleFocusZoom,
              );
            },
          )
        else
          VideoSliderView(
            fps: widget.fps,
            isPlaying: isPlaying,
            onTogglePlay: _togglePlayPause,
            onStepFrames: _stepByFrames,
            onSeek: _seekToPositionMs,
            canToggleFocus: hasFocusTrack,
            isRunnerFocus: _isRunnerFocus,
            onToggleFocus: _toggleRunnerFocus,
            focusZoom: currentZoom,
            onCycleZoom: _cycleFocusZoom,
          ),
      ],
    );
  }
}
