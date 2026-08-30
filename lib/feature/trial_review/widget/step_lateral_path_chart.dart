import 'package:flutter/material.dart';
import 'package:frontend/entities/step_data.dart';
import 'package:frontend/feature/trial_review/trial_review_provider.dart';
import 'package:frontend/feature/trial_review/widget/chart_card.dart';

/// Bird's-eye "footprint trail" of real landing points along the runway,
/// styled to match the pipeline's own equal-scale schematic review video
/// (scripts/tools/render_schematic_topdown_review.py, "Footprint trail"
/// variant) rather than a generic scatter chart: dark runway backdrop,
/// fixed-size footprint glyphs (never stretched by zoom), connected by a
/// trail line in real chronological order.
///
/// X is each step's real along-track distance (`worldXM`) -- not step
/// order -- so stride-length differences show up as real spacing on
/// screen, the same way the video does. Both axes share one scale (an
/// "equal scale" render, like the reference script) so the runway is never
/// visually distorted.
///
/// Requires 6-point homography calibration (worldXM/worldYM) -- 4-point
/// line-calibration sessions have no lateral coordinate and can't plot here.
class StepLateralPathChart extends StatelessWidget {
  final StepsData data;

  const StepLateralPathChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final points = _buildPoints(data);

    if (points.isEmpty) {
      return const ChartCard(
        title: '腳步俯視路徑（等比例，公尺）',
        child: Center(child: Text('沒有可顯示的資料（需使用 6 點校正）')),
      );
    }

    return ChartCard(
      title: '腳步俯視路徑（等比例，公尺）',
      legend: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          legendDot(_kLeftFootColor),
          const SizedBox(width: 4),
          const Text('左腳', style: TextStyle(fontSize: 12)),
          const SizedBox(width: 16),
          legendDot(_kRightFootColor),
          const SizedBox(width: 4),
          const Text('右腳', style: TextStyle(fontSize: 12)),
        ],
      ),
      height: 240,
      child: CustomPaint(
        size: Size.infinite,
        painter: _FootprintTrailPainter(points: points),
      ),
    );
  }

  List<_LandingPoint> _buildPoints(StepsData data) {
    final result = <_LandingPoint>[];
    for (final step in chronologicalSteps(data)) {
      final x = step.worldXM;
      final y = step.worldYM;
      final foot = step.foot;
      if (x == null || y == null || (foot != 'left' && foot != 'right')) {
        continue;
      }
      result.add(
        _LandingPoint(
          stepIndex: step.stepIndex,
          worldXM: x,
          worldYM: y,
          isLeft: foot == 'left',
        ),
      );
    }
    return result;
  }
}

class _LandingPoint {
  final int stepIndex;
  final double worldXM;
  final double worldYM;
  final bool isLeft;

  _LandingPoint({
    required this.stepIndex,
    required this.worldXM,
    required this.worldYM,
    required this.isLeft,
  });
}

// Colors lifted directly from the reference script's BGR literals
// (draw_footprint/draw_runway in render_schematic_topdown_review.py),
// converted to Flutter's ARGB.
const _kCanvasBg = Color(0xFF1F241C); // cv2 (28,36,31) BGR
const _kRunwayFill = Color(0xFFB14A40); // cv2 (64,74,177) BGR
const _kRunwayBorder = Color(0xFFF5F5F5); // cv2 (245,245,245) BGR
const _kCenterLine = Color(0xFFDCDCDC); // cv2 (220,220,220) BGR
const _kTick = Color(0xFFF0F0F0); // cv2 (240,240,240) BGR
const _kLeftFootColor = Color(0xFF2DAAFF); // cv2 (255,170,45) BGR
const _kRightFootColor = Color(0xFFFFDC3C); // cv2 (60,220,255) BGR
const _kTrailColor = Color(0xFFFAEB6E); // cv2 (110,235,250) BGR
const _kAxisLabelColor = Color(0xFFEBEBEB); // cv2 (235,235,235) BGR

class _FootprintTrailPainter extends CustomPainter {
  final List<_LandingPoint> points;

  _FootprintTrailPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final xs = points.map((p) => p.worldXM);
    final ys = points.map((p) => p.worldYM);
    var minX = xs.reduce((a, b) => a < b ? a : b);
    var maxX = xs.reduce((a, b) => a > b ? a : b);
    var minY = ys.reduce((a, b) => a < b ? a : b);
    var maxY = ys.reduce((a, b) => a > b ? a : b);
    // A little breathing room so points at the very edge (and their fixed-
    // size glyphs) aren't clipped against the runway border.
    const padM = 0.6;
    minX -= padM;
    maxX += padM;
    minY -= padM * 0.4;
    maxY += padM * 0.4;
    final spanX = (maxX - minX).abs() < 1e-6 ? 1.0 : maxX - minX;
    final spanY = (maxY - minY).abs() < 1e-6 ? 1.0 : maxY - minY;

    const leftGutter = 34.0;
    const bottomGutter = 34.0;
    const topPadding = 28.0;
    const rightPadding = 12.0;
    final availWidth = (size.width - leftGutter - rightPadding).clamp(
      1.0,
      double.infinity,
    );
    final availHeight = (size.height - topPadding - bottomGutter).clamp(
      1.0,
      double.infinity,
    );

    // Equal scale on both axes -- like the reference video, the runway is
    // never stretched. Whichever axis is the tighter fit sets the scale;
    // the plot area is then centered within the looser axis's slack.
    final pxPerMeter = (availWidth / spanX < availHeight / spanY)
        ? availWidth / spanX
        : availHeight / spanY;
    final plotWidth = spanX * pxPerMeter;
    final plotHeight = spanY * pxPerMeter;
    final plotLeft = leftGutter + (availWidth - plotWidth) / 2;
    final plotTop = topPadding + (availHeight - plotHeight) / 2;

    Offset toCanvas(double worldX, double worldY) {
      return Offset(
        plotLeft + (worldX - minX) * pxPerMeter,
        plotTop + (worldY - minY) * pxPerMeter,
      );
    }

    void drawText(
      String text,
      Offset position, {
      TextAlign align = TextAlign.left,
      Color color = _kAxisLabelColor,
      double fontSize = 10,
    }) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(color: color, fontSize: fontSize),
        ),
        textAlign: align,
        textDirection: TextDirection.ltr,
      )..layout();
      var origin = position;
      if (align == TextAlign.right) {
        origin = position.translate(-painter.width, 0);
      } else if (align == TextAlign.center) {
        origin = position.translate(-painter.width / 2, 0);
      }
      painter.paint(canvas, origin);
    }

    // Runway backdrop.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = _kCanvasBg,
    );
    final runwayRect = Rect.fromPoints(
      toCanvas(minX, minY),
      toCanvas(maxX, maxY),
    );
    canvas.drawRect(runwayRect, Paint()..color = _kRunwayFill);
    canvas.drawRect(
      runwayRect,
      Paint()
        ..color = _kRunwayBorder
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final centerY = toCanvas(minX, (minY + maxY) / 2).dy;
    canvas.drawLine(
      Offset(runwayRect.left, centerY),
      Offset(runwayRect.right, centerY),
      Paint()
        ..color = _kCenterLine
        ..strokeWidth = 1,
    );

    // Along-track meter ticks, one per metre, labelled every 5m.
    for (var m = minX.ceil(); m <= maxX.floor(); m++) {
      final x = toCanvas(m.toDouble(), minY).dx;
      final tickLen = m % 5 == 0 ? 10.0 : 5.0;
      canvas.drawLine(
        Offset(x, runwayRect.bottom),
        Offset(x, runwayRect.bottom - tickLen),
        Paint()
          ..color = _kTick
          ..strokeWidth = 1.5,
      );
      if (m % 5 == 0) {
        drawText(
          '${m}m',
          Offset(x, runwayRect.top - 16),
          align: TextAlign.center,
        );
      }
    }

    // Step-order ticks along the very bottom, one per landing point --
    // mirrors the reference video's chart_axes() step-order row.
    var previousX = double.negativeInfinity;
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final x = toCanvas(p.worldXM, minY).dx;
      final crowded = (x - previousX).abs() < 13;
      previousX = x;
      drawText(
        '${p.stepIndex}',
        Offset(x, size.height - bottomGutter + (crowded && i.isOdd ? 12 : 2)),
        align: TextAlign.center,
        fontSize: 9,
      );
    }

    // Trail line through the real chronological landing sequence.
    if (points.length >= 2) {
      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final offset = toCanvas(points[i].worldXM, points[i].worldYM);
        if (i == 0) {
          path.moveTo(offset.dx, offset.dy);
        } else {
          path.lineTo(offset.dx, offset.dy);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = _kTrailColor
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
    }

    // Fixed-size footprint glyphs -- deliberately NOT scaled by pxPerMeter,
    // same principle as the reference video: a real footprint stays a
    // constant on-screen size regardless of how zoomed in/out the runway is.
    for (final p in points) {
      final center = toCanvas(p.worldXM, p.worldYM);
      _drawFootprint(canvas, center, p.isLeft);
    }
  }

  void _drawFootprint(Canvas canvas, Offset center, bool isLeft) {
    final color = isLeft ? _kLeftFootColor : _kRightFootColor;
    final paint = Paint()..color = color;
    // A small fixed lateral nudge (matching the reference script) so a
    // left/right pair landing at nearly the same worldY don't fully
    // overlap on screen.
    final offsetY = isLeft ? -4.0 : 4.0;
    final sole = center.translate(0, offsetY);
    canvas.drawOval(
      Rect.fromCenter(center: sole, width: 20, height: 10),
      paint,
    );
    // Toe dot, offset toward the direction of travel (+X).
    canvas.drawCircle(sole.translate(9, 0), 3, paint);
  }

  @override
  bool shouldRepaint(_FootprintTrailPainter old) => old.points != points;
}
