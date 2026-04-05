import '../../models/robot_events_models.dart';
import '../../models/open_skill_models.dart';
import '../../models/world_skills_models.dart';

class TeamStatsSnapshot {
  const TeamStatsSnapshot({
    required this.team,
    this.allEvents = const <EventSummary>[],
    this.upcomingEvents = const <EventSummary>[],
    this.rankings = const <RankingRecord>[],
    this.openSkillEntry,
    this.worldSkillsEntry,
    this.lastUpdated,
    this.errorMessage,
  });

  final TeamSummary team;
  final List<EventSummary> allEvents;
  final List<EventSummary> upcomingEvents;
  final List<RankingRecord> rankings;
  final OpenSkillCacheEntry? openSkillEntry;
  final WorldSkillsEntry? worldSkillsEntry;
  final DateTime? lastUpdated;
  final String? errorMessage;

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
    return rankings.fold<int>(0, (sum, entry) {
      return sum + (entry.wins > 0 ? entry.wins : 0);
    });
  }

  int get totalLosses {
    return rankings.fold<int>(0, (sum, entry) {
      return sum + (entry.losses > 0 ? entry.losses : 0);
    });
  }

  int get totalTies {
    return rankings.fold<int>(0, (sum, entry) {
      return sum + (entry.ties > 0 ? entry.ties : 0);
    });
  }

  int get totalMatches => totalWins + totalLosses + totalTies;

  double? get estimatedCcwm {
    final matches = totalMatches;
    if (matches == 0) {
      return null;
    }

    final momentum = totalWins - totalLosses + (totalTies * 0.5);
    return (momentum / matches) * 10;
  }

  double? get ccwm => openSkillEntry?.ccwm ?? estimatedCcwm;

  double? get estimatedOpr {
    final ranking = bestRanking;
    if (ranking == null || ranking.averagePoints <= 0) {
      return null;
    }
    return ranking.averagePoints;
  }

  double? get opr => openSkillEntry?.opr ?? estimatedOpr;

  double? get estimatedDpr {
    final estimatedOffense = estimatedOpr;
    final estimatedMargin = estimatedCcwm;
    if (estimatedOffense == null || estimatedMargin == null) {
      return null;
    }

    final estimate = estimatedOffense - estimatedMargin;
    return estimate < 0 ? 0 : estimate;
  }

  double? get dpr => openSkillEntry?.dpr ?? estimatedDpr;

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
}
