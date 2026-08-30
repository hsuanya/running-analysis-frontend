import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/feature/trial_review/trial_review_provider.dart';
import 'package:frontend/utils/api.dart';
import 'package:video_player/video_player.dart';

/// Optional top-down (homography-rectified) replay, only available for
/// sessions that were 6-point calibrated and successfully exported a
/// review video (see routes/trial_review.py's
/// GET .../topdown_review/{camera_index}). Opens in a dialog rather than a
/// panel slot so it never displaces CAM1-3 when unavailable -- renders
/// nothing at all if no camera has one.
class TopdownReviewPanel extends ConsumerWidget {
  final String runSessionId;

  const TopdownReviewPanel({super.key, required this.runSessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final indicesAsync = ref.watch(
      topdownReviewCameraIndicesProvider(runSessionId),
    );
    final indices = indicesAsync.value ?? const <int>[];
    if (indices.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: OutlinedButton.icon(
        icon: const Icon(Icons.view_in_ar_outlined),
        label: const Text('查看俯視回放'),
        onPressed: () => showDialog(
          context: context,
          builder: (context) => _TopdownReviewDialog(
            runSessionId: runSessionId,
            cameraIndices: indices,
          ),
        ),
      ),
    );
  }
}

class _TopdownReviewDialog extends StatefulWidget {
  final String runSessionId;
  final List<int> cameraIndices;

  const _TopdownReviewDialog({
    required this.runSessionId,
    required this.cameraIndices,
  });

  @override
  State<_TopdownReviewDialog> createState() => _TopdownReviewDialogState();
}

class _TopdownReviewDialogState extends State<_TopdownReviewDialog> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    final url = API.getTopdownReviewVideo(
      widget.runSessionId,
      widget.cameraIndices.first,
    );
    _controller = VideoPlayerController.networkUrl(Uri.parse(url))
      ..initialize().then((_) {
        if (mounted) setState(() {});
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              // Rectified top-down runway strips are very wide/flat --
              // 16:5 is a reasonable placeholder while the real video
              // hasn't reported its own size yet.
              aspectRatio: _controller.value.isInitialized
                  ? (_controller.value.aspectRatio == 0
                        ? 16 / 5
                        : _controller.value.aspectRatio)
                  : 16 / 5,
              child: _controller.value.isInitialized
                  ? VideoPlayer(_controller)
                  : const Center(child: CircularProgressIndicator()),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('關閉'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
