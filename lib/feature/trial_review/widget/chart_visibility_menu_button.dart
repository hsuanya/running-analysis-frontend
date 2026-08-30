import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/feature/trial_review/trial_review_provider.dart';

/// Lets the user show/hide individual metrics-panel charts (①②③), so a
/// long parameter list can stay a single scroll instead of needing
/// pagination. Refuses to hide the last remaining visible chart so the
/// panel is never left completely empty.
class ChartVisibilityMenuButton extends ConsumerWidget {
  const ChartVisibilityMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visible = ref.watch(trialReviewVisibleChartsProvider);

    return PopupMenuButton<MetricsChartType>(
      icon: const Icon(Icons.tune),
      tooltip: '選擇要顯示的圖表',
      onSelected: (type) {
        final next = Set<MetricsChartType>.from(visible);
        if (next.contains(type)) {
          if (next.length <= 1) return; // never hide the last chart
          next.remove(type);
        } else {
          next.add(type);
        }
        ref.read(trialReviewVisibleChartsProvider.notifier).state = next;
      },
      itemBuilder: (context) => [
        for (final type in MetricsChartType.values)
          CheckedPopupMenuItem<MetricsChartType>(
            value: type,
            checked: visible.contains(type),
            child: Text(type.label),
          ),
      ],
    );
  }
}
