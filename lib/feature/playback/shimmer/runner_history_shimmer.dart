import 'package:flutter/material.dart';
import 'package:frontend/feature/playback/placeholder/runner_history_placeholder.dart';
import 'package:shimmer/shimmer.dart';

class RunnerHistoryShimmer extends StatelessWidget {
  const RunnerHistoryShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Theme.of(context).primaryColorDark.withValues(alpha: 0.5),
      highlightColor: Colors.white,
      child: const RunnerHistoryPlaceholder(),
    );
  }
}
