import 'package:flutter/material.dart';
import 'package:frontend/feature/playback/placeholder/video_info_placeholder.dart';
import 'package:shimmer/shimmer.dart';

class VideoInfoShimmer extends StatelessWidget {
  const VideoInfoShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Theme.of(context).primaryColorDark.withValues(alpha: 0.5),
      highlightColor: Colors.white,
      child: VideoInfoPlaceholder(),
    );
  }
}
