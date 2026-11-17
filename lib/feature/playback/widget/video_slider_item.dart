import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/backend/video_playback_state_provider.dart';

class VideoSliderView extends ConsumerStatefulWidget {
  final void Function(int position) onSeek;
  final void Function(int deltaFrames)? onStepFrames;
  final VoidCallback? onTogglePlay;
  final bool isPlaying;
  final int fps;
  final Color? color;
  final bool canToggleFocus;
  final bool isRunnerFocus;
  final VoidCallback? onToggleFocus;
  final double? focusZoom;
  final VoidCallback? onCycleZoom;

  const VideoSliderView({
    super.key,
    required this.onSeek,
    this.onStepFrames,
    this.onTogglePlay,
    this.isPlaying = false,
    this.fps = 60,
    this.color,
    this.canToggleFocus = false,
    this.isRunnerFocus = false,
    this.onToggleFocus,
    this.focusZoom,
    this.onCycleZoom,
  });

  @override
  ConsumerState<VideoSliderView> createState() => _VideoSliderViewState();
}

class _VideoSliderViewState extends ConsumerState<VideoSliderView> {
  Timer? _holdTimer;
  final FocusNode _sliderFocusNode = FocusNode(
    canRequestFocus: false,
    skipTraversal: true,
  );

  @override
  void dispose() {
    _holdTimer?.cancel();
    _sliderFocusNode.dispose();
    super.dispose();
  }

  void _startContinuousStep(int deltaFrames) {
    _holdTimer?.cancel();
    widget.onStepFrames?.call(deltaFrames);
    _holdTimer = Timer.periodic(const Duration(milliseconds: 70), (_) {
      widget.onStepFrames?.call(deltaFrames);
    });
  }

  void _stopContinuousStep() {
    _holdTimer?.cancel();
    _holdTimer = null;
  }

  String _formatSeconds(int ms) {
    final sec = (ms.clamp(0, 3600000)) / 1000.0;
    return '${sec.toStringAsFixed(2)}s';
  }

  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(videoPlaybackStateProvider);
    final duration = playback.duration > 0 ? playback.duration : 1;
    final position = playback.position.clamp(0, duration);
    final isZh = Localizations.localeOf(context).languageCode.startsWith('zh');

    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(25),
          bottomRight: Radius.circular(25),
        ),
        color: widget.color ?? Theme.of(context).primaryColor,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              focusNode: _sliderFocusNode,
              min: 0,
              max: duration.toDouble(),
              value: position.toDouble(),
              thumbColor: Theme.of(context).primaryColorDark,
              activeColor: Theme.of(context).primaryColorDark,
              inactiveColor: Colors.white,
              onChangeStart: (_) {
                ref.read(videoPlaybackStateProvider.notifier).setDragging(true);
              },
              onChanged: (value) {
                ref.read(videoPlaybackStateProvider.notifier).setPosition(value.toInt());
              },
              onChangeEnd: (value) {
                ref.read(videoPlaybackStateProvider.notifier).setDragging(false);
                widget.onSeek(value.toInt());
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                // Left: Fine step controls + Play/Pause
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.onTogglePlay != null)
                      _StepButton(
                        icon: widget.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        tooltip: isZh ? '播放 / 暫停 (Space)' : 'Play / Pause (Space)',
                        onTap: widget.onTogglePlay!,
                      ),
                    const SizedBox(width: 4),
                    _StepButton(
                      icon: Icons.keyboard_double_arrow_left_rounded,
                      tooltip: isZh ? '快退 (Shift + ←)' : 'Rewind (Shift + ←)',
                      onTap: () => widget.onStepFrames?.call(-10),
                      onLongPressStart: () => _startContinuousStep(-5),
                      onLongPressEnd: _stopContinuousStep,
                    ),
                    const SizedBox(width: 4),
                    _StepButton(
                      icon: Icons.chevron_left_rounded,
                      tooltip: isZh ? '微調倒退 (←)' : 'Step backward (←)',
                      onTap: () => widget.onStepFrames?.call(-1),
                      onLongPressStart: () => _startContinuousStep(-1),
                      onLongPressEnd: _stopContinuousStep,
                    ),
                    const SizedBox(width: 4),
                    _StepButton(
                      icon: Icons.chevron_right_rounded,
                      tooltip: isZh ? '微調前進 (→)' : 'Step forward (→)',
                      onTap: () => widget.onStepFrames?.call(1),
                      onLongPressStart: () => _startContinuousStep(1),
                      onLongPressEnd: _stopContinuousStep,
                    ),
                    const SizedBox(width: 4),
                    _StepButton(
                      icon: Icons.keyboard_double_arrow_right_rounded,
                      tooltip: isZh ? '快進 (Shift + →)' : 'Fast forward (Shift + →)',
                      onTap: () => widget.onStepFrames?.call(10),
                      onLongPressStart: () => _startContinuousStep(5),
                      onLongPressEnd: _stopContinuousStep,
                    ),
                  ],
                ),

                // Right: Focus Mode toggle + Time readout
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.canToggleFocus && widget.onToggleFocus != null) ...[
                      Tooltip(
                        message: isZh
                            ? '切換「全畫面 / 跑者聚焦」視角 (F)'
                            : 'Toggle Full View / Runner Focus (F)',
                        child: Material(
                          color: widget.isRunnerFocus
                              ? Colors.amberAccent.withValues(alpha: 0.25)
                              : Colors.black.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: widget.onToggleFocus,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    widget.isRunnerFocus
                                        ? Icons.center_focus_strong_rounded
                                        : Icons.crop_free_rounded,
                                    size: 15,
                                    color: widget.isRunnerFocus ? Colors.amberAccent : Colors.white,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.isRunnerFocus
                                        ? (isZh ? '跑者聚焦' : 'Focus')
                                        : (isZh ? '全畫面' : 'Full'),
                                    style: TextStyle(
                                      color: widget.isRunnerFocus ? Colors.amberAccent : Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (widget.isRunnerFocus &&
                          widget.focusZoom != null &&
                          widget.onCycleZoom != null) ...[
                        const SizedBox(width: 4),
                        Tooltip(
                          message: isZh ? '切換聚焦倍率' : 'Cycle zoom level',
                          child: Material(
                            color: Colors.black.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: widget.onCycleZoom,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                                child: Text(
                                  '${widget.focusZoom!.toStringAsFixed(1)}x',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                    ],
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_formatSeconds(position)} / ${_formatSeconds(duration)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final VoidCallback? onLongPressStart;
  final VoidCallback? onLongPressEnd;

  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.onLongPressStart,
    this.onLongPressEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onLongPressStart: onLongPressStart != null ? (_) => onLongPressStart!() : null,
        onLongPressEnd: onLongPressEnd != null ? (_) => onLongPressEnd!() : null,
        onLongPressCancel: onLongPressEnd,
        child: Material(
          color: Colors.black.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(icon, size: 20, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
