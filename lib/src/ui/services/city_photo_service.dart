import 'package:flutter/material.dart';

import '../../models/robot_events_models.dart';

class CityPhotoVisual {
  const CityPhotoVisual({
    required this.skyColors,
    required this.hazeColor,
    required this.sunColor,
    required this.waterColor,
    required this.groundColor,
    required this.buildingColors,
    required this.landmark,
  });

  final List<Color> skyColors;
  final Color hazeColor;
  final Color sunColor;
  final Color waterColor;
  final Color groundColor;
  final List<Color> buildingColors;
  final CityLandmark landmark;
}

enum CityLandmark { generic, arch }

class CityPhotoService {
  CityPhotoService._();

  static const Map<String, CityPhotoVisual> _cityVisuals =
      <String, CityPhotoVisual>{
        'st louis|missouri|united states': CityPhotoVisual(
          skyColors: <Color>[
            Color(0xFF5E8DB7),
            Color(0xFF87BBE8),
            Color(0xFFF5E7D8),
          ],
          hazeColor: Color(0x44FFF6EB),
          sunColor: Color(0xFFFFD59B),
          waterColor: Color(0xFF76A7C8),
          groundColor: Color(0xFF8C4F3A),
          buildingColors: <Color>[
            Color(0xFFBE8B69),
            Color(0xFFE6DDD0),
            Color(0xFF8EA8C3),
            Color(0xFFC7B39B),
          ],
          landmark: CityLandmark.arch,
        ),
      };

  static const List<CityPhotoVisual> _fallbackVisuals = <CityPhotoVisual>[
    CityPhotoVisual(
      skyColors: <Color>[
        Color(0xFF6289B9),
        Color(0xFF8DBEEB),
        Color(0xFFF4E9DB),
      ],
      hazeColor: Color(0x40FFF7EE),
      sunColor: Color(0xFFFFD9A6),
      waterColor: Color(0xFF7EAFD0),
      groundColor: Color(0xFF946455),
      buildingColors: <Color>[
        Color(0xFFD7B092),
        Color(0xFFE8E3DD),
        Color(0xFF9FB6CF),
        Color(0xFFC8C0B8),
      ],
      landmark: CityLandmark.generic,
    ),
    CityPhotoVisual(
      skyColors: <Color>[
        Color(0xFF536D93),
        Color(0xFF7FB0D9),
        Color(0xFFECE3F8),
      ],
      hazeColor: Color(0x36EDF3FF),
      sunColor: Color(0xFFFFC98F),
      waterColor: Color(0xFF6D96BD),
      groundColor: Color(0xFF7A556A),
      buildingColors: <Color>[
        Color(0xFFC4907B),
        Color(0xFFE7DFE6),
        Color(0xFF88A3C1),
        Color(0xFFB9A5A8),
      ],
      landmark: CityLandmark.generic,
    ),
    CityPhotoVisual(
      skyColors: <Color>[
        Color(0xFF4F6B88),
        Color(0xFF6FB3D8),
        Color(0xFFF6F0E6),
      ],
      hazeColor: Color(0x38F2F6FD),
      sunColor: Color(0xFFFFCF95),
      waterColor: Color(0xFF71A5C7),
      groundColor: Color(0xFF70524A),
      buildingColors: <Color>[
        Color(0xFFC09877),
        Color(0xFFE8E0D6),
        Color(0xFF90A7C2),
        Color(0xFFB0A398),
      ],
      landmark: CityLandmark.generic,
    ),
  ];

  static CityPhotoVisual visualFor(LocationSummary location) {
    final exactMatch = _cityVisuals[_cacheKey(location)];
    if (exactMatch != null) {
      return exactMatch;
    }

    final city = _normalized(location.city);
    final cityOnlyKey = _cityVisuals.keys.cast<String?>().firstWhere(
      (key) => key != null && key.startsWith('$city|'),
      orElse: () => null,
    );
    if (cityOnlyKey != null) {
      return _cityVisuals[cityOnlyKey]!;
    }

    final hashSeed = _normalized(
      <String>[location.city, location.region, location.country].join('|'),
    );
    final index = hashSeed.isEmpty
        ? 0
        : hashSeed.codeUnits.fold<int>(0, (sum, value) => sum + value) %
              _fallbackVisuals.length;
    return _fallbackVisuals[index];
  }

  static String labelFor(LocationSummary location) {
    final pieces = <String>[
      if (location.city.trim().isNotEmpty) location.city.trim(),
      if (location.region.trim().isNotEmpty) location.region.trim(),
    ];
    return pieces.isEmpty ? 'Event City' : pieces.join(', ');
  }

  static String _cacheKey(LocationSummary location) {
    return <String>[
      location.city,
      location.region,
      location.country,
    ].map(_normalized).join('|');
  }

  static String _normalized(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}
