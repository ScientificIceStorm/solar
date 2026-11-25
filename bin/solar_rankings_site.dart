import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:args/args.dart';
import 'package:solar_v6/solar_v6.dart';
import 'package:solar_v6/src/core/solar_competition_scope.dart';
import 'package:solar_v6/src/core/solar_match_analysis.dart';
import 'package:solar_v6/src/core/solar_season_forecast.dart';
import 'solar_event_information.dart';
import 'solar_division_metrics.dart';
import 'solar_streams.dart';

part 'solar_season_index.dart';

const _defaultPort = 8787;
const _siteDirectoryName = 'site';
final _cacheDirectoryName =
    Platform.environment['SOLAR_SITE_CACHE_DIR'] ?? '.solar_rankings_cache';
final _originToken = Platform.environment['SOLAR_ORIGIN_TOKEN']?.trim() ?? '';
const _gradeLevels = <String>['High School', 'Middle School', 'College'];
const _initialRating = 1500.0;
const _fieldKFactor = 92.0;
const _eventConcurrency = 2;
const _divisionConcurrency = 2;
const _cacheTtl = Duration(hours: 12);

Future<Map<int, TeamSummary>>? _teamDirectoryFuture;
final Map<String, Future<Map<String, dynamic>>> _rankingsCache =
    <String, Future<Map<String, dynamic>>>{};
final Map<String, Future<void>> _backgroundRefreshes = <String, Future<void>>{};
final _companionCache = <String, (DateTime, Future<Object>)>{};
final _snapshotLoads = <String, Future<Map<String, dynamic>>>{};
final _snapshotRetryAt = <String, DateTime>{};
final _openSkillSeasonJobs = <int, Future<void>>{};
final _openSkillSeasonRefresh = <int, DateTime>{};
final _openSkillSeasonMatches = <int, Map<(int, int, int), MatchSummary>>{};
final _webcastJobs = <int, Future<void>>{};
final _webcastResults = <int, Map<String, List<String>>>{};
final _webcastRefresh = <int, DateTime>{};

// Event dates may arrive as UTC midnight or as venue midnight converted to UTC.
bool _eventToday(EventSummary event, DateTime now) {
  final start = event.start;
  if (start == null) return false;
  int day(DateTime value) => value.year * 10000 + value.month * 100 + value.day;
  final longitude = event.location.longitude;
  final estimate = longitude == null ? 0 : (longitude * 4).round();
  final country = event.location.country.toLowerCase();
  if (country.startsWith('united states') || country == 'usa') {
    // VEX event dates use a shared Eastern offset for some U.S. venues.
    final utc = now.toUtc();
    final march = DateTime.utc(utc.year, 3, 1);
    final november = DateTime.utc(utc.year, 11, 1);
    DateTime sunday(DateTime month) =>
        month.add(Duration(days: (7 - month.weekday) % 7));
    final observesDst = !const {
      'Arizona',
      'Hawaii',
    }.contains(event.location.region);
    final dst =
        observesDst &&
        !utc.isBefore(sunday(march).add(const Duration(days: 7, hours: 9))) &&
        utc.isBefore(sunday(november).add(const Duration(hours: 8)));
    final west = switch (event.location.region) {
      'California' || 'Washington' || 'Oregon' || 'Nevada' => -8,
      'Arizona' ||
      'Colorado' ||
      'New Mexico' ||
      'Utah' ||
      'Wyoming' ||
      'Montana' => -7,
      'Hawaii' => -10,
      'Georgia' ||
      'Ohio' ||
      'South Carolina' ||
      'North Carolina' ||
      'Virginia' ||
      'West Virginia' ||
      'New York' ||
      'Pennsylvania' ||
      'Maryland' ||
      'New Jersey' ||
      'Delaware' ||
      'Connecticut' ||
      'Rhode Island' ||
      'Massachusetts' ||
      'Vermont' ||
      'New Hampshire' ||
      'Maine' ||
      'District of Columbia' => -5,
      _ => longitude == null ? -5 : (longitude / 15).round(),
    };
    final today = day(utc.add(Duration(hours: west + (dst ? 1 : 0))));
    return today >= day(start.toUtc()) &&
        today <= day((event.end ?? start).toUtc());
  }
  int offset(DateTime value) {
    final utc = value.toUtc();
    final minutes = utc.hour * 60 + utc.minute;
    if (minutes == 0) return estimate;
    final candidates = [-minutes, 1440 - minutes];
    candidates.sort(
      (a, b) => (a - estimate).abs().compareTo((b - estimate).abs()),
    );
    return candidates.first;
  }

  final end = event.end ?? start;
  DateTime venueDate(DateTime value) =>
      value.toUtc().hour == 0 && value.toUtc().minute == 0
      ? value.toUtc()
      : value.toUtc().add(Duration(minutes: offset(value)));
  final today = day(now.toUtc().add(Duration(minutes: offset(start))));
  return today >= day(venueDate(start)) && today <= day(venueDate(end));
}

Future<List<SeasonSummary>> _siteSeasons(SolarApi api) async {
  final snapshot = await _siteSnapshot(
    'seasons',
    const Duration(hours: 12),
    () async {
      final seasons = await api.robotEvents.fetchSeasons(
        programId: solarPrimaryProgramId,
      );
      return {'rows': seasons.map((season) => season.toJson()).toList()};
    },
  );
  return (snapshot['rows'] as List)
      .cast<Map<String, dynamic>>()
      .map(SeasonSummary.fromJson)
      .toList();
}

Future<List<Map<String, dynamic>>> _skillsRows(
  SolarApi api,
  int season,
  String grade,
) async {
  final snapshot = await _siteSnapshot(
    'skills-$season-${_slugify(grade)}',
    const Duration(minutes: 15),
    () async {
      final rows = await api.worldSkills.fetchRankings(
        seasonId: season,
        gradeLevel: grade,
      );
      return {
        'rows': rows
            .where((row) => isSolarPrimaryProgramText(row.program))
            .map((row) => row.toJson())
            .toList(),
      };
    },
  );
  return (snapshot['rows'] as List).cast<Map<String, dynamic>>();
}

int _seasonYear(SeasonSummary season) =>
    int.tryParse(RegExp(r'\b20\d{2}\b').firstMatch(season.name)?[0] ?? '') ?? 0;

Future<int?> _previousSeasonId(SolarApi api, int id) async {
  final seasons = await _siteSeasons(api);
  final current = seasons.where((season) => season.id == id).firstOrNull;
  if (current == null || _seasonYear(current) == 0) return null;
  return (seasons
          .where((season) => _seasonYear(season) < _seasonYear(current))
          .toList()
        ..sort((a, b) => _seasonYear(b).compareTo(_seasonYear(a))))
      .firstOrNull
      ?.id;
}

Future<Map<String, dynamic>> _siteSnapshot(
  String key,
  Duration maxAge,
  Future<Map<String, dynamic>> Function() load, {
  bool waitForRefresh = false,
}) async {
  final file = File('$_cacheDirectoryName/companion/$key.json');
  final saved = await _readSiteSnapshot(key);
  final now = DateTime.now();
  final timestamp = DateTime.tryParse(saved?['_cachedAt'] as String? ?? '');
  if (timestamp != null && now.difference(timestamp) < maxAge) {
    return saved!;
  }
  _snapshotRetryAt.removeWhere((_, retryAt) => !retryAt.isAfter(now));
  if (_snapshotRetryAt.containsKey(key)) {
    if (saved != null) return saved;
    throw SolarApiException('Snapshot refresh is cooling down');
  }
  final pending = _snapshotLoads.putIfAbsent(key, () async {
    try {
      final value = {
        ...await load(),
        '_cachedAt': DateTime.now().toIso8601String(),
      };
      try {
        await file.parent.create(recursive: true);
        final temporary = File('${file.path}.tmp');
        await temporary.writeAsString(jsonEncode(value));
        await temporary.rename(file.path);
      } on FileSystemException {
        // Cache failures should not prevent the live response.
      }
      return value;
    } on Exception catch (error) {
      final retry = error is SolarApiException ? error.retryAfter : null;
      _snapshotRetryAt[key] = DateTime.now().add(
        retry ?? const Duration(seconds: 30),
      );
      rethrow;
    } finally {
      _snapshotLoads.remove(key);
    }
  });
  if (saved != null && !waitForRefresh) {
    unawaited(pending.then<void>((_) {}, onError: (Object _, StackTrace _) {}));
    return saved;
  }
  try {
    return await pending;
  } on Exception {
    if (saved != null) return saved;
    rethrow;
  }
}

Future<List<MatchSummary>> _seasonTeamMatches(
  SolarApi api,
  int team,
  int season, {
  Duration maxAge = const Duration(minutes: 15),
  bool waitForRefresh = false,
}) async {
  final snapshot = await _siteSnapshot(
    'team-matches-$team-$season',
    maxAge,
    () async {
      final matches = await api.robotEvents.fetchTeamMatches(
        team,
        season: season,
      );
      return {'matches': matches.map((match) => match.toJson()).toList()};
    },
    waitForRefresh: waitForRefresh,
  );
  return (snapshot['matches'] as List)
      .cast<Map<String, dynamic>>()
      .map(MatchSummary.fromJson)
      .toList();
}

/// Scored matches from [event]'s season to rate its teams with: the season
/// index, plus each team's saved match history when [savedTeams] is set or
/// the index doesn't know most of them yet (e.g. right after a restart).
Future<List<MatchSummary>> _seasonHistory(
  EventSummary event,
  List<MatchSummary> matches, {
  bool savedTeams = false,
}) async {
  final history = <MatchSummary>[
    ...?_openSkillSeasonMatches[event.seasonId]?.values,
  ];
  if (event.seasonId <= 0) return history;
  final teamIds = {
    for (final match in matches)
      for (final alliance in match.alliances)
        for (final team in alliance.teams)
          if (team.id > 0) team.id,
  };
  final known = {
    for (final match in history)
      if (match.event.id != event.id)
        for (final alliance in match.alliances)
          for (final team in alliance.teams) team.id,
  };
  if (!savedTeams &&
      known.intersection(teamIds).length * 2 >= teamIds.length) {
    return history;
  }
  await _mapWithConcurrency(teamIds.toList(), 4, (team, _) async {
    final saved = await _readSiteSnapshot(
      'team-matches-$team-${event.seasonId}',
    );
    history.addAll(
      (saved?['matches'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(MatchSummary.fromJson),
    );
  });
  return history;
}

Future<Map<String, Object?>> _previousEventOdds(
  SolarApi api,
  EventSummary event,
  List<MatchSummary> matches,
) async {
  final start = event.start;
  if (start == null || event.seasonId <= 0 || matches.isEmpty) return {};
  final teamIds = matches
      .expand((match) => match.alliances)
      .expand((alliance) => alliance.teams)
      .map((team) => team.id)
      .where((id) => id > 0)
      .toSet()
      .toList();
  final history = <MatchSummary>[
    ...?_openSkillSeasonMatches[event.seasonId]?.values,
  ];
  Future<List<MatchSummary>> savedHistory(int team, int season) async {
    final saved = await _readSiteSnapshot('team-matches-$team-$season');
    return (saved?['matches'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(MatchSummary.fromJson)
        .toList();
  }

  await _mapWithConcurrency(teamIds, 2, (team, _) async {
    history.addAll(await savedHistory(team, event.seasonId));
  });
  final now = DateTime.now();
  final prior = SolarMatchAnalysis.beforeEvent(
    history,
    eventId: event.id,
    cutoff: start.isBefore(now) ? start : now,
    openSkill: true,
  );
  final missing = teamIds
      .where((id) => (prior.ratings[id]?.matches ?? 0) == 0)
      .toList();
  final previousMatches = <MatchSummary>[];
  if (missing.isNotEmpty) {
    final previousSeason = await _previousSeasonId(api, event.seasonId);
    if (previousSeason != null) {
      previousMatches.addAll(
        _openSkillSeasonMatches[previousSeason]?.values ?? [],
      );
      await _mapWithConcurrency(missing, 2, (team, _) async {
        previousMatches.addAll(await savedHistory(team, previousSeason));
      });
    }
  }
  final previous = SolarMatchAnalysis.beforeEvent(
    previousMatches,
    eventId: event.id,
    cutoff: start,
    openSkill: true,
  );
  final analysis = SolarMatchAnalysis(
    matches,
    now: now,
    prior: prior,
    conservativeOdds: true,
    openSkill: true,
    previousSeason: previous.ratings,
  );
  return {for (final row in analysis.rows) '${row['id']}': row['forecast']};
}

Future<Object> _companionData(
  String key,
  Future<Object> Function() load,
) async {
  final now = DateTime.now();
  _companionCache.removeWhere((_, entry) => entry.$1.isBefore(now));
  final pending = _companionCache.putIfAbsent(
    key,
    () => (now.add(const Duration(minutes: 5)), load()),
  );
  try {
    return await pending.$2;
  } catch (_) {
    if (identical(_companionCache[key], pending)) _companionCache.remove(key);
    rethrow;
  }
}

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('host', defaultsTo: '127.0.0.1')
    ..addOption('port', defaultsTo: '$_defaultPort')
    ..addFlag('help', abbr: 'h', negatable: false);

  final results = parser.parse(arguments);
  if (results['help'] as bool) {
    stdout.writeln(
      'Usage: dart run bin/solar_rankings_site.dart [--host 127.0.0.1] [--port 8787]',
    );
    return;
  }

  final host = (results['host'] as String).trim();
  final port = int.tryParse(results['port'] as String) ?? _defaultPort;
  final api = await SolarApi.fromLocalConfig(
    configFilePath: await File('solar.local.json').exists()
        ? 'solar.local.json'
        : 'assets/config/solar.local.json',
  );
  final siteDirectory = Directory(_siteDirectoryName);

  if (!await siteDirectory.exists()) {
    stderr.writeln(
      'Missing "$_siteDirectoryName" directory. Run this command from the project root.',
    );
    exitCode = 1;
    api.close();
    return;
  }

  final server = await HttpServer.bind(host, port);
  server.autoCompress = true;
  stdout.writeln('Solar rankings site running at http://$host:$port');
  if (Platform.environment['RAILWAY_ENVIRONMENT'] != null) {
    unawaited(_scanWebcastArchive(api));
    unawaited(_warmCurrentRatings(api));
    Timer.periodic(const Duration(days: 1), (_) {
      unawaited(_scanWebcastArchive(api));
    });
  }

  ProcessSignal.sigint.watch().listen((_) async {
    await server.close(force: true);
    api.close();
    exit(0);
  });

  await for (final request in server) {
    unawaited(_handleRequest(request, api: api, siteDirectory: siteDirectory));
  }
}

Future<void> _handleRequest(
  HttpRequest request, {
  required SolarApi api,
  required Directory siteDirectory,
}) async {
  try {
    if (request.method == 'OPTIONS') {
      _applyApiHeaders(request.response);
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }

    final path = request.uri.path;
    if (path.startsWith('/api/') &&
        _originToken.isNotEmpty &&
        request.headers['X-Solar-Origin-Token']?.singleOrNull != _originToken) {
      return _writeError(request.response, HttpStatus.forbidden, 'Forbidden.');
    }
    if (path == '/api/health') {
      return _writeJson(request.response, <String, dynamic>{
        'ok': true,
        'config': api.config.toSafeJson(),
      });
    }

    if (path == '/api/seasons') {
      final seasons = await _companionData('seasons', () async {
        final values = await _siteSeasons(api);
        return values.map((season) => season.toJson()).toList();
      });

      return _writeJson(request.response, <String, dynamic>{
        'program': solarPrimaryProgramFilter,
        'gradeLevels': _gradeLevels,
        'seasons': seasons,
      }, maxAge: const Duration(minutes: 5));
    }

    if (path == '/api/event') {
      final sku = (request.uri.queryParameters['sku'] ?? '').toUpperCase();
      final divisionId = int.tryParse(
        request.uri.queryParameters['division'] ?? '',
      );
      if (!RegExp(r'^(RE|VE)-[A-Z0-9-]{4,40}$').hasMatch(sku)) {
        return _writeError(
          request.response,
          HttpStatus.badRequest,
          'Invalid event code.',
        );
      }
      final snapshot = await _siteSnapshot(
        'event-$sku',
        const Duration(minutes: 30),
        () async {
          final season = int.tryParse(
            request.uri.queryParameters['seasonId'] ?? '',
          );
          if (season != null && season > 0) {
            final calendar = await _readSiteSnapshot('calendar-map-v1-$season');
            final savedEvent = (calendar?['events'] as List? ?? [])
                .whereType<Map<String, dynamic>>()
                .where((event) => event['sku'] == sku)
                .firstOrNull;
            if (savedEvent != null) return {'event': savedEvent};
          }
          final event =
              (await api.robotEvents
                      .fetchEvents(sku: sku)
                      .timeout(const Duration(seconds: 6)))
                  .where((item) => item.sku == sku)
                  .firstOrNull;
          return {'event': event?.toJson()};
        },
      );
      final rawEvent = snapshot['event'];
      if (rawEvent is! Map<String, dynamic>) {
        return _writeError(
          request.response,
          HttpStatus.notFound,
          'Event not found.',
        );
      }
      final event = EventSummary.fromJson(rawEvent);
      if (request.uri.queryParameters['scouting'] == '1') {
        final detail = await _siteSnapshot(
          'scouting-event-${event.id}',
          _eventToday(event, DateTime.now())
              ? const Duration(minutes: 2)
              : const Duration(days: 1),
          () async {
            final (skills, awards) = await (
              api.robotEvents.fetchEventSkills(event.id),
              api.robotEvents.fetchEventAwards(event.id),
            ).wait;
            return {
              'skills': skills.map((row) => row.toJson()).toList(),
              'awards': awards.map((row) => row.toJson()).toList(),
            };
          },
        );
        return _writeJson(request.response, detail);
      }
      if (request.uri.queryParameters['information'] == '1') {
        final information = await _eventInformation(event.sku, event: event);
        return _writeJson(request.response, information);
      }
      if (request.uri.queryParameters['roster'] == '1') {
        final roster = await _siteSnapshot(
          'roster-${event.id}',
          const Duration(minutes: 10),
          () async {
            final teams = (await api.robotEvents.fetchEventTeams(
              event.id,
            )).toList()..sort((a, b) => a.number.compareTo(b.number));
            return {'teams': teams.map((team) => team.toJson()).toList()};
          },
        );
        return _writeJson(request.response, roster['teams'] as List);
      }
      final division = divisionId == null
          ? event.divisions.firstOrNull
          : event.divisions.where((item) => item.id == divisionId).firstOrNull;
      if (divisionId != null && division == null) {
        return _writeError(
          request.response,
          HttpStatus.notFound,
          'Division not found.',
        );
      }
      final now = DateTime.now();
      final active = _eventToday(event, now);
      Future<Map<String, dynamic>> indexedDivision() async {
        final cached = await _readSiteSnapshot(
          'rated-matches-${event.id}-${division?.id}',
        );
        final indexed = <(int, int, int), MatchSummary>{};
        _rememberMatches(indexed, cached?['matches']);
        for (final entry
            in _openSkillSeasonMatches[event.seasonId]?.entries ??
                const <MapEntry<(int, int, int), MatchSummary>>[]) {
          if (entry.key.$1 == event.id && entry.key.$2 == division?.id) {
            indexed[entry.key] = entry.value;
          }
        }
        return {
          'event': event.toJson(),
          'division': division?.toJson(),
          'matches': SolarMatchAnalysis(
            indexed.values,
            now: now,
            openSkill: true,
          ).rows,
          'partial': true,
        };
      }

      final detailsOnly =
          request.uri.queryParameters['streams'] == '1' ||
          request.uri.queryParameters['history'] == '1';
      final divisionKey = 'division-v5-${event.id}-${division?.id}';
      // When RobotEvents had no standings (or the request failed) the saved
      // snapshot is retried within a minute instead of being kept all day.
      final savedDivision = await _readSiteSnapshot(divisionKey);
      final standingsPending = const {'previous', 'missing'}.contains(
        savedDivision?['standingsSource'],
      );
      final snapshotLoad = _siteSnapshot(
        divisionKey,
        active
            ? const Duration(seconds: 12)
            : standingsPending
            ? const Duration(minutes: 1)
            : event.end?.isBefore(now) == true
            ? const Duration(days: 1)
            : const Duration(minutes: 15),
        () async {
          if (division == null) {
            return <String, Object?>{'event': event.toJson()};
          }
          final (standings, matches) = await (
            api.robotEvents
                .fetchDivisionRankings(
                  eventId: event.id,
                  divisionId: division.id,
                )
                .onError<Exception>((_, _) => <RankingRecord>[]),
            api.robotEvents.fetchDivisionMatches(
              eventId: event.id,
              divisionId: division.id,
            ),
          ).wait;
          final seasonHistory =
              _openSkillSeasonMatches[event.seasonId]?.values ??
              const <MatchSummary>[];
          final prior = SolarMatchAnalysis.beforeEvent(
            seasonHistory,
            eventId: event.id,
            cutoff: event.start ?? now,
            openSkill: true,
          );
          final analysis = SolarMatchAnalysis(
            matches,
            now: DateTime.now(),
            prior: prior,
            conservativeOdds: true,
            openSkill: true,
          );
          final metrics = solarDivisionMetrics(matches);
          final divisionRatings = prior.ratings.isEmpty
              ? analysis.ratings
              : SolarMatchAnalysis(matches, now: now, openSkill: true).ratings;
          standings.sort((a, b) => a.rank.compareTo(b.rank));
          // A failed or empty rankings request must not wipe standings that
          // were already posted: keep the last official ones and retry soon.
          // (Standings can't be rebuilt from scores; DQs and corrections only
          // show up in RobotEvents' own rankings.)
          var rows = standings.map((row) => row.toJson()).toList();
          String? source;
          if (rows.isEmpty) {
            final previous = (await _readSiteSnapshot(divisionKey))?['standings'];
            if (previous is List && previous.isNotEmpty) {
              rows = previous.whereType<Map<String, dynamic>>().toList();
              source = 'previous';
            } else if (matches.any(
              (match) =>
                  match.round == MatchRound.qualification &&
                  match.alliances.any((alliance) => alliance.score > 0),
            )) {
              source = 'missing';
            }
          }
          final seasonOdds = SolarSeasonForecast.forMatches(
            await _seasonHistory(event, matches),
            matches,
          );
          return <String, Object?>{
            'event': event.toJson(),
            'division': division.toJson(),
            'active': active,
            'standingsSource': ?source,
            'standings': rows
                .map(
                  (row) => {
                    ...row,
                    'skill': divisionRatings[(row['team'] as Map)['id']]
                        ?.toJson(),
                    ...?metrics[(row['team'] as Map)['id']],
                  },
                )
                .toList(),
            // Score-based season odds (see SolarSeasonForecast); the rating
            // forecast stays only for teams with no scored match yet.
            'matches': [
              for (final row in analysis.rows)
                {...row, 'forecast': seasonOdds[row['id']] ?? row['forecast']},
            ],
          };
        },
      );
      final data = detailsOnly
          ? await snapshotLoad
          : await snapshotLoad
                .timeout(const Duration(seconds: 3), onTimeout: indexedDivision)
                .onError<Object>((_, _) => indexedDivision());
      final rows =
          (data['matches'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      if (request.uri.queryParameters['streams'] == '1' && division != null) {
        final streams = await _siteSnapshot(
          'streams-v5-${event.id}-${division.id}',
          active ? const Duration(minutes: 2) : const Duration(hours: 2),
          () async => {
            'rows': await solarMatchStreams(
              event,
              division,
              rows.map(MatchSummary.fromJson),
              () async =>
                  ((await _eventInformation(event.sku, event: event))['webcasts'] as List)
                      .cast<String>(),
            ),
          },
        );
        return _writeJson(request.response, streams['rows'] as Map);
      }
      if (request.uri.queryParameters['history'] == '1' && division != null) {
        final odds = await _siteSnapshot(
          'odds-season-v1-${event.id}-${division.id}',
          active ? const Duration(minutes: 2) : const Duration(hours: 6),
          () async {
            final matches = rows.map(MatchSummary.fromJson).toList();
            final previous = await _previousEventOdds(api, event, matches);
            final season = SolarSeasonForecast.forMatches(
              await _seasonHistory(event, matches, savedTeams: true),
              matches,
            );
            return {
              ...previous,
              for (final entry in season.entries) '${entry.key}': entry.value,
            };
          },
        );
        return _writeJson(request.response, odds);
      }
      if (active) request.response.headers.set('X-Solar-Live', '1');
      if (data['partial'] == true) {
        request.response.headers.set('Cache-Control', 'no-store');
      }
      return _writeJson(request.response, {
        ...data,
        'active': active,
        'nextLiveCheck': event.start?.toIso8601String(),
      });
    }

    if (const {
      '/api/skills',
      '/api/events',
      '/api/team',
      '/api/openskill',
      '/api/webcasts',
    }.contains(path)) {
      final query = request.uri.queryParameters;
      final season = int.tryParse(query['seasonId'] ?? '');
      final grade = query['gradeLevel'] ?? 'High School';
      final number = (query['number'] ?? '').trim().toUpperCase();
      if (season == null ||
          season <= 0 ||
          (path == '/api/skills' && !_gradeLevels.contains(grade)) ||
          (path == '/api/openskill' &&
              grade != 'All' &&
              !_gradeLevels.contains(grade)) ||
          (path == '/api/team' &&
              !RegExp(r'^[A-Z0-9]{1,12}$').hasMatch(number))) {
        return _writeError(
          request.response,
          HttpStatus.badRequest,
          'Invalid filters.',
        );
      }
      if (path == '/api/openskill') {
        final board = await _siteSnapshot(
          'leaderboard-v2-$season-${grade.replaceAll(' ', '-')}',
          const Duration(minutes: 5),
          () => _openSkillLeaderboard(api, season, grade),
        );
        return _writeJson(
          request.response,
          board,
          maxAge: const Duration(minutes: 2),
        );
      }
      if (path == '/api/webcasts') {
        final calendar = await _calendar(api, season);
        return _writeJson(
          request.response,
          await _seasonWebcasts(season, calendar),
        );
      }
      if (path == '/api/skills') {
        return _writeJson(
          request.response,
          await _skillsRows(api, season, grade),
          maxAge: const Duration(minutes: 1),
        );
      }
      if (path == '/api/events') {
        final events = await _calendar(api, season);
        return _writeJson(
          request.response,
          events.map((event) => event.toJson()).toList(),
          maxAge: const Duration(minutes: 1),
        );
      }
      final profileKey = 'profile-$season-$number';
      final savedProfile = await _readSiteSnapshot(profileKey);
      final indexedMatches =
          (_openSkillSeasonMatches[season]?.values ?? const <MatchSummary>[])
              .where(
                (match) => match.alliances.any(
                  (alliance) => alliance.teams.any(
                    (team) => team.number.toUpperCase() == number,
                  ),
                ),
              )
              .toList();
      final indexedTeam = indexedMatches
          .expand((match) => match.alliances)
          .expand((alliance) => alliance.teams)
          .where((team) => team.number.toUpperCase() == number)
          .firstOrNull;
      final indexedEventIds = indexedMatches
          .map((match) => match.event.id)
          .toSet();
      final calendar = await _readSiteSnapshot('calendar-map-v1-$season');
      final eventsById = {
        for (final event in [
          ...(calendar?['events'] as List? ?? []),
          ...(savedProfile?['events'] as List? ?? []),
        ].whereType<Map<String, dynamic>>().map(EventSummary.fromJson))
          if (indexedEventIds.contains(event.id) ||
              (savedProfile?['events'] as List? ?? []).any(
                (row) => row is Map && row['id'] == event.id,
              ))
            event.id: event,
      };
      final liveHint = eventsById.values.any(
        (event) => _eventToday(event, DateTime.now()),
      );
      Future<Map<String, dynamic>?> lookup() async {
        if (api.isRateLimited) return null;
        try {
          return await _lookupTeam(
            api,
            number,
          ).timeout(const Duration(seconds: 2), onTimeout: () => null);
        } on Exception {
          return null;
        }
      }

      Future<Object?> identity() async =>
          savedProfile?['team'] ??
          (await _readSiteSnapshot('team-identity-$number'))?['team'] ??
          (indexedTeam == null
              ? null
              : {'id': indexedTeam.id, 'number': number}) ??
          await lookup();
      if (query['upcoming'] == '1') {
        final data = await _siteSnapshot(
          'team-registrations-$season-$number',
          const Duration(minutes: 15),
          () async {
            final team = await identity();
            if (team is! Map || team['id'] is! int) {
              throw SolarApiException('Could not look up team registrations');
            }
            final now = DateTime.now();
            final entries = await api.robotEvents.fetchEvents(
              teamId: team['id'] as int,
              season: season,
              startsAfter: now.subtract(const Duration(days: 1)),
            );
            return {'events': entries.map((event) => event.toJson()).toList()};
          },
        );
        final now = DateTime.now();
        final upcoming =
            (data['events'] as List? ?? [])
                .whereType<Map<String, dynamic>>()
                .map(EventSummary.fromJson)
                .where((event) => event.start?.isAfter(now) == true)
                .toList()
              ..sort((a, b) => a.start!.compareTo(b.start!));
        return _writeJson(request.response, {
          'events': upcoming.map((event) => event.toJson()).toList(),
        }, maxAge: const Duration(minutes: 3));
      }
      if (query['summary'] == '1') {
        final team = await identity();
        return _writeJson(
          request.response,
          {'team': team, 'skill': savedProfile?['skill']},
          maxAge: team == null ? Duration.zero : const Duration(minutes: 1),
        );
      }
      if (savedProfile?['team'] != null && !liveHint) {
        return _writeJson(request.response, {
          ...savedProfile!,
          'active': false,
        }, maxAge: const Duration(seconds: 30));
      }
      Future<Map<String, dynamic>> indexedProfile() async {
        final analysis = SolarMatchAnalysis(
          indexedMatches,
          now: DateTime.now(),
          conservativeOdds: true,
          openSkill: true,
        );
        return {
          'team': await identity() ?? {'number': number},
          'events': eventsById.values.map((event) => event.toJson()).toList(),
          'matches': analysis.rows,
          'skill': analysis.ratings[indexedTeam?.id]?.toJson(),
          'partial': true,
        };
      }

      final data =
          await _siteSnapshot(
                profileKey,
                const Duration(seconds: 25),
                () async {
                  if (api.isRateLimited) {
                    throw SolarApiException('VEX is cooling down');
                  }
                  final identity =
                      savedProfile?['team'] as Map<String, dynamic>? ??
                      await _lookupTeam(api, number);
                  if (identity == null) return <String, Object?>{'team': null};
                  final team = TeamSummary.fromJson(identity);
                  final events = savedProfile?['team'] == null
                      ? await api.robotEvents.fetchEvents(
                          teamId: team.id,
                          season: season,
                        )
                      : eventsById.values.toList();
                  final matches = <(int, int, int), MatchSummary>{};
                  if (savedProfile?['team'] == null) {
                    for (final match in await _seasonTeamMatches(
                      api,
                      team.id,
                      season,
                    )) {
                      matches[(match.event.id, match.division.id, match.id)] =
                          match;
                    }
                  } else {
                    _rememberMatches(matches, savedProfile?['matches']);
                    for (final event in events.where(
                      (event) => _eventToday(event, DateTime.now()),
                    )) {
                      final liveMatches = await api.robotEvents
                          .fetchTeamMatches(team.id, eventId: event.id);
                      for (final match in liveMatches.where(
                        (m) => m.event.id == event.id,
                      )) {
                        matches[(match.event.id, match.division.id, match.id)] =
                            match;
                      }
                    }
                  }
                  _rememberMatches(
                    _openSkillSeasonMatches.putIfAbsent(season, () => {}),
                    matches.values.map((match) => match.toJson()).toList(),
                  );
                  final analysis = SolarMatchAnalysis(
                    matches.values,
                    now: DateTime.now(),
                    conservativeOdds: true,
                    openSkill: true,
                  );
                  return {
                    'team': team.toJson(),
                    'events': events.map((event) => event.toJson()).toList(),
                    'skill': analysis.ratings[team.id]?.toJson(),
                    'matches': analysis.rows,
                  };
                },
              )
              .timeout(const Duration(seconds: 3), onTimeout: indexedProfile)
              .onError<Exception>((_, _) => indexedProfile());
      final live =
          liveHint ||
          (data['events'] as List? ?? [])
              .whereType<Map<String, dynamic>>()
              .map(EventSummary.fromJson)
              .any((event) => _eventToday(event, DateTime.now()));
      if (live) request.response.headers.set('X-Solar-Live', '1');
      if (data['partial'] == true) {
        request.response.headers.set('Cache-Control', 'no-store');
      }
      return _writeJson(
        request.response,
        {...data, 'active': live},
        maxAge: data['partial'] == true
            ? null
            : live
            ? const Duration(seconds: 5)
            : const Duration(seconds: 30),
      );
    }

    if (path == '/api/rankings') {
      final seasonId = int.tryParse(
        request.uri.queryParameters['seasonId'] ?? '',
      );
      final gradeLevel =
          (request.uri.queryParameters['gradeLevel'] ?? 'High School').trim();
      final forceRefresh =
          request.uri.queryParameters['refresh'] == '1' ||
          request.uri.queryParameters['refresh'] == 'true';

      if (seasonId == null) {
        return _writeError(
          request.response,
          HttpStatus.badRequest,
          'Missing or invalid seasonId query parameter.',
        );
      }

      final payload = await _loadRankingsPayload(
        api,
        seasonId: seasonId,
        gradeLevel: gradeLevel,
        forceRefresh: forceRefresh,
      );
      return _writeJson(request.response, payload);
    }

    final isDetailPage = RegExp(
      r'^/(event/(?:RE|VE)-[A-Z0-9-]+|team/[A-Z0-9]+)$',
      caseSensitive: false,
    ).hasMatch(path);
    final assetPath = path == '/' || isDetailPage ? '/index.html' : path;
    if (!const {
      '/index.html',
      '/styles.css',
      '/app.js',
      '/map.js',
      '/california-counties.json',
      '/solar-photo.jpg',
      '/manrope.woff2',
    }.contains(assetPath)) {
      return _writeError(request.response, HttpStatus.notFound, 'Not found.');
    }
    final file = File(
      '${siteDirectory.path}${assetPath.replaceAll('/', Platform.pathSeparator)}',
    );
    if (!await file.exists()) {
      return _writeError(request.response, HttpStatus.notFound, 'Not found.');
    }

    request.response.headers.contentType = _contentTypeFor(file.path);
    await request.response.addStream(file.openRead());
    await request.response.close();
  } catch (error, stackTrace) {
    stderr.writeln('Site error: $error');
    stderr.writeln(stackTrace);
    await _writeError(
      request.response,
      HttpStatus.internalServerError,
      'Solar could not load this data. Try again shortly.',
    );
  }
}

Future<Map<String, dynamic>?> _lookupTeam(SolarApi api, String number) async {
  final snapshot = await _siteSnapshot(
    'team-identity-$number',
    const Duration(days: 1),
    () async {
      final teams = await api.robotEvents.searchTeams(number: number);
      final team = teams
          .where((team) => team.number.toUpperCase() == number)
          .firstOrNull;
      return {'team': team?.toJson()};
    },
  );
  return snapshot['team'] as Map<String, dynamic>?;
}

Future<Map<String, dynamic>?> _readSiteSnapshot(String key) async {
  for (final directory in [
    '$_cacheDirectoryName/companion',
    if (Platform.environment['SOLAR_SITE_SEED_DIR'] case final String seed)
      seed,
  ]) {
    try {
      final file = File('$directory/$key.json');
      return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    } on Exception {
      // A deployment can ship a public snapshot for a cold cache.
    }
  }
  return null;
}

Future<Map<String, dynamic>> _eventInformation(
  String sku, {
  EventSummary? event,
}) => _siteSnapshot(
  'event-information-v4-$sku',
  const Duration(minutes: 15),
  () async {
    final information = await solarEventInformation(sku);
    final webcasts = (information['webcasts'] as List? ?? [])
        .whereType<String>()
        .toList();
    return {
      ...information,
      // Only streams that were live around this event's dates.
      'webcasts': await solarWebcastsDuring(webcasts, event?.start, event?.end),
    };
  },
);

Future<Map<String, dynamic>> _loadRankingsPayload(
  SolarApi api, {
  required int seasonId,
  required String gradeLevel,
  required bool forceRefresh,
}) async {
  final cacheKey = '$seasonId::$gradeLevel';
  final cacheFile = _cacheFileFor(seasonId: seasonId, gradeLevel: gradeLevel);

  if (forceRefresh) {
    _rankingsCache.remove(cacheKey);
    return _rankingsCache.putIfAbsent(cacheKey, () async {
      try {
        final payload = await _buildRankingsPayload(
          api,
          seasonId: seasonId,
          gradeLevel: gradeLevel,
        );
        await _writeCachedPayload(cacheFile, payload);
        return payload;
      } catch (_) {
        _rankingsCache.remove(cacheKey);
        rethrow;
      }
    });
  }

  final cachedPayload = await _readCachedPayload(cacheFile);
  if (cachedPayload != null) {
    if (_isPayloadStale(cachedPayload)) {
      unawaited(
        _scheduleBackgroundRefresh(
          api,
          cacheKey: cacheKey,
          cacheFile: cacheFile,
          seasonId: seasonId,
          gradeLevel: gradeLevel,
        ),
      );
    }
    return cachedPayload;
  }

  return _rankingsCache.putIfAbsent(cacheKey, () async {
    try {
      final payload = await _buildRankingsPayload(
        api,
        seasonId: seasonId,
        gradeLevel: gradeLevel,
      );
      await _writeCachedPayload(cacheFile, payload);
      return payload;
    } catch (_) {
      _rankingsCache.remove(cacheKey);
      rethrow;
    }
  });
}

Future<void> _scheduleBackgroundRefresh(
  SolarApi api, {
  required String cacheKey,
  required File cacheFile,
  required int seasonId,
  required String gradeLevel,
}) {
  return _backgroundRefreshes.putIfAbsent(cacheKey, () async {
    stdout.writeln(
      'Refreshing cached rankings for $seasonId / $gradeLevel in the background...',
    );
    try {
      final payload = await _buildRankingsPayload(
        api,
        seasonId: seasonId,
        gradeLevel: gradeLevel,
      );
      await _writeCachedPayload(cacheFile, payload);
      _rankingsCache[cacheKey] = Future<Map<String, dynamic>>.value(payload);
    } catch (error) {
      stderr.writeln(
        'Background rankings refresh failed for $seasonId / $gradeLevel: $error',
      );
    } finally {
      _backgroundRefreshes.remove(cacheKey);
    }
  });
}

Future<Map<String, dynamic>> _buildRankingsPayload(
  SolarApi api, {
  required int seasonId,
  required String gradeLevel,
}) async {
  final teamDirectory = await _loadTeamDirectory(api);
  final divisions = await _collectSeasonDivisions(
    api,
    seasonId: seasonId,
    gradeLevel: gradeLevel,
    teamDirectory: teamDirectory,
  );
  final rows = _buildPublishedRows(divisions: divisions);

  return <String, dynamic>{
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'seasonId': seasonId,
    'gradeLevel': gradeLevel,
    'regions': _buildRegions(rows),
    'warning': rows.isEmpty
        ? 'No completed ${gradeLevel.toLowerCase()} standings were available for this season.'
        : null,
    'methodology': <String, dynamic>{
      'id': 'match-field-v2',
      'source': 'solar-localhost',
      'summary':
          'Built from RobotEvents match-derived division standings only. Ratings weight stronger fields and bigger events more heavily, so signature and championship results count more without replaying every single match feed.',
    },
    'matchRows': rows,
  };
}

Future<Map<String, dynamic>?> _readCachedPayload(File file) async {
  for (final candidate in _snapshotCandidatesFor(file)) {
    try {
      if (!await candidate.exists()) {
        continue;
      }

      final raw = await candidate.readAsString();
      final decoded = jsonDecode(raw);
      final payload = decoded is Map<String, dynamic>
          ? decoded
          : decoded is Map
          ? decoded.cast<String, dynamic>()
          : null;

      if (payload == null || payload['matchRows'] is! List) {
        continue;
      }

      return payload;
    } catch (error) {
      stderr.writeln(
        'Skipping unreadable rankings cache at ${candidate.path}: $error',
      );
    }
  }

  return null;
}

Future<void> _writeCachedPayload(
  File file,
  Map<String, dynamic> payload,
) async {
  await file.parent.create(recursive: true);
  await file.writeAsString('${jsonEncode(payload)}\n');
}

bool _isPayloadStale(Map<String, dynamic> payload) {
  final generatedAtRaw = payload['generatedAt'];
  if (generatedAtRaw is! String || generatedAtRaw.trim().isEmpty) {
    return true;
  }

  final generatedAt = DateTime.tryParse(generatedAtRaw)?.toUtc();
  if (generatedAt == null) {
    return true;
  }

  return DateTime.now().toUtc().difference(generatedAt) > _cacheTtl;
}

File _cacheFileFor({required int seasonId, required String gradeLevel}) {
  return File(
    '$_cacheDirectoryName${Platform.pathSeparator}$seasonId-${_slugify(gradeLevel)}.json',
  );
}

List<File> _snapshotCandidatesFor(File primaryFile) {
  final candidates = <File>[primaryFile];
  final fileName = primaryFile.uri.pathSegments.last;
  final customRankingsDir = Platform.environment['SKYLOFT_RANKINGS_DIR'];

  if (customRankingsDir != null && customRankingsDir.trim().isNotEmpty) {
    candidates.add(
      File('${customRankingsDir.trim()}${Platform.pathSeparator}$fileName'),
    );
  }

  final userProfile = Platform.environment['USERPROFILE'];
  if (userProfile != null && userProfile.trim().isNotEmpty) {
    candidates.add(
      File(
        '$userProfile${Platform.pathSeparator}Documents${Platform.pathSeparator}GitHub${Platform.pathSeparator}skyloft.tech${Platform.pathSeparator}assets${Platform.pathSeparator}data${Platform.pathSeparator}rankings${Platform.pathSeparator}$fileName',
      ),
    );
  }

  return candidates;
}

Future<Map<int, TeamSummary>> _loadTeamDirectory(SolarApi api) {
  return _teamDirectoryFuture ??= () async {
    stdout.writeln('Loading Solar team directory...');
    final teams = await api.robotEvents.searchTeams(
      programIds: solarPrimaryProgramIds,
    );
    final directory = <int, TeamSummary>{};
    for (final team in teams) {
      if (team.id <= 0) {
        continue;
      }
      directory[team.id] = team;
    }
    stdout.writeln('Loaded ${directory.length} teams.');
    return directory;
  }();
}

Future<List<_DivisionSnapshot>> _collectSeasonDivisions(
  SolarApi api, {
  required int seasonId,
  required String gradeLevel,
  required Map<int, TeamSummary> teamDirectory,
}) async {
  final events = await api.robotEvents.fetchEvents(season: seasonId);
  final divisions = <_DivisionSnapshot>[];
  var processed = 0;

  await _mapWithConcurrency<EventSummary>(events, _eventConcurrency, (
    event,
    eventIndex,
  ) async {
    processed += 1;
    if (processed == 1 || processed % 50 == 0 || processed == events.length) {
      stdout.writeln(
        'Processed $processed/${events.length} events for season $seasonId...',
      );
    }

    if (event.divisions.isEmpty) {
      return;
    }

    final eventTier = _classifyEventTier(event);
    await _mapWithConcurrency<DivisionSummary>(
      event.divisions,
      _divisionConcurrency,
      (division, divisionIndex) async {
        final rawRankings = await api.robotEvents.fetchDivisionRankings(
          eventId: event.id,
          divisionId: division.id,
        );

        if (rawRankings.isEmpty) {
          return;
        }

        final entries = <_NormalizedRankingEntry>[];
        for (final rawRanking in rawRankings) {
          final normalized = _normalizeRankingRecord(rawRanking, teamDirectory);
          if (normalized == null || normalized.gradeLevel != gradeLevel) {
            continue;
          }
          entries.add(normalized);
        }

        if (entries.isEmpty) {
          return;
        }

        entries.sort((left, right) {
          final rankCompare = left.rank.compareTo(right.rank);
          if (rankCompare != 0) {
            return rankCompare;
          }
          return left.teamNumber.compareTo(right.teamNumber);
        });

        final pointValues = entries
            .map((entry) => entry.averagePoints)
            .where((value) => value > 0)
            .toList(growable: false);

        divisions.add(
          _DivisionSnapshot(
            eventId: event.id,
            eventName: event.name,
            eventWeight: eventTier.weight,
            eventBucket: eventTier.bucket,
            timestamp:
                _toTimestamp(event.end) ?? _toTimestamp(event.start) ?? 0,
            divisionId: division.id,
            divisionName: division.name,
            entries: entries
                .map(
                  (entry) => entry.copyWith(
                    pointsPct: _normalizeToUnit(
                      entry.averagePoints,
                      pointValues,
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        );
      },
    );
  });

  return divisions;
}

List<Map<String, dynamic>> _buildPublishedRows({
  required List<_DivisionSnapshot> divisions,
}) {
  if (divisions.isEmpty) {
    return const <Map<String, dynamic>>[];
  }

  final teamStates = <int, _TeamRatingState>{};
  final orderedDivisions = List<_DivisionSnapshot>.from(divisions)
    ..sort(_compareDivisionsChronologically);

  _TeamRatingState getState(_NormalizedRankingEntry entry) {
    return teamStates.putIfAbsent(
      entry.teamId,
      () => _TeamRatingState(
        teamId: entry.teamId,
        teamNumber: entry.teamNumber,
        teamName: entry.teamName,
        organization: entry.organization,
        city: entry.city,
        region: entry.region,
        country: entry.country,
        regionLabel: entry.regionLabel,
      ),
    );
  }

  for (final division in orderedDivisions) {
    final size = division.entries.length;
    if (size == 0) {
      continue;
    }

    final sizeWeight = 1 + math.min(0.18, _log2(size + 1) / 10);
    final ratingsAtStart = <int, double>{};

    for (final entry in division.entries) {
      ratingsAtStart[entry.teamId] = getState(entry).rating;
    }

    final divisionAverage = _average(ratingsAtStart.values);

    for (final entry in division.entries) {
      final state = getState(entry);
      final opponentRatings = division.entries
          .where((candidate) => candidate.teamId != entry.teamId)
          .map(
            (candidate) => ratingsAtStart[candidate.teamId] ?? divisionAverage,
          );
      final opponentFieldRating = _average(opponentRatings);

      final winPct = entry.matchesPlayed > 0
          ? (entry.wins + entry.ties * 0.5) / entry.matchesPlayed
          : 0.5;
      final rankPct = size <= 1
          ? 1.0
          : 1 - ((math.max(entry.rank, 1) - 1) / (size - 1));
      final performance =
          winPct * 0.58 + rankPct * 0.27 + entry.pointsPct * 0.15;
      final expected = _expectedOutcome(state.rating, opponentFieldRating);
      final activityWeight =
          1 + math.min(0.14, _log2(entry.matchesPlayed + 1) / 12);
      final delta =
          _fieldKFactor *
          division.eventWeight *
          sizeWeight *
          activityWeight *
          (performance - expected);

      state.rating += delta;
      state.matchesPlayed += entry.matchesPlayed;
      state.wins += entry.wins;
      state.losses += entry.losses;
      state.ties += entry.ties;
      state.eventIds.add(division.eventId);
      state.averagePointsWeighted += entry.averagePoints * entry.matchesPlayed;
      state.fieldSamples.add(
        _FieldSample(
          fieldRating: opponentFieldRating,
          weight: division.eventWeight * sizeWeight,
        ),
      );

      switch (division.eventBucket) {
        case 'signature':
          state.signatureEvents.add(division.eventId);
          break;
        case 'championship':
          state.championshipEvents.add(division.eventId);
          break;
        default:
          state.localEvents.add(division.eventId);
          break;
      }
    }
  }

  final rows =
      teamStates.values
          .where((state) => state.matchesPlayed > 0)
          .map(_toPublishedRow)
          .toList(growable: false)
        ..sort((left, right) {
          final ratingCompare = (right['matchRating'] as double).compareTo(
            left['matchRating'] as double,
          );
          if (ratingCompare != 0) {
            return ratingCompare;
          }

          final strengthCompare = (right['scheduleStrength'] as double)
              .compareTo(left['scheduleStrength'] as double);
          if (strengthCompare != 0) {
            return strengthCompare;
          }

          final winPctCompare = (right['winPct'] as double).compareTo(
            left['winPct'] as double,
          );
          if (winPctCompare != 0) {
            return winPctCompare;
          }

          final avgPointsCompare = (right['averagePoints'] as double).compareTo(
            left['averagePoints'] as double,
          );
          if (avgPointsCompare != 0) {
            return avgPointsCompare;
          }

          return (left['teamNumber'] as String).compareTo(
            right['teamNumber'] as String,
          );
        });

  return List<Map<String, dynamic>>.generate(rows.length, (index) {
    return <String, dynamic>{...rows[index], 'rank': index + 1};
  }, growable: false);
}

Map<String, dynamic> _toPublishedRow(_TeamRatingState state) {
  final scheduleStrength = _computeFieldStrength(state.fieldSamples);
  final averagePoints = state.matchesPlayed > 0
      ? state.averagePointsWeighted / state.matchesPlayed
      : 0.0;
  final winPct = state.matchesPlayed > 0
      ? (state.wins + state.ties * 0.5) / state.matchesPlayed
      : 0.0;
  final sampleSize = state.matchesPlayed + state.eventIds.length * 2;
  final confidence = math.min(1.0, math.sqrt(sampleSize / 26));
  final stabilizedRating =
      _initialRating + (state.rating - _initialRating) * confidence;

  return <String, dynamic>{
    'rank': 0,
    'teamId': state.teamId,
    'teamNumber': state.teamNumber,
    'teamName': state.teamName,
    'organization': state.organization,
    'city': state.city,
    'region': state.region,
    'country': state.country,
    'regionLabel': state.regionLabel,
    'matchRating': _roundTo(stabilizedRating, 1),
    'rawMatchRating': _roundTo(state.rating, 1),
    'scheduleStrength': _roundTo(scheduleStrength, 1),
    'matchesPlayed': state.matchesPlayed,
    'wins': state.wins,
    'losses': state.losses,
    'ties': state.ties,
    'winPct': _roundTo(winPct * 100, 1),
    'averagePoints': _roundTo(averagePoints, 1),
    'signatureEvents': state.signatureEvents.length,
    'championshipEvents': state.championshipEvents.length,
    'localEvents': state.localEvents.length,
    'confidence': _roundTo(confidence * 100, 1),
    'meta': _buildMetaLabel(
      state: state,
      scheduleStrength: scheduleStrength,
      averagePoints: averagePoints,
      confidence: confidence,
    ),
  };
}

String _buildMetaLabel({
  required _TeamRatingState state,
  required double scheduleStrength,
  required double averagePoints,
  required double confidence,
}) {
  final record = '${state.wins}-${state.losses}-${state.ties}';
  final parts = <String>[
    record,
    'Field ${_formatSigned(scheduleStrength)}',
    'Avg ${_roundTo(averagePoints, 1).toStringAsFixed(1)}',
  ];

  if (state.signatureEvents.isNotEmpty) {
    parts.add('${state.signatureEvents.length} sig');
  } else if (state.championshipEvents.isNotEmpty) {
    parts.add('${state.championshipEvents.length} champ');
  } else {
    parts.add('${state.localEvents.length} local');
  }

  if (confidence < 0.68) {
    parts.add('small sample');
  }

  return parts.join(' | ');
}

double _computeFieldStrength(List<_FieldSample> samples) {
  if (samples.isEmpty) {
    return 0;
  }

  final totalWeight = samples.fold<double>(
    0,
    (sum, sample) => sum + sample.weight,
  );
  if (totalWeight <= 0) {
    return 0;
  }

  final weighted =
      samples.fold<double>(
        0,
        (sum, sample) => sum + sample.fieldRating * sample.weight,
      ) /
      totalWeight;

  return weighted - _initialRating;
}

_NormalizedRankingEntry? _normalizeRankingRecord(
  RankingRecord rawRanking,
  Map<int, TeamSummary> teamDirectory,
) {
  final teamId = rawRanking.team.id;
  final team = teamDirectory[teamId];
  final gradeLevel = _normalizeGrade(team?.grade ?? '');

  if (team == null || gradeLevel == null) {
    return null;
  }

  final wins = math.max(0, rawRanking.wins);
  final losses = math.max(0, rawRanking.losses);
  final ties = math.max(0, rawRanking.ties);
  final matchesPlayed = wins + losses + ties;

  if (matchesPlayed <= 0) {
    return null;
  }

  return _NormalizedRankingEntry(
    teamId: teamId,
    teamNumber: team.number.isNotEmpty ? team.number : rawRanking.team.number,
    teamName: team.teamName.isNotEmpty ? team.teamName : rawRanking.team.name,
    organization: team.organization,
    city: team.location.city,
    region: team.location.region,
    country: team.location.country,
    regionLabel: _buildRegionLabel(team),
    gradeLevel: gradeLevel,
    rank: math.max(1, rawRanking.rank <= 0 ? 9999 : rawRanking.rank),
    wins: wins,
    losses: losses,
    ties: ties,
    matchesPlayed: matchesPlayed,
    averagePoints: rawRanking.averagePoints < 0 ? 0 : rawRanking.averagePoints,
    pointsPct: 0.5,
  );
}

List<String> _buildRegions(List<Map<String, dynamic>> rows) {
  final unique = <String>{'All Regions'};
  for (final row in rows) {
    final regionLabel = row['regionLabel'] as String? ?? '';
    if (regionLabel.isNotEmpty) {
      unique.add(regionLabel);
    }
  }

  final regions = unique.toList(growable: false);
  regions.sort((left, right) {
    if (left == 'All Regions') {
      return -1;
    }
    if (right == 'All Regions') {
      return 1;
    }
    return left.compareTo(right);
  });
  return regions;
}

_EventTier _classifyEventTier(EventSummary event) {
  final haystack = _normalizeText('${event.name} ${event.sku}');

  if (haystack.contains('world championship')) {
    return const _EventTier(
      label: 'World Championship',
      bucket: 'championship',
      weight: 2.2,
    );
  }

  if (haystack.contains('signature')) {
    return const _EventTier(
      label: 'Signature',
      bucket: 'signature',
      weight: 1.85,
    );
  }

  if (haystack.contains('national championship')) {
    return const _EventTier(
      label: 'National Championship',
      bucket: 'championship',
      weight: 1.7,
    );
  }

  if (haystack.contains('state championship') ||
      haystack.contains('regional championship') ||
      haystack.contains('region championship') ||
      haystack.contains('provincial championship')) {
    return const _EventTier(
      label: 'Regional Championship',
      bucket: 'championship',
      weight: 1.5,
    );
  }

  if (haystack.contains('championship')) {
    return const _EventTier(
      label: 'Championship',
      bucket: 'championship',
      weight: 1.38,
    );
  }

  if (haystack.contains('league')) {
    return const _EventTier(label: 'League', bucket: 'local', weight: 0.96);
  }

  return const _EventTier(label: 'Local', bucket: 'local', weight: 1.0);
}

int _compareDivisionsChronologically(
  _DivisionSnapshot left,
  _DivisionSnapshot right,
) {
  if (left.timestamp != right.timestamp) {
    return left.timestamp.compareTo(right.timestamp);
  }
  if (left.eventId != right.eventId) {
    return left.eventId.compareTo(right.eventId);
  }
  return left.divisionId.compareTo(right.divisionId);
}

String _buildRegionLabel(TeamSummary team) {
  final region = team.location.region.trim();
  final country = team.location.country.trim();

  if (region.isNotEmpty && country.isNotEmpty) {
    if (country == 'United States' ||
        country == 'Canada' ||
        country == 'Mexico') {
      return region;
    }
    return country;
  }

  return region.isNotEmpty
      ? region
      : country.isNotEmpty
      ? country
      : 'Unknown Region';
}

String? _normalizeGrade(String value) {
  final normalized = _normalizeText(value);
  if (normalized.isEmpty) {
    return null;
  }

  if (normalized.contains('college') || normalized.contains('university')) {
    return 'College';
  }
  if (normalized.contains('middle')) {
    return 'Middle School';
  }
  if (normalized.contains('high') || normalized.contains('secondary')) {
    return 'High School';
  }
  return null;
}

double _expectedOutcome(double firstRating, double secondRating) {
  return 1 / (1 + math.pow(10, (secondRating - firstRating) / 400));
}

double _normalizeToUnit(double value, List<double> population) {
  if (population.isEmpty) {
    return 0.5;
  }

  final minValue = population.reduce(math.min);
  final maxValue = population.reduce(math.max);
  if (minValue == maxValue) {
    return 0.5;
  }

  return ((value - minValue) / (maxValue - minValue)).clamp(0.0, 1.0);
}

double _average(Iterable<double> values) {
  final list = values.toList(growable: false);
  if (list.isEmpty) {
    return _initialRating;
  }
  return list.reduce((left, right) => left + right) / list.length;
}

double _roundTo(double value, int digits) {
  final factor = math.pow(10, digits).toDouble();
  return (value * factor).round() / factor;
}

String _formatSigned(double value) {
  final rounded = _roundTo(value, 0).toInt();
  if (rounded > 0) {
    return '+$rounded';
  }
  return '$rounded';
}

double _log2(num value) {
  return math.log(value) / math.ln2;
}

String _normalizeText(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

String _slugify(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

int? _toTimestamp(DateTime? value) {
  return value?.millisecondsSinceEpoch;
}

Future<void> _mapWithConcurrency<T>(
  List<T> items,
  int concurrency,
  Future<void> Function(T item, int index) worker,
) async {
  if (items.isEmpty) {
    return;
  }

  var cursor = 0;

  Future<void> consume() async {
    while (true) {
      final currentIndex = cursor;
      if (currentIndex >= items.length) {
        break;
      }
      cursor += 1;
      await worker(items[currentIndex], currentIndex);
    }
  }

  await Future.wait<void>(
    List<Future<void>>.generate(
      math.min(concurrency, items.length),
      (_) => consume(),
      growable: false,
    ),
  );
}

Future<void> _writeJson(
  HttpResponse response,
  Object value, {
  Duration? maxAge,
}) async {
  _applyApiHeaders(response);
  if (maxAge != null) {
    response.headers.set(
      'Cache-Control',
      'public, max-age=${maxAge.inSeconds}',
    );
  }
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(value));
  await response.close();
}

Future<void> _writeError(
  HttpResponse response,
  int statusCode,
  String message,
) async {
  response.statusCode = statusCode;
  response.headers.set('Cache-Control', 'no-store');
  _applyApiHeaders(response);
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(<String, dynamic>{'error': message}));
  await response.close();
}

void _applyApiHeaders(HttpResponse response) {
  response.headers.set('Access-Control-Allow-Origin', '*');
  response.headers.set('Access-Control-Allow-Methods', 'GET, OPTIONS');
  response.headers.set('Access-Control-Allow-Headers', 'Content-Type');
}

ContentType _contentTypeFor(String path) {
  if (path.endsWith('.woff2')) return ContentType('font', 'woff2');
  if (path.endsWith('.css')) {
    return ContentType('text', 'css', charset: 'utf-8');
  }
  if (path.endsWith('.js')) {
    return ContentType('application', 'javascript', charset: 'utf-8');
  }
  if (path.endsWith('.json')) {
    return ContentType.json;
  }
  if (path.endsWith('.svg')) {
    return ContentType('image', 'svg+xml');
  }
  if (path.endsWith('.png')) {
    return ContentType('image', 'png');
  }
  if (path.endsWith('.jpg') || path.endsWith('.jpeg')) {
    return ContentType('image', 'jpeg');
  }
  return ContentType.html;
}

class _EventTier {
  const _EventTier({
    required this.label,
    required this.bucket,
    required this.weight,
  });

  final String label;
  final String bucket;
  final double weight;
}

class _DivisionSnapshot {
  const _DivisionSnapshot({
    required this.eventId,
    required this.eventName,
    required this.eventWeight,
    required this.eventBucket,
    required this.timestamp,
    required this.divisionId,
    required this.divisionName,
    required this.entries,
  });

  final int eventId;
  final String eventName;
  final double eventWeight;
  final String eventBucket;
  final int timestamp;
  final int divisionId;
  final String divisionName;
  final List<_NormalizedRankingEntry> entries;
}

class _NormalizedRankingEntry {
  const _NormalizedRankingEntry({
    required this.teamId,
    required this.teamNumber,
    required this.teamName,
    required this.organization,
    required this.city,
    required this.region,
    required this.country,
    required this.regionLabel,
    required this.gradeLevel,
    required this.rank,
    required this.wins,
    required this.losses,
    required this.ties,
    required this.matchesPlayed,
    required this.averagePoints,
    required this.pointsPct,
  });

  final int teamId;
  final String teamNumber;
  final String teamName;
  final String organization;
  final String city;
  final String region;
  final String country;
  final String regionLabel;
  final String gradeLevel;
  final int rank;
  final int wins;
  final int losses;
  final int ties;
  final int matchesPlayed;
  final double averagePoints;
  final double pointsPct;

  _NormalizedRankingEntry copyWith({double? pointsPct}) {
    return _NormalizedRankingEntry(
      teamId: teamId,
      teamNumber: teamNumber,
      teamName: teamName,
      organization: organization,
      city: city,
      region: region,
      country: country,
      regionLabel: regionLabel,
      gradeLevel: gradeLevel,
      rank: rank,
      wins: wins,
      losses: losses,
      ties: ties,
      matchesPlayed: matchesPlayed,
      averagePoints: averagePoints,
      pointsPct: pointsPct ?? this.pointsPct,
    );
  }
}

class _TeamRatingState {
  _TeamRatingState({
    required this.teamId,
    required this.teamNumber,
    required this.teamName,
    required this.organization,
    required this.city,
    required this.region,
    required this.country,
    required this.regionLabel,
  });

  final int teamId;
  final String teamNumber;
  final String teamName;
  final String organization;
  final String city;
  final String region;
  final String country;
  final String regionLabel;

  double rating = _initialRating;
  int matchesPlayed = 0;
  int wins = 0;
  int losses = 0;
  int ties = 0;
  final Set<int> eventIds = <int>{};
  final Set<int> signatureEvents = <int>{};
  final Set<int> championshipEvents = <int>{};
  final Set<int> localEvents = <int>{};
  double averagePointsWeighted = 0;
  final List<_FieldSample> fieldSamples = <_FieldSample>[];
}

class _FieldSample {
  const _FieldSample({required this.fieldRating, required this.weight});

  final double fieldRating;
  final double weight;
}
