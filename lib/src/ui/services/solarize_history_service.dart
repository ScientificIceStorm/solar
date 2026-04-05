import 'dart:math' as math;

import '../../models/open_skill_models.dart';
import '../../models/robot_events_models.dart';
import '../../models/world_skills_models.dart';

class SolarizeHistoryService {
  const SolarizeHistoryService();

  List<OpenSkillCacheEntry> build({
    required List<WorldSkillsEntry> worldSkills,
    required Map<String, List<RankingRecord>> rankingsByTeam,
  }) {
    final computed =
        worldSkills
            .map((entry) {
              final key = entry.teamNumber.trim().toUpperCase();
              final rankings = rankingsByTeam[key] ?? const <RankingRecord>[];
              return _buildEntry(entry, rankings);
            })
            .toList(growable: false)
          ..sort((a, b) {
            final ordinalCompare = b.openSkillOrdinal.compareTo(
              a.openSkillOrdinal,
            );
            if (ordinalCompare != 0) {
              return ordinalCompare;
            }
            final muCompare = b.openSkillMu.compareTo(a.openSkillMu);
            if (muCompare != 0) {
              return muCompare;
            }
            return a.teamNumber.compareTo(b.teamNumber);
          });

    return List<OpenSkillCacheEntry>.generate(computed.length, (index) {
      final entry = computed[index];
      return OpenSkillCacheEntry(
        ranking: index + 1,
        rankingChange: entry.rankingChange,
        teamNumber: entry.teamNumber,
        id: entry.id,
        region: entry.region,
        country: entry.country,
        trueSkill: entry.trueSkill,
        openSkillMu: entry.openSkillMu,
        openSkillSigma: entry.openSkillSigma,
        openSkillOrdinal: entry.openSkillOrdinal,
        ratingSource: entry.ratingSource,
        ccwm: entry.ccwm,
        totalWins: entry.totalWins,
        totalLosses: entry.totalLosses,
        totalTies: entry.totalTies,
        apPerMatch: entry.apPerMatch,
        awpPerMatch: entry.awpPerMatch,
        wpPerMatch: entry.wpPerMatch,
        opr: entry.opr,
        dpr: entry.dpr,
        qualifiedForRegionals: entry.qualifiedForRegionals,
        qualifiedForWorlds: entry.qualifiedForWorlds,
      );
    });
  }

  OpenSkillCacheEntry _buildEntry(
    WorldSkillsEntry entry,
    List<RankingRecord> rankings,
  ) {
    final history = _HistorySnapshot.fromRankings(rankings);
    final combinedScore = entry.combinedScore.toDouble();
    final driverScore = entry.maxDriverScore.toDouble();
    final programmingScore = entry.maxProgrammingScore.toDouble();
    final hasHistory = history.events > 0;

    final worldRankBoost = _worldRankBoost(entry.rank);
    final skillsBoost =
        (combinedScore / 55).clamp(0, 4.8).toDouble() +
        (driverScore / 160).clamp(0, 0.95).toDouble() +
        (programmingScore / 175).clamp(0, 0.9).toDouble();
    final averagePointsBoost = (history.averagePoints / 18)
        .clamp(0, 7)
        .toDouble();
    final winRateBoost = history.winRate * 10;
    final topCutBoost = history.topCutRate * 5;
    final podiumBoost = history.podiumRate * 4;
    final eventVolumeBoost = math.min(history.events.toDouble(), 10) * 0.45;
    final rankPenalty = history.events == 0
        ? 0
        : ((history.averageRank - 1).clamp(0, 18) / 9.0);
    final badFinishPenalty = history.badFinishRate * 2.2;

    final mu =
        14 +
        worldRankBoost +
        skillsBoost +
        averagePointsBoost +
        winRateBoost +
        topCutBoost +
        podiumBoost +
        eventVolumeBoost -
        rankPenalty -
        badFinishPenalty;
    final sigma =
        (8.4 -
                (math.min(history.events.toDouble(), 10) * 0.45) -
                math.min(history.matches.toDouble() / 40, 1.7) -
                (history.topCutRate * 0.8) -
                (history.podiumRate * 0.6) +
                (history.events > 0 && history.events < 6 ? 1.2 : 0) +
                (history.badFinishRate * 1.0))
            .clamp(2.8, hasHistory ? 8.2 : 6.8)
            .toDouble();
    final ordinal = mu - (sigma * 2.8);

    final winRate = hasHistory ? history.winRate : _priorWinRate(entry.rank);
    final averagePoints = hasHistory
        ? history.averagePoints
        : _priorAveragePoints(entry);
    final apPerMatch = hasHistory
        ? history.apPerMatch
        : _priorApPerMatch(entry);
    final topCutRate = hasHistory
        ? history.topCutRate
        : _priorTopCutRate(entry);
    final ccwm =
        ((winRate - 0.5) * 22) +
        ((((averagePoints / 90).clamp(0.15, 1.0)) - 0.5) * 14) +
        ((topCutRate - 0.5) * 8);
    final opr =
        (averagePoints + (math.max(ccwm, 0) * 0.55) + (driverScore / 10))
            .clamp(10, 140)
            .toDouble();
    final dpr = math.max(0.0, opr - ccwm);
    final awpPerMatch =
        (((apPerMatch / 10).clamp(0.0, 1.0) * 0.55) +
                ((programmingScore / 120).clamp(0.0, 1.0) * 0.45))
            .clamp(0.05, 0.95)
            .toDouble();

    return OpenSkillCacheEntry(
      ranking: 0,
      rankingChange: 0,
      teamNumber: entry.teamNumber,
      id: entry.teamId,
      region: entry.region,
      country: entry.country,
      trueSkill: mu,
      openSkillMu: mu,
      openSkillSigma: sigma,
      openSkillOrdinal: ordinal,
      ratingSource: hasHistory ? 'solarize-history' : 'solarize-prior',
      ccwm: ccwm,
      totalWins: history.totalWins,
      totalLosses: history.totalLosses,
      totalTies: history.totalTies,
      apPerMatch: apPerMatch,
      awpPerMatch: awpPerMatch,
      wpPerMatch: winRate,
      opr: opr,
      dpr: dpr,
      qualifiedForRegionals: hasHistory && history.topCutCount > 0 ? 1 : 0,
      qualifiedForWorlds:
          (entry.rank > 0 && entry.rank <= 100) || history.podiumCount > 0
          ? 1
          : 0,
    );
  }

  double _worldRankBoost(int rank) {
    if (rank <= 0) {
      return 0;
    }
    return 6 / math.sqrt(rank.toDouble());
  }

  double _priorAveragePoints(WorldSkillsEntry entry) {
    return (entry.combinedScore * 0.38) + (entry.maxDriverScore * 0.14);
  }

  double _priorApPerMatch(WorldSkillsEntry entry) {
    return ((entry.maxProgrammingScore / 16) + (entry.maxDriverScore / 18))
        .clamp(2.0, 8.5)
        .toDouble();
  }

  double _priorTopCutRate(WorldSkillsEntry entry) {
    final rank = entry.rank;
    if (rank <= 0) {
      return 0.25;
    }
    if (rank <= 16) {
      return 0.82;
    }
    if (rank <= 64) {
      return 0.64;
    }
    if (rank <= 128) {
      return 0.52;
    }
    if (rank <= 256) {
      return 0.42;
    }
    return 0.3;
  }

  double _priorWinRate(int rank) {
    if (rank <= 0) {
      return 0.5;
    }
    return (0.78 - (math.log(rank.toDouble()) / 18))
        .clamp(0.42, 0.82)
        .toDouble();
  }
}

class _HistorySnapshot {
  const _HistorySnapshot({
    required this.events,
    required this.matches,
    required this.totalWins,
    required this.totalLosses,
    required this.totalTies,
    required this.topCutCount,
    required this.podiumCount,
    required this.badFinishCount,
    required this.averageRank,
    required this.averagePoints,
    required this.apPerMatch,
  });

  const _HistorySnapshot.empty()
    : events = 0,
      matches = 0,
      totalWins = 0,
      totalLosses = 0,
      totalTies = 0,
      topCutCount = 0,
      podiumCount = 0,
      badFinishCount = 0,
      averageRank = 0,
      averagePoints = 0,
      apPerMatch = 0;

  final int events;
  final int matches;
  final int totalWins;
  final int totalLosses;
  final int totalTies;
  final int topCutCount;
  final int podiumCount;
  final int badFinishCount;
  final double averageRank;
  final double averagePoints;
  final double apPerMatch;

  double get winRate {
    if (matches <= 0) {
      return 0.5;
    }
    return (totalWins + (totalTies * 0.5)) / matches;
  }

  double get topCutRate {
    if (events <= 0) {
      return 0;
    }
    return topCutCount / events;
  }

  double get podiumRate {
    if (events <= 0) {
      return 0;
    }
    return podiumCount / events;
  }

  double get badFinishRate {
    if (events <= 0) {
      return 0;
    }
    return badFinishCount / events;
  }

  factory _HistorySnapshot.fromRankings(List<RankingRecord> rankings) {
    if (rankings.isEmpty) {
      return const _HistorySnapshot.empty();
    }

    var matches = 0;
    var wins = 0;
    var losses = 0;
    var ties = 0;
    var topCutCount = 0;
    var podiumCount = 0;
    var badFinishCount = 0;
    var totalRank = 0.0;
    var rankedEvents = 0;
    var weightedAveragePoints = 0.0;
    var totalAp = 0.0;

    for (final ranking in rankings) {
      final teamMatches =
          math.max(ranking.wins, 0).toInt() +
          math.max(ranking.losses, 0).toInt() +
          math.max(ranking.ties, 0).toInt();
      matches += teamMatches;
      wins += math.max(ranking.wins, 0).toInt();
      losses += math.max(ranking.losses, 0).toInt();
      ties += math.max(ranking.ties, 0).toInt();
      totalAp += math.max(ranking.ap, 0).toDouble();

      if (ranking.rank > 0) {
        rankedEvents += 1;
        totalRank += ranking.rank.toDouble();
        if (ranking.rank <= 8) {
          topCutCount += 1;
        }
        if (ranking.rank <= 3) {
          podiumCount += 1;
        }
        if (ranking.rank > 16) {
          badFinishCount += 1;
        }
      }

      if (ranking.averagePoints > 0) {
        weightedAveragePoints +=
            ranking.averagePoints * math.max(teamMatches, 1);
      }
    }

    final safeMatches = math.max(matches, 1);
    return _HistorySnapshot(
      events: rankings.length,
      matches: matches,
      totalWins: wins,
      totalLosses: losses,
      totalTies: ties,
      topCutCount: topCutCount,
      podiumCount: podiumCount,
      badFinishCount: badFinishCount,
      averageRank: rankedEvents == 0 ? 0 : totalRank / rankedEvents,
      averagePoints: weightedAveragePoints / safeMatches,
      apPerMatch: totalAp / safeMatches,
    );
  }
}
