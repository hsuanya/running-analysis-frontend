import 'package:flutter/material.dart';
import 'package:frontend/utils/locale_provider.dart';
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
        child: Row(
          children: [
            const Icon(Icons.people, size: 16),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                context.l10n.selectRunner,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_forward_ios_outlined, size: 12),
          ],
        ),
      ),
    );
  }
}
