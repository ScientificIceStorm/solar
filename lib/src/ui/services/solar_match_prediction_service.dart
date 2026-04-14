import 'dart:math' as math;

import '../../models/open_skill_models.dart';
import '../../models/robot_events_models.dart';
import '../../models/world_skills_models.dart';
import '../models/solar_match_prediction.dart';

class SolarMatchPredictionService {
  const SolarMatchPredictionService();

  SolarMatchPrediction predictMatch({
    required MatchSummary match,
    required EventSummary? event,
    required List<MatchSummary> divisionMatches,
    required Map<int, List<MatchSummary>> seasonMatchesByTeamId,
    required Map<String, OpenSkillCacheEntry> openSkillByTeam,
    required Map<String, WorldSkillsEntry> worldSkillsByTeam,
    required List<SkillAttempt> eventSkills,
  }) {
    final priorDivisionMatches = divisionMatches
        .where((candidate) {
          if (candidate.id == match.id || !_hasOfficialScore(candidate)) {
            return false;
          }
          return _matchOccurredBefore(candidate, match);
        })
        .toList(growable: false);

    final divisionHistory = _buildDivisionHistory(priorDivisionMatches);
    final eventSkillsByTeam = _buildEventSkillsTable(eventSkills);
    final divisionAverageScore = _averageAllianceScore(priorDivisionMatches);

    final redAlliance = _predictAlliance(
      targetMatch: match,
      color: 'red',
      divisionHistory: divisionHistory,
      seasonMatchesByTeamId: seasonMatchesByTeamId,
      openSkillByTeam: openSkillByTeam,
      worldSkillsByTeam: worldSkillsByTeam,
      eventSkillsByTeam: eventSkillsByTeam,
    );
    final blueAlliance = _predictAlliance(
      targetMatch: match,
      color: 'blue',
      divisionHistory: divisionHistory,
      seasonMatchesByTeamId: seasonMatchesByTeamId,
      openSkillByTeam: openSkillByTeam,
      worldSkillsByTeam: worldSkillsByTeam,
      eventSkillsByTeam: eventSkillsByTeam,
    );

    final baselineScore =
        divisionAverageScore ??
        _average(<double>[redAlliance.offense, blueAlliance.offense, 26])!;

    final redProjectedRaw =
        baselineScore +
        ((redAlliance.offense - blueAlliance.defense) * 0.30) +
        (redAlliance.momentum * 0.34) +
        ((redAlliance.strength - blueAlliance.strength) * 0.16) +
        ((redAlliance.awpPotential - blueAlliance.awpPotential) * 4.0);
    final blueProjectedRaw =
        baselineScore +
        ((blueAlliance.offense - redAlliance.defense) * 0.30) +
        (blueAlliance.momentum * 0.34) +
        ((blueAlliance.strength - redAlliance.strength) * 0.16) +
        ((blueAlliance.awpPotential - redAlliance.awpPotential) * 4.0);

    final normalizedScores = _normalizeProjectedScores(
      redProjectedRaw,
      blueProjectedRaw,
    );
    final redProjected = normalizedScores.$1;
    final blueProjected = normalizedScores.$2;
    final ratingGap = redAlliance.strength - blueAlliance.strength;
    final redWinProbability = 1 / (1 + math.exp(-(ratingGap / 11.5)));
    final blueWinProbability = 1 - redWinProbability;
    final evidenceMatches =
        redAlliance.teams.fold<int>(
          0,
          (sum, team) => sum + team.priorSeasonMatches,
        ) +
        blueAlliance.teams.fold<int>(
          0,
          (sum, team) => sum + team.priorSeasonMatches,
        );
    final coverage =
        _average(<double>[
          for (final team in redAlliance.teams) team.coverage,
          for (final team in blueAlliance.teams) team.coverage,
        ]) ??
        0.2;
    final confidence =
        (0.42 +
                (coverage * 0.26) +
                ((math.min(evidenceMatches, 28) / 28) * 0.14) +
                ((redWinProbability - 0.5).abs() * 0.46))
            .clamp(0.45, 0.96);

    final insights = _buildInsights(
      redAlliance: redAlliance,
      blueAlliance: blueAlliance,
      redWinProbability: redWinProbability,
      evidenceMatches: evidenceMatches,
    );

    return SolarMatchPrediction(
      match: match,
      event: event,
      redAlliance: redAlliance.copyWith(projectedScore: redProjected),
      blueAlliance: blueAlliance.copyWith(projectedScore: blueProjected),
      redWinProbability: redWinProbability,
      blueWinProbability: blueWinProbability,
      predictedRedScore: redProjected.round(),
      predictedBlueScore: blueProjected.round(),
      confidence: confidence,
      favoredAllianceColor: redWinProbability >= 0.5 ? 'red' : 'blue',
      evidenceMatches: evidenceMatches,
      insights: insights,
    );
  }

  SolarAlliancePrediction _predictAlliance({
    required MatchSummary targetMatch,
    required String color,
    required Map<String, _HistoryStats> divisionHistory,
    required Map<int, List<MatchSummary>> seasonMatchesByTeamId,
    required Map<String, OpenSkillCacheEntry> openSkillByTeam,
    required Map<String, WorldSkillsEntry> worldSkillsByTeam,
    required Map<String, _EventSkillSnapshot> eventSkillsByTeam,
  }) {
    final alliance = _allianceForColor(targetMatch, color);
    final teams = alliance?.teams ?? const <TeamReference>[];
    final teamPredictions = teams
        .map((team) {
          final key = team.number.trim().toUpperCase();
          final divisionStats = divisionHistory[key];
          final seasonStats = _buildSeasonHistory(
            team: team,
            matches: seasonMatchesByTeamId[team.id] ?? const <MatchSummary>[],
            targetMatch: targetMatch,
          );
          final openSkill = openSkillByTeam[key];
          final worldSkills = worldSkillsByTeam[key];
          final eventSkill = eventSkillsByTeam[key];
          final awpPotential =
              _weightedAverage(<_Signal>[
                _Signal(openSkill?.awpPerMatch, weight: 0.60),
                _Signal(
                  _scaledAutonForAwp(eventSkill?.autonScore),
                  weight: 0.30,
                ),
                _Signal(
                  _scaledAutonForAwp(worldSkills?.programmingScore),
                  weight: 0.10,
                ),
              ]) ??
              0.42;

          final skillPower = _weightedAverage(<_Signal>[
            _Signal(_scaledSkillScore(eventSkill?.combinedScore), weight: 0.58),
            _Signal(
              _scaledSkillScore(worldSkills?.combinedScore),
              weight: 0.42,
            ),
          ]);
          final ordinalPower = _scaledOrdinal(openSkill?.openSkillOrdinal);
          final openSkillDpr =
              openSkill?.dpr ??
              ((openSkill?.opr != null && openSkill?.ccwm != null)
                  ? openSkill!.opr! - openSkill.ccwm!
                  : null);
          final winRate =
              _weightedAverage(<_Signal>[
                _Signal(divisionStats?.winRate, weight: 0.56),
                _Signal(seasonStats.winRate, weight: 0.44),
              ]) ??
              0.5;
          final offense =
              _weightedAverage(<_Signal>[
                _Signal(divisionStats?.offenseAvg, weight: 0.46),
                _Signal(seasonStats.offenseAvg, weight: 0.24),
                _Signal(openSkill?.opr, weight: 0.18),
                _Signal(skillPower, weight: 0.08),
                _Signal(ordinalPower, weight: 0.04),
              ]) ??
              22;
          final defense =
              _weightedAverage(<_Signal>[
                _Signal(divisionStats?.defenseAvg, weight: 0.40),
                _Signal(seasonStats.defenseAvg, weight: 0.24),
                _Signal(openSkillDpr, weight: 0.24),
                _Signal(_fallbackDefense(openSkill), weight: 0.12),
              ]) ??
              20;
          final momentum =
              _weightedAverage(<_Signal>[
                _Signal(divisionStats?.marginAvg, weight: 0.40),
                _Signal(seasonStats.marginAvg, weight: 0.24),
                _Signal(openSkill?.ccwm, weight: 0.20),
                _Signal((winRate - 0.5) * 24, weight: 0.10),
                _Signal(ordinalPower, weight: 0.04),
                _Signal(
                  skillPower != null ? skillPower - 16 : null,
                  weight: 0.02,
                ),
              ]) ??
              0;
          final compositeRating =
              offense -
              (defense * 0.34) +
              (momentum * 1.04) +
              ((awpPotential - 0.5) * 4.5);
          final coverage =
              ([
                        if (divisionStats?.matches != null &&
                            divisionStats!.matches > 0)
                          1.0,
                        if (seasonStats.matches > 0) 1.0,
                        if (openSkill != null) 1.0,
                        if (worldSkills != null) 1.0,
                        if (eventSkill != null) 1.0,
                      ].length /
                      5)
                  .clamp(0.2, 1.0);

          return SolarTeamPrediction(
            team: team,
            compositeRating: compositeRating,
            offense: offense,
            defense: defense,
            momentum: momentum,
            coverage: coverage,
            winRate: winRate,
            priorEventMatches: divisionStats?.matches ?? 0,
            priorSeasonMatches: seasonStats.matches,
            eventCombinedSkills: eventSkill?.combinedScore,
            eventDriverScore: eventSkill?.driverScore,
            eventAutonScore: eventSkill?.autonScore,
            worldRank: worldSkills?.rank,
            worldCombinedScore: worldSkills?.combinedScore,
            openSkillOrdinal: openSkill?.openSkillOrdinal,
            openSkillOpr: openSkill?.opr,
            openSkillDpr: openSkillDpr,
            openSkillCcwm: openSkill?.ccwm,
            openSkillAwpPerMatch: awpPotential,
          );
        })
        .toList(growable: false);

    return SolarAlliancePrediction(
      color: color,
      teams: teamPredictions,
      strength:
          _average(teamPredictions.map((team) => team.compositeRating)) ?? 0,
      offense: _average(teamPredictions.map((team) => team.offense)) ?? 22,
      defense: _average(teamPredictions.map((team) => team.defense)) ?? 20,
      momentum: _average(teamPredictions.map((team) => team.momentum)) ?? 0,
      awpPotential:
          _average(
            teamPredictions.map((team) => team.openSkillAwpPerMatch ?? 0.42),
          ) ??
          0.42,
      projectedScore: 0,
      actualScore: alliance?.score != null && alliance!.score >= 0
          ? alliance.score
          : null,
    );
  }

  Map<String, _HistoryStats> _buildDivisionHistory(List<MatchSummary> matches) {
    final result = <String, _HistoryAccumulator>{};

    for (final match in matches) {
      final red = _allianceForColor(match, 'red');
      final blue = _allianceForColor(match, 'blue');
      if (red == null || blue == null || red.score < 0 || blue.score < 0) {
        continue;
      }

      _accumulateAlliance(result, alliance: red, opponent: blue);
      _accumulateAlliance(result, alliance: blue, opponent: red);
    }

    return <String, _HistoryStats>{
      for (final entry in result.entries) entry.key: entry.value.toStats(),
    };
  }

  _HistoryStats _buildSeasonHistory({
    required TeamReference team,
    required List<MatchSummary> matches,
    required MatchSummary targetMatch,
  }) {
    final accumulator = _HistoryAccumulator();
    final priorMatches = <MatchSummary>[];
    for (final match in matches) {
      if (match.id == targetMatch.id || !_hasOfficialScore(match)) {
        continue;
      }
      if (!_matchOccurredBefore(match, targetMatch) ||
          !_isPredictableRound(match.round)) {
        continue;
      }
      priorMatches.add(match);
    }

    priorMatches.sort(_compareMatchesChronologically);
    final recentWindow = priorMatches.length > 10
        ? priorMatches.sublist(priorMatches.length - 10)
        : priorMatches;

    for (var i = 0; i < recentWindow.length; i++) {
      final match = recentWindow[i];
      final alliance = _findAllianceForTeam(match, team);
      if (alliance == null || alliance.score < 0) {
        continue;
      }
      final opponent = _opposingAlliance(match, alliance);
      if (opponent == null || opponent.score < 0) {
        continue;
      }

      final recencyWeight = recentWindow.length <= 1
          ? 1.0
          : 0.75 + ((i / (recentWindow.length - 1)) * 0.5);
      accumulator.add(
        score: alliance.score,
        against: opponent.score,
        weight: recencyWeight,
      );
    }

    return accumulator.toStats();
  }

  Map<String, _EventSkillSnapshot> _buildEventSkillsTable(
    List<SkillAttempt> attempts,
  ) {
    final table = <String, _MutableEventSkillSnapshot>{};
    for (final attempt in attempts) {
      final key = attempt.team.number.trim().toUpperCase();
      final snapshot = table.putIfAbsent(key, _MutableEventSkillSnapshot.new);
      final type = attempt.type.trim().toLowerCase();
      if (type.startsWith('driver')) {
        snapshot.driverScore = math.max(
          snapshot.driverScore ?? 0,
          attempt.score,
        );
      } else {
        snapshot.autonScore = math.max(snapshot.autonScore ?? 0, attempt.score);
      }
    }

    return <String, _EventSkillSnapshot>{
      for (final entry in table.entries)
        entry.key: _EventSkillSnapshot(
          driverScore: entry.value.driverScore,
          autonScore: entry.value.autonScore,
        ),
    };
  }

  List<String> _buildInsights({
    required SolarAlliancePrediction redAlliance,
    required SolarAlliancePrediction blueAlliance,
    required double redWinProbability,
    required int evidenceMatches,
  }) {
    final insights = <String>[];

    final skillGap = _skillsPower(redAlliance) - _skillsPower(blueAlliance);
    if (skillGap.abs() >= 3.5) {
      insights.add(
        skillGap.isNegative
            ? 'Blue brings the stronger scoring ceiling from recent skills and event data.'
            : 'Red brings the stronger scoring ceiling from recent skills and event data.',
      );
    }

    final momentumGap = redAlliance.momentum - blueAlliance.momentum;
    if (momentumGap.abs() >= 2.5) {
      insights.add(
        momentumGap.isNegative
            ? 'Blue has the better recent scoring margin in prior matches.'
            : 'Red has the better recent scoring margin in prior matches.',
      );
    }

    final ordinalGap = _ordinalPower(redAlliance) - _ordinalPower(blueAlliance);
    if (ordinalGap.abs() >= 1.5) {
      insights.add(
        ordinalGap.isNegative
            ? 'Blue owns the stronger season-long efficiency profile.'
            : 'Red owns the stronger season-long efficiency profile.',
      );
    }

    if (evidenceMatches < 8) {
      insights.add(
        'Solarize is leaning more on season form because this event still has limited completed matches.',
      );
    } else if ((redWinProbability - 0.5).abs() < 0.08) {
      insights.add(
        'This projects as a close match with only a narrow edge separating the alliances.',
      );
    }

    if (redWinProbability > 0.43 && redWinProbability < 0.57) {
      insights.add(
        'Upset risk is high here. One big mistake could flip it.',
      );
    }

    if (insights.isEmpty) {
      insights.add(
        'Both alliances grade out close, so Solarize is separating them with small differences in recent form and efficiency.',
      );
    }

    return insights.take(3).toList(growable: false);
  }

  (double, double) _normalizeProjectedScores(double red, double blue) {
    var normalizedRed = red;
    var normalizedBlue = blue;

    if (normalizedRed < 0 || normalizedBlue < 0) {
      final floor = math.min(normalizedRed, normalizedBlue);
      normalizedRed += floor.abs() + 4;
      normalizedBlue += floor.abs() + 4;
    }

    if ((normalizedRed - normalizedBlue).abs() < 1.2) {
      normalizedRed += 1.1;
      normalizedBlue -= 1.1;
    }

    return (
      normalizedRed.clamp(0, 250).toDouble(),
      normalizedBlue.clamp(0, 250).toDouble(),
    );
  }

  static void _accumulateAlliance(
    Map<String, _HistoryAccumulator> table, {
    required MatchAlliance alliance,
    required MatchAlliance opponent,
  }) {
    for (final team in alliance.teams) {
      final key = team.number.trim().toUpperCase();
      final accumulator = table.putIfAbsent(key, _HistoryAccumulator.new);
      accumulator.add(score: alliance.score, against: opponent.score);
    }
  }

  static MatchAlliance? _allianceForColor(MatchSummary match, String color) {
    for (final alliance in match.alliances) {
      if (alliance.color.toLowerCase().contains(color)) {
        return alliance;
      }
    }

    if (match.alliances.isEmpty) {
      return null;
    }

    return color == 'red'
        ? match.alliances.first
        : match.alliances.length > 1
        ? match.alliances[1]
        : match.alliances.first;
  }

  static MatchAlliance? _findAllianceForTeam(
    MatchSummary match,
    TeamReference team,
  ) {
    for (final alliance in match.alliances) {
      for (final allianceTeam in alliance.teams) {
        if (allianceTeam.id == team.id ||
            allianceTeam.number.trim().toUpperCase() ==
                team.number.trim().toUpperCase()) {
          return alliance;
        }
      }
    }
    return null;
  }

  static MatchAlliance? _opposingAlliance(
    MatchSummary match,
    MatchAlliance alliance,
  ) {
    for (final candidate in match.alliances) {
      if (!identical(candidate, alliance) &&
          candidate.color.toLowerCase() != alliance.color.toLowerCase()) {
        return candidate;
      }
    }

    for (final candidate in match.alliances) {
      if (!identical(candidate, alliance)) {
        return candidate;
      }
    }
    return null;
  }

  static bool _hasOfficialScore(MatchSummary match) {
    final red = _allianceForColor(match, 'red');
    final blue = _allianceForColor(match, 'blue');
    return red != null &&
        blue != null &&
        red.score >= 0 &&
        blue.score >= 0 &&
        _isPredictableRound(match.round);
  }

  static bool _matchOccurredBefore(
    MatchSummary candidate,
    MatchSummary target,
  ) {
    final candidateAnchor = _matchAnchor(candidate);
    final targetAnchor = _matchAnchor(target);
    if (candidateAnchor != null && targetAnchor != null) {
      if (candidateAnchor.isBefore(targetAnchor)) {
        return true;
      }
      if (candidateAnchor.isAfter(targetAnchor)) {
        return false;
      }
    }

    if (candidate.round.code != target.round.code) {
      return candidate.round.code < target.round.code;
    }

    if (candidate.instance != target.instance) {
      return candidate.instance < target.instance;
    }

    if (candidate.matchNumber != target.matchNumber) {
      return candidate.matchNumber < target.matchNumber;
    }

    return candidate.id < target.id;
  }

  static int _compareMatchesChronologically(
    MatchSummary left,
    MatchSummary right,
  ) {
    final leftAnchor = _matchAnchor(left);
    final rightAnchor = _matchAnchor(right);
    if (leftAnchor != null && rightAnchor != null) {
      final anchorCompare = leftAnchor.compareTo(rightAnchor);
      if (anchorCompare != 0) {
        return anchorCompare;
      }
    }

    if (left.round.code != right.round.code) {
      return left.round.code.compareTo(right.round.code);
    }

    if (left.instance != right.instance) {
      return left.instance.compareTo(right.instance);
    }

    if (left.matchNumber != right.matchNumber) {
      return left.matchNumber.compareTo(right.matchNumber);
    }

    return left.id.compareTo(right.id);
  }

  static DateTime? _matchAnchor(MatchSummary match) {
    return match.started ?? match.scheduled;
  }

  static bool _isPredictableRound(MatchRound round) {
    return round != MatchRound.none && round != MatchRound.practice;
  }

  static double? _average(Iterable<double> values) {
    var count = 0;
    var total = 0.0;
    for (final value in values) {
      total += value;
      count += 1;
    }
    if (count == 0) {
      return null;
    }
    return total / count;
  }

  static double? _averageAllianceScore(List<MatchSummary> matches) {
    final scores = <double>[];
    for (final match in matches) {
      for (final alliance in match.alliances) {
        if (alliance.score >= 0) {
          scores.add(alliance.score.toDouble());
        }
      }
    }
    return _average(scores);
  }

  static double? _weightedAverage(List<_Signal> signals) {
    var totalWeight = 0.0;
    var total = 0.0;
    for (final signal in signals) {
      if (signal.value == null) {
        continue;
      }
      totalWeight += signal.weight;
      total += signal.value! * signal.weight;
    }
    if (totalWeight == 0) {
      return null;
    }
    return total / totalWeight;
  }

  static double? _scaledSkillScore(int? score) {
    if (score == null || score <= 0) {
      return null;
    }
    return score / 8.0;
  }

  static double? _scaledOrdinal(double? ordinal) {
    if (ordinal == null || ordinal <= 0) {
      return null;
    }
    return ordinal / 2.2;
  }

  static double? _scaledAutonForAwp(int? auton) {
    if (auton == null || auton <= 0) {
      return null;
    }
    return (auton / 120).clamp(0.1, 1.0);
  }

  static double? _fallbackDefense(OpenSkillCacheEntry? entry) {
    if (entry?.opr == null || entry?.ccwm == null) {
      return null;
    }
    return entry!.opr! - entry.ccwm!;
  }

  static double _skillsPower(SolarAlliancePrediction alliance) {
    return alliance.teams.fold<double>(0, (sum, team) {
      final scaled = _scaledSkillScore(
        team.eventCombinedSkills ?? team.worldCombinedScore,
      );
      return sum + ((scaled ?? 0).clamp(0, 40));
    });
  }

  static double _ordinalPower(SolarAlliancePrediction alliance) {
    return alliance.teams.fold<double>(0, (sum, team) {
      final scaled = _scaledOrdinal(team.openSkillOrdinal);
      return sum + (scaled ?? 0);
    });
  }
}

class _Signal {
  const _Signal(this.value, {required this.weight});

  final double? value;
  final double weight;
}

class _HistoryAccumulator {
  int matches = 0;
  double weightedMatches = 0;
  double weightedWins = 0;
  double weightedTies = 0;
  double offenseTotal = 0;
  double defenseTotal = 0;
  double marginTotal = 0;

  void add({required int score, required int against, double weight = 1.0}) {
    matches += 1;
    weightedMatches += weight;
    offenseTotal += score * weight;
    defenseTotal += against * weight;
    marginTotal += (score - against) * weight;
    if (score > against) {
      weightedWins += weight;
    } else if (score < against) {
      // Losses are implied by the remaining weight.
    } else {
      weightedTies += weight;
    }
  }

  _HistoryStats toStats() {
    if (matches == 0 || weightedMatches == 0) {
      return const _HistoryStats();
    }

    return _HistoryStats(
      matches: matches,
      offenseAvg: offenseTotal / weightedMatches,
      defenseAvg: defenseTotal / weightedMatches,
      marginAvg: marginTotal / weightedMatches,
      winRate: (weightedWins + (weightedTies * 0.5)) / weightedMatches,
    );
  }
}

class _HistoryStats {
  const _HistoryStats({
    this.matches = 0,
    this.offenseAvg,
    this.defenseAvg,
    this.marginAvg,
    this.winRate,
  });

  final int matches;
  final double? offenseAvg;
  final double? defenseAvg;
  final double? marginAvg;
  final double? winRate;
}

class _MutableEventSkillSnapshot {
  int? driverScore;
  int? autonScore;
}

class _EventSkillSnapshot {
  const _EventSkillSnapshot({
    required this.driverScore,
    required this.autonScore,
  });

  final int? driverScore;
  final int? autonScore;

  int? get combinedScore {
    final driver = driverScore;
    final auton = autonScore;
    if (driver == null && auton == null) {
      return null;
    }
    return (driver ?? 0) + (auton ?? 0);
  }
}

extension on SolarAlliancePrediction {
  SolarAlliancePrediction copyWith({double? projectedScore}) {
    return SolarAlliancePrediction(
      color: color,
      teams: teams,
      strength: strength,
      offense: offense,
      defense: defense,
      momentum: momentum,
      awpPotential: awpPotential,
      projectedScore: projectedScore ?? this.projectedScore,
      actualScore: actualScore,
    );
  }
}
