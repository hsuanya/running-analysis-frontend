import 'package:awesome_snackbar_content/awesome_snackbar_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/backend/backend_provider.dart';
import 'package:frontend/entities/run_session_info.dart';
import 'package:frontend/feature/playback/placeholder/runner_history_placeholder.dart';
import 'package:frontend/feature/playback/playback_provider.dart';
import 'package:frontend/widget/async_value_widget.dart';
import 'package:frontend/feature/playback/shimmer/runner_history_shimmer.dart';
import 'package:intl/intl.dart';

class RunnerHistoryView extends ConsumerWidget {
  const RunnerHistoryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runnerId = ref.watch(playbackSelectedRunnerIdProvider);
    final videoId = ref.watch(playbackSelectedRunSessionIdProvider);
    if (runnerId == null || videoId == null) {
      return const RunnerHistoryPlaceholder();
    }

    final runnerHistory = ref.watch(runnerHistoryProvider(runnerId));
    return AsyncValueWidget(
      value: runnerHistory,
      loading: const RunnerHistoryShimmer(),
      data: (List<RunSessionInfo> videos) {
        final List<String> headers = ["日期時間", "相機數量", "總時間", "備註"];
        final List<List<String>> values = [
          videos
              .map(
                (video) => DateFormat('yyyy-MM-dd HH:mm:ss').format(video.date),
              )
              .toList(),
          videos.map((video) => video.cameraCount.toString()).toList(),
          videos
              .map(
                (video) => video.status == 'processing'
                    ? '分析中...'
                    : (video.totalTime?.toString() ?? 'N/A'),
              )
              .toList(),
          videos.map((video) => video.note).toList(),
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
          children: [
            // 表格標題
            TableRow(
              children: headers
                  .map(
                    (header) => Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Text(
                        header,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis, // 單行，不換行
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                  .toList(),
            ),
            // 表格內容
            for (int i = 0; i < videos.length; i++)
              TableRow(
                decoration: BoxDecoration(
                  color: videoId == videos[i].runSessionId
                      ? Theme.of(context).primaryColorDark
                      : Colors.transparent,
                ),
                children: [
                  for (int j = 0; j < values.length; j++)
                    TableRowInkWell(
                      onTap: () {
                        final video = videos[i];
                        if (video.status == 'failed') {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: AwesomeSnackbarContent(
                                title: "分析失敗！",
                                message: "此次影片分析失敗，請重新上傳或聯繫開發者",
                                contentType: ContentType.failure,
                              ),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: Colors.transparent,
                              elevation: 0,
                            ),
                          );
                          return;
                        }
                        ref
                            .read(playbackSelectedRunSessionIdProvider.notifier)
                            .state = video
                            .runSessionId;
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4.0),
                        child: Text(
                          values[j][i],
                          textAlign: TextAlign.center,
                          softWrap: true, // 允許換行
                        ),
                      ),
                    ),
                ],
              ),

            TableRow(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                  bottomLeft: const Radius.circular(25),
                  bottomRight: const Radius.circular(25),
                ),
              ),
              children: [
                for (int i = 0; i < headers.length; i++)
                  Padding(padding: const EdgeInsets.all(12.0)),
              ],
            ),
          ],
        );
      },
    );
  }
}
