import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:frontend/backend/backend_provider.dart';
import 'package:frontend/backend/video_playback_state_provider.dart';
import 'package:frontend/entities/graph_data.dart';
import 'package:frontend/feature/playback/placeholder/graph_list_placeholder.dart';
import 'package:frontend/feature/playback/playback_provider.dart';
import 'package:frontend/widget/async_value_widget.dart';
import 'package:frontend/feature/playback/shimmer/graph_list_shimmer.dart';
import 'package:frontend/widget/processing_progress_widget.dart';

class GraphListView extends ConsumerWidget {
  const GraphListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runnerId = ref.watch(playbackSelectedRunnerIdProvider);
    final videoId = ref.watch(playbackSelectedRunSessionIdProvider);
    if (runnerId == null || videoId == null) {
      return const GraphListPlaceholder();
    }

    final videoInfo = ref.watch(videoInfoProvider(videoId));
    final videoPlayback = ref.watch(videoPlaybackStateProvider);

    return AsyncValueWidget(
      value: videoInfo,
      loading: const GraphListShimmer(),
      data: (info) {
        if (info.status == 'processing') {
          return Stack(
            alignment: Alignment.center,
            children: [
              const GraphListShimmer(),
              ProcessingProgressWidget(progress: info.progress),
            ],
          );
        }

        final graphData = ref.watch(graphDataProvider(videoId));

        return AsyncValueWidget(
          value: graphData,
          loading: const GraphListShimmer(),
          data: (List<GraphData> graphs) {
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: graphs.length,
              itemBuilder: (context, index) {
                final spots = List.generate(
                  graphs[index].y.length,
                  (i) =>
                      FlSpot(graphs[index].x[i].toDouble(), graphs[index].y[i]),
                );
                final progress =
                    videoPlayback.position / videoPlayback.duration;
                final currentIndex = (progress * (spots.length - 1))
                    .floor()
                    .clamp(0, spots.length - 1);

                final playedSpots = spots.sublist(0, currentIndex + 1);

                // 尚未播放的白線
                final whiteLine = LineChartBarData(
                  spots: spots,
                  color: Colors.white.withValues(alpha: 0.5),
                  barWidth: 3,
                  dotData: FlDotData(show: false),
                );

                // 已播放的紅線
                final redLine = LineChartBarData(
                  spots: playedSpots,
                  color: Colors.red,
                  barWidth: 5,
                  dotData: FlDotData(show: false),
                );

                return Container(
                  padding: const EdgeInsets.only(
                    top: 8,
                    bottom: 4,
                    left: 12,
                    right: 24,
                  ),
                  child: Column(
                    children: [
                      Text(
                        graphs[index].title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 20,
                        ),
                      ),
                      SizedBox(
                        height: 200,
                        child: LineChart(
                          LineChartData(
                            lineTouchData: LineTouchData(
                              touchTooltipData: LineTouchTooltipData(
                                getTooltipColor: (_) =>
                                    const Color.fromARGB(150, 48, 54, 47),
                                getTooltipItems: (touchedSpots) {
                                  return touchedSpots.map((spot) {
                                    final isWhite =
                                        spot.bar.color != Colors.red;
                                    final spotIndex = spot.bar.spots.indexOf(
                                      spot,
                                    );
                                    // 過濾不顯示的點
                                    if (isWhite && spotIndex <= currentIndex)
                                      return null;

                                    return LineTooltipItem(
                                      '${spot.y}',
                                      TextStyle(
                                        fontSize: 16,
                                        color: isWhite
                                            ? Colors.white
                                            : Colors.red,
                                      ),
                                    );
                                  }).toList();
                                },
                              ),
                            ),
                            lineBarsData: [whiteLine, redLine],
                            minY: graphs[index].yMin,
                            maxY: graphs[index].yMax,
                            clipData: FlClipData.none(),
                            extraLinesData: ExtraLinesData(
                              verticalLines: [
                                for (
                                  double x = 1.0;
                                  x <= (graphs[index].x.lastOrNull ?? 0);
                                  x += 1.0
                                )
                                  VerticalLine(
                                    x: x,
                                    color: Theme.of(
                                      context,
                                    ).primaryColorDark.withAlpha(128),
                                    strokeWidth: 2,
                                    dashArray: [5, 5],
                                  ),
                              ],
                            ),
                            titlesData: FlTitlesData(
                              topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                axisNameSize: 32,
                                axisNameWidget: const Text(
                                  'Time',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                                sideTitles: SideTitles(
                                  interval: 1.0,
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      value.toStringAsFixed(1),
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              leftTitles: AxisTitles(
                                axisNameSize: 32,
                                axisNameWidget: Text(
                                  graphs[index].yLabel,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: graphs[index].yMax > 10 ? 150 : 1,
                                  reservedSize: 35,
                                  getTitlesWidget: (value, meta) {
                                    if (meta.min > 10) {
                                      if ((meta.min - value).abs() < 1 &&
                                          (meta.min - value).abs() != 0) {
                                        return const SizedBox.shrink();
                                      }
                                      if ((meta.max - value).abs() < 1 &&
                                          (meta.max - value).abs() != 0) {
                                        return const SizedBox.shrink();
                                      }
                                    } else {
                                      if ((meta.min - value).abs() < 0.05 &&
                                          (meta.min - value).abs() != 0) {
                                        return const SizedBox.shrink();
                                      }
                                      if ((meta.max - value).abs() < 0.05 &&
                                          (meta.max - value).abs() != 0) {
                                        return const SizedBox.shrink();
                                      }
                                    }
                                    return Text(
                                      meta.max > 10
                                          ? value.toStringAsFixed(0)
                                          : value.toStringAsFixed(2),
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(
                              show: true,
                              border: Border(
                                bottom: BorderSide(
                                  color: Theme.of(
                                    context,
                                  ).primaryColorDark.withAlpha(128),
                                  width: 3,
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
          },
        );
      },
    );
  }
}
