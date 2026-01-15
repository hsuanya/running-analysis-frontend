import 'package:flutter/material.dart';
import 'package:frontend/feature/playback/placeholder/one_graph_placeholder_item.dart';
import 'package:shimmer/shimmer.dart';

class GraphListShimmer extends StatelessWidget {
  const GraphListShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final titles = ["Distance", "Velocity", "Acceleration"];
    final yLabels = ["Distance(m)", "Velocity(m/s)", "Acceleration(m/s^2)"];

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      itemBuilder: (context, index) => Container(
        padding: EdgeInsets.only(top: 8, bottom: 4, left: 12, right: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          color: Theme.of(context).primaryColor,
        ),
        child: Shimmer.fromColors(
          baseColor: Theme.of(context).primaryColorDark.withValues(alpha: 0.5),
          highlightColor: Colors.white,
          child: OneGraphPlaceholderItem(
            title: titles[index],
            yLabel: yLabels[index],
          ),
        ),
      ),
    );
  }
}
