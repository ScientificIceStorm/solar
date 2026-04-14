import 'dart:math' as math;

import 'package:flutter/material.dart';

class SolarTrendPoint {
  const SolarTrendPoint({
    required this.label,
    required this.value,
    this.detail,
  });

  final String label;
  final double value;
  final String? detail;
}

class SolarTrendChart extends StatelessWidget {
  const SolarTrendChart({
    required this.points,
    required this.emptyLabel,
    required this.valueLabel,
    super.key,
    this.lineColor = const Color(0xFF1F4B99),
    this.signed = false,
    this.height = 170,
  });

  final List<SolarTrendPoint> points;
  final String emptyLabel;
  final String valueLabel;
  final Color lineColor;
  final bool signed;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return Text(
        emptyLabel,
        style: const TextStyle(
          color: Color(0xFF8E92A7),
          fontSize: 14,
          height: 1.45,
        ),
      );
    }

    final values = points.map((point) => point.value).toList(growable: false);
    final latest = points.last.value;
    final minValue = values.reduce(math.min);
    final maxValue = values.reduce(math.max);
    final middle = points.length ~/ 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              _formatValue(latest),
              style: const TextStyle(
                color: Color(0xFF24243A),
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                valueLabel,
                style: const TextStyle(
                  color: Color(0xFF8E92A7),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${_formatValue(minValue)} to ${_formatValue(maxValue)}',
              style: const TextStyle(
                color: Color(0xFF8E92A7),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _SolarTrendChartPainter(
              points: points,
              lineColor: lineColor,
              signed: signed,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                points.first.label,
                style: const TextStyle(
                  color: Color(0xFF8E92A7),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Text(
                points[middle].label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF8E92A7),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Expanded(
              child: Text(
                points.last.label,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Color(0xFF8E92A7),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _formatValue(double value) {
    if (signed) {
      return value >= 0
          ? '+${value.toStringAsFixed(1)}'
          : value.toStringAsFixed(1);
    }
    if (value.abs() >= 10) {
      return value.toStringAsFixed(1);
    }
    return value.toStringAsFixed(2);
  }
}

class _SolarTrendChartPainter extends CustomPainter {
  const _SolarTrendChartPainter({
    required this.points,
    required this.lineColor,
    required this.signed,
  });

  final List<SolarTrendPoint> points;
  final Color lineColor;
  final bool signed;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) {
      return;
    }

    final values = points.map((point) => point.value).toList(growable: false);
    var minValue = values.reduce(math.min);
    var maxValue = values.reduce(math.max);
    if ((maxValue - minValue).abs() < 0.0001) {
      minValue -= 1;
      maxValue += 1;
    }

    final chartRect = Rect.fromLTWH(0, 6, size.width, size.height - 14);
    final gridPaint = Paint()
      ..color = const Color(0xFFE7E8F1)
      ..strokeWidth = 1;
    final baselinePaint = Paint()
      ..color = const Color(0xFFD7DAE8)
      ..strokeWidth = 1.2;
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          lineColor.withValues(alpha: 0.20),
          lineColor.withValues(alpha: 0.02),
        ],
      ).createShader(chartRect);
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final dotPaint = Paint()..color = lineColor;
    final dotFillPaint = Paint()..color = Colors.white;

    for (var i = 0; i < 4; i++) {
      final dy = chartRect.top + ((chartRect.height / 3) * i);
      canvas.drawLine(
        Offset(chartRect.left, dy),
        Offset(chartRect.right, dy),
        gridPaint,
      );
    }

    Offset pointAt(int index) {
      final ratio = points.length <= 1 ? 0.0 : index / (points.length - 1);
      final normalized = (points[index].value - minValue) / (maxValue - minValue);
      return Offset(
        chartRect.left + (chartRect.width * ratio),
        chartRect.bottom - (chartRect.height * normalized),
      );
    }

    if (signed && minValue < 0 && maxValue > 0) {
      final zeroRatio = (0 - minValue) / (maxValue - minValue);
      final zeroY = chartRect.bottom - (chartRect.height * zeroRatio);
      canvas.drawLine(
        Offset(chartRect.left, zeroY),
        Offset(chartRect.right, zeroY),
        baselinePaint,
      );
    }

    final path = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(pointAt(i).dx, pointAt(i).dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(chartRect.right, chartRect.bottom)
      ..lineTo(chartRect.left, chartRect.bottom)
      ..close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    for (var i = 0; i < points.length; i++) {
      final point = pointAt(i);
      canvas.drawCircle(point, 4.5, dotFillPaint);
      canvas.drawCircle(point, 3.2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SolarTrendChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.signed != signed;
  }
}
