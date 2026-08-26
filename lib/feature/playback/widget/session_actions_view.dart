import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/backend/backend_provider.dart';
import 'package:frontend/entities/run_session_info.dart';
import 'package:frontend/feature/playback/playback_provider.dart';
import 'package:frontend/widget/async_value_widget.dart';
import 'package:frontend/utils/download_helper/download_helper.dart';

class SessionActionsView extends ConsumerWidget {
  const SessionActionsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runnerId = ref.watch(playbackSelectedRunnerIdProvider);
    final videoId = ref.watch(playbackSelectedRunSessionIdProvider);
    if (runnerId == null || videoId == null) {
      return const SizedBox.shrink();
    }

    final videoInfo = ref.watch(videoInfoProvider(videoId));
    return AsyncValueWidget(
      value: videoInfo,
      loading: const SizedBox.shrink(),
      data: (RunSessionInfo video) {
        if (video.status == 'processing') {
          return const SizedBox.shrink();
        }

        final isDone = video.status == 'done';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6.0),
              child: Center(
                child: Text(
                  "操作",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const Divider(color: Colors.white, thickness: 3.0, height: 3.0),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isDone
                              ? () async {
                                  final filename =
                                      "Runner_Analysis_Report_${video.runSessionId}.pdf";
                                  final backend = ref.read(backendProvider);
                                  final bytes = await backend
                                      .getRunSessionPdf(video.runSessionId);
                                  await saveBytesToFile(bytes, filename);
                                }
                              : null,
                          icon: const Icon(
                            Icons.picture_as_pdf,
                            color: Colors.white,
                            size: 18,
                          ),
                          label: const Text(
                            "下載 PDF 報告",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(
                              255,
                              121,
                              169,
                              234,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isDone
                              ? () async {
                                  final filename =
                                      "angles_${video.runSessionId}.csv";
                                  final backend = ref.read(backendProvider);
                                  final bytes = await backend
                                      .getRunSessionCsv(video.runSessionId);
                                  await saveBytesToFile(bytes, filename);
                                }
                              : null,
                          icon: const Icon(
                            Icons.table_chart,
                            color: Colors.white,
                            size: 18,
                          ),
                          label: const Text(
                            "下載 CSV 數據",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal[400],
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text("確認刪除"),
                          content: const Text("您確定要永久刪除此分析紀錄與所有影片檔案嗎？此操作無法還原。"),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text("取消"),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              child: const Text("刪除"),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("正在刪除紀錄...")),
                        );
                        try {
                          final backend = ref.read(backendProvider);
                          await backend.deleteRunSession(video.runSessionId);

                          // 1. Fetch updated history list to select another session
                          final history = await backend.getRunnerHistory(
                            video.runnerId,
                          );

                          // 2. Select next available session or null
                          if (history.isNotEmpty) {
                            ref
                                .read(
                                  playbackSelectedRunSessionIdProvider.notifier,
                                )
                                .state = history
                                .last
                                .runSessionId;
                          } else {
                            ref
                                    .read(
                                      playbackSelectedRunSessionIdProvider
                                          .notifier,
                                    )
                                    .state =
                                null;
                          }

                          // 3. Invalidate history provider to update UI list
                          ref.invalidate(runnerHistoryProvider(video.runnerId));

                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).clearSnackBars();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("紀錄已成功刪除")),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text("刪除失敗: $e")));
                        }
                      }
                    },
                    icon: const Icon(
                      Icons.delete,
                      color: Colors.white,
                      size: 18,
                    ),
                    label: const Text(
                      "刪除此次紀錄",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
