import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:solar_v6/src/app/app_session_controller.dart';
import 'package:solar_v6/src/app/solar_background_refresh.dart';
import 'package:solar_v6/src/config/solar_config.dart';
import 'package:solar_v6/src/models/robot_events_models.dart';
import 'package:solar_v6/src/models/world_skills_models.dart';
import 'package:solar_v6/src/solar_api.dart';
import 'package:solar_v6/src/ui/models/team_stats_snapshot.dart';
import 'package:solar_v6/src/ui/services/in_memory_account_repository.dart';
import 'package:solar_v6/src/ui/services/solar_disk_cache_store.dart';
import 'package:solar_v6/src/ui/services/team_directory_service.dart';

final team = TeamSummary.fromJson({
  'id': 17,
  'number': '24B',
  'team_name': 'Test team',
  'grade': 'High School',
});
const config = SolarConfig(
  robotEventsApiKey: 'test-only',
  robotEventsBaseUrl: 'https://events.vex.com/api/v2',
  worldSkillsBaseUrl: 'https://events.vex.com/api',
  roboServerBaseUrl: 'http://localhost:8080',
  supabaseUrl: '',
  supabaseAnonKey: '',
  supabaseRedirectUrl: '',
);

class SlowDirectory extends FakeTeamDirectoryService {
  SlowDirectory() : super(teamsByNumber: {'24B': team});
  final gate = Completer<TeamSummary>();
  @override
  Future<TeamSummary> validateTeamNumber(
    String teamNumber, {
    int? preferredSeasonId,
    List<int> programIds = const [1],
  }) => gate.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('team refresh replaces a previously displayed Skills score', () async {
    var score = 58;
    final api = SolarApi(
      config: config,
      httpClient: MockClient((request) async {
        return http.Response(
          jsonEncode([
            {
              'rank': 340,
              'team': {'id': 17, 'team': '24B', 'program': 'V5RC'},
              'scores': {'score': score},
            },
          ]),
          200,
        );
      }),
    );
    final controller = AppSessionController(
      repository: InMemoryAccountRepository(),
      teamDirectory: FakeTeamDirectoryService(teamsByNumber: {'24B': team}),
      api: api,
      cacheStore: SolarDiskCacheStore.inMemory(),
    );
    await controller.initialize();
    await controller.updatePreferredSeason(seasonId: 204, refresh: false);
    await controller.createLocalAccount(teamNumber: '24B');
    await controller.refreshTeamStats();
    expect(controller.teamStats?.skillsScoreLabel, '58');

    score = 88;
    await controller.refreshTeamStats();
    expect(controller.teamStats?.skillsScoreLabel, '88');
    expect(controller.teamStats?.skillsRankLabel, '#340');
    controller.dispose();
    api.close();
  });

  test(
    'team and name saves finish locally while API validation is pending',
    () async {
      final directory = SlowDirectory();
      final repository = InMemoryAccountRepository();
      final controller = AppSessionController(
        repository: repository,
        teamDirectory: directory,
        cacheStore: SolarDiskCacheStore.inMemory(),
      );
      await controller.initialize();
      await controller.createLocalAccount(teamNumber: '');
      final timer = Stopwatch()..start();
      await controller
          .updateTeam(teamNumber: '24B')
          .timeout(const Duration(milliseconds: 250));
      await controller
          .updateProfile(fullName: 'New name')
          .timeout(const Duration(milliseconds: 250));
      expect(directory.gate.isCompleted, false);
      expect(controller.currentAccount!.team.number, '24B');
      expect(controller.currentAccount!.fullName, 'New name');
      expect(timer.elapsedMilliseconds, lessThan(250));
      directory.gate.complete(team);
      await Future<void>.delayed(Duration.zero);
      await controller.refreshTeamStats();
      expect(
        controller.currentAccount!.fullName,
        'New name',
        reason: 'Old refresh must not overwrite a newer profile edit',
      );
      expect(controller.currentAccount!.team.id, 17);
      controller.dispose();
    },
  );

  test(
    'snapshot cache round-trips the data needed for instant home screens',
    () {
      final snapshot = TeamStatsSnapshot(
        team: team,
        allEvents: [
          EventSummary.fromJson({
            'id': 20,
            'name': 'Test event',
            'season': {'id': 197},
            'start': '2026-09-20T12:00:00Z',
          }),
        ],
        rankings: [
          RankingRecord.fromJson({
            'id': 1,
            'rank': 2,
            'wins': 4,
            'team': {'id': 17, 'number': '24B'},
          }),
        ],
        worldSkillsEntry: WorldSkillsEntry.fromJson({
          'rank': 3,
          'teamId': 17,
          'teamNumber': '24B',
          'combinedScore': 100,
        }),
        lastUpdated: DateTime(2026, 9, 18),
      );
      final restored = TeamStatsSnapshot.fromJson(
        jsonDecode(jsonEncode(snapshot.toJson())) as Map<String, dynamic>,
      );
      expect(restored.team.number, '24B');
      expect(restored.allEvents.single.name, 'Test event');
      expect(restored.rankings.single.wins, 4);
      expect(restored.worldSkillsEntry!.combinedScore, 100);
      expect(restored.lastUpdated, snapshot.lastUpdated);
    },
  );

  test(
    'background refresh warms the exact foreground caches with bounded requests',
    () async {
      final cache = SolarDiskCacheStore.inMemory();
      await cache.writeList<Map<String, dynamic>>(
        namespace: 'background_context',
        key: 'current',
        items: [
          {
            'team': TeamSummary.fromJson({'id': 0, 'number': ''}).toJson(),
            'programFilter': 'V5RC',
            'gradeLevel': 'High School',
            'preferredSeasonId': 197,
            'snapshotKey': 'v5rc|guest|197',
          },
        ],
        toJson: (value) => value,
      );
      final paths = <String>[];
      final api = SolarApi(
        config: config,
        httpClient: MockClient((request) async {
          paths.add(request.url.path);
          return http.Response(
            jsonEncode(
              request.url.path.endsWith('/seasons')
                  ? {
                      'meta': {'last_page': 1},
                      'data': [
                        {
                          'id': 197,
                          'name':
                              'VEX V5 Robotics Competition 2025-2026: Push Back',
                          'program': {
                            'id': 1,
                            'name': 'VEX V5 Robotics Competition',
                          },
                        },
                      ],
                    }
                  : [
                      {
                        'rank': 1,
                        'team': {'id': 17, 'team': '24B', 'program': 'V5RC'},
                        'scores': {'score': 100},
                      },
                    ],
            ),
            200,
          );
        }),
      );
      await refreshSolarCache(api, cache);
      expect(paths, ['/api/v2/seasons', '/api/seasons/197/skills']);
      expect(
        await cache.readList<SeasonSummary>(
          namespace: 'seasons_vex_v1',
          key: 'v5rc',
          fromJson: SeasonSummary.fromJson,
        ),
        hasLength(1),
      );
      expect(
        await cache.readList<WorldSkillsEntry>(
          namespace: 'world_skills_rankings',
          key: '197|high school',
          fromJson: WorldSkillsEntry.fromJson,
        ),
        hasLength(1),
      );
      expect(
        await cache.readList<Map<String, dynamic>>(
          namespace: 'background_status',
          key: 'last_success',
          fromJson: (v) => v,
        ),
        hasLength(1),
      );
      api.close();
    },
  );
}
