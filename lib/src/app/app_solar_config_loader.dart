import 'dart:convert';

import 'package:flutter/services.dart';

import '../config/solar_config.dart';
import '../core/json_utils.dart';

class AppSolarConfigLoader {
  static const assetConfigPath = 'assets/config/solar.local.json';

  static Future<SolarConfig> load() async {
    final baseConfig = await SolarConfig.load();
    final assetValues = await _loadAssetValues();

    return SolarConfig(
      robotEventsApiKey: _resolvedOrAsset(
        resolvedValue: baseConfig.robotEventsApiKey,
        defaultValue: SolarConfig.defaults.robotEventsApiKey,
        assetValue: readString(assetValues['robotEventsApiKey']),
      ),
      robotEventsBaseUrl: _resolvedOrAsset(
        resolvedValue: baseConfig.robotEventsBaseUrl,
        defaultValue: SolarConfig.defaults.robotEventsBaseUrl,
        assetValue: readString(assetValues['robotEventsBaseUrl']),
      ),
      roboServerBaseUrl: _resolvedOrAsset(
        resolvedValue: baseConfig.roboServerBaseUrl,
        defaultValue: SolarConfig.defaults.roboServerBaseUrl,
        assetValue: readString(assetValues['roboServerBaseUrl']),
      ),
      worldSkillsBaseUrl: _resolvedOrAsset(
        resolvedValue: baseConfig.worldSkillsBaseUrl,
        defaultValue: SolarConfig.defaults.worldSkillsBaseUrl,
        assetValue: readString(assetValues['worldSkillsBaseUrl']),
      ),
      supabaseUrl: _resolvedOrAsset(
        resolvedValue: baseConfig.supabaseUrl,
        defaultValue: SolarConfig.defaults.supabaseUrl,
        assetValue: firstNonEmpty(<String?>[
          readString(assetValues['supabaseUrl']),
          readString(assetValues['supabaseURL']),
        ]),
      ),
      supabaseAnonKey: _resolvedOrAsset(
        resolvedValue: baseConfig.supabaseAnonKey,
        defaultValue: SolarConfig.defaults.supabaseAnonKey,
        assetValue: firstNonEmpty(<String?>[
          readString(assetValues['supabasePublishableKey']),
          readString(assetValues['supabaseAnonKey']),
          readString(assetValues['supabaseKey']),
        ]),
      ),
      supabaseRedirectUrl: _resolvedOrAsset(
        resolvedValue: baseConfig.supabaseRedirectUrl,
        defaultValue: SolarConfig.defaults.supabaseRedirectUrl,
        assetValue: readString(assetValues['supabaseRedirectUrl']),
      ),
    );
  }

  static Future<JsonMap> _loadAssetValues() async {
    try {
      final rawJson = await rootBundle.loadString(assetConfigPath);
      return asJsonMap(jsonDecode(rawJson));
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  static String _resolvedOrAsset({
    required String resolvedValue,
    required String defaultValue,
    required String assetValue,
  }) {
    final trimmedResolved = resolvedValue.trim();
    final trimmedAsset = assetValue.trim();
    final hasCustomResolved =
        trimmedResolved.isNotEmpty && trimmedResolved != defaultValue;

    if (hasCustomResolved) {
      return trimmedResolved;
    }

    if (trimmedAsset.isNotEmpty) {
      return trimmedAsset;
    }

    if (trimmedResolved.isNotEmpty) {
      return trimmedResolved;
    }

    return defaultValue;
  }
}
