import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/robot_events_models.dart';
import '../services/city_photo_service.dart';

class SolarEventPhoto extends StatelessWidget {
  const SolarEventPhoto({
    required this.location,
    super.key,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.overlay,
  });

  final LocationSummary location;
  final BoxFit fit;
  final Alignment alignment;
  final Widget? overlay;

  @override
  Widget build(BuildContext context) {
    final overlayChildren = overlay == null ? null : <Widget>[overlay!];

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        SolarEventPhotoFallback(
          location: location,
          fit: fit,
          alignment: alignment,
        ),
        ...?overlayChildren,
      ],
    );
  }
}

class SolarEventPhotoFallback extends StatelessWidget {
  const SolarEventPhotoFallback({
    required this.location,
    super.key,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
  });

  final LocationSummary location;
  final BoxFit fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final visual = CityPhotoService.visualFor(location);
    final label = CityPhotoService.labelFor(location);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: visual.skyColors,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          CustomPaint(painter: _SolarEventScenePainter(visual: visual)),
          Positioned(
            left: 18,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF1B213B),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SolarEventScenePainter extends CustomPainter {
  const _SolarEventScenePainter({required this.visual});

  final CityPhotoVisual visual;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final hazePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          Colors.white.withValues(alpha: 0),
          visual.hazeColor,
          Colors.white.withValues(alpha: 0),
        ],
        stops: const <double>[0, 0.62, 1],
      ).createShader(rect);
    canvas.drawRect(rect, hazePaint);

    final sunPaint = Paint()..color = visual.sunColor.withValues(alpha: 0.92);
    canvas.drawCircle(
      Offset(size.width * 0.82, size.height * 0.18),
      size.shortestSide * 0.09,
      sunPaint,
    );

    final cloudPaint = Paint()..color = Colors.white.withValues(alpha: 0.28);
    _drawCloud(
      canvas,
      Offset(size.width * 0.18, size.height * 0.16),
      cloudPaint,
    );
    _drawCloud(
      canvas,
      Offset(size.width * 0.58, size.height * 0.12),
      cloudPaint,
    );
    _drawCloud(
      canvas,
      Offset(size.width * 0.78, size.height * 0.28),
      cloudPaint..color = Colors.white.withValues(alpha: 0.16),
    );

    final skylineBaseline = size.height * 0.56;
    final buildingWidths = <double>[
      size.width * 0.16,
      size.width * 0.12,
      size.width * 0.18,
      size.width * 0.11,
      size.width * 0.15,
      size.width * 0.1,
    ];
    final buildingHeights = <double>[
      size.height * 0.34,
      size.height * 0.27,
      size.height * 0.38,
      size.height * 0.24,
      size.height * 0.31,
      size.height * 0.36,
    ];

    var x = size.width * 0.02;
    for (var i = 0; i < buildingWidths.length; i++) {
      final width = buildingWidths[i];
      final height = buildingHeights[i];
      final color = visual.buildingColors[i % visual.buildingColors.length];
      final buildingRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, skylineBaseline - height, width, height),
        const Radius.circular(6),
      );
      canvas.drawRRect(buildingRect, Paint()..color = color);

      final stripePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.15)
        ..strokeWidth = 1.2;
      final stripeCount = math.max(2, (height / 18).floor());
      for (var stripe = 1; stripe < stripeCount; stripe++) {
        final y = skylineBaseline - height + (stripe * height / stripeCount);
        canvas.drawLine(
          Offset(x + 6, y),
          Offset(x + width - 6, y),
          stripePaint,
        );
      }

      x += width + size.width * 0.015;
    }

    if (visual.landmark == CityLandmark.arch) {
      final archPaint = Paint()
        ..color = const Color(0xFFECE9E4)
        ..strokeWidth = size.width * 0.022
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final archRect = Rect.fromCenter(
        center: Offset(size.width * 0.62, skylineBaseline - size.height * 0.1),
        width: size.width * 0.26,
        height: size.height * 0.48,
      );
      canvas.drawArc(archRect, math.pi, -math.pi, false, archPaint);
    }

    final riverPath = Path()
      ..moveTo(0, size.height * 0.74)
      ..quadraticBezierTo(
        size.width * 0.24,
        size.height * 0.66,
        size.width * 0.52,
        size.height * 0.78,
      )
      ..quadraticBezierTo(
        size.width * 0.72,
        size.height * 0.86,
        size.width,
        size.height * 0.76,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      riverPath,
      Paint()..color = visual.waterColor.withValues(alpha: 0.5),
    );

    final lawnPaint = Paint()
      ..color = const Color(0xFF7CA15A).withValues(alpha: 0.9);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.width * 0.36, size.height * 0.78),
        width: size.width * 0.48,
        height: size.height * 0.18,
      ),
      lawnPaint,
    );

    final plazaPaint = Paint()..color = visual.groundColor;
    final plazaPath = Path()
      ..moveTo(size.width * 0.08, size.height * 0.88)
      ..lineTo(size.width * 0.92, size.height * 0.88)
      ..lineTo(size.width * 0.76, size.height * 0.67)
      ..lineTo(size.width * 0.24, size.height * 0.67)
      ..close();
    canvas.drawPath(plazaPath, plazaPaint);

    final walkwayPaint = Paint()
      ..color = const Color(0xFFE8DDD1).withValues(alpha: 0.96);
    final walkwayPath = Path()
      ..moveTo(size.width * 0.47, size.height)
      ..lineTo(size.width * 0.53, size.height)
      ..lineTo(size.width * 0.58, size.height * 0.67)
      ..lineTo(size.width * 0.42, size.height * 0.67)
      ..close();
    canvas.drawPath(walkwayPath, walkwayPaint);

    final pavilionPaint = Paint()..color = const Color(0xFFD9D4CB);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.31,
          size.height * 0.68,
          size.width * 0.38,
          size.height * 0.07,
        ),
        const Radius.circular(6),
      ),
      pavilionPaint,
    );

    final roofPaint = Paint()..color = const Color(0xFFC84A47);
    final roofPath = Path()
      ..moveTo(size.width * 0.28, size.height * 0.69)
      ..lineTo(size.width * 0.5, size.height * 0.61)
      ..lineTo(size.width * 0.72, size.height * 0.69)
      ..close();
    canvas.drawPath(roofPath, roofPaint);
  }

  void _drawCloud(Canvas canvas, Offset offset, Paint paint) {
    canvas.drawOval(
      Rect.fromCenter(center: offset, width: 60, height: 18),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: offset.translate(-18, 2), width: 28, height: 22),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: offset.translate(18, 0), width: 24, height: 18),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _SolarEventScenePainter oldDelegate) {
    return oldDelegate.visual != visual;
  }
}
