import 'package:http/http.dart' as http;

import 'config/solar_config.dart';
import 'core/json_api_client.dart';
import 'services/robo_server_client.dart';
import 'services/robot_events_client.dart';
import 'services/world_skills_client.dart';

class SolarApi {
  SolarApi._({required this.config, required http.Client httpClient})
    : _httpClient = httpClient,
      _jsonClient = JsonApiClient(httpClient);

  factory SolarApi({required SolarConfig config, http.Client? httpClient}) {
    return SolarApi._(config: config, httpClient: httpClient ?? http.Client());
  }

  static Future<SolarApi> fromLocalConfig({
    String configFilePath = 'solar.local.json',
    http.Client? httpClient,
  }) async {
    final config = await SolarConfig.load(configFilePath: configFilePath);
    return SolarApi(config: config, httpClient: httpClient);
  }

  final SolarConfig config;
  final http.Client _httpClient;
  final JsonApiClient _jsonClient;

  late final RobotEventsClient robotEvents = RobotEventsClient(
    jsonClient: _jsonClient,
    apiKey: config.robotEventsApiKey,
    baseUrl: config.robotEventsBaseUrl,
  );

  late final WorldSkillsClient worldSkills = WorldSkillsClient(
    jsonClient: _jsonClient,
    baseUrl: config.worldSkillsBaseUrl,
  );

  late final RoboServerClient roboServer = RoboServerClient(
    jsonClient: _jsonClient,
    baseUrl: config.roboServerBaseUrl,
  );

  void close() {
    _httpClient.close();
  }
}
