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
            },
            onHorizontalDragUpdate: (details) {
              if (_didPopThisDrag) {
                return;
              }
              if ((details.primaryDelta ?? 0) > 14) {
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
