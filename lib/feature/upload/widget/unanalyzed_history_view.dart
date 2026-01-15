import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/backend/backend_provider.dart';
import 'package:frontend/entities/unanalyzed_run_session_info.dart';
import 'package:frontend/feature/upload/upload_provider.dart';
import 'package:frontend/widget/async_value_widget.dart';
import 'package:frontend/feature/playback/shimmer/runner_history_shimmer.dart';
import 'package:intl/intl.dart';

class UnanalyzedHistoryView extends ConsumerWidget {
  const UnanalyzedHistoryView({super.key, required this.onVideoSelected});

  final Function(UnanalyzedRunSessionInfo video) onVideoSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runnerId = ref.watch(uploadSelectedRunnerIdProvider);
    final videoId = ref.watch(uploadSelectedRunSessionIdProvider);
    if (runnerId == null) {
      return const SizedBox.shrink();
    }

    final runnerHistory = ref.watch(runnerUnanalyzedHistoryProvider(runnerId));
    return AsyncValueWidget(
      value: runnerHistory,
      loading: const RunnerHistoryShimmer(),
      data: (List<UnanalyzedRunSessionInfo> videos) {
        if (videos.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              "目前沒有未分析的紀錄",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                fontFamily: 'Noto Sans TC',
              ),
            ),
          );
        }

        final List<String> headers = ["日期時間", "攝影機數量", "備註"];
        final List<List<String>> values = [
          videos
              .map(
                (video) => DateFormat('yyyy-MM-dd HH:mm:ss').format(video.date),
              )
              .toList(),
          videos.map((video) => video.cameraCount.toString()).toList(),
          videos.map((video) => video.note).toList(),
        ];

        return LayoutBuilder(
          builder: (context, constraints) {
            double percentage;
            if (constraints.maxWidth < 1000) {
              percentage = 1;
            } else {
              percentage = 0.5;
            }
            return Container(
              width: constraints.maxWidth * percentage,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(25),
                color: Theme.of(context).primaryColor,
              ),
              child: Table(
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
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
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
                            ? const Color.fromARGB(255, 80, 143, 232)
                            : Colors.transparent,
                      ),
                      children: [
                        for (int j = 0; j < values.length; j++)
                          TableRowInkWell(
                            onTap: () {
                              final video = videos[i];
                              ref
                                  .read(
                                    uploadSelectedRunSessionIdProvider.notifier,
                                  )
                                  .state = video
                                  .runSessionId;
                              onVideoSelected(video);
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
              ),
            );
          },
        );
      },
    );
  }
}
