import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:rehab_ai/theme/rehab_theme.dart';

class RecoveryTrendChart extends StatelessWidget {
  const RecoveryTrendChart({
    super.key,
    required this.attempts,
    required this.tracksRepetitions,
    required this.color,
  });

  final List<Map<String, dynamic>> attempts;
  final bool tracksRepetitions;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final values = attempts
        .map<double?>(
          (attempt) => tracksRepetitions
              ? (attempt['duration_seconds'] as num?)?.toDouble()
              : (attempt['accuracy_score'] as num?)?.toDouble(),
        )
        .whereType<double>()
        .toList();
    if (values.isEmpty) return const SizedBox.shrink();

    final metric = tracksRepetitions ? 'Completion time' : 'Accuracy';
    final semantics = values
        .asMap()
        .entries
        .map((entry) {
          final value = tracksRepetitions
              ? '${entry.value.toStringAsFixed(0)} seconds'
              : '${entry.value.toStringAsFixed(0)} percent';
          return 'Attempt ${entry.key + 1}: $value';
        })
        .join(', ');

    return Semantics(
      label: '$metric trend. $semantics',
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        decoration: BoxDecoration(
          color: context.rehabSurfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.14)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$metric trend',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 126,
              width: double.infinity,
              child: CustomPaint(
                painter: _RecoveryTrendPainter(
                  values: values,
                  color: color,
                  suffix: tracksRepetitions ? 's' : '%',
                  gridColor: context.rehabBorder,
                  pointBackgroundColor: context.rehabSurfaceElevated,
                  labelColor: context.rehabMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecoveryTrendPainter extends CustomPainter {
  const _RecoveryTrendPainter({
    required this.values,
    required this.color,
    required this.suffix,
    required this.gridColor,
    required this.pointBackgroundColor,
    required this.labelColor,
  });

  final List<double> values;
  final Color color;
  final String suffix;
  final Color gridColor;
  final Color pointBackgroundColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    const left = 8.0;
    const right = 8.0;
    const top = 18.0;
    const bottom = 23.0;
    final chartWidth = math.max(1.0, size.width - left - right);
    final chartHeight = math.max(1.0, size.height - top - bottom);
    final minimum = values.reduce(math.min);
    final maximum = values.reduce(math.max);
    final spread = maximum - minimum;
    final padding = spread == 0
        ? math.max(maximum.abs() * 0.08, 1.0)
        : spread * 0.2;
    final minY = minimum - padding;
    final maxY = maximum + padding;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var row = 0; row < 3; row++) {
      final y = top + chartHeight * row / 2;
      canvas.drawLine(
        Offset(left, y),
        Offset(size.width - right, y),
        gridPaint,
      );
    }

    Offset pointFor(int index) {
      final x = values.length == 1
          ? left + chartWidth / 2
          : left + chartWidth * index / (values.length - 1);
      final normalized = (values[index] - minY) / (maxY - minY);
      return Offset(x, top + chartHeight * (1 - normalized));
    }

    final points = List.generate(values.length, pointFor);
    if (points.length > 1) {
      final fillPath = Path()..moveTo(points.first.dx, top + chartHeight);
      for (final point in points) {
        fillPath.lineTo(point.dx, point.dy);
      }
      fillPath
        ..lineTo(points.last.dx, top + chartHeight)
        ..close();
      canvas.drawPath(
        fillPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.22),
              color.withValues(alpha: 0.02),
            ],
          ).createShader(Rect.fromLTWH(left, top, chartWidth, chartHeight)),
      );

      final linePath = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        linePath.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(
        linePath,
        Paint()
          ..color = color
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      canvas.drawCircle(point, 4, Paint()..color = pointBackgroundColor);
      canvas.drawCircle(
        point,
        3,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill,
      );
      if (index == 0 || index == points.length - 1) {
        _drawLabel(
          canvas,
          '${values[index].toStringAsFixed(0)}$suffix',
          Offset(point.dx, math.max(0, point.dy - 17)),
          center: true,
          color: color,
          bold: true,
        );
      }
    }

    _drawLabel(
      canvas,
      'First',
      Offset(left, size.height - 13),
      color: labelColor,
    );
    if (values.length > 1) {
      _drawLabel(
        canvas,
        'Latest',
        Offset(size.width - right, size.height - 13),
        alignRight: true,
        color: labelColor,
      );
    }
  }

  void _drawLabel(
    Canvas canvas,
    String text,
    Offset position, {
    bool center = false,
    bool alignRight = false,
    required Color color,
    bool bold = false,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = center
        ? position.dx - painter.width / 2
        : alignRight
        ? position.dx - painter.width
        : position.dx;
    painter.paint(canvas, Offset(dx, position.dy));
  }

  @override
  bool shouldRepaint(covariant _RecoveryTrendPainter oldDelegate) => true;
}
