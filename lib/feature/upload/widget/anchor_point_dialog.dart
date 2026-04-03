import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ── Data classes ──────────────────────────────────────────────

/// Normalised anchor point (x, y ∈ [0, 1])
class AnchorPoint {
  final double x;
  final double y;
  const AnchorPoint(this.x, this.y);

  @override
  String toString() => 'AnchorPoint($x, $y)';

  Map<String, double> toJson() => {'x': x, 'y': y};
}

/// Result: 4 points (TL → TR → BR → BL) + top/bottom real distances (m)
class AnchorResult {
  final List<AnchorPoint> points;
  final double topDistanceM;
  final double bottomDistanceM;

  const AnchorResult({
    required this.points,
    required this.topDistanceM,
    required this.bottomDistanceM,
  });

  Map<String, dynamic> toJson() => {
    'points': points.map((p) => p.toJson()).toList(),
    'topDistanceM': topDistanceM,
    'bottomDistanceM': bottomDistanceM,
  };
}

// ── Styling constants ─────────────────────────────────────────

const _labels = ['左上', '右上', '右下', '左下'];
const _colors = [
  Color(0xFF4FC3F7), // 淺藍 – TL
  Color(0xFF81C784), // 淺綠 – TR
  Color(0xFFFFB74D), // 橘   – BR
  Color(0xFFE57373), // 紅   – BL
];

/// Hit-test radius for grabbing an existing anchor (logical pixels)
const _kHitRadius = 16.0;

/// Magnifier radius (logical pixels)
const _kMagRadius = 54.0;

/// Magnifier zoom factor
const _kMagZoom = 2.8;

// ── Public entry point ────────────────────────────────────────

Future<AnchorResult?> showAnchorPointDialog({
  required BuildContext context,
  required String thumbnailUrl,
  required int cameraIndex,
  AnchorResult? initialAnchor,
}) {
  return showDialog<AnchorResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _AnchorPointDialog(
      thumbnailUrl: thumbnailUrl,
      cameraIndex: cameraIndex,
      initialAnchor: initialAnchor,
    ),
  );
}

// ── Dialog widget ─────────────────────────────────────────────

class _AnchorPointDialog extends StatefulWidget {
  final String thumbnailUrl;
  final int cameraIndex;
  final AnchorResult? initialAnchor;

  const _AnchorPointDialog({
    required this.thumbnailUrl,
    required this.cameraIndex,
    this.initialAnchor,
  });

  @override
  State<_AnchorPointDialog> createState() => _AnchorPointDialogState();
}

class _AnchorPointDialogState extends State<_AnchorPointDialog>
    with SingleTickerProviderStateMixin {
  // Anchor points (normalised 0–1)
  final List<Offset> _pts = [];

  // Drag / magnifier state
  int? _draggingIdx;
  Offset? _magPos; // normalised position shown in magnifier

  // Pending tap (set in onTapDown, consumed in onTap)
  Offset? _pendingTapNorm;

  // Cached image size set in LayoutBuilder
  double _imgW = 1.0;
  double _imgH = 1.0;

  // Distance inputs
  final _topCtrl = TextEditingController();
  final _botCtrl = TextEditingController();

  // Pulse animation for "next point" badge
  late AnimationController _pulse;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.85,
      end: 1.15,
    ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

    // Pre-load previous anchor result if available
    final prev = widget.initialAnchor;
    if (prev != null) {
      _pts.addAll(prev.points.map((p) => Offset(p.x, p.y)));
      _topCtrl.text = prev.topDistanceM.toString();
      _botCtrl.text = prev.bottomDistanceM.toString();
    }
  }

  @override
  void dispose() {
    _topCtrl.dispose();
    _botCtrl.dispose();
    _pulse.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────

  bool get _full => _pts.length == 4;
  int get _nextIdx => _pts.length;

  /// Normalise local position to [0, 1]
  Offset _norm(Offset local) => Offset(
    (local.dx / _imgW).clamp(0.0, 1.0),
    (local.dy / _imgH).clamp(0.0, 1.0),
  );

  /// Find the index of the nearest existing point within _kHitRadius px.
  int? _nearestIdx(Offset normPos) {
    int? best;
    double bestDist = double.infinity;
    for (int i = 0; i < _pts.length; i++) {
      final dx = (normPos.dx - _pts[i].dx) * _imgW;
      final dy = (normPos.dy - _pts[i].dy) * _imgH;
      final d = dx * dx + dy * dy;
      if (d < _kHitRadius * _kHitRadius && d < bestDist) {
        bestDist = d;
        best = i;
      }
    }
    return best;
  }

  // ── Gesture handlers ───────────────────────────────────────

  void _onTapDown(TapDownDetails d) {
    _pendingTapNorm = _norm(d.localPosition);
  }

  void _onTap() {
    final pos = _pendingTapNorm;
    _pendingTapNorm = null;
    if (pos == null || _full) return;

    // Don't add if user touched near an existing point (they probably wanted to drag)
    if (_nearestIdx(pos) != null) return;

    setState(() => _pts.add(pos));
  }

  void _onPanStart(DragStartDetails d) {
    if (_pts.isEmpty) return;
    final norm = _norm(d.localPosition);
    final idx = _nearestIdx(norm);
    if (idx != null) {
      setState(() {
        _draggingIdx = idx;
        _magPos = _pts[idx];
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails d) {
    if (_draggingIdx == null) return;
    final norm = _norm(d.localPosition);
    setState(() {
      _pts[_draggingIdx!] = norm;
      _magPos = norm;
    });
  }

  void _onPanEnd(DragEndDetails _) {
    setState(() {
      _draggingIdx = null;
      _magPos = null;
    });
  }

  // ── Confirm / utility ──────────────────────────────────────

  bool get _canConfirm {
    if (!_full) return false;
    final t = double.tryParse(_topCtrl.text);
    final b = double.tryParse(_botCtrl.text);
    return t != null && t > 0 && b != null && b > 0;
  }

  void _confirm() {
    final result = AnchorResult(
      points: _pts.map((o) => AnchorPoint(o.dx, o.dy)).toList(),
      topDistanceM: double.parse(_topCtrl.text),
      bottomDistanceM: double.parse(_botCtrl.text),
    );
    Navigator.of(context).pop(result);
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1A2035),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: MediaQuery.of(context).size.height * 0.95,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildProgressBar(),
                    const SizedBox(height: 12),

                    _buildImageArea(),
                    const SizedBox(height: 16),

                    // ── 距離輸入 (移回影像下方) ─────────────────────
                    _buildDistanceInputs(),
                    const SizedBox(height: 16),

                    _buildGuide(),
                    const SizedBox(height: 16),
                    _buildActions(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sub-builders ───────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColorDark,
        // gradient: LinearGradient(
        //   colors: [Color(0xFF2979FF), Color(0xFF00BFA5)],
        //   begin: Alignment.centerLeft,
        //   end: Alignment.centerRight,
        // ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          const Icon(Icons.my_location, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '相機 ${widget.cameraIndex + 1} — 設定錨點',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'NotoSansTC',
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(null),
            icon: const Icon(Icons.close, color: Colors.white70),
            tooltip: '略過設定錨點',
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        children: List.generate(4, (i) {
          final done = i < _pts.length;
          final active = i == _pts.length;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 5,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: done
                    ? _colors[i]
                    : active
                    ? _colors[i].withValues(alpha: 0.45)
                    : Colors.white12,
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildImageArea() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: LayoutBuilder(
          builder: (_, constraints) {
            _imgW = constraints.maxWidth;
            _imgH = constraints.maxHeight;

            return GestureDetector(
              // Tap → add new point
              onTapDown: _onTapDown,
              onTap: _onTap,
              // Pan → drag existing point
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // ── Background image ──────────────────────
                  Positioned.fill(
                    child: Image.network(
                      widget.thumbnailUrl,
                      fit: BoxFit.cover,
                      loadingBuilder: (_, child, prog) {
                        if (prog == null) return child;
                        return Container(
                          color: Colors.black26,
                          alignment: Alignment.center,
                          child: const CircularProgressIndicator(
                            color: Color(0xFF2979FF),
                          ),
                        );
                      },
                    ),
                  ),

                  // ── Dim overlay ───────────────────────────
                  if (!_full)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.07),
                        alignment: Alignment.center,
                        child: _pts.isEmpty
                            ? const Text(
                                '點擊影像選取錨點',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                  fontFamily: 'NotoSansTC',
                                ),
                              )
                            : null,
                      ),
                    ),

                  // ── Quadrilateral lines ───────────────────
                  if (_pts.length >= 2)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _QuadPainter(
                          points: _pts,
                          width: _imgW,
                          height: _imgH,
                          draggingIdx: _draggingIdx,
                        ),
                      ),
                    ),

                  // ── Anchor markers ────────────────────────
                  ..._pts.asMap().entries.map((e) {
                    final i = e.key;
                    final pt = e.value;
                    final isDragging = i == _draggingIdx;
                    return Positioned(
                      left: pt.dx * _imgW - 16,
                      top: pt.dy * _imgH - 16,
                      child: AnimatedScale(
                        scale: isDragging ? 1.35 : 1.0,
                        duration: const Duration(milliseconds: 150),
                        child: _AnchorMarker(
                          label: _labels[i],
                          color: _colors[i],
                          index: i + 1,
                          isDragging: isDragging,
                        ),
                      ),
                    );
                  }),

                  // ── Next-point badge ──────────────────────
                  if (!_full && _draggingIdx == null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (_, child) => Transform.scale(
                          scale: _pulseAnim.value,
                          child: child,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _colors[_nextIdx].withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '點 ${_nextIdx + 1}：${_labels[_nextIdx]}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'NotoSansTC',
                            ),
                          ),
                        ),
                      ),
                    ),

                  // ── Drag hint label ───────────────────────
                  if (_full && _draggingIdx == null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.open_with,
                              size: 12,
                              color: Colors.white70,
                            ),
                            SizedBox(width: 4),
                            Text(
                              '可拖動錨點微調',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                                fontFamily: 'NotoSansTC',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  if (_draggingIdx != null && _magPos != null)
                    _buildMagnifier(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMagnifier() {
    final norm = _magPos!;
    final cx = norm.dx * _imgW;
    final cy = norm.dy * _imgH;
    const r = _kMagRadius;
    const zoom = _kMagZoom;

    // Position magnifier above the finger; keep it inside image bounds
    double left = cx - r;
    double top = cy - r * 2.6 - 8;

    // Clamp so magnifier stays within the SizedBox bounds
    left = left.clamp(0.0, _imgW - r * 2);
    top = top.clamp(0.0, _imgH - r * 2);

    // The image inside the magnifier is translated so that (cx, cy) lands at (r, r)
    final tx = r - cx * zoom;
    final ty = r - cy * zoom;

    final draggingColor = _draggingIdx != null
        ? _colors[_draggingIdx!]
        : Colors.white;

    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: r * 2,
        height: r * 2,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: draggingColor, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: draggingColor.withValues(alpha: 0.4),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Zoomed image
            OverflowBox(
              minWidth: 0,
              minHeight: 0,
              maxWidth: double.infinity,
              maxHeight: double.infinity,
              alignment: Alignment.topLeft,
              child: Transform.translate(
                offset: Offset(tx, ty),
                child: SizedBox(
                  width: _imgW * zoom,
                  height: _imgH * zoom,
                  child: Image.network(widget.thumbnailUrl, fit: BoxFit.cover),
                ),
              ),
            ),
            // Crosshair overlay
            Positioned.fill(
              child: CustomPaint(
                painter: _CrosshairPainter(color: draggingColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistanceInputs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          spacing: 12,
          children: [
            Expanded(
              child: _buildDistanceField(
                label: '上邊實際距離 (公尺)',
                controller: _topCtrl,
                icon: Icons.straighten,
                color: const Color(0xFF4FC3F7),
              ),
            ),
            Expanded(
              child: _buildDistanceField(
                label: '下邊實際距離 (公尺)',
                controller: _botCtrl,
                icon: Icons.straighten,
                color: const Color(0xFFFFB74D),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDistanceField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontFamily: 'NotoSansTC',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: Icon(icon, size: 18, color: color),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.05),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            hintText: '0.00',
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildGuide() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white54, size: 14),
              SizedBox(width: 6),
              Text(
                '點選順序・設定完可拖動微調',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontFamily: 'NotoSansTC',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              4,
              (i) => _GuideStep(
                index: i + 1,
                label: _labels[i],
                color: _colors[i],
                done: i < _pts.length,
                active: i == _draggingIdx,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        OutlinedButton.icon(
          onPressed: _pts.isEmpty
              ? null
              : () => setState(() => _pts.removeLast()),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: const BorderSide(color: Colors.white24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: const Icon(Icons.undo, size: 16),
          label: const Text(
            '復原',
            style: TextStyle(fontFamily: 'NotoSansTC', fontSize: 13),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: _pts.isEmpty ? null : () => setState(() => _pts.clear()),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white54,
            side: const BorderSide(color: Colors.white12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text(
            '重設',
            style: TextStyle(fontFamily: 'NotoSansTC', fontSize: 13),
          ),
        ),
        const Spacer(),
        AnimatedOpacity(
          opacity: _canConfirm ? 1.0 : 0.4,
          duration: const Duration(milliseconds: 200),
          child: ElevatedButton.icon(
            onPressed: _canConfirm ? _confirm : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00BFA5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text(
              '確認錨點',
              style: TextStyle(
                fontFamily: 'NotoSansTC',
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Anchor Marker ─────────────────────────────────────────────

class _AnchorMarker extends StatelessWidget {
  final String label;
  final Color color;
  final int index;
  final bool isDragging;

  const _AnchorMarker({
    required this.label,
    required this.color,
    required this.index,
    this.isDragging = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isDragging ? 34 : 28,
          height: isDragging ? 34 : 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(
              color: isDragging ? Colors.white : Colors.white70,
              width: isDragging ? 2.5 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: isDragging ? 0.8 : 0.5),
                blurRadius: isDragging ? 14 : 8,
                spreadRadius: isDragging ? 3 : 1,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            '$index',
            style: TextStyle(
              color: Colors.white,
              fontSize: isDragging ? 14 : 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDragging ? 1.0 : 0.85),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              fontFamily: 'NotoSansTC',
            ),
          ),
        ),
      ],
    );
  }
}

// ── Guide Step ────────────────────────────────────────────────

class _GuideStep extends StatelessWidget {
  final int index;
  final String label;
  final Color color;
  final bool done;
  final bool active;

  const _GuideStep({
    required this.index,
    required this.label,
    required this.color,
    required this.done,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: active ? 30 : 26,
          height: active ? 30 : 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? color : Colors.transparent,
            border: Border.all(
              color: done || active ? color : color.withValues(alpha: 0.35),
              width: active ? 2.5 : 1.5,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.5),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: done
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : Text(
                  '$index',
                  style: TextStyle(
                    color: color.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: done || active ? color : Colors.white38,
            fontSize: 11,
            fontFamily: 'NotoSansTC',
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

// ── Quad Painter ──────────────────────────────────────────────

class _QuadPainter extends CustomPainter {
  final List<Offset> points;
  final double width;
  final double height;
  final int? draggingIdx;

  const _QuadPainter({
    required this.points,
    required this.width,
    required this.height,
    this.draggingIdx,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final pts = points.map((p) => Offset(p.dx * width, p.dy * height)).toList();

    final linePaint = Paint()
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // Edges
    for (int i = 0; i < pts.length - 1; i++) {
      final isDragEdge =
          draggingIdx != null && (i == draggingIdx || i + 1 == draggingIdx);
      linePaint
        ..color = _colors[i].withValues(alpha: isDragEdge ? 1.0 : 0.75)
        ..strokeWidth = isDragEdge ? 2.5 : 2.0;
      canvas.drawLine(pts[i], pts[i + 1], linePaint);
    }

    // Close quad
    if (pts.length == 4) {
      final isDragEdge =
          draggingIdx != null && (draggingIdx == 3 || draggingIdx == 0);
      linePaint
        ..color = _colors[3].withValues(alpha: isDragEdge ? 1.0 : 0.75)
        ..strokeWidth = isDragEdge ? 2.5 : 2.0;
      canvas.drawLine(pts[3], pts[0], linePaint);

      // Semi-transparent fill
      final path = Path()..addPolygon(pts, true);
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF2979FF).withValues(alpha: 0.10)
          ..style = PaintingStyle.fill,
      );
    }
  }

  @override
  bool shouldRepaint(_QuadPainter old) =>
      old.points != points ||
      old.width != width ||
      old.height != height ||
      old.draggingIdx != draggingIdx;
}

// ── Crosshair Painter ─────────────────────────────────────────

class _CrosshairPainter extends CustomPainter {
  final Color color;
  const _CrosshairPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Gap around the center dot so lines don't overlap it
    const gapRadius = 5.0;
    const dotRadius = 3.5;
    const lineLength = 14.0;

    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Horizontal lines (left gap ← center → right gap)
    canvas.drawLine(
      Offset(cx - gapRadius - lineLength, cy),
      Offset(cx - gapRadius, cy),
      linePaint,
    );
    canvas.drawLine(
      Offset(cx + gapRadius, cy),
      Offset(cx + gapRadius + lineLength, cy),
      linePaint,
    );

    // Vertical lines
    canvas.drawLine(
      Offset(cx, cy - gapRadius - lineLength),
      Offset(cx, cy - gapRadius),
      linePaint,
    );
    canvas.drawLine(
      Offset(cx, cy + gapRadius),
      Offset(cx, cy + gapRadius + lineLength),
      linePaint,
    );

    // Colored center dot
    canvas.drawCircle(Offset(cx, cy), dotRadius, Paint()..color = color);
    // White ring around dot for contrast
    canvas.drawCircle(
      Offset(cx, cy),
      dotRadius,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_CrosshairPainter old) => old.color != color;
}
