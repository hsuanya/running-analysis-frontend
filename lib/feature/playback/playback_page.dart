import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:frontend/backend/backend_provider.dart';
import 'package:frontend/entities/runner_info.dart';
import 'package:frontend/feature/playback/playback_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/feature/playback/widget/video_player_view.dart';
import 'package:frontend/widget/async_value_widget.dart';
import 'package:frontend/feature/playback/widget/graph_list_view.dart';
import 'package:frontend/feature/playback/widget/runner_history_view.dart';
import 'package:frontend/feature/playback/widget/video_info_view.dart';
import 'package:frontend/feature/playback/widget/session_actions_view.dart';
import 'package:frontend/widget/rounded_box_widget.dart';
import 'package:shimmer/shimmer.dart';

class PlaybackPage extends ConsumerStatefulWidget {
  const PlaybackPage({super.key, this.runnerId, this.videoId});

  final String? runnerId;
  final String? videoId;

  @override
  ConsumerState<PlaybackPage> createState() => _PlaybackPageState();
}

class _PlaybackPageState extends ConsumerState<PlaybackPage> {
  @override
  void initState() {
    super.initState();

    Future.microtask(() {
      if (widget.runnerId != null && widget.videoId != null) {
        ref.read(playbackSelectedRunSessionIdProvider.notifier).state =
            widget.videoId;
        ref.read(playbackSelectedRunnerIdProvider.notifier).state =
            widget.runnerId;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final runners = ref.watch(runnerProvider);
    final selectedRunnerId = ref.watch(playbackSelectedRunnerIdProvider);
    final selectedVideoId = ref.watch(playbackSelectedRunSessionIdProvider);

    // Validate runner ID against the runner list when loaded
    final activeRunnerId = runners.when(
      data: (items) {
        final isRunnerIdValid = items.any((r) => r.id == selectedRunnerId);
        if (!isRunnerIdValid && selectedRunnerId != null && selectedRunnerId.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ref.read(playbackSelectedRunnerIdProvider.notifier).state =
                items.isNotEmpty ? items.first.id : null;
            ref.read(playbackSelectedRunSessionIdProvider.notifier).state =
                items.isNotEmpty ? items.first.lastVideoId : null;
            context.go('/playback');
          });
          return items.isNotEmpty ? items.first.id : null;
        }
        return selectedRunnerId;
      },
      error: (_, __) => null,
      loading: () => null,
    );

    // Validate video ID against the runner's history list when loaded
    if (activeRunnerId != null) {
      ref.watch(runnerHistoryProvider(activeRunnerId)).whenData((history) {
        if (selectedVideoId != null && selectedVideoId.isNotEmpty) {
          if (!history.any((s) => s.runSessionId == selectedVideoId)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              ref.read(playbackSelectedRunSessionIdProvider.notifier).state =
                  history.isNotEmpty ? history.last.runSessionId : null;
              context.go('/playback');
            });
          }
        }
      });
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // 小螢幕 1 欄，大螢幕 2 欄
        final crossAxisCount = constraints.maxWidth < 800 ? 1 : 2;

        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(left: 12, right: 12, top: 12),
                child: AsyncValueWidget(
                  value: runners,
                  loading: Shimmer.fromColors(
                    baseColor: Theme.of(context).primaryColorDark,
                    highlightColor: Theme.of(
                      context,
                    ).primaryColor.withValues(alpha: 0.3),
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
                          const Expanded(
                            child: Text(
                              '選擇選手',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios_outlined, size: 12),
                        ],
                      ),
                    ),
                  ),
                  data: (List<RunnerInfo> items) {
                    final selectedRunnerName = items
                        .firstWhere(
                          (runner) => runner.id == activeRunnerId,
                          orElse: () =>
                              RunnerInfo(id: '', name: '', lastVideoId: ''),
                        )
                        .name;

                    return Row(
                      children: [
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton2<String>(
                              isExpanded: true,
                              hint: const Row(
                                children: [
                                  Icon(Icons.people, size: 16),
                                  SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      '選擇選手',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              items: items
                                  .map(
                                    (RunnerInfo item) =>
                                        DropdownMenuItem<String>(
                                          value: item.id,
                                          child: Text(
                                            item.name,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                  )
                                  .toList(),
                              value: activeRunnerId,
                              onChanged: (value) {
                                setState(() {
                                  ref
                                          .read(
                                            playbackSelectedRunnerIdProvider
                                                .notifier,
                                          )
                                          .state =
                                      value;
                                });
                                ref
                                    .read(
                                      playbackSelectedRunSessionIdProvider
                                          .notifier,
                                    )
                                    .state = items
                                    .firstWhere((item) => item.id == value)
                                    .lastVideoId;
                              },
                              buttonStyleData: ButtonStyleData(
                                height: 50,
                                padding: const EdgeInsets.only(
                                  left: 12,
                                  right: 12,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.black26),
                                ),
                              ),
                              iconStyleData: const IconStyleData(
                                icon: Icon(Icons.arrow_forward_ios_outlined),
                                iconSize: 12,
                              ),
                              dropdownStyleData: DropdownStyleData(
                                maxHeight: 200,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                offset: const Offset(0, 0),
                                scrollbarTheme: ScrollbarThemeData(
                                  radius: const Radius.circular(40),
                                ),
                              ),
                              menuItemStyleData: const MenuItemStyleData(
                                height: 40,
                                padding: EdgeInsets.only(left: 12, right: 12),
                              ),
                            ),
                          ),
                        ),
                        if (selectedRunnerId != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text("確認刪除選手"),
                                  content: Text(
                                    "您確定要永久刪除選手「$selectedRunnerName」嗎？這將會刪除該選手以及他所有的歷史跑步紀錄與分析檔案！此操作無法還原。",
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: const Text("取消"),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
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
                                  const SnackBar(content: Text("正在刪除選手...")),
                                );

                                try {
                                  final backend = ref.read(backendProvider);
                                  await backend.deleteRunner(selectedRunnerId);

                                  ref
                                          .read(
                                            playbackSelectedRunnerIdProvider
                                                .notifier,
                                          )
                                          .state =
                                      null;
                                  ref
                                          .read(
                                            playbackSelectedRunSessionIdProvider
                                                .notifier,
                                          )
                                          .state =
                                      null;
                                  ref.invalidate(runnerProvider);

                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(
                                    context,
                                  ).clearSnackBars();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text("選手已成功刪除")),
                                  );
                                } catch (e) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("刪除失敗: $e")),
                                  );
                                }
                              }
                            },
                            icon: const Icon(
                              Icons.delete_forever,
                              color: Colors.redAccent,
                              size: 24,
                            ),
                            tooltip: "刪除此選手",
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
            if (selectedVideoId != null && selectedVideoId.isEmpty)
              const SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      "此跑者尚無歷史紀錄，請先上傳",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.all(12),
                sliver: SliverMasonryGrid(
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  gridDelegate: SliverSimpleGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                  ),
                  delegate: SliverChildListDelegate([
                    VideoPlayerView(),
                    GraphListView(),
                    RoundedBoxWidget(child: VideoInfoView()),
                    RoundedBoxWidget(child: SessionActionsView()),
                    RoundedBoxWidget(child: RunnerHistoryView()),
                  ]),
                ),
              ),
          ],
        );
      },
    );
  }
}
