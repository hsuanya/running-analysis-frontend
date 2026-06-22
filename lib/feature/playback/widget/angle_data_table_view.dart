import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/backend/backend_provider.dart';
import 'package:frontend/entities/angle_data.dart';
import 'package:frontend/feature/playback/playback_provider.dart';
import 'package:frontend/widget/async_value_widget.dart';

class AngleDataTableView extends ConsumerWidget {
  const AngleDataTableView({super.key});

  static const Map<String, String> _labels = {
    'left_knee_angle': '左膝',
    'right_knee_angle': '右膝',
    'left_hip_angle': '左髖',
    'right_hip_angle': '右髖',
    'left_arm_torso_angle': '左臂軀幹',
    'right_arm_torso_angle': '右臂軀幹',
    'left_elbow_flexion_angle': '左手肘',
    'right_elbow_flexion_angle': '右手肘',
    'left_shoulder_flexion': '左肩',
    'right_shoulder_flexion': '右肩',
    'pelvis_torso_angle': '骨盆軀幹',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoId = ref.watch(playbackSelectedRunSessionIdProvider);
    if (videoId == null || videoId.isEmpty) return const SizedBox.shrink();

    final videoInfo = ref.watch(videoInfoProvider(videoId));
    final isProcessing = videoInfo.maybeWhen(
      data: (info) => info.status == 'processing',
      orElse: () => false,
    );
    if (isProcessing) return const SizedBox.shrink();

    final angleData = ref.watch(angleDataProvider(videoId));
    return AsyncValueWidget(
      value: angleData,
      loading: const SizedBox(
        height: 96,
        child: Center(child: CircularProgressIndicator()),
      ),
      data: (AngleData data) {
        if (data.samples.isEmpty || data.columns.isEmpty) {
          return const SizedBox.shrink();
        }

        final columns = data.columns
            .where(
              (column) => data.samples.any((s) => s.values[column] != null),
            )
            .toList();

        return Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: false,
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 4,
            ),
            leading: const Icon(
              Icons.table_chart_rounded,
              color: Colors.white70,
              size: 22,
            ),
            title: const Text(
              'Angle Data',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              '${data.samples.length} frames',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            iconColor: Colors.white70,
            collapsedIconColor: Colors.white54,
            children: [
              SizedBox(
                height: 360,
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8, right: 8),
                      child: SizedBox(
                        width: _tableWidth(columns.length),
                        child: Column(
                          children: [
                            _headerRow(context, columns),
                            Expanded(
                              child: ListView.builder(
                                padding: const EdgeInsets.only(bottom: 12),
                                itemCount: data.samples.length,
                                itemBuilder: (context, index) {
                                  final sample = data.samples[index];
                                  return _dataRow(context, sample, columns);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatAngle(double? value) {
    if (value == null) return '-';
    return '${value.toStringAsFixed(1)}°';
  }

  double _tableWidth(int angleColumnCount) {
    return 96 + angleColumnCount * 96;
  }

  Widget _headerRow(BuildContext context, List<String> columns) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColorDark.withValues(alpha: 0.35),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
        ),
      ),
      child: Row(
        children: [
          _cell('時間', width: 96, isHeader: true),
          for (final column in columns)
            _cell(_labels[column] ?? column, width: 96, isHeader: true),
        ],
      ),
    );
  }

  Widget _dataRow(
    BuildContext context,
    AngleSample sample,
    List<String> columns,
  ) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          _cell('${sample.timeSec.toStringAsFixed(3)} s', width: 96),
          for (final column in columns)
            _cell(_formatAngle(sample.values[column]), width: 96),
        ],
      ),
    );
  }

  Widget _cell(String text, {required double width, bool isHeader = false}) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isHeader ? Colors.white : Colors.white70,
            fontSize: isHeader ? 13 : 12,
            fontWeight: isHeader ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
