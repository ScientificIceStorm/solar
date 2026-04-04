import '../core/json_api_client.dart';
import '../core/json_utils.dart';
import '../models/open_skill_models.dart';
import '../models/robo_server_models.dart';

class RoboServerClient {
  RoboServerClient({required JsonApiClient jsonClient, required this.baseUrl})
    : _jsonClient = jsonClient;

  final JsonApiClient _jsonClient;
  final String baseUrl;

  Future<RoboServerHealth> health() async {
    final payload = await _jsonClient.getJson(
      baseUrl: baseUrl,
      path: '/api/health',
    );
    return RoboServerHealth.fromJson(asJsonMap(payload));
  }

  Future<SiteDataSnapshot> fetchSiteData({
    required int season,
    required String gradeLevel,
  }) async {
    final payload = await _jsonClient.getJson(
      baseUrl: baseUrl,
      path: '/api/site-data',
      query: <String, Object?>{'season': season, 'grade_level': gradeLevel},
    );
    return SiteDataSnapshot.fromJson(asJsonMap(payload));
  }

  Future<LoaderStartResult> startTeamLoader({
    required int season,
    required String gradeLevel,
    bool forceRefresh = false,
  }) async {
    final payload = await _jsonClient.postJson(
      baseUrl: baseUrl,
      path: '/api/team-loader/start',
      body: <String, Object?>{
        'season': season,
        'grade_level': gradeLevel,
        'force_refresh': forceRefresh,
      },
    );
    return LoaderStartResult.fromJson(asJsonMap(payload));
  }

  Future<LoaderStatus> fetchTeamLoaderStatus({
    required int season,
    required String gradeLevel,
  }) async {
    final payload = await _jsonClient.getJson(
      baseUrl: baseUrl,
      path: '/api/team-loader/status',
      query: <String, Object?>{'season': season, 'grade_level': gradeLevel},
    );
    return LoaderStatus.fromJson(asJsonMap(payload));
  }

  Future<LoaderStartResult> startRankingsLoader({
    required int season,
    required String gradeLevel,
    bool forceRefresh = false,
  }) async {
    final payload = await _jsonClient.postJson(
      baseUrl: baseUrl,
      path: '/api/rankings-loader/start',
      body: <String, Object?>{
        'season': season,
        'grade_level': gradeLevel,
        'force_refresh': forceRefresh,
      },
    );
    return LoaderStartResult.fromJson(asJsonMap(payload));
  }

  Future<LoaderStatus> fetchRankingsLoaderStatus({
    required int season,
    required String gradeLevel,
  }) async {
    final payload = await _jsonClient.getJson(
      baseUrl: baseUrl,
      path: '/api/rankings-loader/status',
      query: <String, Object?>{'season': season, 'grade_level': gradeLevel},
    );
    return LoaderStatus.fromJson(asJsonMap(payload));
  }

  Future<List<OpenSkillCacheEntry>> fetchOpenSkillCache({
    required int season,
    required String gradeLevel,
    bool forceRefresh = false,
  }) async {
    final payload = await _jsonClient.getJson(
      baseUrl: baseUrl,
      path: '/api/openskill-cache',
      query: <String, Object?>{
        'season': season,
        'grade_level': gradeLevel,
        'force_refresh': forceRefresh,
      },
    );

    final json = asJsonMap(payload);
    return asJsonMapList(
      json['data'],
    ).map(OpenSkillCacheEntry.fromJson).toList(growable: false);
  }

  Future<OpenSkillPredictionResponse> predictOpenSkill(
    OpenSkillPredictionRequest request,
  ) async {
    final payload = await _jsonClient.postJson(
      baseUrl: baseUrl,
      path: '/api/openskill-predict',
      body: request.toJson(),
    );
    return OpenSkillPredictionResponse.fromJson(asJsonMap(payload));
  }

  Future<JsonMap> predictModel(JsonMap requestBody) async {
    final payload = await _jsonClient.postJson(
      baseUrl: baseUrl,
      path: '/api/predict',
      body: requestBody,
    );
    return asJsonMap(payload);
  }
}
