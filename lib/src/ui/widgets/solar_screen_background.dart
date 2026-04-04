import 'package:flutter/material.dart';

class SolarScreenBackground extends StatelessWidget {
  const SolarScreenBackground({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.symmetric(horizontal: 24),
    this.respectSafeArea = true,
  });

  final Widget child;
  final EdgeInsets padding;
  final bool respectSafeArea;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFFBF9FD),
            Color(0xFFF7F4F8),
            Color(0xFFFCFBFE),
          ],
        ),
      ),
      child: Stack(
        children: <Widget>[
          const Positioned(
            top: -80,
            left: -70,
            child: _GlowBlob(size: 220, color: Color(0xFFFFD2C1)),
          ),
          const Positioned(
            top: 160,
            right: -70,
            child: _GlowBlob(size: 250, color: Color(0xFFCDE4FF)),
          ),
          const Positioned(
            bottom: -110,
            left: -90,
            child: _GlowBlob(size: 300, color: Color(0xFFE7D8FF)),
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
