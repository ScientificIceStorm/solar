import 'dart:math' as math;

import '../models/robot_events_models.dart';

/// Season-long, score-based win probabilities.
///
/// Like OpenScout's rating it counts how much teams score and concede against
/// who they played all season, but it rates attack and defence separately and
/// keeps an uncertainty per team. An alliance's expected score is the league
/// average plus its teams' attack minus the opponents' defence; after each
/// scored match the ratings move by a Kalman update, so teams with little
/// history learn fast and well-known teams stay steady. Uncertainty grows
/// with time away, because robots change over a season.
///
/// Predictions never peek: each match is forecast only from results that were
/// in before it started (a score is counted three minutes after its start).
///
/// Leak-free backtest on the Override season (17,650 scored matches from 286
/// events; tuned on the earliest 60% by date, judged on the latest 40%,
/// 6,595 decided matches):
///
/// | model                            | winner | Brier | log-loss |
/// |----------------------------------|--------|-------|----------|
/// | win/loss rating (previous Solar) | 65.3%  | 0.213 | 0.613    |
/// | this event's OPR only            | 68.1%  | 0.200 | 0.582    |
/// | margin rating (OpenScout-style)  | 69.4%  | 0.195 | 0.571    |
/// | attack + defence (this)          | 70.1%  | 0.191 | 0.561    |
///
/// Calibrated: 90%+ calls won 94%, 80–90% won 85%, 70–80% won 74%.
class SolarSeasonForecast {
  SolarSeasonForecast._();

  /// Spread of one alliance's score around its expectation (points).
  static const noise = 30.0;

  /// Uncertainty (variance, points²) of a team nobody has seen yet.
  static const priorVariance = 400.0;

  /// Variance added per day a team is away (robots change between events).
  static const driftPerDay = 16.0;

  /// Defence's share of the attack variance.
  static const defenceShare = .25;

  /// Extra margin spread (points) in the win probability.
  static const scale = 40.0;

  /// Largest score surprise (in standard deviations) a single match counts.
  static const clip = 1.5;

  static const _resultDelay = Duration(minutes: 3);

  /// Match id -> {'red': p, 'blue': 1 - p} for each of [matches], learning
  /// from [history] and the event's own results in time order. A match whose
  /// teams have no scored history yet is left out.
  static Map<int, Map<String, double>> forMatches(
    Iterable<MatchSummary> history,
    Iterable<MatchSummary> matches,
  ) {
    final state = _Ratings();
    final targets = matches.toList()..sort(_byTime);
    final targetKeys = {
      for (final match in targets) (match.event.id, match.division.id, match.id),
    };
    final learning = <MatchSummary>[
      for (final match in history)
        if (_time(match) != null &&
            !targetKeys.contains(
              (match.event.id, match.division.id, match.id),
            ))
          match,
      for (final match in targets)
        if (_time(match) != null) match,
    ]..sort(_byTime);
    final result = <int, Map<String, double>>{};
    var next = 0;
    for (final match in targets) {
      final start = _time(match);
      if (start == null) continue;
      while (next < learning.length &&
          !_time(learning[next])!.add(_resultDelay).isAfter(start)) {
        state.learn(learning[next++]);
      }
      final p = state.predict(match);
      if (p != null) result[match.id] = {'red': p, 'blue': 1 - p};
    }
    return result;
  }

  static DateTime? _time(MatchSummary match) =>
      match.started ?? match.scheduled;

  static int _byTime(MatchSummary a, MatchSummary b) {
    final ta = _time(a), tb = _time(b);
    if (ta != null && tb != null && ta != tb) return ta.compareTo(tb);
    if (ta == null && tb != null) return 1;
    if (ta != null && tb == null) return -1;
    return a.id.compareTo(b.id);
  }
}

typedef _Sides = ({List<int> red, List<int> blue, int redScore, int blueScore});

class _Ratings {
  static const _noise2 =
      SolarSeasonForecast.noise * SolarSeasonForecast.noise;
  static const _prior = SolarSeasonForecast.priorVariance;
  static const _defencePrior =
      SolarSeasonForecast.priorVariance * SolarSeasonForecast.defenceShare;

  final attack = <int, double>{};
  final defence = <int, double>{};
  final attackVariance = <int, double>{};
  final defenceVariance = <int, double>{};
  final lastSeen = <int, DateTime>{};
  final seen = <(int, int, int)>{};
  double average = 60;
  int scores = 0;

  static _Sides? sides(MatchSummary match) {
    MatchAlliance? side(String color) => match.alliances
        .where((alliance) => alliance.color.toLowerCase() == color)
        .firstOrNull;
    final red = side('red'), blue = side('blue');
    if (red == null || blue == null) return null;
    final redIds = [for (final team in red.teams) if (team.id > 0) team.id];
    final blueIds = [for (final team in blue.teams) if (team.id > 0) team.id];
    if (redIds.isEmpty || blueIds.isEmpty) return null;
    return (
      red: redIds,
      blue: blueIds,
      redScore: red.score,
      blueScore: blue.score,
    );
  }

  (double, double) expect(List<int> side, List<int> other) {
    var mean = average, variance = 0.0;
    for (final team in side) {
      mean += attack[team] ?? 0;
      variance += attackVariance[team] ?? _prior;
    }
    for (final team in other) {
      mean -= defence[team] ?? 0;
      variance += defenceVariance[team] ?? _defencePrior;
    }
    return (mean, variance);
  }

  double? predict(MatchSummary match) {
    final s = sides(match);
    if (s == null) return null;
    if (![...s.red, ...s.blue].any(lastSeen.containsKey)) return null;
    final (red, redVariance) = expect(s.red, s.blue);
    final (blue, blueVariance) = expect(s.blue, s.red);
    const scale2 = SolarSeasonForecast.scale * SolarSeasonForecast.scale;
    return _normalCdf(
      (red - blue) / math.sqrt(scale2 + redVariance + blueVariance),
    );
  }

  void _age(int team, DateTime time) {
    final last = lastSeen[team];
    if (last != null) {
      final days = math.max(0, time.difference(last).inSeconds / 86400);
      const drift = SolarSeasonForecast.driftPerDay;
      attackVariance[team] = math.min(
        _prior,
        (attackVariance[team] ?? _prior) + drift * days,
      );
      defenceVariance[team] = math.min(
        _defencePrior,
        (defenceVariance[team] ?? _defencePrior) +
            drift * SolarSeasonForecast.defenceShare * days,
      );
    }
    lastSeen[team] = time;
  }

  void learn(MatchSummary match) {
    if (match.round == MatchRound.practice || match.round == MatchRound.none) {
      return;
    }
    // The same match can come from the season index and a team's history.
    if (!seen.add((match.event.id, match.division.id, match.id))) return;
    final s = sides(match);
    final time = SolarSeasonForecast._time(match);
    if (s == null || time == null) return;
    if (s.redScore < 0 || s.blueScore < 0 || s.redScore + s.blueScore == 0) {
      return;
    }
    for (final team in [...s.red, ...s.blue]) {
      _age(team, time);
    }
    for (final (side, other, score) in [
      (s.red, s.blue, s.redScore),
      (s.blue, s.red, s.blueScore),
    ]) {
      final (mean, variance) = expect(side, other);
      final denominator = variance + _noise2;
      final limit = SolarSeasonForecast.clip * math.sqrt(denominator);
      final error = (score - mean).clamp(-limit, limit);
      for (final team in side) {
        final v = attackVariance[team] ?? _prior;
        final gain = v / denominator;
        attack[team] = (attack[team] ?? 0) + gain * error;
        attackVariance[team] = v * (1 - gain);
      }
      for (final team in other) {
        final v = defenceVariance[team] ?? _defencePrior;
        final gain = v / denominator;
        defence[team] = (defence[team] ?? 0) - gain * error;
        defenceVariance[team] = v * (1 - gain);
      }
    }
    scores += 2;
    average +=
        ((s.redScore + s.blueScore) / 2 - average) * math.max(.002, 1 / scores);
  }

  /// Standard normal CDF (Abramowitz–Stegun 26.2.17, error < 1e-7).
  static double _normalCdf(double x) {
    final t = 1 / (1 + 0.2316419 * x.abs());
    final poly =
        t *
        (0.319381530 +
            t *
                (-0.356563782 +
                    t * (1.781477937 + t * (-1.821255978 + t * 1.330274429))));
    final tail = math.exp(-x * x / 2) / math.sqrt(2 * math.pi) * poly;
    return x < 0 ? tail : 1 - tail;
  }
}
