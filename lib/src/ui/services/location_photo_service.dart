import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/robot_events_models.dart';

class LocationPhotoService {
  LocationPhotoService._();

  static final Map<String, Future<LocationPhotoAsset?>> _photoCache =
      <String, Future<LocationPhotoAsset?>>{};

  static Future<String?> photoUrlFor(LocationSummary location) {
    return photoAssetFor(location).then((asset) => asset?.url);
  }

  static Future<LocationPhotoAsset?> photoAssetFor(LocationSummary location) {
    final cacheKey = _cacheKey(location);
    if (cacheKey.isEmpty) {
      return Future<LocationPhotoAsset?>.value(null);
    }

    return _photoCache.putIfAbsent(cacheKey, () => _loadPhotoAsset(location));
  }

  static Future<LocationPhotoAsset?> _loadPhotoAsset(
    LocationSummary location,
  ) async {
    final client = http.Client();
    try {
      for (final query in _queriesFor(location)) {
        final uri = Uri.https(
          'api.openverse.org',
          '/v1/images/',
          <String, String>{
            'q': query,
            'page_size': '8',
            'license_type': 'all',
            'mature': 'false',
          },
        );
        final response = await client.get(
          uri,
          headers: const <String, String>{'Accept': 'application/json'},
        );
        if (response.statusCode != 200) {
          continue;
        }

        final payload = jsonDecode(response.body);
        if (payload is! Map) {
          continue;
        }

        final results = payload['results'];
        if (results is! List) {
          continue;
        }

        for (final item in results) {
          if (item is! Map) {
            continue;
          }

          final thumbnail = (item['thumbnail'] as String?)?.trim();
          final url = (item['url'] as String?)?.trim();
          final imageUrl = thumbnail?.isNotEmpty == true
              ? thumbnail!
              : (url?.isNotEmpty == true ? url! : null);
          if (imageUrl == null) {
            continue;
          }

          final creator =
              (item['creator'] as String?)?.trim() ??
              (item['author'] as String?)?.trim() ??
              '';
          final sourceUrl =
              (item['foreign_landing_url'] as String?)?.trim() ??
              (item['creator_url'] as String?)?.trim() ??
              '';
          final provider =
              (item['source'] as String?)?.trim() ??
              (item['provider'] as String?)?.trim() ??
              'Openverse';

          return LocationPhotoAsset(
            url: imageUrl,
            creditLabel: creator.isEmpty ? provider : '$creator via $provider',
            creditUrl: sourceUrl,
          );
        }
      }
    } catch (_) {
      return null;
    } finally {
      client.close();
    }

    return null;
  }

  static List<String> _queriesFor(LocationSummary location) {
    final city = location.city.trim();
    final region = location.region.trim();
    final country = location.country.trim();
    final venue = location.venue.trim();

    final baseLabels = <String>[
      if (city.isNotEmpty && region.isNotEmpty) '$city $region',
      if (city.isNotEmpty && country.isNotEmpty) '$city $country',
      if (city.isNotEmpty) city,
      if (region.isNotEmpty && country.isNotEmpty) '$region $country',
      if (region.isNotEmpty) region,
      if (country.isNotEmpty) country,
    ];

    final queries = <String>[];
    void addQuery(String value) {
      final normalized = value.trim();
      if (normalized.isEmpty || queries.contains(normalized)) {
        return;
      }
      queries.add(normalized);
    }

    for (final label in baseLabels) {
      addQuery('$label skyline');
      addQuery('$label downtown');
      addQuery('$label cityscape');
    }

    if (venue.isNotEmpty && city.isNotEmpty) {
      addQuery('$venue $city robotics event');
      addQuery('$venue $city arena');
    }

    return queries;
  }

  static String _cacheKey(LocationSummary location) {
    return <String>[
      location.city,
      location.region,
      location.country,
      location.venue,
    ].map(_normalize).where((value) => value.isNotEmpty).join('|');
  }

  static String _normalize(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}

class LocationPhotoAsset {
  const LocationPhotoAsset({
    required this.url,
    required this.creditLabel,
    this.creditUrl,
  });

  final String url;
  final String creditLabel;
  final String? creditUrl;
}
