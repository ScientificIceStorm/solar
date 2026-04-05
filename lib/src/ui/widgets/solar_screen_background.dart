import 'package:flutter/material.dart';

class SolarScreenBackground extends StatelessWidget {
  const SolarScreenBackground({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.symmetric(horizontal: 24),
    this.respectSafeArea = true,
    this.topFillColor,
    this.topFillHeight = 0,
  });

  final Widget child;
  final EdgeInsets padding;
  final bool respectSafeArea;
  final Color? topFillColor;
  final double topFillHeight;

  @override
  Widget build(BuildContext context) {
    final darkMode = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: darkMode
              ? const <Color>[
                  Color(0xFF0D1020),
                  Color(0xFF12172A),
                  Color(0xFF171D33),
                ]
              : const <Color>[
                  Color(0xFFFBF9FD),
                  Color(0xFFF7F4F8),
                  Color(0xFFFCFBFE),
                ],
        ),
      ),
      child: Stack(
        children: <Widget>[
          if (topFillColor != null && topFillHeight > 0)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: topFillHeight,
              child: ColoredBox(color: topFillColor!),
            ),
          Positioned(
            top: -80,
            left: -70,
            child: _GlowBlob(
              size: 220,
              color: darkMode
                  ? const Color(0xFF284564)
                  : const Color(0xFFFFD2C1),
            ),
          ),
          Positioned(
            top: 160,
            right: -70,
            child: _GlowBlob(
              size: 250,
              color: darkMode
                  ? const Color(0xFF213B72)
                  : const Color(0xFFCDE4FF),
            ),
          ),
          Positioned(
            bottom: -110,
            left: -90,
            child: _GlowBlob(
              size: 300,
              color: darkMode
                  ? const Color(0xFF3D325C)
                  : const Color(0xFFE7D8FF),
            ),
          ),
          if (respectSafeArea)
            SafeArea(
              child: Padding(padding: padding, child: child),
            )
          else
            Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[
              color.withValues(alpha: 0.34),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}
