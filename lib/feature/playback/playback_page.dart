import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:frontend/backend/backend_provider.dart';
import 'package:frontend/entities/runner_info.dart';
import 'package:frontend/feature/playback/playback_provider.dart';
import 'package:frontend/feature/playback/widget/video_player_view.dart';
import 'package:frontend/widget/async_value_widget.dart';
import 'package:frontend/feature/playback/widget/graph_list_view.dart';
import 'package:frontend/feature/playback/widget/runner_history_view.dart';
import 'package:frontend/feature/playback/widget/video_info_view.dart';
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
                      width: 160,
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
                    return DropdownButtonHideUnderline(
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
                              (RunnerInfo item) => DropdownMenuItem<String>(
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
                        value: selectedRunnerId,
                        onChanged: (value) {
                          setState(() {
                            ref
                                    .read(
                                      playbackSelectedRunnerIdProvider.notifier,
                                    )
                                    .state =
                                value;
                          });
                          ref
                              .read(
                                playbackSelectedRunSessionIdProvider.notifier,
                              )
                              .state = items
                              .firstWhere((item) => item.id == value)
                              .lastVideoId;
                        },
                        buttonStyleData: ButtonStyleData(
                          height: 50,
                          width: 160,
                          padding: const EdgeInsets.only(left: 12, right: 12),
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
                    RoundedBoxWidget(child: GraphListView()),
                    RoundedBoxWidget(child: VideoInfoView()),
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
