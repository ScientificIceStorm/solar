import '../core/json_utils.dart';
import 'open_skill_models.dart';

class RoboServerHealth {
  const RoboServerHealth({required this.ok, required this.modelLoaded});

  final bool ok;
  final bool modelLoaded;

  factory RoboServerHealth.fromJson(JsonMap json) {
    return RoboServerHealth(
      ok: readBool(json['ok']),
      modelLoaded: readBool(json['modelLoaded']),
    );
  }

  JsonMap toJson() {
    return <String, dynamic>{'ok': ok, 'modelLoaded': modelLoaded};
  }
}

class TeamDirectoryEntry {
  const TeamDirectoryEntry({
    required this.id,
    required this.teamNumber,
    required this.region,
    required this.country,
  });

  final int id;
  final String teamNumber;
  final String region;
  final String country;

  factory TeamDirectoryEntry.fromJson(JsonMap json) {
    return TeamDirectoryEntry(
      id: readInt(json['id']),
      teamNumber: readString(json['team_number']),
      region: readString(json['loc_region']),
      country: readString(json['loc_country']),
    );
  }

  JsonMap toJson() {
    return <String, dynamic>{
      'id': id,
      'teamNumber': teamNumber,
      'region': region,
      'country': country,
    };
  }
}

class SiteDataSnapshot {
  const SiteDataSnapshot({
    required this.ok,
    required this.season,
    required this.gradeLevel,
    required this.teamCacheExists,
    required this.teamCacheUsable,
    required this.teamCachePartial,
    required this.teamPreviewCount,
    required this.rankingsCacheExists,
    required this.rankingsCacheUsable,
    required this.rankingsCachePartial,
    required this.teamCacheUpdatedAt,
    required this.rankingsUpdatedAt,
    required this.teams,
    required this.rankings,
    required this.teamSyncRunning,
    required this.teamSyncPercent,
    required this.rankingsSyncRunning,
    required this.rankingsSyncPercent,
  });

  final bool ok;
  final int season;
  final String gradeLevel;
  final bool teamCacheExists;
  final bool teamCacheUsable;
  final bool teamCachePartial;
  final int teamPreviewCount;
  final bool rankingsCacheExists;
  final bool rankingsCacheUsable;
  final bool rankingsCachePartial;
  final DateTime? teamCacheUpdatedAt;
  final DateTime? rankingsUpdatedAt;
  final List<TeamDirectoryEntry> teams;
  final List<OpenSkillCacheEntry> rankings;
  final bool teamSyncRunning;
  final int teamSyncPercent;
  final bool rankingsSyncRunning;
  final int rankingsSyncPercent;

  factory SiteDataSnapshot.fromJson(JsonMap json) {
    return SiteDataSnapshot(
      ok: readBool(json['ok']),
      season: readInt(json['season']),
      gradeLevel: readString(json['grade_level']),
      teamCacheExists: readBool(json['team_cache_exists']),
      teamCacheUsable: readBool(json['team_cache_usable']),
      teamCachePartial: readBool(json['team_cache_partial']),
      teamPreviewCount: readInt(json['team_preview_count']),
      rankingsCacheExists: readBool(json['rankings_cache_exists']),
      rankingsCacheUsable: readBool(json['rankings_cache_usable']),
      rankingsCachePartial: readBool(json['rankings_cache_partial']),
      teamCacheUpdatedAt: readDateTime(json['team_cache_updated_at']),
      rankingsUpdatedAt: readDateTime(json['rankings_updated_at']),
      teams: asJsonMapList(
        json['teams'],
      ).map(TeamDirectoryEntry.fromJson).toList(growable: false),
      rankings: asJsonMapList(
        json['rankings'],
      ).map(OpenSkillCacheEntry.fromJson).toList(growable: false),
      teamSyncRunning: readBool(json['team_sync_running']),
      teamSyncPercent: readInt(json['team_sync_percent']),
      rankingsSyncRunning: readBool(json['rankings_sync_running']),
      rankingsSyncPercent: readInt(json['rankings_sync_percent']),
    );
  }

  JsonMap toJson() {
    return <String, dynamic>{
      'ok': ok,
      'season': season,
      'gradeLevel': gradeLevel,
      'teamCacheExists': teamCacheExists,
      'teamCacheUsable': teamCacheUsable,
      'teamCachePartial': teamCachePartial,
      'teamPreviewCount': teamPreviewCount,
      'rankingsCacheExists': rankingsCacheExists,
      'rankingsCacheUsable': rankingsCacheUsable,
      'rankingsCachePartial': rankingsCachePartial,
      'teamCacheUpdatedAt': teamCacheUpdatedAt?.toIso8601String(),
      'rankingsUpdatedAt': rankingsUpdatedAt?.toIso8601String(),
      'teams': teams.map((team) => team.toJson()).toList(),
      'rankings': rankings.map((entry) => entry.toJson()).toList(),
      'teamSyncRunning': teamSyncRunning,
      'teamSyncPercent': teamSyncPercent,
      'rankingsSyncRunning': rankingsSyncRunning,
      'rankingsSyncPercent': rankingsSyncPercent,
    };
  }
}

class LoaderStartResult {
  const LoaderStartResult({
    required this.ok,
    required this.started,
    required this.alreadyRunning,
  });

  final bool ok;
  final bool started;
  final bool alreadyRunning;

  factory LoaderStartResult.fromJson(JsonMap json) {
    return LoaderStartResult(
      ok: readBool(json['ok']),
      started: readBool(json['started']),
      alreadyRunning: readBool(json['already_running']),
    );
  }

  JsonMap toJson() {
    return <String, dynamic>{
      'ok': ok,
      'started': started,
      'alreadyRunning': alreadyRunning,
    };
  }
}

class LoaderStatus {
  const LoaderStatus({
    required this.ok,
    required this.season,
    required this.gradeLevel,
    required this.running,
    required this.usableCache,
    required this.hasCache,
    required this.percent,
    required this.currentEventSku,
    required this.currentDivisionName,
    required this.eventsTotal,
    required this.eventsCompleted,
    required this.divisionsTotal,
    required this.divisionsCompleted,
    required this.teamsLoaded,
    required this.teamsRated,
    required this.logs,
    required this.finalCacheExists,
    required this.finalCacheUsable,
  });

  final bool ok;
  final int season;
  final String gradeLevel;
  final bool running;
  final bool usableCache;
  final bool hasCache;
  final int percent;
  final String currentEventSku;
  final String currentDivisionName;
  final int eventsTotal;
  final int eventsCompleted;
  final int divisionsTotal;
  final int divisionsCompleted;
  final int teamsLoaded;
  final int teamsRated;
  final List<String> logs;
  final bool finalCacheExists;
  final bool finalCacheUsable;

  factory LoaderStatus.fromJson(JsonMap json) {
    return LoaderStatus(
      ok: readBool(json['ok']),
      season: readInt(json['season']),
      gradeLevel: readString(json['grade_level']),
      running: readBool(json['running']),
      usableCache: readBool(json['usable_cache']),
      hasCache: readBool(json['has_cache']),
      percent: readInt(json['percent']),
      currentEventSku: readString(json['current_event_sku']),
      currentDivisionName: readString(json['current_division_name']),
      eventsTotal: readInt(json['events_total']),
      eventsCompleted: readInt(json['events_completed']),
      divisionsTotal: readInt(json['divisions_total']),
      divisionsCompleted: readInt(json['divisions_completed']),
      teamsLoaded: readInt(json['teams_loaded']),
      teamsRated: readInt(json['teams_rated']),
      logs: readStringList(json['logs']),
      finalCacheExists: readBool(json['final_cache_exists']),
      finalCacheUsable: readBool(json['final_cache_usable']),
    );
  }

  JsonMap toJson() {
    return <String, dynamic>{
      'ok': ok,
      'season': season,
      'gradeLevel': gradeLevel,
      'running': running,
      'usableCache': usableCache,
      'hasCache': hasCache,
      'percent': percent,
      'currentEventSku': currentEventSku,
      'currentDivisionName': currentDivisionName,
      'eventsTotal': eventsTotal,
      'eventsCompleted': eventsCompleted,
      'divisionsTotal': divisionsTotal,
      'divisionsCompleted': divisionsCompleted,
      'teamsLoaded': teamsLoaded,
      'teamsRated': teamsRated,
      'logs': logs,
      'finalCacheExists': finalCacheExists,
      'finalCacheUsable': finalCacheUsable,
    };
  }
}
