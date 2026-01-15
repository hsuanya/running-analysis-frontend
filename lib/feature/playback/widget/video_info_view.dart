import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/backend/backend_provider.dart';
import 'package:frontend/entities/run_session_info.dart';
import 'package:frontend/feature/playback/placeholder/video_info_placeholder.dart';
import 'package:frontend/feature/playback/playback_provider.dart';
import 'package:frontend/widget/async_value_widget.dart';
import 'package:frontend/feature/playback/shimmer/video_info_shimmer.dart';
import 'package:intl/intl.dart';

import 'package:frontend/widget/processing_progress_widget.dart';

class VideoInfoView extends ConsumerWidget {
  const VideoInfoView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runnerId = ref.watch(playbackSelectedRunnerIdProvider);
    final videoId = ref.watch(playbackSelectedRunSessionIdProvider);
    if (runnerId == null || videoId == null) {
      return const VideoInfoPlaceholder();
    }

    final videoInfo = ref.watch(videoInfoProvider(videoId));
    return AsyncValueWidget(
      value: videoInfo,
      loading: const VideoInfoShimmer(),
      data: (RunSessionInfo video) {
        if (video.status == 'processing') {
          return Stack(
            alignment: Alignment.center,
            children: [
              const VideoInfoShimmer(),
              ProcessingProgressWidget(progress: video.progress),
            ],
          );
        }
        final List<String> headers = [
          "選手姓名",
          "日期時間",
          "相機數量",
          "fps",
          "平均速度",
          "平均加速度",
          "平均步幅",
          "總時間",
          "備註",
        ];
        final List<String> values = [
          video.runnerName,
          DateFormat('yyyy-MM-dd HH:mm:ss').format(video.date),
          video.cameraCount.toString(),
          video.fps.toString(),
          video.avgVelocity.toString(),
          video.avgAcceleration.toString(),
          video.avgStepLength.toString(),
          video.totalTime.toString(),
          video.note,
        ];

        return Table(
          border: TableBorder(
            horizontalInside: BorderSide(
              width: 3,
              color: Colors.white,
            ), // 只要橫向分隔線
            verticalInside: BorderSide(width: 3, color: Colors.white),
            top: BorderSide.none, // 不要最上面
            bottom: BorderSide.none, // 不要最下面
            left: BorderSide.none, // 不要最左邊
            right: BorderSide.none, // 不要最右邊
          ),
          columnWidths: const {
            0: FixedColumnWidth(200), // Rep 欄固定 60px
            1: FlexColumnWidth(), // Error 欄自動填滿
          },
          children: [
            // 表格內容
            for (int i = 0; i < headers.length; i++)
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Text(
                      headers[i],
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis, // 單行，不換行
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Text(
                      values[i],
                      textAlign: TextAlign.center,
                      softWrap: true, // 允許換行
                    ),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }
}
