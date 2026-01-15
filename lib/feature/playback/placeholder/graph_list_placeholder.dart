import 'package:flutter/material.dart';
import 'package:frontend/feature/playback/placeholder/one_graph_placeholder_item.dart';

class GraphListPlaceholder extends StatelessWidget {
  const GraphListPlaceholder({super.key, this.itemCount = 3});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final titles = ["Distance", "Velocity", "Acceleration"];
    final yLabels = ["Distance(m)", "Velocity(m/s)", "Acceleration(m/s^2)"];

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) => Container(
        padding: EdgeInsets.only(top: 8, bottom: 4, left: 12, right: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          color: Theme.of(context).primaryColor,
        ),
        child: OneGraphPlaceholderItem(
          title: titles[index],
          yLabel: yLabels[index],
        ),
      ),
    );
  }
}
