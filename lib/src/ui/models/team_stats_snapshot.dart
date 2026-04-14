import '../../models/robot_events_models.dart';
import '../../models/open_skill_models.dart';
import '../../models/world_skills_models.dart';

class TeamStatsSnapshot {
  const TeamStatsSnapshot({
    required this.team,
    this.allEvents = const <EventSummary>[],
    this.upcomingEvents = const <EventSummary>[],
    this.rankings = const <RankingRecord>[],
    this.matchHistory = const <MatchSummary>[],
    this.openSkillEntry,
    this.worldSkillsEntry,
    this.lastUpdated,
    this.errorMessage,
  });

  final TeamSummary team;
  final List<EventSummary> allEvents;
  final List<EventSummary> upcomingEvents;
  final List<RankingRecord> rankings;
  final List<MatchSummary> matchHistory;
  final OpenSkillCacheEntry? openSkillEntry;
  final WorldSkillsEntry? worldSkillsEntry;
  final DateTime? lastUpdated;
  final String? errorMessage;

  bool get hasLiveSignal {
    return allEvents.isNotEmpty ||
        upcomingEvents.isNotEmpty ||
        rankings.isNotEmpty ||
        matchHistory.isNotEmpty ||
        openSkillEntry != null ||
        worldSkillsEntry != null ||
        (errorMessage?.trim().isNotEmpty ?? false);
  }

  List<EventSummary> get futureEvents {
    if (allEvents.isEmpty) {
      return upcomingEvents;
    }

    final now = DateTime.now();
    final events = allEvents
        .where((event) {
          final anchor = event.end ?? event.start;
          return anchor == null || !anchor.isBefore(now);
        })
        .toList(growable: false);

    return events;
  }

  List<EventSummary> get pastEvents {
    if (allEvents.isEmpty) {
      return const <EventSummary>[];
    }

    final now = DateTime.now();
    final events =
        allEvents.where((event) {
          final anchor = event.end ?? event.start;
          return anchor != null && anchor.isBefore(now);
        }).toList()..sort((a, b) {
          final aStart = a.start ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bStart = b.start ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bStart.compareTo(aStart);
        });

    return events;
  }

  RankingRecord? get bestRanking {
    final rankedEntries = rankings.where((entry) => entry.rank > 0).toList();
    if (rankedEntries.isEmpty) {
      return null;
    }
    rankedEntries.sort((a, b) => a.rank.compareTo(b.rank));
    return rankedEntries.first;
  }

  int get totalWins {
    final matchWins = _completedWins;
    if (matchWins != null) {
      return matchWins;
    }
    return rankings.fold<int>(0, (sum, entry) {
      return sum + (entry.wins > 0 ? entry.wins : 0);
    });
  }

  int get totalLosses {
    final matchLosses = _completedLosses;
    if (matchLosses != null) {
      return matchLosses;
    }
    return rankings.fold<int>(0, (sum, entry) {
      return sum + (entry.losses > 0 ? entry.losses : 0);
    });
  }

  int get totalTies {
    final matchTies = _completedTies;
    if (matchTies != null) {
      return matchTies;
    }
    return rankings.fold<int>(0, (sum, entry) {
      return sum + (entry.ties > 0 ? entry.ties : 0);
    });
  }

  int get totalMatches => totalWins + totalLosses + totalTies;

  List<MatchSummary> get completedMatches {
    return matchHistory.where((match) {
      return match.alliances.length >= 2 &&
          match.alliances.every((alliance) => alliance.score >= 0);
    }).toList(growable: false);
  }

  int? scoreForTeam(MatchSummary match) {
    final teamNumber = team.number.trim().toUpperCase();
    for (final alliance in match.alliances) {
      final containsTeam = alliance.teams.any((member) {
        return member.number.trim().toUpperCase() == teamNumber;
      });
      if (containsTeam) {
        return alliance.score >= 0 ? alliance.score : null;
      }
    }
    return null;
  }

  int? opponentScoreForTeam(MatchSummary match) {
    final teamNumber = team.number.trim().toUpperCase();
    MatchAlliance? teamAlliance;
    for (final alliance in match.alliances) {
      final containsTeam = alliance.teams.any((member) {
        return member.number.trim().toUpperCase() == teamNumber;
      });
      if (containsTeam) {
        teamAlliance = alliance;
        break;
      }
    }

    if (teamAlliance == null) {
      return null;
    }

    for (final alliance in match.alliances) {
      if (!identical(alliance, teamAlliance)) {
        return alliance.score >= 0 ? alliance.score : null;
      }
    }
    return null;
  }

  double? get scoringMargin {
    return _robustWeightedAverage(
      completedMatches.map((match) {
        final teamScore = scoreForTeam(match);
        final opponentScore = opponentScoreForTeam(match);
        if (teamScore == null || opponentScore == null) {
          return null;
        }
        return (teamScore - opponentScore).toDouble();
      }),
      signed: true,
    );
  }

  double? get averageScored {
    return _robustWeightedAverage(
      completedMatches.map((match) {
        final teamScore = scoreForTeam(match);
        return teamScore?.toDouble();
      }),
    );
  }

  double? get averageAllowed {
    return _robustWeightedAverage(
      completedMatches.map((match) {
        final opponentScore = opponentScoreForTeam(match);
        return opponentScore?.toDouble();
      }),
    );
  }

  double? get estimatedCcwm {
    if (scoringMargin != null) {
      return scoringMargin;
    }
    final matches = totalMatches;
    if (matches == 0) {
      return null;
    }

    final momentum = totalWins - totalLosses + (totalTies * 0.5);
    return (momentum / matches) * 10;
  }

  double? get ccwm => estimatedCcwm ?? openSkillEntry?.ccwm;

  double? get estimatedOpr {
    if (averageScored != null) {
      return averageScored;
    }
    final ranking = bestRanking;
    if (ranking == null || ranking.averagePoints <= 0) {
      return null;
    }
    return ranking.averagePoints;
  }

  double? get opr => estimatedOpr ?? openSkillEntry?.opr;

  double? get estimatedDpr {
    if (averageAllowed != null) {
      return averageAllowed;
    }
    final estimatedOffense = estimatedOpr;
    final estimatedMargin = estimatedCcwm;
    if (estimatedOffense == null || estimatedMargin == null) {
      return null;
    }

    final estimate = estimatedOffense - estimatedMargin;
    return estimate < 0 ? 0 : estimate;
  }

  double? get dpr => estimatedDpr ?? openSkillEntry?.dpr;

  String get recordLabel {
    if (totalMatches == 0) {
      return '--';
    }

    return '$totalWins-$totalLosses-$totalTies';
  }

  double? get winRate {
    if (totalMatches == 0) {
      return null;
    }

    return ((totalWins + (totalTies * 0.5)) / totalMatches) * 100;
  }

  String get skillsRankLabel {
    final rank = worldSkillsEntry?.rank;
    if (rank == null || rank <= 0) {
      return '--';
    }
    return '#$rank';
  }

  String get skillsScoreLabel {
    final score = worldSkillsEntry?.combinedScore;
    return score == null || score <= 0 ? '--' : '$score';
  }

  String get driverScoreLabel {
    final score = worldSkillsEntry?.driverScore;
    return score == null || score <= 0 ? '--' : '$score';
  }

  String get programmingScoreLabel {
    final score = worldSkillsEntry?.programmingScore;
    return score == null || score <= 0 ? '--' : '$score';
  }

  String get locationLabel {
    final pieces = <String>[
      if (team.location.city.isNotEmpty) team.location.city,
      if (team.location.region.isNotEmpty) team.location.region,
      if (team.location.country.isNotEmpty) team.location.country,
    ];
    return pieces.isEmpty ? 'Location pending' : pieces.join(', ');
  }

  int? get _completedWins {
    final outcomes = _completedOutcomes;
    if (outcomes == null) {
      return null;
    }
    return outcomes.where((outcome) => outcome > 0).length;
  }

  int? get _completedLosses {
    final outcomes = _completedOutcomes;
    if (outcomes == null) {
      return null;
    }
    return outcomes.where((outcome) => outcome < 0).length;
  }

  int? get _completedTies {
    final outcomes = _completedOutcomes;
    if (outcomes == null) {
      return null;
    }
    return outcomes.where((outcome) => outcome == 0).length;
  }

  List<int>? get _completedOutcomes {
    final matches = completedMatches;
    if (matches.isEmpty) {
      return null;
    }

    final outcomes = <int>[];
    for (final match in matches) {
      final teamScore = scoreForTeam(match);
      final opponentScore = opponentScoreForTeam(match);
      if (teamScore == null || opponentScore == null) {
        continue;
      }
      outcomes.add(teamScore.compareTo(opponentScore));
    }
    return outcomes.isEmpty ? null : outcomes;
  }

  double? _robustWeightedAverage(
    Iterable<double?> sourceValues, {
    bool signed = false,
  }) {
    final values = sourceValues.whereType<double>().toList(growable: false);
    if (values.isEmpty) {
      return null;
    }

    final sorted = values.toList()..sort();
    final median = sorted[sorted.length ~/ 2];
    final deviations = values
        .map((value) => (value - median).abs())
        .toList(growable: false)
      ..sort();
    final mad = deviations[deviations.length ~/ 2];
    final guardBand = mad <= 0 ? (signed ? 18.0 : 12.0) : mad * 2.6;

    var weightedTotal = 0.0;
    var weightTotal = 0.0;
    for (var index = 0; index < values.length; index++) {
      final progress = values.length <= 1 ? 1.0 : index / (values.length - 1);
      final recencyWeight = 0.7 + (progress * 0.9);
      final lowerBound = median - guardBand;
      final upperBound = median + guardBand;
      final dampedValue = values[index].clamp(lowerBound, upperBound);
      weightedTotal += dampedValue * recencyWeight;
      weightTotal += recencyWeight;
    }

    if (weightTotal <= 0) {
      return null;
    }
    return weightedTotal / weightTotal;
  }
}
