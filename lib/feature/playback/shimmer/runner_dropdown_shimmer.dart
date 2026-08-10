import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class RunnerDropdownShimmer extends StatelessWidget {
  const RunnerDropdownShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Theme.of(context).primaryColorDark,
      highlightColor: Theme.of(context).primaryColor.withValues(alpha: 0.3),
      child: Container(
        height: 50,
        width: double.infinity,
        padding: const EdgeInsets.only(left: 12, right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black26),
        ),
        child: const Row(
          children: [
            Icon(Icons.people, size: 16),
            SizedBox(width: 4),
            Expanded(
              child: Text(
                '選擇選手',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.arrow_forward_ios_outlined, size: 12),
          ],
        ),
      ),
    );
  }
}
