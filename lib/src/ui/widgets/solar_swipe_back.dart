import 'package:flutter/material.dart';

class SolarSwipeBack extends StatefulWidget {
  const SolarSwipeBack({required this.child, super.key, this.edgeWidth = 28});

  final Widget child;
  final double edgeWidth;

  @override
  State<SolarSwipeBack> createState() => _SolarSwipeBackState();
}

class _SolarSwipeBackState extends State<SolarSwipeBack> {
  bool _didPopThisDrag = false;
  double _dragDistance = 0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        widget.child,
        Positioned(
          left: 0,
          top: 0,
          bottom: 0,
          width: widget.edgeWidth,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (_) {
              _didPopThisDrag = false;
              _dragDistance = 0;
            },
            onHorizontalDragUpdate: (details) {
              if (_didPopThisDrag) {
                return;
              }
              final delta = details.primaryDelta ?? 0;
              if (delta > 0) {
                _dragDistance += delta;
              } else {
                _dragDistance = (_dragDistance + delta).clamp(0, double.infinity);
              }
            },
            onHorizontalDragEnd: (details) {
              if (_didPopThisDrag) {
                return;
              }
              final velocity = details.primaryVelocity ?? 0;
              if (_dragDistance >= 72 || velocity >= 680) {
                _didPopThisDrag = true;
                Navigator.of(context).maybePop();
              }
            },
          ),
        ),
      ],
    );
  }
}
