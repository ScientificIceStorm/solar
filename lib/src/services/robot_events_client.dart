import '../core/api_exception.dart';
import '../core/json_api_client.dart';
import '../core/json_utils.dart';
import '../models/robot_events_models.dart';

class RobotEventsClient {
  RobotEventsClient({
    required JsonApiClient jsonClient,
    required this.apiKey,
    required this.baseUrl,
  }) : _jsonClient = jsonClient;

  final JsonApiClient _jsonClient;
  final String apiKey;
  final String baseUrl;

  Future<List<SeasonSummary>> fetchSeasons({int? programId}) async {
    final data = await _pagedGet(
      '/seasons',
      query: <String, Object?>{
        ...?programId == null ? null : <String, Object?>{'program': programId},
      },
    );
    return data.map(SeasonSummary.fromJson).toList(growable: false);
  }

  Future<List<TeamSummary>> searchTeams({
    int? id,
    String? number,
    List<int> programIds = const <int>[1, 4],
  }) async {
    final data = await _pagedGet(
      '/teams',
      query: <String, Object?>{
        ...?id == null ? null : <String, Object?>{'id': id},
        ...?number == null || number.trim().isEmpty
            ? null
            : <String, Object?>{'number': number.trim()},
        ...?programIds.isEmpty
            ? null
            : <String, Object?>{'program': programIds},
      },
    );
    return data.map(TeamSummary.fromJson).toList(growable: false);
  }

  Future<List<EventSummary>> fetchEvents({
    int? id,
    String? sku,
    int? season,
    int? teamId,
  }) async {
    final data = await _pagedGet(
      '/events',
      query: <String, Object?>{
        ...?id == null ? null : <String, Object?>{'id': id},
        ...?sku == null || sku.trim().isEmpty
            ? null
            : <String, Object?>{'sku': sku.trim()},
        ...?season == null ? null : <String, Object?>{'season': season},
        ...?teamId == null ? null : <String, Object?>{'team': teamId},
      },
    );
    return data.map(EventSummary.fromJson).toList(growable: false);
  }

  Future<List<TeamSummary>> fetchEventTeams(int eventId) async {
    final data = await _pagedGet('/events/$eventId/teams');
    return data.map(TeamSummary.fromJson).toList(growable: false);
  }

  Future<List<RankingRecord>> fetchDivisionRankings({
    required int eventId,
    required int divisionId,
  }) async {
    final data = await _pagedGet(
      '/events/$eventId/divisions/$divisionId/rankings',
    );
    return data.map(RankingRecord.fromJson).toList(growable: false);
  }

  Future<List<MatchSummary>> fetchDivisionMatches({
    required int eventId,
    required int divisionId,
  }) async {
    final data = await _pagedGet(
      '/events/$eventId/divisions/$divisionId/matches',
    );
    return data.map(MatchSummary.fromJson).toList(growable: false);
  }

  Future<List<SkillAttempt>> fetchEventSkills(
    int eventId, {
    int? teamId,
  }) async {
    final data = await _pagedGet(
      '/events/$eventId/skills',
      query: <String, Object?>{
        ...?teamId == null ? null : <String, Object?>{'team': teamId},
      },
    );
    return data.map(SkillAttempt.fromJson).toList(growable: false);
  }

  Future<List<AwardSummary>> fetchEventAwards(int eventId) async {
    final data = await _pagedGet('/events/$eventId/awards');
    return data.map(AwardSummary.fromJson).toList(growable: false);
  }

  Future<List<MatchSummary>> fetchTeamMatches(
    int teamId, {
    int? season,
    int? eventId,
  }) async {
    final data = await _pagedGet(
      '/teams/$teamId/matches',
      query: <String, Object?>{
        ...?season == null ? null : <String, Object?>{'season': season},
        ...?eventId == null ? null : <String, Object?>{'event': eventId},
      },
    );
    return data.map(MatchSummary.fromJson).toList(growable: false);
  }

  Future<List<RankingRecord>> fetchTeamRankings(
    int teamId, {
    int? season,
  }) async {
    final data = await _pagedGet(
      '/teams/$teamId/rankings',
      query: <String, Object?>{
        ...?season == null ? null : <String, Object?>{'season': season},
      },
    );
    return data.map(RankingRecord.fromJson).toList(growable: false);
  }

  Future<List<JsonMap>> _pagedGet(
    String path, {
    Map<String, Object?> query = const <String, Object?>{},
  }) async {
    _ensureApiKey();

    final results = <JsonMap>[];
    var currentPage = 1;

    while (true) {
      final payload = await _jsonClient.getJson(
        baseUrl: baseUrl,
        path: path,
        query: <String, Object?>{
          ...query,
          'page': currentPage,
          'per_page': query['per_page'] ?? 250,
        },
        headers: _headers,
      );

      final json = asJsonMap(payload);
      final pageData = asJsonMapList(json['data']);
      final meta = asJsonMap(json['meta']);
      final serverPage = readInt(meta['current_page'], currentPage);
      final lastPage = readInt(meta['last_page'], currentPage);

      results.addAll(pageData);

      if (serverPage >= lastPage) {
        break;
      }
      currentPage = serverPage + 1;
    }

    return results;
  }

  Map<String, String> get _headers {
    return <String, String>{
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };
  }

  void _ensureApiKey() {
    if (apiKey.trim().isEmpty) {
      throw SolarApiException(
        'RobotEvents API key is missing. Set ROBOEVENTS_API_KEY or add robotEventsApiKey to assets/config/solar.local.json.',
      );
    }
  }
}
