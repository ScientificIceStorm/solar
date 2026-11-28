import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:solar_v6/src/app/app_session_controller.dart';
import 'package:solar_v6/src/config/solar_config.dart';
import 'package:solar_v6/src/solar_api.dart';
import 'package:solar_v6/src/ui/services/in_memory_account_repository.dart';
import 'package:solar_v6/src/ui/services/solar_disk_cache_store.dart';
import 'package:solar_v6/src/ui/services/team_directory_service.dart';

const _seasons = {'meta': {'current_page': 1, 'last_page': 1}, 'data': [
  {'id': 197, 'name': 'VEX V5 Robotics Competition 2025-2026: Push Back', 'program': {'id': 1, 'name': 'VEX V5 Robotics Competition'}}
]};
final _skills = [{'rank': 1, 'team': {'id': 17, 'team': '24B', 'program': 'V5RC', 'teamName': 'Test team', 'grade': 'High School'}, 'scores': {'score': 100, 'programming': 50, 'driver': 50}}];
const _config = SolarConfig(robotEventsApiKey: 'test-only', robotEventsBaseUrl: 'https://events.vex.com/api/v2', worldSkillsBaseUrl: 'https://events.vex.com/api', roboServerBaseUrl: 'http://localhost:8080', supabaseUrl: '', supabaseAnonKey: '', supabaseRedirectUrl: '');

AppSessionController _controller(MockClient client, SolarDiskCacheStore cache) => AppSessionController(
  api: SolarApi(config: _config, httpClient: client),
  cacheStore: cache,
  repository: InMemoryAccountRepository(),
  teamDirectory: FakeTeamDirectoryService(teamsByNumber: {}),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('failed season requests are retryable in the same session', () async {
    var failing = true;
    var requests = 0;
    final controller = _controller(MockClient((_) async {
      requests++;
      return http.Response(jsonEncode(failing ? {} : _seasons), failing ? 401 : 200);
    }), SolarDiskCacheStore.inMemory());
    expect(await controller.fetchWorldSkillsSeasons(), isEmpty);
    expect(controller.seasonLoadError, contains('authorize'));
    failing = false;
    expect((await controller.fetchWorldSkillsSeasons()).single.id, 197);
    expect(controller.seasonLoadError, isNull);
    expect(requests, 2);
    controller.dispose();
  });

  test('25 reopen cycles preserve seasons offline without any network calls', () async {
    final cache = SolarDiskCacheStore.inMemory();
    var requests = 0;
    var controller = _controller(MockClient((_) async {requests++; return http.Response(jsonEncode(_seasons), 200);}), cache);
    expect(await controller.fetchWorldSkillsSeasons(), hasLength(1));
    controller.dispose();
    for (var i = 0; i < 25; i++) {
      controller = _controller(MockClient((_) async { requests++; throw http.ClientException('offline'); }), cache);
      expect((await controller.fetchWorldSkillsSeasons()).single.id, 197, reason: 'restart $i');
      controller.dispose();
    }
    expect(requests, 1);
  });

  test('failed forced refresh retains the last successful seasons and recovers', () async {
    var failing = false;
    final controller = _controller(MockClient((_) async => http.Response(jsonEncode(failing ? {} : _seasons), failing ? 403 : 200)), SolarDiskCacheStore.inMemory());
    expect(await controller.fetchWorldSkillsSeasons(), hasLength(1));
    failing = true;
    expect(await controller.fetchWorldSkillsSeasons(force: true), hasLength(1));
    expect(controller.seasonLoadError, isNotNull);
    failing = false;
    expect(await controller.fetchWorldSkillsSeasons(force: true), hasLength(1));
    expect(controller.seasonLoadError, isNull);
    controller.dispose();
  });

  test('search preload never crawls team match histories', () async {
    final paths = <String>[];
    final controller = _controller(MockClient((request) async {
      paths.add(request.url.path);
      return http.Response(jsonEncode(request.url.path.endsWith('/seasons') ? _seasons : _skills), 200);
    }), SolarDiskCacheStore.inMemory());
    await controller.initialize();
    await controller.createLocalAccount(teamNumber: '');
    await controller.preloadSearchTeams();
    expect(controller.preloadedSearchTeams, isNotEmpty);
    expect(paths.any((p) => p.contains('/teams/') || p.endsWith('/rankings') || p.endsWith('/matches')), isFalse);
    expect(paths.length, lessThanOrEqualTo(3));
    controller.dispose();
  });

  test('disposing during a pending load does not notify dead listeners', () async {
    final controller = _controller(MockClient((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
      return http.Response(jsonEncode(_seasons), 200);
    }), SolarDiskCacheStore.inMemory());
    final pending = controller.fetchWorldSkillsSeasons();
    controller.dispose();
    await pending;
    controller.notifyListeners();
  });
}
