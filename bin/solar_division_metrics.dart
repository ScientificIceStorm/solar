import 'package:solar_v6/solar_v6.dart';

/// Fits separate alliance score and opponent score models for qualifications.
Map<int, Map<String, double>> solarDivisionMetrics(
  Iterable<MatchSummary> matches,
) {
  final observations = <(List<int>, int, int)>[];
  for (final match in matches) {
    if (match.round != MatchRound.qualification ||
        !(match.started ?? match.scheduled ?? DateTime.utc(9999)).isBefore(
          DateTime.now(),
        )) {
      continue;
    }
    final red = match.alliances
        .where((side) => side.color.toLowerCase() == 'red')
        .firstOrNull;
    final blue = match.alliances
        .where((side) => side.color.toLowerCase() == 'blue')
        .firstOrNull;
    if (red == null ||
        blue == null ||
        red.score < 0 ||
        blue.score < 0 ||
        (red.score == 0 && blue.score == 0)) {
      continue;
    }
    final redIds = red.teams
        .map((team) => team.id)
        .where((id) => id > 0)
        .toSet();
    final blueIds = blue.teams
        .map((team) => team.id)
        .where((id) => id > 0)
        .toSet();
    if (redIds.isEmpty ||
        redIds.length != blueIds.length ||
        redIds.intersection(blueIds).isNotEmpty) {
      continue;
    }
    observations.add((redIds.toList(), red.score, blue.score));
    observations.add((blueIds.toList(), blue.score, red.score));
  }
  final teams = observations.expand((row) => row.$1).toSet().toList();
  final n = teams.length;
  final indexes = {for (var i = 0; i < n; i++) teams[i]: i};
  final matrix = List.generate(
    n,
    (i) => List<double>.filled(n + 2, 0)..[i] = 0.1,
  );
  for (final (alliance, scored, conceded) in observations) {
    final indices = alliance.map((id) => indexes[id]!).toList();
    for (final i in indices) {
      for (final j in indices) {
        matrix[i][j]++;
      }
      matrix[i][n] += scored;
      matrix[i][n + 1] += conceded;
    }
  }
  // Ridge regularization keeps the solution stable for teams with fixed partners.
  for (var i = 0; i < n; i++) {
    final pivot = matrix[i][i];
    for (var j = i + 1; j < n; j++) {
      final factor = matrix[j][i] / pivot;
      if (factor == 0) continue;
      for (var k = i + 1; k < n + 2; k++) {
        matrix[j][k] -= factor * matrix[i][k];
      }
    }
  }
  for (var i = n - 1; i >= 0; i--) {
    for (var j = i + 1; j < n; j++) {
      matrix[i][n] -= matrix[i][j] * matrix[j][n];
      matrix[i][n + 1] -= matrix[i][j] * matrix[j][n + 1];
    }
    matrix[i][n] /= matrix[i][i];
    matrix[i][n + 1] /= matrix[i][i];
  }
  return {
    for (var i = 0; i < n; i++)
      teams[i]: {
        'opr': matrix[i][n],
        'dpr': matrix[i][n + 1],
        'ccwm': matrix[i][n] - matrix[i][n + 1],
      },
  };
}
