import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:frontend/backend/backend_provider.dart';
import 'package:frontend/backend/video_playback_state_provider.dart';
import 'package:frontend/entities/angle_data.dart';
import 'package:frontend/entities/graph_data.dart';
import 'package:frontend/entities/run_session_info.dart';
import 'package:frontend/entities/video_playback.dart';
import 'package:frontend/feature/playback/placeholder/graph_list_placeholder.dart';
import 'package:frontend/feature/playback/playback_provider.dart';
import 'package:frontend/utils/download_file_web.dart';
import 'package:frontend/widget/async_value_widget.dart';
import 'package:frontend/feature/playback/shimmer/graph_list_shimmer.dart';
import 'package:frontend/widget/processing_progress_widget.dart';
import 'package:frontend/widget/rounded_box_widget.dart';

// ══════════════════════════════════════════════════════════════════════════════

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
        final angleData = ref.watch(angleDataProvider(videoId));

        return AsyncValueWidget(
          value: graphData,
          loading: const GraphListShimmer(),
          data: (List<GraphData> graphs) {
            final metricsGraphs = graphs
                .where((g) => g.category == 'metrics')
                .toList();
            final anglesGraphs = graphs
                .where((g) => g.category == 'angles')
                .toList();

            return Column(
              children: [
                _ReportDownloadBar(
                  info: info,
                  graphs: graphs,
                  angleData: angleData,
                ),
                const SizedBox(height: 8),
                RoundedBoxWidget(
                  child: _GraphSection(
                    title: 'Distance, Velocity & Acceleration',
                    icon: Icons.speed_rounded,
                    graphs: metricsGraphs,
                    videoPlayback: videoPlayback,
                    initiallyExpanded: true,
                  ),
                ),
                const SizedBox(height: 8),
                RoundedBoxWidget(
                  child: _GraphSection(
                    title: 'Joint Angles',
                    icon: Icons.accessibility_new_rounded,
                    graphs: anglesGraphs,
                    videoPlayback: videoPlayback,
                    initiallyExpanded: false,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ReportDownloadBar extends StatelessWidget {
  static const Map<String, String> _angleLabels = {
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

  final RunSessionInfo info;
  final List<GraphData> graphs;
  final AsyncValue<AngleData> angleData;

  const _ReportDownloadBar({
    required this.info,
    required this.graphs,
    required this.angleData,
  });

  @override
  Widget build(BuildContext context) {
    final angleDataValue = angleData.maybeWhen(
      data: (data) => data,
      orElse: () => null,
    );

    return RoundedBoxWidget(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const Icon(
              Icons.assignment_rounded,
              color: Colors.white70,
              size: 22,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Analysis Report',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            IconButton(
              tooltip: '下載圖表報告與角度資料',
              icon: const Icon(
                Icons.download_rounded,
                color: Colors.white70,
                size: 22,
              ),
              onPressed: graphs.isEmpty || angleDataValue == null
                  ? null
                  : () => _downloadReport(angleDataValue),
            ),
          ],
        ),
      ),
    );
  }

  void _downloadReport(AngleData angleData) {
    downloadTextFile(
      filename: 'running_report_${info.runSessionId}.html',
      content: _buildHtmlReport(),
      mimeType: 'text/html;charset=utf-8',
      utf8Bom: false,
    );
    downloadTextFile(
      filename: 'angles_${info.runSessionId}.csv',
      content: _buildAngleCsv(angleData),
      mimeType: 'text/csv;charset=utf-8',
      utf8Bom: true,
    );
  }

  String _buildAngleCsv(AngleData data) {
    final columns = data.columns
        .where((column) => data.samples.any((s) => s.values[column] != null))
        .toList();
    final rows = <List<String>>[
      ['time_sec', ...columns.map((column) => _angleLabels[column] ?? column)],
      for (final sample in data.samples)
        [
          sample.timeSec.toStringAsFixed(6),
          for (final column in columns)
            sample.values[column]?.toStringAsFixed(6) ?? '',
        ],
    ];
    return '${rows.map((row) => row.map(_csv).join(',')).join('\n')}\n';
  }

  String _buildHtmlReport() {
    final metricsGraphs = graphs.where((g) => g.category == 'metrics');
    final anglesGraphs = graphs.where((g) => g.category == 'angles');

    return '''
<!doctype html>
<html lang="zh-Hant">
<head>
  <meta charset="utf-8">
  <title>Runner Analysis Report</title>
  <style>
    * { box-sizing: border-box; }
    body {
      margin: 0;
      background: #f4f6f8;
      color: #17212b;
      font-family: Arial, "Noto Sans TC", sans-serif;
      line-height: 1.45;
    }
    .page {
      max-width: 960px;
      margin: 24px auto;
      background: #fff;
      padding: 40px;
      box-shadow: 0 8px 30px rgba(24, 34, 45, 0.12);
    }
    h1 { margin: 0 0 6px; font-size: 30px; }
    h2 {
      margin: 34px 0 14px;
      padding-bottom: 8px;
      border-bottom: 2px solid #d9e1ea;
      font-size: 20px;
    }
    h3 { margin: 0 0 10px; font-size: 16px; }
    .subtle { color: #647487; font-size: 13px; }
    .summary {
      display: grid;
      grid-template-columns: repeat(3, 1fr);
      gap: 12px;
      margin-top: 24px;
    }
    .metric {
      border: 1px solid #dce4ed;
      border-radius: 8px;
      padding: 12px;
      min-height: 76px;
      background: #fbfcfe;
    }
    .label { color: #65758a; font-size: 12px; margin-bottom: 5px; }
    .value { font-size: 20px; font-weight: 700; }
    .chart {
      break-inside: avoid;
      border: 1px solid #dce4ed;
      border-radius: 8px;
      padding: 18px;
      margin-bottom: 16px;
      background: #fff;
    }
    .legend {
      display: flex;
      flex-wrap: wrap;
      gap: 12px;
      margin-top: 10px;
      font-size: 12px;
      color: #344457;
    }
    .legend-item { display: inline-flex; align-items: center; gap: 5px; }
    .swatch { width: 12px; height: 3px; display: inline-block; border-radius: 999px; }
    svg { width: 100%; height: auto; display: block; }
    @media print {
      body { background: #fff; }
      .page { margin: 0; box-shadow: none; max-width: none; }
    }
  </style>
</head>
<body>
  <main class="page">
    <h1>Runner Analysis Report</h1>
    <div class="subtle">Generated from run session ${_html(info.runSessionId)}</div>

    <section class="summary">
      ${_summaryCard('Runner', info.runnerName)}
      ${_summaryCard('Date', info.date.toLocal().toString())}
      ${_summaryCard('FPS', info.fps.toString())}
      ${_summaryCard('Total Time', '${_numOrBlank(info.totalTime)} s')}
      ${_summaryCard('Avg Velocity', '${_numOrBlank(info.avgVelocity)} m/s')}
      ${_summaryCard('Avg Acceleration', '${_numOrBlank(info.avgAcceleration)} m/s²')}
      ${_summaryCard('Avg Step Length', '${_numOrBlank(info.avgStepLength)} m')}
      ${_summaryCard('Camera Count', info.cameraCount.toString())}
      ${_summaryCard('Note', info.note.isEmpty ? '-' : info.note)}
    </section>

    <h2>Distance, Velocity & Acceleration</h2>
    ${metricsGraphs.map(_chartCard).join('\n')}

    <h2>Joint Angles</h2>
    ${anglesGraphs.map(_chartCard).join('\n')}
  </main>
</body>
</html>
''';
  }

  String _summaryCard(String label, String value) {
    return '''
<div class="metric">
  <div class="label">${_html(label)}</div>
  <div class="value">${_html(value)}</div>
</div>''';
  }

  String _chartCard(GraphData graph) {
    final colors = ['#2563eb', '#dc2626', '#059669', '#7c3aed'];
    final legends = [
      for (var i = 0; i < graph.series.length; i++)
        '<span class="legend-item"><span class="swatch" style="background:${colors[i % colors.length]}"></span>${_html(graph.series[i].name)}</span>',
    ].join('');

    return '''
<section class="chart">
  <h3>${_html(graph.title)}</h3>
  ${_svgChart(graph, colors)}
  <div class="legend">$legends</div>
</section>''';
  }

  String _svgChart(GraphData graph, List<String> colors) {
    const width = 860.0;
    const height = 280.0;
    const left = 58.0;
    const right = 18.0;
    const top = 18.0;
    const bottom = 42.0;
    const plotW = width - left - right;
    const plotH = height - top - bottom;

    final xValues = graph.x;
    final xMin = xValues.isEmpty ? 0.0 : xValues.first;
    final xMax = xValues.isEmpty ? 1.0 : xValues.last;
    final yMin = graph.yMin == graph.yMax ? graph.yMin - 1 : graph.yMin;
    final yMax = graph.yMin == graph.yMax ? graph.yMax + 1 : graph.yMax;

    double sx(double x) => left + ((x - xMin) / _range(xMin, xMax)) * plotW;
    double sy(double y) =>
        top + (1 - ((y - yMin) / _range(yMin, yMax))) * plotH;

    final grid = StringBuffer();
    for (var i = 0; i <= 4; i++) {
      final y = top + plotH * i / 4;
      final value = yMax - (yMax - yMin) * i / 4;
      grid.writeln(
        '<line x1="$left" y1="$y" x2="${left + plotW}" y2="$y" stroke="#e6edf3" />',
      );
      grid.writeln(
        '<text x="${left - 8}" y="${y + 4}" text-anchor="end" font-size="11" fill="#647487">${value.toStringAsFixed(1)}</text>',
      );
    }
    for (var i = 0; i <= 4; i++) {
      final x = left + plotW * i / 4;
      final value = xMin + (xMax - xMin) * i / 4;
      grid.writeln(
        '<line x1="$x" y1="$top" x2="$x" y2="${top + plotH}" stroke="#f0f3f7" />',
      );
      grid.writeln(
        '<text x="$x" y="${height - 12}" text-anchor="middle" font-size="11" fill="#647487">${value.toStringAsFixed(1)}s</text>',
      );
    }

    final paths = StringBuffer();
    for (var s = 0; s < graph.series.length; s++) {
      final series = graph.series[s];
      final points = <String>[];
      final count = series.y.length < xValues.length
          ? series.y.length
          : xValues.length;
      for (var i = 0; i < count; i++) {
        points.add(
          '${sx(xValues[i]).toStringAsFixed(2)},${sy(series.y[i]).toStringAsFixed(2)}',
        );
      }
      if (points.length >= 2) {
        paths.writeln(
          '<polyline fill="none" stroke="${colors[s % colors.length]}" stroke-width="2.4" points="${points.join(' ')}" />',
        );
      }
    }

    return '''
<svg viewBox="0 0 $width $height" role="img" aria-label="${_html(graph.title)} chart">
  <rect x="0" y="0" width="$width" height="$height" fill="#ffffff" />
  $grid
  <line x1="$left" y1="${top + plotH}" x2="${left + plotW}" y2="${top + plotH}" stroke="#93a4b7" />
  <line x1="$left" y1="$top" x2="$left" y2="${top + plotH}" stroke="#93a4b7" />
  $paths
  <text x="${left + plotW / 2}" y="${height - 2}" text-anchor="middle" font-size="12" fill="#344457">Time</text>
  <text x="12" y="${top + plotH / 2}" transform="rotate(-90 12 ${top + plotH / 2})" text-anchor="middle" font-size="12" fill="#344457">${_html(graph.yLabel)}</text>
</svg>''';
  }

  String _numOrBlank(num? value) {
    if (value == null) return '';
    return value.toString();
  }

  double _range(double min, double max) {
    final range = max - min;
    return range == 0 ? 1 : range;
  }

  String _html(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  String _csv(String value) {
    final escaped = value.replaceAll('"', '""');
    if (escaped.contains(',') ||
        escaped.contains('"') ||
        escaped.contains('\n') ||
        escaped.contains('\r')) {
      return '"$escaped"';
    }
    return escaped;
  }
}

// ─── Collapsible section ───────────────────────────────────────────────────

class _GraphSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<GraphData> graphs;
  final VideoPlayback videoPlayback;
  final bool initiallyExpanded;

  const _GraphSection({
    required this.title,
    required this.icon,
    required this.graphs,
    required this.videoPlayback,
    required this.initiallyExpanded,
  });

  @override
  Widget build(BuildContext context) {
    if (graphs.isEmpty) return const SizedBox.shrink();

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        collapsedBackgroundColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Icon(icon, color: Colors.white70, size: 22),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        iconColor: Colors.white70,
        collapsedIconColor: Colors.white54,
        children: [
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: graphs.length,
            // The backend decides how many series each graph has:
            //   1 series  → single-line chart
            //   2 series  → paired left/right chart
            itemBuilder: (context, index) {
              final g = graphs[index];
              return g.series.length >= 2
                  ? _buildPairedChart(context, g)
                  : _buildSingleChart(context, g);
            },
          ),
        ],
      ),
    );
  }

  // ── shared helpers ──────────────────────────────────────────────────────

  int _currentIndex(List<FlSpot> spots) {
    final progress = videoPlayback.position / videoPlayback.duration;
    return (progress * (spots.length - 1)).floor().clamp(0, spots.length - 1);
  }

  List<VerticalLine> _secondTicks(BuildContext context, List<double> xValues) =>
      [
        for (double x = 1.0; x <= (xValues.lastOrNull ?? 0); x += 1.0)
          VerticalLine(
            x: x,
            color: Theme.of(context).primaryColorDark.withAlpha(128),
            strokeWidth: 2,
            dashArray: [5, 5],
          ),
      ];

  SideTitles _leftTitles(double yMax) => SideTitles(
    showTitles: true,
    interval: yMax > 10 ? 150 : 1,
    reservedSize: 35,
    getTitlesWidget: (value, meta) {
      if (meta.min > 10) {
        if ((meta.min - value).abs() < 1 && (meta.min - value).abs() != 0) {
          return const SizedBox.shrink();
        }
        if ((meta.max - value).abs() < 1 && (meta.max - value).abs() != 0) {
          return const SizedBox.shrink();
        }
      } else {
        if ((meta.min - value).abs() < 0.05 && (meta.min - value).abs() != 0) {
          return const SizedBox.shrink();
        }
        if ((meta.max - value).abs() < 0.05 && (meta.max - value).abs() != 0) {
          return const SizedBox.shrink();
        }
      }
      return Text(
        meta.max > 10 ? value.toStringAsFixed(0) : value.toStringAsFixed(2),
        style: const TextStyle(color: Colors.white),
      );
    },
  );

  FlTitlesData _titlesData(BuildContext context, String yLabel, double yMax) =>
      FlTitlesData(
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          axisNameSize: 32,
          axisNameWidget: const Text(
            'Time',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
          sideTitles: SideTitles(
            interval: 1.0,
            showTitles: true,
            getTitlesWidget: (value, meta) => Text(
              value.toStringAsFixed(1),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
        leftTitles: AxisTitles(
          axisNameSize: 32,
          axisNameWidget: Text(
            yLabel,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          sideTitles: _leftTitles(yMax),
        ),
      );

  FlBorderData _borderData(BuildContext context) => FlBorderData(
    show: true,
    border: Border(
      bottom: BorderSide(
        color: Theme.of(context).primaryColorDark.withAlpha(128),
        width: 3,
      ),
    ),
  );

  Widget _chartContainer({
    required BuildContext context,
    required Widget titleWidget,
    required Widget chart,
  }) {
    return Container(
      padding: const EdgeInsets.only(top: 8, bottom: 4, left: 12, right: 24),
      child: Column(
        children: [
          titleWidget,
          SizedBox(height: 200, child: chart),
        ],
      ),
    );
  }

  Widget _legendDot(Color color) => Container(
    width: 12,
    height: 12,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  // ── 1 series → single-line chart ────────────────────────────────────────

  Widget _buildSingleChart(BuildContext context, GraphData graph) {
    final primaryColor = Theme.of(context).primaryColorDark;
    final y = graph.series.first.y;
    final spots = List.generate(
      y.length,
      (i) => FlSpot(graph.x[i].toDouble(), y[i]),
    );
    final ci = _currentIndex(spots);
    final playedSpots = spots.sublist(0, ci + 1);

    // barIndex 0 = faded (unplayed), barIndex 1 = played
    final whiteLine = LineChartBarData(
      spots: spots,
      color: Colors.white.withValues(alpha: 0.5),
      barWidth: 3,
      dotData: FlDotData(show: false),
    );
    final redLine = LineChartBarData(
      spots: playedSpots,
      color: primaryColor,
      barWidth: 4,
      dotData: FlDotData(show: false),
    );

    return _chartContainer(
      context: context,
      titleWidget: Text(
        graph.title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontSize: 20,
        ),
      ),
      chart: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => const Color.fromARGB(150, 48, 54, 47),
              getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                // barIndex 0 = faded (unplayed), 1 = played
                final isFaded = spot.barIndex == 0;
                // For the faded line, hide spots that are already played
                if (isFaded && spot.bar.spots.indexOf(spot) <= ci) return null;
                return LineTooltipItem(
                  '${spot.y}',
                  TextStyle(
                    fontSize: 16,
                    color: isFaded ? Colors.white : primaryColor,
                  ),
                );
              }).toList(),
            ),
          ),
          lineBarsData: [whiteLine, redLine],
          minY: graph.yMin,
          maxY: graph.yMax,
          clipData: FlClipData.none(),
          extraLinesData: ExtraLinesData(
            verticalLines: _secondTicks(context, graph.x),
          ),
          titlesData: _titlesData(context, graph.yLabel, graph.yMax),
          borderData: _borderData(context),
        ),
      ),
    );
  }

  // ── 2 series → paired left/right chart ──────────────────────────────────

  Widget _buildPairedChart(BuildContext context, GraphData graph) {
    final primaryColor = Theme.of(context).primaryColorDark;
    final leftY = graph.series[0].y; // name == "left"
    final rightY = graph.series[1].y; // name == "right"

    final leftSpots = List.generate(
      leftY.length,
      (i) => FlSpot(graph.x[i].toDouble(), leftY[i]),
    );
    final rightSpots = List.generate(
      rightY.length,
      (i) => FlSpot(graph.x[i].toDouble(), rightY[i]),
    );

    final leftCI = _currentIndex(leftSpots);
    final rightCI = _currentIndex(rightSpots);

    final leftPlayed = leftSpots.sublist(0, leftCI + 1);
    final rightPlayed = rightSpots.sublist(0, rightCI + 1);

    // Faded "future" lines
    final leftFaded = primaryColor.withValues(alpha: 0.5);
    final rightFaded = Colors.white.withValues(alpha: 0.5);
    final leftFade = LineChartBarData(
      spots: leftSpots,
      color: leftFaded,
      barWidth: 3,
      dotData: FlDotData(show: false),
    );
    final rightFade = LineChartBarData(
      spots: rightSpots,
      color: rightFaded,
      barWidth: 3,
      dotData: FlDotData(show: false),
    );
    // Vivid "played" lines  (index 2 = leftLive, index 3 = rightLive in lineBarsData)
    final leftLive = LineChartBarData(
      spots: leftPlayed,
      color: primaryColor,
      barWidth: 4,
      dotData: FlDotData(show: false),
    );
    final rightLive = LineChartBarData(
      spots: rightPlayed,
      color: Colors.white,
      barWidth: 4,
      dotData: FlDotData(show: false),
    );

    return _chartContainer(
      context: context,
      titleWidget: Column(
        children: [
          Text(
            graph.title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(primaryColor),
              const SizedBox(width: 4),
              const Text(
                'Left',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(width: 16),
              _legendDot(Colors.white),
              const SizedBox(width: 4),
              const Text(
                'Right',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
      chart: LineChart(
        LineChartData(
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => const Color.fromARGB(150, 48, 54, 47),
              getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
                // barIndex: 0=leftFade, 1=rightFade, 2=leftLive, 3=rightLive
                final idx = spot.barIndex;
                final spotIdx = spot.bar.spots.indexOf(spot);

                // Faded bars: only show tooltip for unplayed region
                if (idx == 0 && spotIdx <= leftCI) return null;
                if (idx == 1 && spotIdx <= rightCI) return null;

                final isLeft = idx == 0 || idx == 2;
                return LineTooltipItem(
                  '${isLeft ? "L" : "R"}: ${spot.y.toStringAsFixed(1)}°',
                  TextStyle(
                    fontSize: 16,
                    color: isLeft ? primaryColor : Colors.white,
                  ),
                );
              }).toList(),
            ),
          ),
          lineBarsData: [leftFade, rightFade, leftLive, rightLive],
          minY: graph.yMin,
          maxY: graph.yMax,
          clipData: FlClipData.none(),
          extraLinesData: ExtraLinesData(
            verticalLines: _secondTicks(context, graph.x),
          ),
          titlesData: _titlesData(context, graph.yLabel, graph.yMax),
          borderData: _borderData(context),
        ),
      ),
    );
  }
}
