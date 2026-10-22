import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/utils/locale_provider.dart';
import 'camera_level_model.dart';
import 'camera_level_provider.dart';

class CameraLevelOverlay extends ConsumerWidget {
  const CameraLevelOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showLevel = ref.watch(showCameraLevelProvider);
    if (!showLevel) return const SizedBox.shrink();

    final levelAsync = ref.watch(cameraLevelStreamProvider);

    return levelAsync.when(
      data: (data) {
        if (!data.isAvailable) {
          // 在電腦或未偵測到感測器的設備上，顯示小提示
          return Positioned(
            bottom: 64,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outline, size: 14, color: Colors.white70),
                    const SizedBox(width: 6),
                    Text(
                      context.l10n.levelSensorUnavailable,
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return IgnorePointer(
          ignoring: true,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _CameraLevelPainter(data: data),
                size: Size.infinite,
              ),
              // 中央度數標籤
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: data.isLevel
                            ? const Color(0xFF00E676)
                            : Colors.white.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          data.isLevel
                              ? '${context.l10n.levelCalibrated} (0.0°)'
                              : '${data.roll > 0 ? "+" : ""}${data.roll.toStringAsFixed(1)}°',
                          style: TextStyle(
                            color: data.isLevel ? const Color(0xFF00E676) : Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 1,
                          height: 10,
                          color: Colors.white30,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${context.l10n.levelPitch} ${data.pitch > 0 ? "+" : ""}${data.pitch.toStringAsFixed(1)}°',
                          style: TextStyle(
                            color: data.pitch.abs() <= 2.0 ? const Color(0xFF00E676) : Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _CameraLevelPainter extends CustomPainter {
  final CameraLevelData data;

  _CameraLevelPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final isLevel = data.isLevel;

    final primaryColor = isLevel
        ? const Color(0xFF00E676)
        : (data.roll.abs() <= 3.0 ? Colors.white : Colors.amberAccent);

    final linePaint = Paint()
      ..color = primaryColor.withValues(alpha: isLevel ? 0.95 : 0.8)
      ..strokeWidth = isLevel ? 2.5 : 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final refPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // 1. 繪製固定基準線 (兩側的水平基準標記)
    const fixedLineInner = 36.0;
    const fixedLineOuter = 100.0;

    // 左側固定基準線
    canvas.drawLine(
      Offset(center.dx - fixedLineOuter, center.dy),
      Offset(center.dx - fixedLineInner, center.dy),
      refPaint,
    );
    // 右側固定基準線
    canvas.drawLine(
      Offset(center.dx + fixedLineInner, center.dy),
      Offset(center.dx + fixedLineOuter, center.dy),
      refPaint,
    );

    // 基準線的上下極限刻度 (幫助判斷水平差多少)
    const tickH = 6.0;
    canvas.drawLine(
      Offset(center.dx - fixedLineOuter, center.dy - tickH),
      Offset(center.dx - fixedLineOuter, center.dy + tickH),
      refPaint,
    );
    canvas.drawLine(
      Offset(center.dx + fixedLineOuter, center.dy - tickH),
      Offset(center.dx + fixedLineOuter, center.dy + tickH),
      refPaint,
    );

    // 2. 繪製中央固定準心十字/圓圈
    final reticlePaint = Paint()
      ..color = isLevel
          ? const Color(0xFF00E676).withValues(alpha: 0.9)
          : Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, 12, reticlePaint);
    // 十字刻度
    canvas.drawLine(Offset(center.dx, center.dy - 6), Offset(center.dx, center.dy - 2), reticlePaint);
    canvas.drawLine(Offset(center.dx, center.dy + 2), Offset(center.dx, center.dy + 6), reticlePaint);
    canvas.drawLine(Offset(center.dx - 6, center.dy), Offset(center.dx - 2, center.dy), reticlePaint);
    canvas.drawLine(Offset(center.dx + 2, center.dy), Offset(center.dx + 6, center.dy), reticlePaint);

    // 3. 繪製旋轉動態水平儀橫線 (依據 roll 角度旋轉)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-data.roll * pi / 180.0);

    // 如果達到水平，增加發光外框效果
    if (isLevel) {
      final glowPaint = Paint()
        ..color = const Color(0xFF00E676).withValues(alpha: 0.5)
        ..strokeWidth = 6.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0)
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      canvas.drawLine(const Offset(-88, 0), const Offset(-20, 0), glowPaint);
      canvas.drawLine(const Offset(20, 0), const Offset(88, 0), glowPaint);
    }

    // 左動態水平線
    canvas.drawLine(const Offset(-88, 0), const Offset(-20, 0), linePaint);
    // 右動態水平線
    canvas.drawLine(const Offset(20, 0), const Offset(88, 0), linePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CameraLevelPainter oldDelegate) {
    return oldDelegate.data.roll != data.roll ||
        oldDelegate.data.pitch != data.pitch ||
        oldDelegate.data.isLevel != data.isLevel ||
        oldDelegate.data.isAvailable != data.isAvailable;
  }
}
