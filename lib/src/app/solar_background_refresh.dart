import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';
import '../core/solar_competition_scope.dart';
import '../models/robot_events_models.dart';
import '../models/world_skills_models.dart';
import '../solar_api.dart';
import '../ui/models/team_stats_snapshot.dart';
import '../ui/services/solar_disk_cache_store.dart';
import '../ui/services/team_directory_service.dart';
import 'app_solar_config_loader.dart';

const solarRefreshTask = 'dev.minzhang.solar.refresh';

@pragma('vm:entry-point')
void solarBackgroundDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    final config = await AppSolarConfigLoader.load();
    if (!config.hasRobotEventsApiKey) return true;
    final api = SolarApi(config: config);
    try {
      await refreshSolarCache(
        api,
        SolarDiskCacheStore.instance,
      ).timeout(const Duration(seconds: 25));
      return true;
    } catch (error) {
      debugPrint('Solar background sync deferred (${error.runtimeType})');
      return false;
    } finally {
      api.close();
    }
  });
}

Future<void> scheduleSolarBackgroundRefresh() async {
  if (!Platform.isAndroid && !Platform.isIOS) return;
  try {
    await Workmanager().initialize(solarBackgroundDispatcher);
    await Workmanager().registerPeriodicTask(
      solarRefreshTask,
      solarRefreshTask,
      frequency: const Duration(minutes: 30),
      initialDelay: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(
        networkType: NetworkType.unmetered,
        requiresBatteryNotLow: true,
      ),
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 15),
    );
    if (kDebugMode &&
        const bool.fromEnvironment('SOLAR_BACKGROUND_SMOKE_TEST')) {
      await Workmanager().registerOneOffTask(
        '$solarRefreshTask.smoke',
        solarRefreshTask,
        existingWorkPolicy: ExistingWorkPolicy.replace,
        constraints: Constraints(networkType: NetworkType.connected),
      );
    }
  } catch (error) {
    // Scheduling must never block or prevent the foreground app from opening.
    debugPrint(
      'Solar background scheduling unavailable (${error.runtimeType})',
    );
  }
}

/// A small refresh: seasons, one skills leaderboard, and the selected team.
/// Does not open the account database or crawl other teams' match histories.
Future<void> refreshSolarCache(SolarApi api, SolarDiskCacheStore cache) async {
  final saved = await cache.readList<Map<String, dynamic>>(
    namespace: 'background_context',
    key: 'current',
    fromJson: (value) => value,
  );
  if (saved == null || saved.isEmpty) return;
  final context = saved.first;
  final filter =
      context['programFilter'] as String? ?? solarPrimaryProgramFilter;
  final seasons = await api.robotEvents.fetchSeasons(
    programId: filter == solarPrimaryProgramFilter
        ? solarPrimaryProgramId
        : null,
  );
  final matching =
      seasons
          .where(
            (season) => filter == solarPrimaryProgramFilter
                ? isSolarPrimaryProgramText(
                    '${season.name} ${season.programName}',
                  )
                : '${season.name} ${season.programName}'.toLowerCase().contains(
                    filter.toLowerCase(),
                  ),
          )
          .toList()
        ..sort(
          (a, b) => compareSolarSeasonPriority(
            leftName: a.name,
            leftId: a.id,
            rightName: b.name,
            rightId: b.id,
          ),
        );
  if (matching.isEmpty) return;
  await cache.writeList<SeasonSummary>(
    namespace: 'seasons_vex_v1',
    key: filter.toLowerCase(),
    items: matching,
    toJson: (value) => value.toJson(),
    ttl: const Duration(hours: 6),
  );
  final seasonId = context['preferredSeasonId'] as int? ?? matching.first.id;
  final grade = context['gradeLevel'] as String? ?? 'High School';
  final skills = await api.worldSkills.fetchRankings(
    seasonId: seasonId,
    gradeLevel: grade,
  );
  if (skills.isNotEmpty) {
    await cache.writeList<WorldSkillsEntry>(
      namespace: 'world_skills_rankings',
      key: '$seasonId|${grade.toLowerCase()}',
      items: skills,
      toJson: (value) => value.toJson(),
      ttl: const Duration(minutes: 30),
    );
  }
  final team = TeamSummary.fromJson(
    Map<String, dynamic>.from(context['team'] as Map),
  );
  if (team.id > 0) {
    final snapshotKey = context['snapshotKey'] as String;
    final entry = skills.where((entry) => entry.teamId == team.id).firstOrNull;
    if (entry != null) {
      final cached = await cache.readList<TeamStatsSnapshot>(
        namespace: 'team_snapshot_v1',
        key: snapshotKey,
        fromJson: TeamStatsSnapshot.fromJson,
        allowExpired: true,
      );
      final updated = (cached?.firstOrNull ?? TeamStatsSnapshot(team: team))
          .withWorldSkillsEntry(entry);
      await cache.writeList<TeamStatsSnapshot>(
        namespace: 'team_snapshot_v1',
        key: snapshotKey,
        items: [updated],
        toJson: (value) => value.toJson(),
        ttl: const Duration(minutes: 15),
      );
    }
    final snapshot = await SolarTeamDirectoryService(api: api).loadTeamStats(
      team,
      preferredSeasonId: seasonId,
      seedWorldSkillsEntry: entry,
    );
    if (snapshot.errorMessage == null) {
      await cache.writeList<TeamStatsSnapshot>(
        namespace: 'team_snapshot_v1',
        key: snapshotKey,
        items: [snapshot],
        toJson: (value) => value.toJson(),
        ttl: const Duration(minutes: 15),
      );
    }
  }
  await cache.writeList<Map<String, dynamic>>(
    namespace: 'background_status',
    key: 'last_success',
    items: [
      {'completedAt': DateTime.now().toIso8601String()},
    ],
    toJson: (value) => value,
  );
}
