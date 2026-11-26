part of 'solar_rankings_site.dart';

bool _scanningWebcastArchive = false;

Future<void> _warmCurrentRatings(SolarApi api) async {
  try {
    final seasons = await _siteSeasons(api);
    final current = seasons.reduce((a, b) => a.id > b.id ? a : b);
    await _openSkillLeaderboard(api, current.id, 'All');
  } on Exception {
    // The first leaderboard visit can still start the index.
  }
}

Future<void> _scanWebcastArchive(SolarApi api) async {
  if (_scanningWebcastArchive) return;
  _scanningWebcastArchive = true;
  try {
    final seasons = await _siteSeasons(api);
    for (final season in seasons.reversed) {
      try {
        await _calendar(api, season.id).then((events) async {
          while (_webcastJobs.isNotEmpty) {
            await Future.wait(_webcastJobs.values.toList());
          }
          await _seasonWebcasts(season.id, events);
          await _webcastJobs[season.id];
        });
      } on Exception catch (error) {
        stderr.writeln(
          'Webcast scan skipped season ${season.id}: ${error.runtimeType}',
        );
      }
    }
  } on Exception catch (error) {
    stderr.writeln('Webcast archive unavailable: ${error.runtimeType}');
  } finally {
    _scanningWebcastArchive = false;
  }
}

Future<List<EventSummary>> _calendar(SolarApi api, int season) async {
  final data = await _siteSnapshot(
    'calendar-map-v1-$season',
    const Duration(minutes: 15),
    () async {
      final events = await api.robotEvents.fetchEvents(season: season);
      events.sort(
        (a, b) => (a.start?.millisecondsSinceEpoch ?? 0).compareTo(
          b.start?.millisecondsSinceEpoch ?? 0,
        ),
      );
      return {'events': events.map((event) => event.toJson()).toList()};
    },
  );
  return (data['events'] as List)
      .cast<Map<String, dynamic>>()
      .map(EventSummary.fromJson)
      .toList();
}

Future<Map<String, List<String>>> _seasonWebcasts(
  int season,
  List<EventSummary> events,
) async {
  final results = _webcastResults.putIfAbsent(season, () => {});
  final catalog = await solarWebcastCatalog();
  for (final event in events) {
    final links = {
      ...?catalog[event.sku],
      if (event.livestreamLink.isNotEmpty) event.livestreamLink,
    };
    if (links.isNotEmpty) {
      results[event.sku] = {...?results[event.sku], ...links}.toList();
    }
  }
  if (_webcastRefresh[season]?.isAfter(DateTime.now()) != true &&
      _webcastJobs.isEmpty) {
    _webcastJobs[season] = Future<void>(() async {
      try {
        final now = DateTime.now();
        final ordered = [...events]
          ..sort(
            (a, b) =>
                (a.start?.difference(now).inSeconds.abs() ?? double.infinity)
                    .compareTo(
                      b.start?.difference(now).inSeconds.abs() ??
                          double.infinity,
                    ),
          );
        for (final event in ordered) {
          if (results.containsKey(event.sku)) continue;
          try {
            final data = await _siteSnapshot(
              'webcast-${event.id}',
              const Duration(hours: 12),
              () async {
                final data = await solarEventInformation(
                  event.sku,
                  fallbacks: false,
                );
                await Future<void>.delayed(const Duration(milliseconds: 500));
                return {'webcasts': data['webcasts']};
              },
            );
            final links = (data['webcasts'] as List)
                .whereType<String>()
                .toList();
            if (links.isNotEmpty) results[event.sku] = links;
          } on Exception {
            // Continue if an organizer page is unavailable.
          }
        }
        _webcastRefresh[season] = DateTime.now().add(const Duration(hours: 12));
      } finally {
        _webcastJobs.remove(season);
      }
    });
  }
  return results;
}

typedef _MatchIndex = Map<(int, int, int), MatchSummary>;
final _seasonDivisionSignals = <int, Map<(int, int), Map<String, dynamic>>>{};
final _seasonAwards = <int, Map<int, List<String>>>{};

Map<int, double> _percentiles(Map<int, double> values) {
  final sorted = values.entries.toList()
    ..sort((a, b) => a.value.compareTo(b.value));
  final result = <int, double>{};
  for (var i = 0; i < sorted.length;) {
    var end = i + 1;
    while (end < sorted.length && sorted[end].value == sorted[i].value) {
      end++;
    }
    final percentile = sorted.length == 1
        ? .5
        : (i + end - 1) / (2 * (sorted.length - 1));
    for (; i < end; i++) {
      result[sorted[i].key] = percentile;
    }
  }
  return result;
}

Map<int, Map<String, Object>> _combinedRatings(
  int season,
  Map<int, double> base,
  Map<int, double> openSkill,
  Map<Object?, Map<String, dynamic>> skills,
  Map<int, String> numbers,
  Map<int, Set<int>> eventCoverage,
) {
  final teamwork = <int, List<double>>{};
  final programming = <int, List<double>>{};
  final appearances = <int, Set<int>>{};
  for (final entry in (_seasonDivisionSignals[season] ?? {}).entries) {
    final teamValues = <int, double>{};
    final apValues = <int, double>{};
    for (final row in (entry.value['rows'] as List).cast<Map>()) {
      final id = row['id'] as int;
      appearances.putIfAbsent(id, () => {}).add(entry.key.$1);
      if (row['opr'] case final num opr) {
        teamValues[id] = opr - (row['dpr'] as num).toDouble();
      }
      if (row['ap'] case final num ap) apValues[id] = ap.toDouble();
    }
    for (final (source, target) in [
      (teamValues, teamwork),
      (apValues, programming),
    ]) {
      if (source.length < 2) continue;
      for (final value in _percentiles(source).entries) {
        target.putIfAbsent(value.key, () => []).add(value.value);
      }
    }
  }
  double mean(List<double> values) =>
      values.reduce((a, b) => a + b) / values.length;
  final awardCounts = <String, int>{};
  final awards = _seasonAwards[season] ?? {};
  for (final winners in awards.values) {
    for (final number in winners) {
      awardCounts.update(number, (count) => count + 1, ifAbsent: () => 1);
    }
  }
  final signals = {
    'teamwork': _percentiles(
      teamwork.map((id, values) => MapEntry(id, mean(values))),
    ),
    'programming': _percentiles({
      for (final id in base.keys)
        if (skills[id]?['programmingScore'] case final num score)
          if (score > 0) id: score.toDouble(),
    }),
    'autonomous': _percentiles(
      programming.map((id, values) => MapEntry(id, mean(values))),
    ),
    'driving': _percentiles({
      for (final id in base.keys)
        if (skills[id]?['driverScore'] case final num score)
          if (score > 0) id: score.toDouble(),
    }),
    'skills': _percentiles({
      for (final id in base.keys)
        if (skills[id]?['combinedScore'] case final num score)
          id: score.toDouble(),
    }),
    'awards': _percentiles({
      for (final id in base.keys)
        if (appearances[id]?.any(awards.containsKey) == true)
          id:
              (awardCounts[numbers[id]?.toUpperCase()] ?? 0) /
              appearances[id]!.where(awards.containsKey).length,
    }),
  };
  const weights = {
    'teamwork': .05,
    'programming': .06,
    'autonomous': .03,
    'driving': .06,
    'awards': .03,
  };
  final ranks = <String, Map<int, int>>{};
  for (final key in ['strength', 'openskill', ...signals.keys]) {
    final values = (switch (key) {
      'strength' => base,
      'openskill' => openSkill,
      _ => signals[key]!,
    }).entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    ranks[key] = {};
    for (var i = 0; i < values.length; i++) {
      ranks[key]![values[i].key] =
          i > 0 && values[i].value == values[i - 1].value
          ? ranks[key]![values[i - 1].key]!
          : i + 1;
    }
  }
  final normalized = _percentiles(base);
  double score(int id) {
    final eventCount = eventCoverage[id]?.length ?? 0;
    final baseline = normalized[id]!;
    var adjustment = 0.0;
    for (final weight in weights.entries) {
      final signal = signals[weight.key]![id];
      if (signal == null) continue;
      final samples = switch (weight.key) {
        'teamwork' => teamwork[id]?.length ?? 0,
        'autonomous' => programming[id]?.length ?? 0,
        'awards' => appearances[id]?.where(awards.containsKey).length ?? 0,
        _ => 3,
      };
      adjustment +=
          weight.value * samples / (samples + 2) * (signal - baseline);
    }
    // A single event provides less evidence than repeat performance across fields.
    return 100 *
        (.5 +
            (baseline + adjustment - .5) *
                (.82 + .18 * eventCount / (eventCount + 2)));
  }

  return {
    for (final id in base.keys)
      id: {
        'score': score(id),
        'awardCount': awardCounts[numbers[id]?.toUpperCase()] ?? 0,
        'componentRanks': {
          for (final entry in ranks.entries)
            if (entry.value.containsKey(id)) entry.key: entry.value[id]!,
        },
      },
  };
}

void _rememberMatches(_MatchIndex index, Object? rows) {
  if (rows is! List) return;
  for (final json in rows.whereType<Map<String, dynamic>>()) {
    final match = MatchSummary.fromJson(json);
    index[(match.event.id, match.division.id, match.id)] = match;
  }
}

Future<void> _seedOpenSkillIndex(
  int season,
  Set<int> eventIds,
  _MatchIndex index,
) async {
  for (final cache in [
    if (Platform.environment['SOLAR_SITE_SEED_DIR'] case final String seed)
      Directory(seed),
    Directory('$_cacheDirectoryName/companion'),
  ]) {
    if (!await cache.exists()) continue;
    await for (final file in cache.list()) {
      if (file is! File) continue;
      final name = file.uri.pathSegments.last;
      final divisionEvent = RegExp(
        r'^(?:division-v[3456]|rated-matches)-(\d+)-\d+\.json$',
      ).firstMatch(name);
      final teamHistory =
          name.startsWith('team-matches-') && name.endsWith('-$season.json');
      final signals = RegExp(
        r'^rating-signals-(\d+)-(\d+)\.json$',
      ).firstMatch(name);
      final awards = RegExp(r'^rating-awards-(\d+)\.json$').firstMatch(name);
      final auxiliaryEvent = int.tryParse(signals?[1] ?? awards?[1] ?? '');
      if (!teamHistory &&
          !eventIds.contains(auxiliaryEvent) &&
          (divisionEvent == null ||
              !eventIds.contains(int.tryParse(divisionEvent[1]!)))) {
        continue;
      }
      try {
        final value =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        if (signals != null) {
          _seasonDivisionSignals.putIfAbsent(
            season,
            () => {},
          )[(int.parse(signals[1]!), int.parse(signals[2]!))] = value;
        } else if (awards != null) {
          _seasonAwards.putIfAbsent(season, () => {})[int.parse(awards[1]!)] =
              (value['winners'] as List).whereType<String>().toList();
        } else {
          _rememberMatches(index, value['matches']);
        }
      } on Exception {
        // Invalid snapshots can be rebuilt.
      }
    }
  }
}

Future<void> _refreshOpenSkillIndex(
  SolarApi api,
  int season,
  List<EventSummary> events,
  _MatchIndex index,
) async {
  try {
    final now = DateTime.now();
    final started = events.reversed
        .where((event) => event.start?.isBefore(now) == true)
        .toList();
    await _mapWithConcurrency(started, 1, (event, _) async {
      if (api.isRateLimited) return;
      for (final division in event.divisions) {
        try {
          final data = await _siteSnapshot(
            'rated-matches-${event.id}-${division.id}',
            event.end?.isBefore(now.subtract(const Duration(days: 1))) == true
                ? const Duration(days: 14)
                : const Duration(minutes: 10),
            () async {
              // Leave gaps in the shared VEX queue for interactive requests.
              await Future<void>.delayed(const Duration(seconds: 2));
              if (api.isRateLimited) throw StateError('VEX is cooling down');
              final matches = await api.robotEvents.fetchDivisionMatches(
                eventId: event.id,
                divisionId: division.id,
              );
              return {
                'matches': matches.map((match) => match.toJson()).toList(),
              };
            },
          );
          _rememberMatches(index, data['matches']);
          final matches = (data['matches'] as List)
              .cast<Map<String, dynamic>>()
              .map(MatchSummary.fromJson)
              .toList();
          if (matches.isEmpty) continue;
          final signals = await _siteSnapshot(
            'rating-signals-${event.id}-${division.id}',
            const Duration(hours: 3),
            () async {
              final rankings = await api.robotEvents.fetchDivisionRankings(
                eventId: event.id,
                divisionId: division.id,
              );
              final metrics = solarDivisionMetrics(matches);
              return {
                'rows': [
                  for (final row in rankings)
                    if (row.wins + row.losses + row.ties > 0)
                      {
                        'id': row.team.id,
                        ...?metrics[row.team.id],
                        if (row.ap >= 0)
                          'ap': row.ap / (row.wins + row.losses + row.ties),
                      },
                ],
              };
            },
          );
          _seasonDivisionSignals.putIfAbsent(
            season,
            () => {},
          )[(event.id, division.id)] = signals;
        } on Object {
          // Retain the last posted match results if a division is unavailable.
        }
      }
      if (event.end?.isBefore(now) == true && !api.isRateLimited) {
        try {
          final awards = await _siteSnapshot(
            'rating-awards-${event.id}',
            const Duration(days: 1),
            () async {
              final rows = await api.robotEvents.fetchEventAwards(event.id);
              return {
                'winners': [
                  for (final row in rows)
                    ...row.recipients.map((number) => number.toUpperCase()),
                ],
              };
            },
          );
          _seasonAwards.putIfAbsent(season, () => {})[event.id] =
              (awards['winners'] as List).cast<String>();
        } on Exception {
          // Leave awards unavailable until refreshed.
        }
      }
    });
    _openSkillSeasonRefresh[season] = DateTime.now().add(
      api.isRateLimited
          ? const Duration(minutes: 2)
          : const Duration(minutes: 30),
    );
  } finally {
    _openSkillSeasonJobs.remove(season);
  }
}

Future<Map<String, Object>> _openSkillLeaderboard(
  SolarApi api,
  int season,
  String grade,
) async {
  final events = await _calendar(api, season);
  final index = _openSkillSeasonMatches.putIfAbsent(season, () => {});
  // Up to two seasons index at once, so someone browsing an old season never
  // holds up the current season's refresh (and vice versa).
  bool canStart() =>
      !_openSkillSeasonJobs.containsKey(season) &&
      _openSkillSeasonJobs.length < 2;
  if (_openSkillSeasonRefresh[season]?.isAfter(DateTime.now()) != true &&
      canStart()) {
    if (!_seasonDivisionSignals.containsKey(season)) {
      await _seedOpenSkillIndex(
        season,
        events.map((event) => event.id).toSet(),
        index,
      );
    }
    if (canStart()) {
      _openSkillSeasonJobs[season] = Future<void>(
        () => _refreshOpenSkillIndex(api, season, events, index),
      );
    }
  }
  final grades = grade == 'All' ? _gradeLevels.take(2) : [grade];
  final directory = Future.wait(
    grades.map((level) async {
      try {
        return await _skillsRows(api, season, level);
      } on Exception {
        return <Map<String, dynamic>>[];
      }
    }),
  );
  final lists = await (grade == 'All'
      ? directory.timeout(
          const Duration(milliseconds: 500),
          onTimeout: () => [],
        )
      : directory);
  final metadata = {
    for (final team in lists.expand((list) => list)) team['teamId']: team,
  };
  final numbers = {
    for (final match in index.values)
      for (final alliance in match.alliances)
        for (final team in alliance.teams) team.id: team.number,
  };
  final analysis = SolarMatchAnalysis(
    index.values,
    now: DateTime.now(),
    conservativeOdds: true,
    openSkill: true,
    eventWeights: {
      for (final event in events) event.id: _classifyEventTier(event).weight,
    },
  );
  final eventCoverage = <int, Set<int>>{};
  final points = <int, (int, int, int)>{};
  for (final row in analysis.rows.where((row) => row['completed'] == true)) {
    final match = MatchSummary.fromJson(row);
    final alliances = match.alliances;
    if (alliances.length != 2) continue;
    for (var i = 0; i < 2; i++) {
      final side = alliances[i];
      for (final team in side.teams) {
        if (side.disqualifiedTeamIds.contains(team.id)) continue;
        eventCoverage.putIfAbsent(team.id, () => {}).add(match.event.id);
        final (scored, conceded, count) = points[team.id] ?? (0, 0, 0);
        points[team.id] = (
          scored + side.score,
          conceded + alliances[1 - i].score,
          count + 1,
        );
      }
    }
  }
  final divisionTotals = <int, (double, double, int)>{};
  for (final division in (_seasonDivisionSignals[season] ?? {}).values) {
    for (final row in (division['rows'] as List).whereType<Map>()) {
      final id = row['id'] as int;
      final opr = row['opr'];
      final dpr = row['dpr'];
      if (opr is! num || dpr is! num) continue;
      final (offense, defense, count) = divisionTotals[id] ?? (0.0, 0.0, 0);
      divisionTotals[id] = (offense + opr, defense + dpr, count + 1);
    }
  }
  // Solar ranks by score-based season strength (attack + defence, minus one
  // standard deviation so thin evidence can't top the list); OpenSkill's
  // win/loss rating can't tell a weak local from a strong field.
  final seasonRatings = SolarSeasonForecast.teamRatings(index.values);
  final unseen = -math.sqrt(
    SolarSeasonForecast.priorVariance * (1 + SolarSeasonForecast.defenceShare),
  );
  final combined = _combinedRatings(
    season,
    {
      for (final entry in analysis.ratings.entries)
        if (entry.value.matches > 0)
          entry.key: switch (seasonRatings[entry.key]) {
            final r? => r.attack + r.defence - r.uncertainty,
            null => unseen,
          },
    },
    {
      for (final entry in analysis.ratings.entries)
        if (entry.value.matches > 0) entry.key: entry.value.rating,
    },
    metadata,
    numbers,
    eventCoverage,
  );
  final rows =
      [
        for (final entry in analysis.ratings.entries)
          if (entry.value.matches > 0 &&
              (grade == 'All' || metadata.containsKey(entry.key)))
            {
              'teamNumber': numbers[entry.key],
              ...?metadata[entry.key],
              'skill': entry.value.toJson(),
              if (seasonRatings[entry.key] case final r?) ...{
                'strength': r.attack + r.defence,
                'attack': r.attack,
                'defence': r.defence,
                'strengthUncertainty': r.uncertainty,
              },
              ...?combined[entry.key],
              'eventsPlayed': eventCoverage[entry.key]?.length ?? 0,
              if (points[entry.key] case final p?) ...{
                'averagePoints': p.$1 / p.$3,
                'averageConceded': p.$2 / p.$3,
                'scoredMatches': p.$3,
              },
              if (divisionTotals[entry.key] case final p?) ...{
                'opr': p.$1 / p.$3,
                'dpr': p.$2 / p.$3,
                'ccwm': (p.$1 - p.$2) / p.$3,
              },
            },
      ]..sort((a, b) {
        final comparison = (b['score'] as num).compareTo(a['score'] as num);
        return comparison != 0
            ? comparison
            : '${a['teamNumber']}'.compareTo('${b['teamNumber']}');
      });
  return {
    'rows': [
      for (var i = 0; i < rows.length; i++) {...rows[i], 'rank': i + 1},
    ],
    'updating': _openSkillSeasonJobs.containsKey(season),
  };
}
