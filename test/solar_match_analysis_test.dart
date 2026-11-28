import 'package:flutter_test/flutter_test.dart';
import 'package:solar_v6/src/core/solar_match_analysis.dart';
import 'package:solar_v6/src/models/robot_events_models.dart';

MatchSummary match(
  int id,
  int hour,
  int red,
  int blue, {
  int event = 10,
  int minute = 0,
  bool actual = true,
}) => MatchSummary.fromJson({
  'id': id,
  'event': {'id': event},
  'division': {'id': 1},
  'round': 2,
  (actual ? 'started' : 'scheduled'): DateTime.utc(
    2026,
    11,
    8,
    hour,
    minute,
  ).toIso8601String(),
  'alliances': [
    {
      'color': 'red',
      'score': red,
      'teams': [
        {
          'team': {'id': 1},
        },
        {
          'team': {'id': 2},
        },
      ],
    },
    {
      'color': 'blue',
      'score': blue,
      'teams': [
        {
          'team': {'id': 3},
        },
        {
          'team': {'id': 4},
        },
      ],
    },
  ],
});

void main() {
  final now = DateTime.utc(2026, 11, 8, 15);

  test(
    'OpenSkill falls back to previous-season results until teams have new evidence',
    () {
      final season = SolarMatchAnalysis(
        [match(100, 8, 80, 20, event: 9)],
        now: now,
        openSkill: true,
        conservativeOdds: true,
      );
      final first = match(1, 10, 15, 100);
      final next = match(2, 11, 80, 10);
      SolarMatchAnalysis run(
        List<MatchSummary> matches, {
        bool usePrevious = true,
      }) => SolarMatchAnalysis(
        matches,
        now: now,
        openSkill: true,
        conservativeOdds: true,
        previousSeason: usePrevious ? season.ratings : {},
      );
      final seeded = run([first, next]);
      final initial = seeded.rows.first['forecast'] as Map<String, double>;
      final update = seeded.rows.last['forecast'] as Map<String, double>;
      expect(initial['red'], greaterThan(0.5));
      expect(update['red'], lessThan(0.5));
      expect(
        run([first, next], usePrevious: false).rows.first['forecast'],
        isNull,
      );
      expect(
        run([first, next], usePrevious: false).rows.last['forecast'],
        update,
      );
      expect(run([first, match(2, 11, 10, 80)]).rows.last['forecast'], update);
    },
  );

  test(
    'production odds ignore the target score, future and overlapping results',
    () {
      final prior = SolarMatchAnalysis.beforeEvent(
        [match(10, 9, 90, 20, event: 9)],
        eventId: 10,
        cutoff: DateTime.utc(2026, 11, 8, 10),
      );
      const neutral = {'red': 0.5, 'blue': 0.5};
      final first = match(1, 10, 50, 10);
      final unverified = match(2, 10, 99, 1, minute: 1, actual: false);
      final overlapping = match(3, 10, 90, 0, minute: 9);
      final target = match(4, 10, 20, 100, minute: 10);
      final changed = match(4, 10, 100, 20, minute: 10);
      final later = match(5, 11, 99, 1);

      Map<String, Object?> forecast(
        List<MatchSummary> matches,
        int id, {
        SolarMatchAnalysis? seed,
      }) => SolarMatchAnalysis(
        matches,
        now: now,
        prior: seed,
        conservativeOdds: true,
      ).rows.firstWhere((row) => row['id'] == id);

      expect(
        forecast([unverified, overlapping, target], 4)['forecast'],
        neutral,
      );
      final expected = forecast([first, target], 4, seed: prior)['forecast'];
      expect(expected, isNot(neutral));
      expect(
        forecast(
          [later, changed, overlapping, unverified, first],
          4,
          seed: prior,
        )['forecast'],
        expected,
      );
    },
  );

  test('event forecasts learn from earlier rounds and temper extremes', () {
    final first = match(1, 1, 80, 10);
    final next = match(2, 2, 10, 90);
    final games = [
      first,
      for (var hour = 2; hour < 12; hour++) match(hour, hour, 80, 10),
      match(12, 12, 10, 90),
    ];
    final analysis = SolarMatchAnalysis(
      games,
      now: now,
      conservativeOdds: true,
    );
    expect(analysis.rows.first['forecast'], {'red': 0.5, 'blue': 0.5});
    final early = analysis.rows[1]['forecast'] as Map<String, double>;
    final late = analysis.rows.last['forecast'] as Map<String, double>;
    expect(early['red'], greaterThan(0.5));
    expect(late['red'], greaterThan(early['red']!));
    expect(late['red'], lessThan(0.85));
    final replay = SolarMatchAnalysis(
      [first, next],
      now: now,
      conservativeOdds: true,
    );
    expect(replay.rows.last['forecast'], early);
  });

  test('event odds start at 50–50 and use only previous event results', () {
    final target = match(1, 14, 10, 90);
    final sameEvent = match(2, 10, 10, 90);
    final laterEvent = match(3, 16, 10, 90, event: 11);
    final neutral = SolarMatchAnalysis.beforeEvent(
      [sameEvent, laterEvent],
      eventId: 10,
      cutoff: now,
    );
    expect(neutral.forecastMatch(target), {'red': 0.5, 'blue': 0.5});

    final prior = match(4, 9, 80, 40, event: 9);
    final history = SolarMatchAnalysis.beforeEvent(
      [prior, sameEvent, laterEvent],
      eventId: 10,
      cutoff: now,
    );
    final estimate = history.forecastMatch(target)!;
    expect(estimate['red'], greaterThan(0.5));
    expect(estimate['red']! + estimate['blue']!, 1);
    expect(history.ratings[1]!.matches, 1);
  });

  test('forecasts depend on earlier results, never on the target score', () {
    final win = match(1, 10, 70, 40);
    final first = SolarMatchAnalysis([match(2, 11, 80, 50), win], now: now);
    final second = SolarMatchAnalysis([win, match(2, 11, 40, 70)], now: now);

    expect(first.rows.first['forecast'], isNull);
    expect(first.rows.last['forecast'], second.rows.last['forecast']);
    final odds = first.rows.last['forecast'] as Map<String, Object>;
    final red = odds['red'] as double;
    final blue = odds['blue'] as double;
    final draw = odds['draw'] as double;
    expect(red, greaterThan(blue));
    expect(red + blue + draw, closeTo(1, 1e-9));
    expect(odds['minPriorMatches'], 1);
    expect(first.ratings[1]!.wins, 2);
    expect(second.ratings[1]!.losses, 1);
  });

  test('simultaneous, duplicate, unplayed and future matches cannot leak', () {
    final draw = match(1, 10, 40, 40);
    final analysis = SolarMatchAnalysis([
      draw,
      draw,
      match(2, 10, 0, 0),
      match(3, 16, 80, 30),
    ], now: now);
    expect(analysis.rows.length, 3);
    expect(analysis.rows[1]['forecast'], isNull);
    expect(analysis.rows[1]['completed'], false);
    expect(analysis.rows.last['completed'], false);
    expect(analysis.ratings[1]!.draws, 1);
    expect(analysis.ratings[1]!.matches, 1);
    expect(analysis.ratings[1]!.mean, closeTo(25, 1e-9));
    expect(analysis.ratings[1]!.variance, lessThan(625 / 9));
  });
}
