import 'dart:math' as math;

import 'package:flutter/material.dart';

class SolarBrandMark extends StatelessWidget {
  const SolarBrandMark({
    super.key,
    this.showWordmark = true,
    this.iconSize = 56,
    this.wordmarkSize = 26,
  });

  final bool showWordmark;
  final double iconSize;
  final double wordmarkSize;

  @override
  Widget build(BuildContext context) {
    final logoWidth = showWordmark
        ? math.max(iconSize * 2.9, wordmarkSize * 5.2)
        : iconSize * 1.35;

    return Image.asset(
      'assets/images/solar_logo.png',
      width: logoWidth,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: 'Solar logo',
      errorBuilder: (context, error, stackTrace) {
        return _FallbackSolarBrandMark(
          showWordmark: showWordmark,
          iconSize: iconSize,
          wordmarkSize: wordmarkSize,
        );
      },
    );
  }
}

class _FallbackSolarBrandMark extends StatelessWidget {
  const _FallbackSolarBrandMark({
    required this.showWordmark,
    required this.iconSize,
    required this.wordmarkSize,
  });

  final bool showWordmark;
  final double iconSize;
  final double wordmarkSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        SizedBox.square(
          dimension: iconSize,
          child: CustomPaint(painter: _SolarOrbitPainter()),
        ),
        if (showWordmark) ...<Widget>[
          const SizedBox(width: 10),
          Text(
            'solar',
            style: TextStyle(
              fontSize: wordmarkSize,
              fontWeight: FontWeight.w500,
              letterSpacing: -1,
              color: const Color(0xFF1A1D35),
            ),
          ),
        ],
      ],
    );
  }
}

class _SolarOrbitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.48, size.height * 0.58);
    final baseRadius = size.shortestSide * 0.29;

    final orbitRect = Rect.fromCenter(
      center: center.translate(-2, -2),
      width: size.width * 0.98,
      height: size.height * 0.42,
    );

    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.08
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF9EA4B5);

    final accentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.1
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF1A2041);

    canvas.drawArc(
      orbitRect,
      math.pi * 0.08,
      math.pi * 1.62,
      false,
      orbitPaint,
    );

    canvas.drawArc(
      orbitRect,
      math.pi * 0.8,
      math.pi * 0.72,
      false,
      accentPaint,
    );

    final planetPaint = Paint()..color = const Color(0xFF137C92);
    canvas.drawCircle(center, baseRadius, planetPaint);

    final highlightPaint = Paint()..color = const Color(0xFF20A9C2);
    canvas.drawCircle(
      center.translate(baseRadius * 0.08, baseRadius * -0.1),
      baseRadius * 0.84,
      highlightPaint,
    );

    final moonPaint = Paint()..color = const Color(0xFFFFB53A);
    canvas.drawCircle(
      Offset(size.width * 0.76, size.height * 0.2),
      size.shortestSide * 0.11,
      moonPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
