import 'package:flutter/material.dart';

import '../../models/robot_events_models.dart';
import '../services/city_photo_service.dart';
import '../services/location_photo_service.dart';

class SolarEventPhoto extends StatefulWidget {
  const SolarEventPhoto({
    required this.location,
    super.key,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
    this.overlay,
    this.showAttribution = true,
  });

  final LocationSummary location;
  final BoxFit fit;
  final Alignment alignment;
  final Widget? overlay;
  final bool showAttribution;

  @override
  State<SolarEventPhoto> createState() => _SolarEventPhotoState();
}

class _SolarEventPhotoState extends State<SolarEventPhoto> {
  late Future<LocationPhotoAsset?> _photoAssetFuture;

  @override
  void initState() {
    super.initState();
    _photoAssetFuture = LocationPhotoService.photoAssetFor(widget.location);
  }

  @override
  void didUpdateWidget(covariant SolarEventPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location.city != widget.location.city ||
        oldWidget.location.region != widget.location.region ||
        oldWidget.location.country != widget.location.country ||
        oldWidget.location.venue != widget.location.venue) {
      _photoAssetFuture = LocationPhotoService.photoAssetFor(widget.location);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LocationPhotoAsset?>(
      future: _photoAssetFuture,
      builder: (context, snapshot) {
        final asset = snapshot.data;
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            SolarEventPhotoFallback(
              location: widget.location,
              fit: widget.fit,
              alignment: widget.alignment,
            ),
            if (asset != null)
              Image.network(
                asset.url,
                fit: widget.fit,
                alignment: widget.alignment,
                gaplessPlayback: true,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) {
                    return child;
                  }
                  return AnimatedOpacity(
                    duration: const Duration(milliseconds: 240),
                    opacity: 0,
                    child: child,
                  );
                },
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.shrink(),
              ),
            if (widget.overlay != null) widget.overlay!,
            if (asset != null && widget.showAttribution)
              Positioned(
                left: 6,
                top: 14,
                bottom: 14,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _PhotoCreditLabel(asset: asset),
                ),
              ),
          ],
        );
      },
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
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: visual.skyColors,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned(
            top: -60,
            right: -30,
            child: _SoftOrb(
              size: 180,
              color: Colors.white.withValues(alpha: 0.14),
            ),
          ),
          Positioned(
            left: -40,
            top: 80,
            child: _SoftOrb(
              size: 120,
              color: Colors.white.withValues(alpha: 0.10),
            ),
          ),
          Positioned(
            right: 28,
            bottom: 54,
            child: _SoftOrb(
              size: 96,
              color: Colors.black.withValues(alpha: 0.08),
            ),
          ),
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

class _SoftOrb extends StatelessWidget {
  const _SoftOrb({required this.size, required this.color});

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
              color,
              color.withValues(alpha: 0.04),
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoCreditLabel extends StatelessWidget {
  const _PhotoCreditLabel({required this.asset});

  final LocationPhotoAsset asset;

  @override
  Widget build(BuildContext context) {
    return RotatedBox(
      quarterTurns: 3,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: Text(
          asset.creditLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.92),
            fontSize: 8,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.35,
            shadows: const <Shadow>[
              Shadow(
                color: Color(0x99000000),
                blurRadius: 6,
                offset: Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
