import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:args/args.dart';
import 'package:solar_v6/solar_v6.dart';
import 'package:solar_v6/src/core/solar_competition_scope.dart';

const _defaultPort = 8787;
const _siteDirectoryName = 'site';
const _cacheDirectoryName = '.solar_rankings_cache';
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
  final api = await SolarApi.fromLocalConfig();
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
  stdout.writeln('Solar rankings site running at http://$host:$port');

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
    if (path == '/api/health') {
      return _writeJson(request.response, <String, dynamic>{
        'ok': true,
        'config': api.config.toSafeJson(),
      });
    }

    if (path == '/api/seasons') {
      final seasons = await api.robotEvents.fetchSeasons(
        programId: solarPrimaryProgramId,
      );
      seasons.sort((left, right) {
        return compareSolarSeasonPriority(
          leftName: left.name,
          leftId: left.id,
          rightName: right.name,
          rightId: right.id,
        );
      });

      return _writeJson(request.response, <String, dynamic>{
        'program': solarPrimaryProgramFilter,
        'gradeLevels': _gradeLevels,
        'seasons': seasons
            .map(
              (season) => <String, dynamic>{
                'id': season.id,
                'name': season.name,
                'programName': season.programName,
              },
            )
            .toList(growable: false),
      });
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

    final assetPath = path == '/' ? '/index.html' : path;
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
      '$error',
    );
  }
}

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
    '${Directory.current.path}${Platform.pathSeparator}$_cacheDirectoryName${Platform.pathSeparator}$seasonId-${_slugify(gradeLevel)}.json',
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

Future<void> _writeJson(HttpResponse response, Object value) async {
  _applyApiHeaders(response);
  response.headers.contentType = ContentType.json;
  response.write(const JsonEncoder.withIndent('  ').convert(value));
  await response.close();
}

Future<void> _writeError(
  HttpResponse response,
  int statusCode,
  String message,
) async {
  response.statusCode = statusCode;
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
