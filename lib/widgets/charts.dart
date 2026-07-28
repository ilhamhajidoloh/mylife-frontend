import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class Sparkline extends StatelessWidget {
  final List<double> points;
  final Color color;
  final double maxY;
  final Size size;
  const Sparkline(this.points,
      {super.key,
      required this.color,
      this.maxY = 30,
      this.size = const Size(84, 30)});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: CustomPaint(size: size, painter: _SparkPainter(points, color, maxY)),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> pts;
  final Color color;
  final double maxY;
  _SparkPainter(this.pts, this.color, this.maxY);

  // ค่ามาก = อยู่ด้านบน (เหมือนกราฟทั่วไป) และ clamp กันค่าล้นกรอบเมื่อเกิน maxY
  double _yOf(double v, double height) => height - (v / maxY).clamp(0.0, 1.0) * height;

  @override
  void paint(Canvas canvas, Size size) {
    if (pts.length < 2) return;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final dx = size.width / (pts.length - 1);
    for (var i = 0; i < pts.length; i++) {
      final x = dx * i;
      final y = _yOf(pts[i], size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final prevX = dx * (i - 1);
        final prevY = _yOf(pts[i - 1], size.height);
        final cpX = (prevX + x) / 2;
        path.cubicTo(cpX, prevY, cpX, y, x, y);
      }
    }
    canvas.drawPath(path, paint);

    // Glow effect
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawPath(path, glowPaint);

    // End dot
    final lastX = dx * (pts.length - 1);
    final lastY = _yOf(pts.last, size.height);
    final dotPaint = Paint()..color = color;
    final ringPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(lastX, lastY), 4, dotPaint);
    canvas.drawCircle(Offset(lastX, lastY), 4, ringPaint);
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.pts != pts || old.color != color;
}

/// ป้ายกำกับสำหรับกราฟเส้น 2 ชุดข้อมูล — ไอคอนต่างกันแยกชนิดข้อมูล ไม่พึ่งสีอย่างเดียว
class TrendLegend extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  const TrendLegend({super.key, required this.color, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, size: 12, color: color),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: context.c.ink2)),
      ],
    );
  }
}

/// กราฟเส้นเปรียบเทียบ 2 ชุดข้อมูล (เช่น รายรับ-รายจ่าย) ตามช่วงเวลา
/// ใช้เส้น+พื้นที่แรเงาแทนแท่งคู่ เพื่อไม่ให้แน่นอึดอัดเมื่อมีจุดข้อมูลจำนวนมาก (เช่น รายวัน 31 จุด)
class CompareTrendChart extends StatelessWidget {
  final List<String> labels;
  final List<double> a;
  final List<double> b;
  final Color colorA;
  final Color colorB;
  final double maxV;
  final double height;
  const CompareTrendChart({
    super.key,
    required this.labels,
    required this.a,
    required this.b,
    required this.colorA,
    required this.colorB,
    required this.maxV,
    this.height = 168,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    // แสดงป้ายแกน X แค่บางจุด (ราว 6 ป้าย) กันแน่นเกินไปเมื่อมีข้อมูลเยอะ
    final step = (labels.length / 6).ceil().clamp(1, labels.length);

    return SizedBox(
      height: height + 20,
      child: Column(
        children: [
          Expanded(
            child: SizedBox(
              width: double.infinity,
              child: CustomPaint(painter: _TrendPainter(a, b, colorA, colorB, maxV, c.border)),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: (i % step == 0 || i == labels.length - 1)
                      ? Text(labels[i],
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500, color: c.ink3))
                      : const SizedBox.shrink(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<double> a;
  final List<double> b;
  final Color colorA;
  final Color colorB;
  final double maxV;
  final Color gridColor;
  _TrendPainter(this.a, this.b, this.colorA, this.colorB, this.maxV, this.gridColor);

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (final f in [0.0, 0.5, 1.0]) {
      final y = size.height * (1 - f);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (a.length < 2) {
      if (a.isNotEmpty) {
        _drawDot(canvas, Offset(size.width / 2, size.height * (1 - (a[0] / maxV).clamp(0.0, 1.0))), colorA);
        _drawDot(canvas, Offset(size.width / 2, size.height * (1 - (b[0] / maxV).clamp(0.0, 1.0))), colorB);
      }
      return;
    }

    // เส้นทึบ = รายรับ, เส้นประ = รายจ่าย เพื่อไม่ให้แยกชุดข้อมูลด้วยสีอย่างเดียว (รองรับผู้ที่แยกสีเขียว-แดงยาก)
    _drawSeries(canvas, size, a, colorA, dashed: false);
    _drawSeries(canvas, size, b, colorB, dashed: true);
  }

  void _drawSeries(Canvas canvas, Size size, List<double> values, Color color, {required bool dashed}) {
    final dx = size.width / (values.length - 1);
    Offset pt(int i) => Offset(dx * i, size.height * (1 - (values[i] / maxV).clamp(0.0, 1.0)));

    final line = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < values.length; i++) {
      final prev = pt(i - 1);
      final p = pt(i);
      final cpX = (prev.dx + p.dx) / 2;
      line.cubicTo(cpX, prev.dy, cpX, p.dy, p.dx, p.dy);
    }

    final fill = Path.from(line)
      ..lineTo(pt(values.length - 1).dx, size.height)
      ..lineTo(pt(0).dx, size.height)
      ..close();
    canvas.drawPath(fill, Paint()..color = color.withValues(alpha: 0.10));

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(dashed ? _dashPath(line) : line, strokePaint);

    _drawDot(canvas, pt(values.length - 1), color);
  }

  Path _dashPath(Path source, {double dashWidth = 6, double dashGap = 4.5}) {
    final dashed = Path();
    for (final metric in source.computeMetrics()) {
      var distance = 0.0;
      var draw = true;
      while (distance < metric.length) {
        final next = distance + (draw ? dashWidth : dashGap);
        if (draw) dashed.addPath(metric.extractPath(distance, next.clamp(0, metric.length)), Offset.zero);
        distance = next;
        draw = !draw;
      }
    }
    return dashed;
  }

  void _drawDot(Canvas canvas, Offset o, Color color) {
    canvas.drawCircle(o, 4.5, Paint()..color = color);
    canvas.drawCircle(
      o,
      4.5,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.a != a || old.b != b || old.colorA != colorA || old.colorB != colorB || old.maxV != maxV;
}

class GoalBars extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final double maxV;
  final double goal;
  final String goalLabel;
  final Color color;
  final Color peakColor;
  const GoalBars({
    super.key,
    required this.values,
    required this.labels,
    required this.maxV,
    required this.goal,
    required this.goalLabel,
    required this.color,
    required this.peakColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final peak = values.indexOf(values.reduce((x, y) => x > y ? x : y));
    const barsHeight = 150.0;
    return Column(
      children: [
        SizedBox(
          height: barsHeight,
          child: Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < values.length; i++)
                    Expanded(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: FractionallySizedBox(
                          heightFactor: (values[i] / maxV).clamp(0.0, 1.0),
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            widthFactor: 0.6,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 26),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: i == peak
                                      ? [peakColor, peakColor.withValues(alpha: 0.85)]
                                      : [color, color.withValues(alpha: 0.7)],
                                ),
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(6),
                                    bottom: Radius.circular(3)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: (goal / maxV) * barsHeight,
                child: Row(
                  children: [
                    Expanded(
                      child: CustomPaint(
                        size: const Size(double.infinity, 1),
                        painter: _DashedLinePainter(c.ink3.withValues(alpha: 0.4)),
                      ),
                    ),
                    Container(
                      color: c.surface,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(goalLabel,
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: c.ink3)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final l in labels)
              Expanded(
                child: Text(l,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: c.ink3)),
              ),
          ],
        ),
      ],
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  final Color color;
  _DashedLinePainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    const dash = 5.0, gap = 4.0;
    double x = 0;
    while (x < size.width) {
      canvas.drawLine(Offset(x, 0), Offset(x + dash, 0), paint);
      x += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) => old.color != color;
}

class CategoryBar extends StatelessWidget {
  final String label;
  final String amount;
  final double fraction;
  final Color color;
  const CategoryBar({
    super.key,
    required this.label,
    required this.amount,
    required this.fraction,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: c.ink)),
            Text(amount,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: c.ink2)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 10,
            color: c.surface2,
            child: FractionallySizedBox(
              widthFactor: fraction.clamp(0.0, 1.0),
              alignment: Alignment.centerLeft,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.8)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ProgressRing extends StatelessWidget {
  final double progress;
  final String centerTop;
  final String centerBottom;
  final Color color;
  final double size;
  const ProgressRing({
    super.key,
    required this.progress,
    required this.centerTop,
    required this.centerBottom,
    required this.color,
    this.size = 128,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(progress, color, c.border),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(centerTop,
                  style: TextStyle(
                      fontSize: size * 0.19,
                      fontWeight: FontWeight.w900,
                      color: c.ink)),
              Text(centerBottom,
                  style: TextStyle(fontSize: size * 0.085, fontWeight: FontWeight.w500, color: c.ink3)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color track;
  _RingPainter(this.progress, this.color, this.track);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.width - 14) / 2;
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);
    const start = -1.5708;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start,
        6.28319 * progress, false, arcPaint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

class MoodLine extends StatelessWidget {
  final List<double> values;
  final Color color;
  final double height;
  const MoodLine(this.values,
      {super.key, required this.color, this.height = 120});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _MoodPainter(values, color, c.border, c.surface)),
    );
  }
}

class _MoodPainter extends CustomPainter {
  final List<double> v;
  final Color color;
  final Color grid;
  final Color surface;
  _MoodPainter(this.v, this.color, this.grid, this.surface);

  @override
  void paint(Canvas canvas, Size size) {
    const padY = 14.0;
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final f in [0.0, 0.5, 1.0]) {
      final y = padY + f * (size.height - padY * 2);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    if (v.length < 2) return;
    final dx = size.width / (v.length - 1);
    double xy(int i) => dx * i;
    double yy(double val) =>
        padY + (1 - (val - 1) / 4) * (size.height - padY * 2);

    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    for (var i = 0; i < v.length; i++) {
      final x = xy(i), y = yy(v[i]);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(path, line);

    final dot = Paint()..color = color;
    final ring = Paint()
      ..color = surface
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final peak = v.indexOf(v.reduce((a, b) => a >= b ? a : b));
    for (var i = 0; i < v.length; i++) {
      final o = Offset(xy(i), yy(v[i]));
      canvas.drawCircle(o, i == peak ? 5.5 : 4.5, dot);
      if (i == peak) canvas.drawCircle(o, 5.5, ring);
    }
  }

  @override
  bool shouldRepaint(_MoodPainter old) => old.v != v || old.color != color;
}

class HabitDot extends StatelessWidget {
  final bool? state;
  const HabitDot(this.state, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Color bg;
    Color? border;
    Widget? mark;
    if (state == true) {
      bg = c.accent;
      mark = const Icon(Icons.check, size: 13, color: Colors.white);
    } else if (state == false) {
      bg = c.coralSoft;
    } else {
      bg = c.surface2;
      border = c.border;
    }
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(7),
        border: border != null ? Border.all(color: border) : null,
      ),
      child: mark,
    );
  }
}
