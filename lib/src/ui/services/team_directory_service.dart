import '../../core/api_exception.dart';
import '../../core/solar_competition_scope.dart';
import '../../models/open_skill_models.dart';
import '../../models/robot_events_models.dart';
import '../../models/world_skills_models.dart';
import '../../solar_api.dart';
import '../models/team_stats_snapshot.dart';

abstract class TeamDirectoryService {
  Future<TeamSummary> validateTeamNumber(
    String teamNumber, {
    int? preferredSeasonId,
  });

  Future<TeamStatsSnapshot> loadTeamStats(
    TeamSummary team, {
    int? preferredSeasonId,
    WorldSkillsEntry? seedWorldSkillsEntry,
    OpenSkillCacheEntry? seedOpenSkillEntry,
  });
}

class SolarTeamDirectoryService implements TeamDirectoryService {
  SolarTeamDirectoryService({required SolarApi api}) : _api = api;

  final SolarApi _api;
  static const _eventsTimeout = Duration(seconds: 8);
  static const _statsTimeout = Duration(seconds: 6);
  static const _openSkillTimeout = Duration(seconds: 3);

  @override
  Future<TeamStatsSnapshot> loadTeamStats(
    TeamSummary team, {
    int? preferredSeasonId,
    WorldSkillsEntry? seedWorldSkillsEntry,
    OpenSkillCacheEntry? seedOpenSkillEntry,
  }) async {
    if (!_api.config.hasRobotEventsApiKey) {
      return TeamStatsSnapshot(
        team: team,
        errorMessage:
            'Live RobotEvents stats will appear here after the API key is connected.',
      );
    }

    try {
      final allEventsFuture = team.id <= 0
          ? Future<List<EventSummary>>.value(const <EventSummary>[])
          : _safeFuture<List<EventSummary>>(
              _loadAllEvents(team.id),
              fallback: const <EventSummary>[],
              timeout: _eventsTimeout,
            );
      var seasonId = preferredSeasonId;
      seasonId ??= await _resolveSeasonIdOrNull(await allEventsFuture);

      final allEvents = await allEventsFuture;
      final upcomingEvents = _upcomingEventsFrom(allEvents);
      final gradeLevel = _worldSkillsGradeLevel(team.grade);
      final rankingsFuture = seasonId == null || team.id <= 0
          ? Future<List<RankingRecord>>.value(const <RankingRecord>[])
          : _safeFuture<List<RankingRecord>>(
              _loadRankings(team.id, seasonId: seasonId),
              fallback: const <RankingRecord>[],
            );
      final matchHistoryFuture = seasonId == null || team.id <= 0
          ? Future<List<MatchSummary>>.value(const <MatchSummary>[])
          : _safeFuture<List<MatchSummary>>(
              _loadMatchHistory(team.id, seasonId: seasonId),
              fallback: const <MatchSummary>[],
            );
      final worldSkillsFuture = seedWorldSkillsEntry != null || seasonId == null
          ? Future<WorldSkillsEntry?>.value(seedWorldSkillsEntry)
          : _safeNullableFuture<WorldSkillsEntry>(
              _loadWorldSkillsEntry(
                seasonId: seasonId,
                gradeLevel: gradeLevel,
                team: team,
              ),
            );
      final openSkillFuture = seedOpenSkillEntry != null || seasonId == null
          ? Future<OpenSkillCacheEntry?>.value(seedOpenSkillEntry)
          : _safeNullableFuture<OpenSkillCacheEntry>(
              _loadOpenSkillEntry(
                seasonId: seasonId,
                gradeLevel: gradeLevel,
                team: team,
              ),
              timeout: _openSkillTimeout,
            );
      final results = await Future.wait<Object?>(<Future<Object?>>[
        rankingsFuture.then<Object?>((value) => value),
        matchHistoryFuture.then<Object?>((value) => value),
        worldSkillsFuture.then<Object?>((value) => value),
        openSkillFuture.then<Object?>((value) => value),
      ]);
      final rankings = results[0] as List<RankingRecord>;
      final matchHistory = results[1] as List<MatchSummary>;
      final worldSkillsEntry = results[2] as WorldSkillsEntry?;
      final openSkillEntry = results[3] as OpenSkillCacheEntry?;
      final hasLiveStats =
          allEvents.isNotEmpty ||
          rankings.isNotEmpty ||
          matchHistory.isNotEmpty ||
          worldSkillsEntry != null ||
          openSkillEntry != null;
      return TeamStatsSnapshot(
        team: team,
        allEvents: allEvents,
        upcomingEvents: upcomingEvents,
        rankings: rankings,
        matchHistory: matchHistory,
        openSkillEntry: openSkillEntry,
        worldSkillsEntry: worldSkillsEntry,
        lastUpdated: DateTime.now(),
        errorMessage: hasLiveStats
            ? null
            : 'Live team stats are taking longer than usual. Pull to retry.',
      );
    } on SolarApiException catch (error) {
      return TeamStatsSnapshot(team: team, errorMessage: error.message);
    } catch (_) {
      return TeamStatsSnapshot(
        team: team,
        errorMessage: 'We could not refresh live team stats right now.',
      );
    }
  }

  @override
  Future<TeamSummary> validateTeamNumber(
    String teamNumber, {
    int? preferredSeasonId,
  }) async {
    final normalizedNumber = teamNumber.trim().toUpperCase();
    if (normalizedNumber.isEmpty) {
      throw const FormatException('Enter your team number.');
    }

    if (!_api.config.hasRobotEventsApiKey) {
      throw const FormatException(
        'Team validation needs a RobotEvents API key. Add it with --dart-define=ROBOEVENTS_API_KEY=... or in assets/config/solar.local.json.',
      );
    }

    final matches = await _api.robotEvents.searchTeams(
      number: normalizedNumber,
    );
    final exactMatch = matches.where((team) {
      return team.number.trim().toUpperCase() == normalizedNumber;
    }).toList();

    if (exactMatch.isEmpty) {
      throw FormatException(
        'We could not find team $normalizedNumber. Try another team number.',
      );
    }

    exactMatch.sort((a, b) {
      if (a.registered == b.registered) {
        return a.teamName.compareTo(b.teamName);
      }
      return a.registered ? -1 : 1;
    });

    if (preferredSeasonId == null || exactMatch.length == 1) {
      return exactMatch.first;
    }

    final scoredTeams = await Future.wait<(TeamSummary, int)>(
      exactMatch.map((team) async {
        try {
          final events = await _api.robotEvents.fetchEvents(
            teamId: team.id,
            season: preferredSeasonId,
          );
          return (team, events.length);
        } catch (_) {
          return (team, 0);
        }
      }),
    );

    scoredTeams.sort((a, b) {
      if (a.$2 != b.$2) {
        return b.$2.compareTo(a.$2);
      }
      if (a.$1.registered != b.$1.registered) {
        return a.$1.registered ? -1 : 1;
      }
      return a.$1.teamName.compareTo(b.$1.teamName);
    });

    return scoredTeams.first.$1;
  }

  Future<List<EventSummary>> _loadAllEvents(int teamId) async {
    final events = await _api.robotEvents.fetchEvents(teamId: teamId);
    events.sort((a, b) {
      final aStart = a.start ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bStart = b.start ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aStart.compareTo(bStart);
    });
    return events;
  }

  List<EventSummary> _upcomingEventsFrom(List<EventSummary> allEvents) {
    final now = DateTime.now();
    final upcoming = allEvents
        .where((event) {
          final anchor = event.end ?? event.start;
          return anchor == null || !anchor.isBefore(now);
        })
        .toList(growable: false);
    return upcoming.take(6).toList(growable: false);
  }

  Future<List<RankingRecord>> _loadRankings(
    int teamId, {
    required int seasonId,
  }) async {
    final rankings = await _api.robotEvents.fetchTeamRankings(
      teamId,
      season: seasonId,
    );
    rankings.sort((a, b) {
      final aRank = a.rank < 0 ? 9999 : a.rank;
      final bRank = b.rank < 0 ? 9999 : b.rank;
      return aRank.compareTo(bRank);
    });
    return rankings;
  }

  Future<List<MatchSummary>> _loadMatchHistory(
    int teamId, {
    required int seasonId,
  }) async {
    final matches = await _api.robotEvents.fetchTeamMatches(
      teamId,
      season: seasonId,
    );
    matches.sort((a, b) {
      final aDate =
          a.started ?? a.scheduled ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate =
          b.started ?? b.scheduled ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aDate.compareTo(bDate);
    });
    return matches;
  }

  Future<int> _resolveSeasonId(
    List<EventSummary> allEvents, {
    int? preferredSeasonId,
  }) async {
    if (preferredSeasonId != null) {
      return preferredSeasonId;
    }

    final upcoming = _upcomingEventsFrom(allEvents);
    if (upcoming.isNotEmpty) {
      return upcoming.first.seasonId;
    }

    if (allEvents.isNotEmpty) {
      return allEvents.last.seasonId;
    }

    final seasons = await _api.robotEvents.fetchSeasons(
      programId: solarPrimaryProgramId,
    );
    if (seasons.isEmpty) {
      throw SolarApiException('No RobotEvents seasons were available.');
    }

    seasons.sort((a, b) {
      return compareSolarSeasonPriority(
        leftName: a.name,
        leftId: a.id,
        rightName: b.name,
        rightId: b.id,
      );
    });
    return seasons.first.id;
  }

  Future<int?> _resolveSeasonIdOrNull(List<EventSummary> allEvents) async {
    try {
      return await _resolveSeasonId(allEvents).timeout(_statsTimeout);
    } catch (_) {
      return null;
    }
  }

  Future<WorldSkillsEntry?> _loadWorldSkillsEntry({
    required int seasonId,
    required String gradeLevel,
    required TeamSummary team,
  }) async {
    try {
      final entries =
          (await _api.worldSkills.fetchRankings(
                seasonId: seasonId,
                gradeLevel: gradeLevel,
              ))
              .where((entry) {
                return isSolarPrimaryProgramText(entry.program);
              })
              .toList(growable: false);
      for (final entry in entries) {
        if (entry.teamId == team.id ||
            entry.teamNumber.trim().toUpperCase() ==
                team.number.trim().toUpperCase()) {
          return entry;
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<OpenSkillCacheEntry?> _loadOpenSkillEntry({
    required int seasonId,
    required String gradeLevel,
    required TeamSummary team,
  }) async {
    try {
      final entries = await _api.roboServer.fetchOpenSkillCache(
        season: seasonId,
        gradeLevel: gradeLevel,
      );
      for (final entry in entries) {
        if (entry.id == team.id ||
            entry.teamNumber.trim().toUpperCase() ==
                team.number.trim().toUpperCase()) {
          return entry;
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<T> _safeFuture<T>(
    Future<T> future, {
    required T fallback,
    Duration timeout = _statsTimeout,
  }) async {
    try {
      return await future.timeout(timeout);
    } catch (_) {
      return fallback;
    }
  }

  Future<T?> _safeNullableFuture<T>(
    Future<T?> future, {
    Duration timeout = _statsTimeout,
  }) async {
    try {
      return await future.timeout(timeout);
    } catch (_) {
      return null;
    }
  }

  String _worldSkillsGradeLevel(String grade) {
    final normalized = grade.trim().toLowerCase();
    if (normalized.contains('middle')) {
      return 'Middle School';
    }
    return 'High School';
  }
}

class FakeTeamDirectoryService implements TeamDirectoryService {
  FakeTeamDirectoryService({
    required Map<String, TeamSummary> teamsByNumber,
    Map<int, TeamStatsSnapshot>? snapshotsByTeamId,
  }) : _teamsByNumber = Map<String, TeamSummary>.fromEntries(
         teamsByNumber.entries.map((entry) {
           return MapEntry(entry.key.trim().toUpperCase(), entry.value);
         }),
       ),
       _snapshotsByTeamId =
           snapshotsByTeamId ?? const <int, TeamStatsSnapshot>{};

  final Map<String, TeamSummary> _teamsByNumber;
  final Map<int, TeamStatsSnapshot> _snapshotsByTeamId;

  @override
  Future<TeamStatsSnapshot> loadTeamStats(
    TeamSummary team, {
    int? preferredSeasonId,
    WorldSkillsEntry? seedWorldSkillsEntry,
    OpenSkillCacheEntry? seedOpenSkillEntry,
  }) async {
    return _snapshotsByTeamId[team.id] ?? TeamStatsSnapshot(team: team);
  }

  @override
  Future<TeamSummary> validateTeamNumber(
    String teamNumber, {
    int? preferredSeasonId,
  }) async {
    final normalizedNumber = teamNumber.trim().toUpperCase();
    final team = _teamsByNumber[normalizedNumber];
    if (team == null) {
      throw FormatException(
        'We could not find team $normalizedNumber. Try another team number.',
      );
    }
    return team;
  }
}
