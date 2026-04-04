import '../core/api_exception.dart';
import '../core/json_api_client.dart';
import '../core/json_utils.dart';
import '../models/world_skills_models.dart';

class WorldSkillsClient {
  WorldSkillsClient({required JsonApiClient jsonClient, required this.baseUrl})
    : _jsonClient = jsonClient;

  final JsonApiClient _jsonClient;
  final String baseUrl;

  Future<List<WorldSkillsEntry>> fetchRankings({
    required int seasonId,
    required String gradeLevel,
  }) async {
    final payload = await _jsonClient.getJson(
      baseUrl: baseUrl,
      path: '/seasons/$seasonId/skills',
      query: <String, Object?>{'grade_level': gradeLevel},
    );

    if (payload is! List) {
      throw SolarApiException('World skills response was not a JSON array');
    }

    return payload
        .whereType<Map>()
        .map((entry) => WorldSkillsEntry.fromJson(asJsonMap(entry)))
        .toList(growable: false);
  }
}
