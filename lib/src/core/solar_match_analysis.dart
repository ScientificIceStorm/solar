import 'dart:math' as math;
import 'dart:collection';

import '../models/robot_events_models.dart';

class SolarSkillRating {
  double mean = 25;
  double variance = 625 / 9;
  double scoreStrength = 0;
  int wins = 0;
  int losses = 0;
  int draws = 0;

  int get matches => wins + losses + draws;
  double get rating => mean - 3 * math.sqrt(variance);

  Map<String, Object> toJson() => {
    'mean': mean,
    'uncertainty': math.sqrt(variance),
    'rating': rating,
    'wins': wins,
    'losses': losses,
    'draws': draws,
    'matches': matches,
  };
}

/// Two-alliance Gaussian TrueSkill updates. Forecasts use only earlier results
/// in the supplied sample, with draws represented as an interval of performance.
class SolarMatchAnalysis {
  SolarMatchAnalysis(
    Iterable<MatchSummary> matches, {
    required DateTime now,
    SolarMatchAnalysis? prior,
    bool conservativeOdds = false,
    this.openSkill = false,
    this.previousSeason = const {},
    Map<int, double> eventWeights = const {},
  }) {
    for (final entry
        in prior?.ratings.entries ??
            const <MapEntry<int, SolarSkillRating>>[]) {
      final seed = entry.value;
      ratings[entry.key] = SolarSkillRating()
        ..mean = seed.mean
        ..variance = seed.variance
        ..scoreStrength = seed.scoreStrength
        ..wins = seed.wins
        ..losses = seed.losses
        ..draws = seed.draws;
    }
    final ordered = matches.toList()
      ..sort((a, b) {
        final time = (_time(a) ?? _undated).compareTo(_time(b) ?? _undated);
        if (time != 0) return time;
        final event = a.event.id.compareTo(b.event.id);
        if (event != 0) return event;
        final division = a.division.id.compareTo(b.division.id);
        return division != 0 ? division : a.id.compareTo(b.id);
      });
    final seen = <(int, int, int)>{};
    final participants = <int, Set<int>>{};
    final fieldWeights = <int, double>{};
    if (eventWeights.isNotEmpty) {
      for (final match in ordered) {
        final teams = participants.putIfAbsent(match.event.id, () => {});
        teams.addAll(match.alliances.expand((a) => a.teams).map((t) => t.id));
      }
    }
    final updates =
        Queue<
          ({
            DateTime availableAt,
            _Contest contest,
            int red,
            int blue,
            double weight,
          })
        >();
    void learnBefore(DateTime cutoff) {
      while (updates.isNotEmpty && updates.first.availableAt.isBefore(cutoff)) {
        final update = updates.removeFirst();
        _update(update.contest, update.red, update.blue, update.weight);
      }
    }

    for (final match in ordered) {
      if (!seen.add((match.event.id, match.division.id, match.id))) continue;
      final time = _time(match);
      if (time != null) {
        learnBefore(time.isBefore(now) ? time : now);
      }
      final eventId = match.event.id;
      final weight =
          (eventWeights[eventId] ?? 1.0) *
          (eventWeights.isEmpty || time == null
              ? 1.0
              : fieldWeights.putIfAbsent(eventId, () {
                  final teams = participants[eventId]!;
                  var strength = 0.0;
                  for (final id in teams) {
                    final rating = ratings[id];
                    if (rating == null) continue;
                    strength +=
                        (rating.mean - 25) *
                        rating.matches /
                        (rating.matches + 8);
                  }
                  return (1 + strength / (20 * (teams.length + 8)))
                      .clamp(.85, 1.15)
                      .toDouble();
                }));

      final red = match.alliances
          .where((a) => a.color.toLowerCase() == 'red')
          .firstOrNull;
      final blue = match.alliances
          .where((a) => a.color.toLowerCase() == 'blue')
          .firstOrNull;
      final contest = red == null || blue == null ? null : _contest(red, blue);
      final countedRound =
          match.round != MatchRound.practice && match.round != MatchRound.none;
      final completed =
          countedRound &&
          time != null &&
          !time.isAfter(now) &&
          red != null &&
          blue != null &&
          red.score >= 0 &&
          blue.score >= 0 &&
          (red.score != 0 || blue.score != 0);
      final probability = contest == null || !countedRound || time == null
          ? null
          : openSkill
          ? _openSkillForecast(contest)
          : conservativeOdds
          ? _conservativeForecast(contest)
          : _forecast(contest);
      rows.add({
        ...match.toJson(),
        'completed': completed,
        'forecast': probability,
      });
      if (completed &&
          contest != null &&
          (!conservativeOdds || match.started != null)) {
        updates.add((
          availableAt: conservativeOdds ? time.add(_resultDelay) : time,
          contest: contest,
          red: red.score,
          blue: blue.score,
          weight: weight,
        ));
      }
    }
    learnBefore(now.add(const Duration(microseconds: 1)));
  }

  // VEX provides a start time but not the moment the score became available.
  static const _resultDelay = Duration(minutes: 3);
  static final _undated = DateTime.utc(9999);
  static const _beta = 25 / 6;
  // A 10% draw prior for equally rated alliances before observing any results.
  static const _drawQuantile = 0.1256613469;
  final ratings = <int, SolarSkillRating>{};
  final rows = <Map<String, Object?>>[];
  final bool openSkill;
  final Map<int, SolarSkillRating> previousSeason;

  static SolarMatchAnalysis beforeEvent(
    Iterable<MatchSummary> history, {
    required int eventId,
    required DateTime cutoff,
    bool openSkill = false,
  }) => SolarMatchAnalysis(
    history.where((match) {
      final time = match.started;
      return match.event.id > 0 &&
          match.event.id != eventId &&
          time != null &&
          time.add(_resultDelay).isBefore(cutoff);
    }),
    now: cutoff,
    conservativeOdds: true,
    openSkill: openSkill,
  );

  Map<String, double>? _openSkillForecast(_Contest contest) {
    final players = contest.ids.map((id) {
      final current = ratings[id]!;
      final prior = previousSeason[id];
      if (current.matches > 0 || prior == null || prior.matches == 0) {
        return current;
      }
      return SolarSkillRating()
        ..mean = 25 + (prior.mean - 25) * 0.7
        ..variance = math.max(prior.variance, 25)
        ..wins = prior.wins
        ..losses = prior.losses
        ..draws = prior.draws;
    }).toList();
    if (!players.any((rating) => rating.matches > 0)) return null;
    final estimate = _Contest(
      players.take(contest.red.length).toList(),
      players.skip(contest.red.length).toList(),
      contest.ids,
    );
    final red = _cdf(estimate.difference / estimate.openScale);
    return {'red': red, 'blue': 1 - red};
  }

  /// Binary odds for a decided match, using these ratings without training on
  /// the target match. Unrated teams retain the neutral prior.
  Map<String, double>? forecastMatch(MatchSummary match) {
    final red = match.alliances
        .where((a) => a.color.toLowerCase() == 'red')
        .firstOrNull;
    final blue = match.alliances
        .where((a) => a.color.toLowerCase() == 'blue')
        .firstOrNull;
    if (red == null || blue == null) return null;
    final contest = _contest(red, blue);
    if (contest == null) return null;
    return openSkill
        ? _openSkillForecast(contest)
        : _conservativeForecast(contest);
  }

  static Map<String, double> _conservativeForecast(_Contest contest) {
    final evidence =
        contest.players
            .map((team) => math.min(team.matches, 12))
            .reduce((a, b) => a + b) /
        (contest.red.length + contest.blue.length);
    final weight = 0.76 * evidence / (evidence + 2);
    final outcomeOdds = _cdf(contest.difference / contest.scale);
    final scoreOdds = _cdf(contest.scoreDifference / 0.55);
    final raw = 0.6 * outcomeOdds + 0.4 * scoreOdds;
    final red = 0.5 + (raw - 0.5) * weight;
    return {'red': red, 'blue': 1 - red};
  }

  static DateTime? _time(MatchSummary match) =>
      match.started ?? match.scheduled;

  _Contest? _contest(MatchAlliance red, MatchAlliance blue) {
    final redIds = red.teams.map((team) => team.id).toSet();
    final blueIds = blue.teams.map((team) => team.id).toSet();
    if (redIds.isEmpty ||
        redIds.length != blueIds.length ||
        redIds.contains(0) ||
        blueIds.contains(0) ||
        redIds.intersection(blueIds).isNotEmpty) {
      return null;
    }
    return _Contest(
      redIds
          .map((id) => ratings.putIfAbsent(id, SolarSkillRating.new))
          .toList(),
      blueIds
          .map((id) => ratings.putIfAbsent(id, SolarSkillRating.new))
          .toList(),
      [...redIds, ...blueIds],
    );
  }

  static double _pdf(double x) => math.exp(-x * x / 2) / math.sqrt(2 * math.pi);

  static double _cdf(double x) {
    final t = 1 / (1 + 0.2316419 * x.abs());
    final tail =
        _pdf(x) *
        t *
        (0.319381530 +
            t *
                (-0.356563782 +
                    t * (1.781477937 + t * (-1.821255978 + t * 1.330274429))));
    return x < 0 ? tail : 1 - tail;
  }

  Map<String, Object>? _forecast(_Contest contest) {
    final priorMatches = contest.players
        .map((rating) => rating.matches)
        .reduce(math.min);
    if (priorMatches == 0) return null;
    final red = _cdf((contest.difference - contest.margin) / contest.scale);
    final blue = _cdf((-contest.difference - contest.margin) / contest.scale);
    return {
      'red': red,
      'blue': blue,
      'draw': (1 - red - blue).clamp(0.0, 1.0),
      'minPriorMatches': priorMatches,
    };
  }

  void _update(_Contest contest, int redScore, int blueScore, double weight) {
    if (openSkill) {
      _updateOpenSkill(contest, redScore.compareTo(blueScore), weight);
      return;
    }
    final scale = contest.scale;
    final t = contest.difference / scale;
    final margin = contest.margin / scale;
    final result = redScore.compareTo(blueScore);
    final scoreMargin = (redScore - blueScore) / (redScore + blueScore + 40);
    final scoreAdjustment =
        (scoreMargin - contest.scoreDifference) * 0.3 / contest.players.length;
    double v;
    double w;
    if (result == 0) {
      final lower = -margin - t;
      final upper = margin - t;
      final mass = math.max(1e-15, _cdf(upper) - _cdf(lower));
      v = (_pdf(lower) - _pdf(upper)) / mass;
      w = v * v + (upper * _pdf(upper) - lower * _pdf(lower)) / mass;
    } else {
      final edge = (result * t - margin).clamp(-8.0, 8.0);
      final correction = _pdf(edge) / _cdf(edge);
      v = result * correction;
      w = correction * (correction + edge);
    }
    for (final (side, players) in [(1, contest.red), (-1, contest.blue)]) {
      for (final rating in players) {
        rating.scoreStrength += side * scoreAdjustment;
        rating.mean += side * rating.variance / scale * v;
        rating.variance *=
            1 - rating.variance / (scale * scale) * w.clamp(0.0, 1.0);
        if (result == 0) {
          rating.draws++;
        } else if (result == side) {
          rating.wins++;
        } else {
          rating.losses++;
        }
      }
    }
  }

  // Two-alliance specialization of Weng and Lin's Plackett–Luce update.
  void _updateOpenSkill(_Contest contest, int result, double weight) {
    for (final rating in contest.players) {
      rating.variance += math.pow(25 / 300, 2).toDouble();
    }
    final scale = contest.openScale;
    final predicted = 1 / (1 + math.exp(-contest.difference / scale));
    final actual = (result + 1) / 2;
    final sides = [(1, contest.red), (-1, contest.blue)];
    for (final (side, players) in sides) {
      final variance = players.fold(
        0.0,
        (sum, player) => sum + player.variance,
      );
      final gamma = math.sqrt(variance) / scale;
      for (final rating in players) {
        rating.mean +=
            weight * side * rating.variance / scale * (actual - predicted);
        final reduction =
            gamma *
            rating.variance /
            (scale * scale) *
            predicted *
            (1 - predicted);
        rating.variance *= math
            .pow(math.max(0.0001, 1 - reduction), weight)
            .toDouble();
        if (result == 0) {
          rating.draws++;
        } else if (result == side) {
          rating.wins++;
        } else {
          rating.losses++;
        }
      }
    }
  }
}

class _Contest {
  const _Contest(this.red, this.blue, this.ids);

  final List<SolarSkillRating> red;
  final List<SolarSkillRating> blue;
  final List<int> ids;

  Iterable<SolarSkillRating> get players => [...red, ...blue];
  double get difference =>
      red.fold(0.0, (sum, rating) => sum + rating.mean) -
      blue.fold(0.0, (sum, rating) => sum + rating.mean);
  double get scoreDifference =>
      red.fold(0.0, (sum, rating) => sum + rating.scoreStrength) -
      blue.fold(0.0, (sum, rating) => sum + rating.scoreStrength);
  double get margin =>
      SolarMatchAnalysis._drawQuantile *
      SolarMatchAnalysis._beta *
      math.sqrt(red.length + blue.length);
  double get openScale => math.sqrt(
    players.fold(
      2 * SolarMatchAnalysis._beta * SolarMatchAnalysis._beta,
      (sum, rating) => sum + rating.variance,
    ),
  );
  double get scale => math.sqrt(
    players.fold(
      0.0,
      (sum, rating) =>
          sum +
          rating.variance +
          SolarMatchAnalysis._beta * SolarMatchAnalysis._beta,
    ),
  );
}
