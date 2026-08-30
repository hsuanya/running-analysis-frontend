import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/backend/backend_provider.dart';
import 'package:frontend/entities/runner_info.dart';
import 'package:frontend/feature/trial_review/trial_review_provider.dart';
import 'package:frontend/feature/trial_review/widget/current_trial_summary_header.dart';
import 'package:frontend/feature/trial_review/widget/metrics_panel.dart';
import 'package:frontend/feature/trial_review/widget/triple_video_panel.dart';
import 'package:frontend/feature/trial_review/widget/topdown_review_panel.dart';
import 'package:frontend/widget/async_value_widget.dart';

class TrialReviewPage extends ConsumerStatefulWidget {
  const TrialReviewPage({super.key, this.runnerId, this.videoId});

  final String? runnerId;
  final String? videoId;

  @override
  ConsumerState<TrialReviewPage> createState() => _TrialReviewPageState();
}

class _TrialReviewPageState extends ConsumerState<TrialReviewPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (widget.runnerId != null && widget.videoId != null) {
        ref.read(trialReviewSelectedRunSessionIdProvider.notifier).state =
            widget.videoId;
        ref.read(trialReviewSelectedRunnerIdProvider.notifier).state =
            widget.runnerId;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final runners = ref.watch(runnerProvider);
    final selectedRunnerId = ref.watch(trialReviewSelectedRunnerIdProvider);
    final selectedRunSessionId = ref.watch(
      trialReviewSelectedRunSessionIdProvider,
    );
    final runnerSelector = AsyncValueWidget(
      value: runners,
      loading: const SizedBox(
        height: 50,
        width: 160,
        child: Center(child: CircularProgressIndicator()),
      ),
      data: (List<RunnerInfo> items) {
        return DropdownButtonHideUnderline(
          child: DropdownButton2<String>(
            isExpanded: false,
            hint: const Text('選擇選手'),
            items: items
                .map(
                  (item) => DropdownMenuItem<String>(
                    value: item.id,
                    child: Text(item.name),
                  ),
                )
                .toList(),
            value: selectedRunnerId,
            onChanged: (value) {
              ref.read(trialReviewSelectedRunnerIdProvider.notifier).state =
                  value;
              ref.read(trialReviewSelectedRunSessionIdProvider.notifier).state =
                  items.firstWhere((item) => item.id == value).lastVideoId;
            },
            buttonStyleData: ButtonStyleData(
              height: 50,
              width: 200,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.black26),
              ),
            ),
          ),
        );
      },
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final summary =
                  selectedRunSessionId == null || selectedRunSessionId.isEmpty
                  ? null
                  : CurrentTrialSummaryHeader(
                      key: ValueKey('summary-$selectedRunSessionId'),
                      runSessionId: selectedRunSessionId,
                    );

              if (constraints.maxWidth >= 900) {
                return Row(
                  children: [
                    Expanded(flex: 4, child: Center(child: runnerSelector)),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 5,
                      child: summary ?? const SizedBox.shrink(),
                    ),
                  ],
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  runnerSelector,
                  if (summary != null) ...[const SizedBox(height: 8), summary],
                ],
              );
            },
          ),
        ),
        Expanded(
          child: selectedRunSessionId == null || selectedRunSessionId.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      '請先選擇選手與試跳紀錄',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 900;
                      // Fewer than 3 cameras don't need the video panel's
                      // full flex:3 height share on narrow screens -- see
                      // TripleVideoPanel's matching "< 3 cameras" case. Only
                      // known once videoInfoProvider resolves; the flex:3
                      // split is used as the safe default until then.
                      final cameraCount = ref
                          .watch(videoInfoProvider(selectedRunSessionId))
                          .value
                          ?.cameraCount;
                      final isCompact = cameraCount != null && cameraCount < 3;
                      final videoPanel = TripleVideoPanel(
                        key: ValueKey('video-$selectedRunSessionId'),
                        runSessionId: selectedRunSessionId,
                      );
                      final metricsPanel = MetricsPanel(
                        key: ValueKey('metrics-$selectedRunSessionId'),
                        runSessionId: selectedRunSessionId,
                      );
                      final metricsWorkspace = Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Top-down replay is optional and opens in a dialog,
                          // so it never displaces CAM1–CAM3.
                          TopdownReviewPanel(
                            key: ValueKey('topdown-$selectedRunSessionId'),
                            runSessionId: selectedRunSessionId,
                          ),
                          Expanded(
                            child: Scrollbar(
                              child: SingleChildScrollView(child: metricsPanel),
                            ),
                          ),
                        ],
                      );

                      if (isWide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(flex: 4, child: videoPanel),
                            const SizedBox(width: 16),
                            Expanded(flex: 5, child: metricsWorkspace),
                          ],
                        );
                      }

                      // On narrow screens both work areas remain bounded by
                      // the viewport; the camera stack gets priority when
                      // there's a full 3 cameras to fit. Fewer than that
                      // doesn't need the reserved height (see
                      // TripleVideoPanel/SingleCameraPanel), so let it size
                      // to its own content and hand the rest to metrics.
                      return isCompact
                          ? Column(
                              children: [
                                videoPanel,
                                const SizedBox(height: 12),
                                Expanded(child: metricsWorkspace),
                              ],
                            )
                          : Column(
                              children: [
                                Expanded(flex: 3, child: videoPanel),
                                const SizedBox(height: 12),
                                Expanded(flex: 2, child: metricsWorkspace),
                              ],
                            );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}
