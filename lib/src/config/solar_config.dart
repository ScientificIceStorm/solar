import 'dart:convert';
import 'dart:io';

import '../core/json_utils.dart';

const _robotEventsApiKeyDefine = String.fromEnvironment('ROBOEVENTS_API_KEY');
const _robotEventsBaseUrlDefine = String.fromEnvironment('ROBOEVENTS_BASE_URL');
const _roboServerBaseUrlDefine = String.fromEnvironment('ROBO_SERVER_BASE_URL');
const _worldSkillsBaseUrlDefine = String.fromEnvironment(
  'WORLD_SKILLS_BASE_URL',
);
const _supabaseUrlDefine = String.fromEnvironment('SUPABASE_URL');
const _supabaseAnonKeyDefine = String.fromEnvironment('SUPABASE_ANON_KEY');
const _supabaseRedirectUrlDefine = String.fromEnvironment(
  'SUPABASE_REDIRECT_URL',
);

class SolarConfig {
  const SolarConfig({
    required this.robotEventsApiKey,
    required this.robotEventsBaseUrl,
    required this.roboServerBaseUrl,
    required this.worldSkillsBaseUrl,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.supabaseRedirectUrl,
  });

  static const defaults = SolarConfig(
    robotEventsApiKey: '',
    robotEventsBaseUrl: 'https://www.robotevents.com/api/v2',
    roboServerBaseUrl: 'http://127.0.0.1:8080',
    worldSkillsBaseUrl: 'https://www.robotevents.com/api',
    supabaseUrl: '',
    supabaseAnonKey: '',
    supabaseRedirectUrl: 'dev.minzhang.solarV6://login-callback',
  );

  final String robotEventsApiKey;
  final String robotEventsBaseUrl;
  final String roboServerBaseUrl;
  final String worldSkillsBaseUrl;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String supabaseRedirectUrl;

  bool get hasRobotEventsApiKey => robotEventsApiKey.trim().isNotEmpty;
  bool get hasSupabaseConfig =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  Map<String, dynamic> toSafeJson() {
    return <String, dynamic>{
      'robotEventsApiKeyConfigured': hasRobotEventsApiKey,
      'robotEventsBaseUrl': robotEventsBaseUrl,
      'roboServerBaseUrl': roboServerBaseUrl,
      'worldSkillsBaseUrl': worldSkillsBaseUrl,
      'supabaseConfigured': hasSupabaseConfig,
      'supabaseUrl': supabaseUrl,
      'supabaseRedirectUrl': supabaseRedirectUrl,
    };
  }

  static Future<SolarConfig> load({
    String configFilePath = 'solar.local.json',
  }) async {
    final fileValues = await _loadFileValues(configFilePath);
    final environment = Platform.environment;

    return SolarConfig(
      robotEventsApiKey: firstNonEmpty(<String?>[
        _robotEventsApiKeyDefine,
        environment['ROBOEVENTS_API_KEY'],
        readString(fileValues['robotEventsApiKey']),
      ]),
      robotEventsBaseUrl: firstNonEmpty(<String?>[
        _robotEventsBaseUrlDefine,
        environment['ROBOEVENTS_BASE_URL'],
        readString(fileValues['robotEventsBaseUrl']),
      ], fallback: defaults.robotEventsBaseUrl),
      roboServerBaseUrl: firstNonEmpty(<String?>[
        _roboServerBaseUrlDefine,
        environment['ROBO_SERVER_BASE_URL'],
        readString(fileValues['roboServerBaseUrl']),
      ], fallback: defaults.roboServerBaseUrl),
      worldSkillsBaseUrl: firstNonEmpty(<String?>[
        _worldSkillsBaseUrlDefine,
        environment['WORLD_SKILLS_BASE_URL'],
        readString(fileValues['worldSkillsBaseUrl']),
      ], fallback: defaults.worldSkillsBaseUrl),
      supabaseUrl: firstNonEmpty(<String?>[
        _supabaseUrlDefine,
        environment['SUPABASE_URL'],
        readString(fileValues['supabaseUrl']),
        readString(fileValues['supabaseURL']),
      ]),
      supabaseAnonKey: firstNonEmpty(<String?>[
        _supabaseAnonKeyDefine,
        environment['SUPABASE_ANON_KEY'],
        readString(fileValues['supabaseAnonKey']),
      ]),
      supabaseRedirectUrl: firstNonEmpty(<String?>[
        _supabaseRedirectUrlDefine,
        environment['SUPABASE_REDIRECT_URL'],
        readString(fileValues['supabaseRedirectUrl']),
      ], fallback: defaults.supabaseRedirectUrl),
    );
  }

  static Future<JsonMap> _loadFileValues(String configFilePath) async {
    final file = File(configFilePath);
    if (!await file.exists()) {
      return <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(await file.readAsString());
      return asJsonMap(decoded);
    } on FormatException {
      return <String, dynamic>{};
    }
  }
}
