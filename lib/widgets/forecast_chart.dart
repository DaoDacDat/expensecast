import 'package:flutter/material.dart';

import '../core/formatters.dart';

/// Spending trajectory chart on the Insights screen (mockup 6):
/// solid line = actual spending, dashed line = forecast, horizontal dotted line = limit.
class ForecastChart extends StatelessWidget {
  const ForecastChart({
    super.key,
    required this.actual,
    required this.predicted,
    required this.budgetLimit,
    this.height = 170,
  });

  final List<double> actual;
  final List<double> predicted;
  final double budgetLimit;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _ForecastPainter(
              actual: actual,
              predicted: predicted,
              budgetLimit: budgetLimit,
              actualColor: scheme.primary,
              predictedColor: scheme.tertiary,
              budgetColor: scheme.onSurfaceVariant,
              axisColor: scheme.outlineVariant,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: [
            _LegendItem(
              color: scheme.primary,
              label: 'actual',
              dashed: false,
            ),
            _LegendItem(
              color: scheme.tertiary,
              label: 'predicted',
              dashed: true,
            ),
            _LegendItem(
              color: scheme.onSurfaceVariant,
              label: 'budget ${Fmt.moneyRound(budgetLimit)}',
              dashed: true,
            ),
          ],
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.dashed,
  });

  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 18,
          height: 2,
          child: CustomPaint(
            painter: _LegendLinePainter(color: color, dashed: dashed),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _LegendLinePainter extends CustomPainter {
  _LegendLinePainter({required this.color, required this.dashed});

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    if (!dashed) {
      canvas.drawLine(Offset(0, size.height / 2),
          Offset(size.width, size.height / 2), paint);
      return;
    }
    var x = 0.0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset((x + 4).clamp(0, size.width), size.height / 2),
        paint,
      );
      x += 7;
    }
  }

  @override
  bool shouldRepaint(covariant _LegendLinePainter old) =>
      old.color != color || old.dashed != dashed;
}

class _ForecastPainter extends CustomPainter {
  _ForecastPainter({
    required this.actual,
    required this.predicted,
    required this.budgetLimit,
    required this.actualColor,
    required this.predictedColor,
    required this.budgetColor,
    required this.axisColor,
  });

  final List<double> actual;
  final List<double> predicted;
  final double budgetLimit;
  final Color actualColor;
  final Color predictedColor;
  final Color budgetColor;
  final Color axisColor;

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 8.0;
    const bottomPad = 18.0;
    const topPad = 10.0;

    final chartW = size.width - leftPad * 2;
    final chartH = size.height - bottomPad - topPad;
    if (chartW <= 0 || chartH <= 0) return;

    final all = <double>[...actual, ...predicted, budgetLimit, 0];
    final maxY = all.reduce((a, b) => a > b ? a : b);
    final safeMax = maxY <= 0 ? 1.0 : maxY * 1.12;

    final totalPoints = actual.length + predicted.length;
    if (totalPoints < 2) return;

    double dx(int index) =>
        leftPad + chartW * (index / (totalPoints - 1));
    double dy(double value) =>
        topPad + chartH - (value / safeMax) * chartH;

    // Axes
    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(leftPad, topPad + chartH),
      Offset(leftPad + chartW, topPad + chartH),
      axisPaint,
    );

    // Limit line (horizontal dotted)
    final budgetPaint = Paint()
      ..color = budgetColor
      ..strokeWidth = 1.4;
    final budgetY = dy(budgetLimit);
    var bx = leftPad;
    while (bx < leftPad + chartW) {
      canvas.drawLine(
        Offset(bx, budgetY),
        Offset((bx + 3).clamp(leftPad, leftPad + chartW), budgetY),
        budgetPaint,
      );
      bx += 8;
    }

    // Actual line (solid)
    final actualPaint = Paint()
      ..color = actualColor
      ..strokeWidth = 2.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final actualPath = Path();
    for (var i = 0; i < actual.length; i++) {
      final p = Offset(dx(i), dy(actual[i]));
      if (i == 0) {
        actualPath.moveTo(p.dx, p.dy);
      } else {
        actualPath.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(actualPath, actualPaint);

    // Light fill under the actual line
    if (actual.isNotEmpty) {
      final fill = Path.from(actualPath)
        ..lineTo(dx(actual.length - 1), topPad + chartH)
        ..lineTo(dx(0), topPad + chartH)
        ..close();
      canvas.drawPath(
        fill,
        Paint()..color = actualColor.withValues(alpha: 0.10),
      );
    }

    // Forecast line (dashed), continuing from the last actual point
    if (predicted.isNotEmpty && actual.isNotEmpty) {
      final points = <Offset>[
        Offset(dx(actual.length - 1), dy(actual.last)),
        for (var i = 0; i < predicted.length; i++)
          Offset(dx(actual.length + i), dy(predicted[i])),
      ];

      final predictedPaint = Paint()
        ..color = predictedColor
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round;

      for (var i = 0; i < points.length - 1; i++) {
        _dashedLine(canvas, points[i], points[i + 1], predictedPaint);
      }

      // Dot at the last forecast point
      canvas.drawCircle(
        points.last,
        4,
        Paint()..color = predictedColor,
      );
    }

    // Divider between actual and predicted
    if (actual.isNotEmpty && predicted.isNotEmpty) {
      final sepX = dx(actual.length - 1);
      final sepPaint = Paint()
        ..color = axisColor
        ..strokeWidth = 1;
      var y = topPad;
      while (y < topPad + chartH) {
        canvas.drawLine(Offset(sepX, y), Offset(sepX, y + 3), sepPaint);
        y += 7;
      }
    }
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
    const dash = 6.0;
    const gap = 4.0;
    final total = (b - a).distance;
    if (total == 0) return;
    final dir = (b - a) / total;
    var travelled = 0.0;
    while (travelled < total) {
      final end = (travelled + dash).clamp(0.0, total);
      canvas.drawLine(a + dir * travelled, a + dir * end, paint);
      travelled = end + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _ForecastPainter old) =>
      old.actual != actual ||
      old.predicted != predicted ||
      old.budgetLimit != budgetLimit;
}
