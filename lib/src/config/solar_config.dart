import 'dart:convert';
import 'dart:io';

import '../core/json_utils.dart';

const _robotEventsApiKeyDefine = String.fromEnvironment('ROBOEVENTS_API_KEY');
const _robotEventsBaseUrlDefine = String.fromEnvironment('ROBOEVENTS_BASE_URL');
const _roboServerBaseUrlDefine = String.fromEnvironment('ROBO_SERVER_BASE_URL');
const _worldSkillsBaseUrlDefine = String.fromEnvironment(
  'WORLD_SKILLS_BASE_URL',
);

class SolarConfig {
  const SolarConfig({
    required this.robotEventsApiKey,
    required this.robotEventsBaseUrl,
    required this.roboServerBaseUrl,
    required this.worldSkillsBaseUrl,
  });

  static const defaults = SolarConfig(
    robotEventsApiKey: '',
    robotEventsBaseUrl: 'https://www.robotevents.com/api/v2',
    roboServerBaseUrl: 'http://127.0.0.1:8080',
    worldSkillsBaseUrl: 'https://www.robotevents.com/api',
  );

  final String robotEventsApiKey;
  final String robotEventsBaseUrl;
  final String roboServerBaseUrl;
  final String worldSkillsBaseUrl;

  bool get hasRobotEventsApiKey => robotEventsApiKey.trim().isNotEmpty;

  Map<String, dynamic> toSafeJson() {
    return <String, dynamic>{
      'robotEventsApiKeyConfigured': hasRobotEventsApiKey,
      'robotEventsBaseUrl': robotEventsBaseUrl,
      'roboServerBaseUrl': roboServerBaseUrl,
      'worldSkillsBaseUrl': worldSkillsBaseUrl,
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
