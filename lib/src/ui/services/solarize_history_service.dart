import 'dart:math' as math;

import '../../models/open_skill_models.dart';
import '../../models/robot_events_models.dart';
import '../../models/world_skills_models.dart';

class SolarizeHistoryService {
  const SolarizeHistoryService();

  List<OpenSkillCacheEntry> build({
    required List<WorldSkillsEntry> worldSkills,
    required Map<String, List<RankingRecord>> rankingsByTeam,
    Map<String, List<MatchSummary>> matchesByTeam =
        const <String, List<MatchSummary>>{},
  }) {
    final performanceProfiles = _buildPerformanceProfiles(
      worldSkills: worldSkills,
      rankingsByTeam: rankingsByTeam,
      matchesByTeam: matchesByTeam,
    );
    final computed =
        worldSkills
            .map((entry) {
              final key = entry.teamNumber.trim().toUpperCase();
              final rankings = rankingsByTeam[key] ?? const <RankingRecord>[];
              final matches = matchesByTeam[key] ?? const <MatchSummary>[];
              return _buildEntry(
                entry,
                rankings,
                matches,
                performanceProfiles: performanceProfiles,
              );
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
        gradeLevel: entry.gradeLevel,
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
        strengthOfSchedule: entry.strengthOfSchedule,
        eliminationWinRate: entry.eliminationWinRate,
        eliminationMatches: entry.eliminationMatches,
        eventStrength: entry.eventStrength,
        qualifiedForRegionals: entry.qualifiedForRegionals,
        qualifiedForWorlds: entry.qualifiedForWorlds,
      );
    });
  }

  OpenSkillCacheEntry _buildEntry(
    WorldSkillsEntry entry,
    List<RankingRecord> rankings,
    List<MatchSummary> matches, {
    required Map<String, _PerformanceProfile> performanceProfiles,
  }) {
    final history = _HistorySnapshot.fromRankings(rankings);
    final matchHistory = _MatchHistorySnapshot.fromMatches(
      matches,
      teamNumber: entry.teamNumber,
      performanceProfiles: performanceProfiles,
    );
    final hasHistory = history.events > 0 || matchHistory.matches > 0;

    final worldSkillPrior = _worldSkillPrior(entry);
    final historyConfidence =
        (((history.weightedEvents / 6).clamp(0.0, 1.0) * 0.55) +
                ((matchHistory.weightedMatches / 14).clamp(0.0, 1.0) * 0.45))
            .clamp(0.0, 1.0)
            .toDouble();

    final priorWinRate = (0.34 + (worldSkillPrior * 0.56))
        .clamp(0.30, 0.90)
        .toDouble();
    final priorAveragePoints = (20 + (worldSkillPrior * 58))
        .clamp(16.0, 92.0)
        .toDouble();
    final priorApPerMatch = (1.5 + (worldSkillPrior * 6.4))
        .clamp(1.0, 9.4)
        .toDouble();
    final priorTopCutRate = (0.08 + (worldSkillPrior * 0.52))
        .clamp(0.08, 0.76)
        .toDouble();
    final priorStrengthOfSchedule = (0.40 + (worldSkillPrior * 0.44))
        .clamp(0.25, 0.92)
        .toDouble();
    final priorEliminationWinRate = (0.38 + (worldSkillPrior * 0.48))
        .clamp(0.30, 0.88)
        .toDouble();
    final priorEventStrength = (0.86 + (worldSkillPrior * 0.72))
        .clamp(0.86, 1.70)
        .toDouble();

    final rawBlendedWinRate = matchHistory.matches > 0
        ? ((matchHistory.winRate * 0.72) + (history.winRate * 0.28))
        : history.winRate;
    final blendedWinRate = _blendMetric(
      primary: rawBlendedWinRate,
      fallback: priorWinRate,
      confidence: historyConfidence,
    );

    final rawAveragePoints = history.averagePoints > 0
        ? history.averagePoints
        : matchHistory.offenseAvg > 0
        ? matchHistory.offenseAvg
        : 0.0;
    final averagePoints = _blendMetric(
      primary: rawAveragePoints > 0 ? rawAveragePoints : priorAveragePoints,
      fallback: priorAveragePoints,
      confidence: historyConfidence,
    );

    final rawApPerMatch = history.apPerMatch > 0
        ? history.apPerMatch
        : matchHistory.matches > 0
        ? (matchHistory.offenseAvg / 12).clamp(1.6, 8.2).toDouble()
        : 0.0;
    final apPerMatch = _blendMetric(
      primary: rawApPerMatch > 0 ? rawApPerMatch : priorApPerMatch,
      fallback: priorApPerMatch,
      confidence: historyConfidence,
    );

    final rawTopCutRate = history.topCutRate > 0
        ? history.topCutRate
        : matchHistory.eliminationMatches > 0
        ? (matchHistory.eliminationWinRate * 0.58).clamp(0.16, 0.78).toDouble()
        : 0.0;
    final topCutRate = _blendMetric(
      primary: rawTopCutRate > 0 ? rawTopCutRate : priorTopCutRate,
      fallback: priorTopCutRate,
      confidence: historyConfidence,
    );

    final rawStrengthOfSchedule = matchHistory.matches > 0
        ? matchHistory.strengthOfSchedule
        : 0.0;
    final strengthOfSchedule = _blendMetric(
      primary: rawStrengthOfSchedule > 0
          ? rawStrengthOfSchedule
          : priorStrengthOfSchedule,
      fallback: priorStrengthOfSchedule,
      confidence: historyConfidence,
    );

    final rawEliminationWinRate = matchHistory.eliminationMatches > 0
        ? matchHistory.eliminationWinRate
        : 0.0;
    final eliminationWinRate = _blendMetric(
      primary: rawEliminationWinRate > 0
          ? rawEliminationWinRate
          : priorEliminationWinRate,
      fallback: priorEliminationWinRate,
      confidence: historyConfidence,
    );

    final rawEventStrength = math.max(
      history.eventStrength,
      matchHistory.eventStrength,
    );
    final eventStrength = _blendMetric(
      primary: rawEventStrength > 1.0 ? rawEventStrength : priorEventStrength,
      fallback: priorEventStrength,
      confidence: historyConfidence,
    );

    final averagePointsBoost = ((averagePoints - 20) / 40)
        .clamp(0.0, 1.7)
        .toDouble();
    final winRateBoost = (blendedWinRate - 0.5) * 6.4;
    final topCutBoost = topCutRate * 3.0;
    final podiumBoost = history.podiumRate * 2.4;
    final eventVolumeBoost =
        (math.min(history.weightedEvents, 7.5) * 0.18) +
        math.min(matchHistory.weightedMatches / 12, 1.2);
    final scheduleBoost = (strengthOfSchedule - 0.5) * 5.8;
    final eliminationBoost = ((eliminationWinRate - 0.5) * 6.7);
    final eventStrengthBoost = (eventStrength - 1.0) * 4.6;
    final qualityWinBoost = (matchHistory.qualityWinRate - 0.5) * 5.0;
    final marginBoost = (matchHistory.marginAvg / 17)
        .clamp(-1.3, 2.7)
        .toDouble();
    final worldRankPenalty = (1 - worldSkillPrior) * 0.85;
    final rankPenalty = history.events == 0
        ? worldRankPenalty
        : ((history.averageRank - 1).clamp(0, 24) / 16.0) +
              (worldRankPenalty * 0.45);
    final badFinishPenalty = history.badFinishRate * 1.25;
    final volatilityPenalty = hasHistory
        ? (1 - matchHistory.reliability) * 0.95
        : (0.52 - (worldSkillPrior * 0.28)).clamp(0.18, 0.52);
    final repeatedHeavyLossPenalty =
        math.max(0, matchHistory.corroboratedHeavyLosses - 1) * 0.95;

    final mu =
        15.0 +
        averagePointsBoost +
        winRateBoost +
        topCutBoost +
        podiumBoost +
        eventVolumeBoost +
        scheduleBoost +
        eliminationBoost +
        eventStrengthBoost +
        qualityWinBoost +
        marginBoost -
        rankPenalty -
        badFinishPenalty -
        volatilityPenalty -
        repeatedHeavyLossPenalty;
    final sigma =
        (8.4 -
                (math.min(history.weightedEvents, 8) * 0.24) -
                math.min(matchHistory.weightedMatches / 15, 1.95) -
                math.min(matchHistory.eliminationMatches.toDouble() / 5, 0.78) -
                ((eventStrength - 1.0).clamp(0, 0.6) * 0.5) -
                (topCutRate * 0.36) +
                (history.events > 0 && history.events < 5 ? 0.85 : 0) +
                (history.badFinishRate * 0.62))
            .clamp(2.7, hasHistory ? 8.0 : 7.2)
            .toDouble();
    final ordinal = mu - (sigma * 2.75);
    final ccwm =
        ((blendedWinRate - 0.5) * 22) +
        (matchHistory.marginAvg / 7.0) +
        ((strengthOfSchedule - 0.5) * 6.2) +
        ((eliminationWinRate - 0.5) * 5.8);
    final opr =
        (averagePoints +
                math.max(matchHistory.offenseAvg * 0.32, 0) +
                ((strengthOfSchedule - 0.5) * 14) +
                (((eventStrength - 1.0).clamp(-0.1, 0.6)) * 10))
            .clamp(10, 145)
            .toDouble();
    final defenseFloor = math.max(matchHistory.defenseAvg * 0.24, 0);
    final dpr = math.max(0.0, (opr - ccwm) + defenseFloor);
    final awpPerMatch =
        (((apPerMatch / 10).clamp(0.0, 1.0) * 0.44) +
                (topCutRate * 0.18) +
                ((eliminationWinRate.clamp(0.0, 1.0)) * 0.18) +
                (((eventStrength - 0.9) / 0.7).clamp(0.0, 1.0) * 0.10) +
                ((strengthOfSchedule.clamp(0.0, 1.0)) * 0.10))
            .clamp(0.05, 0.97)
            .toDouble();
    final totalWins = matchHistory.matches > 0
        ? matchHistory.totalWins
        : history.totalWins;
    final totalLosses = matchHistory.matches > 0
        ? matchHistory.totalLosses
        : history.totalLosses;
    final totalTies = matchHistory.matches > 0
        ? matchHistory.totalTies
        : history.totalTies;

    return OpenSkillCacheEntry(
      ranking: 0,
      rankingChange: 0,
      teamNumber: entry.teamNumber,
      id: entry.teamId,
      gradeLevel: _gradeLevelFromProgram(entry.program),
      region: entry.region,
      country: entry.country,
      trueSkill: mu,
      openSkillMu: mu,
      openSkillSigma: sigma,
      openSkillOrdinal: ordinal,
      ratingSource: hasHistory ? 'solarize-history-v3' : 'solarize-prior-v3',
      ccwm: ccwm,
      totalWins: totalWins,
      totalLosses: totalLosses,
      totalTies: totalTies,
      apPerMatch: apPerMatch,
      awpPerMatch: awpPerMatch,
      wpPerMatch: blendedWinRate,
      opr: opr,
      dpr: dpr,
      strengthOfSchedule: strengthOfSchedule,
      eliminationWinRate: eliminationWinRate,
      eliminationMatches: matchHistory.eliminationMatches,
      eventStrength: eventStrength > 1.0 ? eventStrength : null,
      qualifiedForRegionals:
          hasHistory &&
              (history.topCutRate >= 0.35 || eliminationWinRate >= 0.6)
          ? 1
          : 0,
      qualifiedForWorlds:
          history.podiumRate >= 0.2 ||
              history.topCutRate >= 0.45 ||
              eliminationWinRate >= 0.72
          ? 1
          : 0,
    );
  }

  Map<String, _PerformanceProfile> _buildPerformanceProfiles({
    required List<WorldSkillsEntry> worldSkills,
    required Map<String, List<RankingRecord>> rankingsByTeam,
    required Map<String, List<MatchSummary>> matchesByTeam,
  }) {
    final profiles = <String, _PerformanceProfile>{};
    for (final entry in worldSkills) {
      final key = entry.teamNumber.trim().toUpperCase();
      final history = _HistorySnapshot.fromRankings(
        rankingsByTeam[key] ?? const <RankingRecord>[],
      );
      final rawMatchHistory = _MatchHistorySnapshot.fromMatches(
        matchesByTeam[key] ?? const <MatchSummary>[],
        teamNumber: entry.teamNumber,
        performanceProfiles: const <String, _PerformanceProfile>{},
      );
      profiles[key] = _PerformanceProfile.fromSnapshots(
        history: history,
        matchHistory: rawMatchHistory,
      );
    }
    return profiles;
  }
}

class _HistorySnapshot {
  const _HistorySnapshot({
    required this.events,
    required this.weightedEvents,
    required this.totalWins,
    required this.totalLosses,
    required this.totalTies,
    required this.topCutWeight,
    required this.podiumWeight,
    required this.badFinishWeight,
    required this.weightedRankTotal,
    required this.weightedRankSamples,
    required this.weightedAveragePoints,
    required this.weightedApTotal,
    required this.weightedMatches,
    required this.eventStrengthTotal,
  });

  const _HistorySnapshot.empty()
    : events = 0,
      weightedEvents = 0,
      totalWins = 0,
      totalLosses = 0,
      totalTies = 0,
      topCutWeight = 0,
      podiumWeight = 0,
      badFinishWeight = 0,
      weightedRankTotal = 0,
      weightedRankSamples = 0,
      weightedAveragePoints = 0,
      weightedApTotal = 0,
      weightedMatches = 0,
      eventStrengthTotal = 0;

  final int events;
  final double weightedEvents;
  final int totalWins;
  final int totalLosses;
  final int totalTies;
  final double topCutWeight;
  final double podiumWeight;
  final double badFinishWeight;
  final double weightedRankTotal;
  final double weightedRankSamples;
  final double weightedAveragePoints;
  final double weightedApTotal;
  final double weightedMatches;
  final double eventStrengthTotal;

  double get winRate {
    final matches = totalWins + totalLosses + totalTies;
    if (matches <= 0) {
      return 0.5;
    }
    return (totalWins + (totalTies * 0.5)) / matches;
  }

  double get topCutRate {
    if (weightedEvents <= 0) {
      return 0;
    }
    return topCutWeight / weightedEvents;
  }

  double get podiumRate {
    if (weightedEvents <= 0) {
      return 0;
    }
    return podiumWeight / weightedEvents;
  }

  double get badFinishRate {
    if (weightedEvents <= 0) {
      return 0;
    }
    return badFinishWeight / weightedEvents;
  }

  double get averageRank {
    if (weightedRankSamples <= 0) {
      return 0;
    }
    return weightedRankTotal / weightedRankSamples;
  }

  double get averagePoints {
    if (weightedMatches <= 0) {
      return 0;
    }
    return weightedAveragePoints / weightedMatches;
  }

  double get apPerMatch {
    if (weightedMatches <= 0) {
      return 0;
    }
    return weightedApTotal / weightedMatches;
  }

  double get eventStrength {
    if (weightedEvents <= 0) {
      return 1.0;
    }
    return eventStrengthTotal / weightedEvents;
  }

  factory _HistorySnapshot.fromRankings(List<RankingRecord> rankings) {
    if (rankings.isEmpty) {
      return const _HistorySnapshot.empty();
    }

    var wins = 0;
    var losses = 0;
    var ties = 0;
    var weightedEvents = 0.0;
    var topCutWeight = 0.0;
    var podiumWeight = 0.0;
    var badFinishWeight = 0.0;
    var weightedRankTotal = 0.0;
    var weightedRankSamples = 0.0;
    var weightedAveragePoints = 0.0;
    var weightedApTotal = 0.0;
    var weightedMatches = 0.0;
    var eventStrengthTotal = 0.0;

    for (final ranking in rankings) {
      final teamMatches =
          math.max(ranking.wins, 0).toInt() +
          math.max(ranking.losses, 0).toInt() +
          math.max(ranking.ties, 0).toInt();
      final eventWeight = _eventTierWeight(ranking.event.name);
      final sampleWeight = eventWeight * math.max(teamMatches, 1);

      wins += math.max(ranking.wins, 0).toInt();
      losses += math.max(ranking.losses, 0).toInt();
      ties += math.max(ranking.ties, 0).toInt();
      weightedEvents += eventWeight;
      eventStrengthTotal += eventWeight * eventWeight;
      weightedApTotal += math.max(ranking.ap, 0).toDouble() * eventWeight;
      weightedMatches += sampleWeight;

      if (ranking.rank > 0) {
        weightedRankTotal += ranking.rank.toDouble() * eventWeight;
        weightedRankSamples += eventWeight;
        if (ranking.rank <= 8) {
          topCutWeight += eventWeight;
        }
        if (ranking.rank <= 3) {
          podiumWeight += eventWeight;
        }
        if (ranking.rank > 16) {
          badFinishWeight += eventWeight;
        }
      }

      if (ranking.averagePoints > 0) {
        weightedAveragePoints += ranking.averagePoints * sampleWeight;
      }
    }

    return _HistorySnapshot(
      events: rankings.length,
      weightedEvents: weightedEvents,
      totalWins: wins,
      totalLosses: losses,
      totalTies: ties,
      topCutWeight: topCutWeight,
      podiumWeight: podiumWeight,
      badFinishWeight: badFinishWeight,
      weightedRankTotal: weightedRankTotal,
      weightedRankSamples: weightedRankSamples,
      weightedAveragePoints: weightedAveragePoints,
      weightedApTotal: weightedApTotal,
      weightedMatches: weightedMatches,
      eventStrengthTotal: eventStrengthTotal,
    );
  }
}

class _MatchHistorySnapshot {
  const _MatchHistorySnapshot({
    required this.matches,
    required this.totalWins,
    required this.totalLosses,
    required this.totalTies,
    required this.eliminationMatches,
    required this.corroboratedHeavyLosses,
    required this.weightedMatches,
    required this.winRate,
    required this.eliminationWinRate,
    required this.strengthOfSchedule,
    required this.eventStrength,
    required this.marginAvg,
    required this.offenseAvg,
    required this.defenseAvg,
    required this.qualityWinRate,
  });

  const _MatchHistorySnapshot.empty()
    : matches = 0,
      totalWins = 0,
      totalLosses = 0,
      totalTies = 0,
      eliminationMatches = 0,
      corroboratedHeavyLosses = 0,
      weightedMatches = 0,
      winRate = 0.5,
      eliminationWinRate = 0.5,
      strengthOfSchedule = 0.5,
      eventStrength = 1.0,
      marginAvg = 0,
      offenseAvg = 0,
      defenseAvg = 0,
      qualityWinRate = 0.5;

  final int matches;
  final int totalWins;
  final int totalLosses;
  final int totalTies;
  final int eliminationMatches;
  final int corroboratedHeavyLosses;
  final double weightedMatches;
  final double winRate;
  final double eliminationWinRate;
  final double strengthOfSchedule;
  final double eventStrength;
  final double marginAvg;
  final double offenseAvg;
  final double defenseAvg;
  final double qualityWinRate;

  double get reliability {
    final matchConfidence = (math.min(weightedMatches, 20) / 20) * 0.7;
    final eliminationConfidence =
        (math.min(eliminationMatches.toDouble(), 6) / 6) * 0.3;
    return (matchConfidence + eliminationConfidence).clamp(0.0, 1.0);
  }

  factory _MatchHistorySnapshot.fromMatches(
    List<MatchSummary> matches, {
    required String teamNumber,
    required Map<String, _PerformanceProfile> performanceProfiles,
  }) {
    if (matches.isEmpty) {
      return const _MatchHistorySnapshot.empty();
    }

    final officialMatches =
        matches.where(_hasOfficialScore).toList(growable: false)
          ..sort(_compareMatchesChronologically);
    if (officialMatches.isEmpty) {
      return const _MatchHistorySnapshot.empty();
    }

    final recentWindow = officialMatches.length > 28
        ? officialMatches.sublist(officialMatches.length - 28)
        : officialMatches;

    final normalizedTeamNumber = teamNumber.trim().toUpperCase();
    final analyzedMatches = <_AnalyzedMatchSample>[];
    for (var index = 0; index < recentWindow.length; index++) {
      final match = recentWindow[index];
      final alliance = _findAllianceForTeam(match, normalizedTeamNumber);
      final opponent = alliance == null
          ? null
          : _opposingAlliance(match, alliance);
      if (alliance == null || opponent == null) {
        continue;
      }

      final opponentStrength = _averageOpponentStrength(
        opponent.teams,
        performanceProfiles: performanceProfiles,
      );
      final eventWeight = _eventTierWeight(match.event.name);
      final roundWeight = _roundWeight(match.round);
      final recencyWeight = recentWindow.length <= 1
          ? 1.0
          : 0.35 +
                (math.pow(index / (recentWindow.length - 1), 1.85) * 1.55)
                    .toDouble();
      final outcome = alliance.score > opponent.score
          ? 1.0
          : alliance.score == opponent.score
          ? 0.5
          : 0.0;

      analyzedMatches.add(
        _AnalyzedMatchSample(
          round: match.round,
          score: alliance.score,
          against: opponent.score,
          outcome: outcome,
          margin: alliance.score - opponent.score,
          opponentStrength: opponentStrength,
          eventWeight: eventWeight,
          roundWeight: roundWeight,
          recencyWeight: recencyWeight,
        ),
      );
    }

    if (analyzedMatches.isEmpty) {
      return const _MatchHistorySnapshot.empty();
    }

    final scoreMedian = _median(
      analyzedMatches.map((sample) => sample.score.toDouble()),
    );
    final scoreMad = _mad(
      analyzedMatches.map((sample) => sample.score.toDouble()).toList(),
      center: scoreMedian,
    );
    final marginMedian = _median(
      analyzedMatches.map((sample) => sample.margin.toDouble()),
    );
    final marginMad = _mad(
      analyzedMatches.map((sample) => sample.margin.toDouble()).toList(),
      center: marginMedian,
    );
    final severeLossMarginFloor = math
        .min(-24.0, marginMedian - math.max(14.0, marginMad * 3.0))
        .toDouble();
    final severeLossScoreCeiling = math
        .max(0.0, scoreMedian - math.max(12.0, scoreMad * 2.6))
        .toDouble();

    var weightedMatches = 0.0;
    var weightedWins = 0.0;
    var weightedTies = 0.0;
    var weightedMargin = 0.0;
    var weightedOffense = 0.0;
    var weightedDefense = 0.0;
    var weightedSchedule = 0.0;
    var weightedEventStrength = 0.0;
    var weightedQualityNet = 0.0;
    var totalWins = 0;
    var totalLosses = 0;
    var totalTies = 0;
    var eliminationMatches = 0;
    var weightedEliminationMatches = 0.0;
    var weightedEliminationWins = 0.0;
    var weightedEliminationTies = 0.0;
    var corroboratedHeavyLosses = 0;

    for (final sample in analyzedMatches) {
      if (_isLikelyErrantLoss(
        sample,
        analyzedMatches,
        severeLossMarginFloor: severeLossMarginFloor,
        severeLossScoreCeiling: severeLossScoreCeiling,
      )) {
        continue;
      }

      var weight =
          sample.eventWeight * sample.roundWeight * sample.recencyWeight;
      final corroboratedHeavyLoss = _isCorroboratedHeavyLoss(
        sample,
        analyzedMatches,
        severeLossMarginFloor: severeLossMarginFloor,
      );
      if (corroboratedHeavyLoss) {
        weight *= 1.08;
        corroboratedHeavyLosses += 1;
      }

      weightedMatches += weight;
      weightedOffense += sample.score * weight;
      weightedDefense += sample.against * weight;
      weightedMargin += sample.margin * weight;
      weightedSchedule += sample.opponentStrength * weight;
      weightedEventStrength += sample.eventWeight * weight;
      weightedQualityNet +=
          ((((sample.outcome * 2) - 1) * sample.opponentStrength) * weight);

      if (sample.outcome == 1.0) {
        weightedWins += weight;
        totalWins += 1;
      } else if (sample.outcome == 0.5) {
        weightedTies += weight;
        totalTies += 1;
      } else {
        totalLosses += 1;
      }

      if (_isEliminationRound(sample.round)) {
        eliminationMatches += 1;
        weightedEliminationMatches += weight;
        if (sample.outcome == 1.0) {
          weightedEliminationWins += weight;
        } else if (sample.outcome == 0.5) {
          weightedEliminationTies += weight;
        }
      }
    }

    if (weightedMatches == 0) {
      return const _MatchHistorySnapshot.empty();
    }

    return _MatchHistorySnapshot(
      matches: totalWins + totalLosses + totalTies,
      totalWins: totalWins,
      totalLosses: totalLosses,
      totalTies: totalTies,
      eliminationMatches: eliminationMatches,
      corroboratedHeavyLosses: corroboratedHeavyLosses,
      weightedMatches: weightedMatches,
      winRate: (weightedWins + (weightedTies * 0.5)) / weightedMatches,
      eliminationWinRate: weightedEliminationMatches <= 0
          ? 0.5
          : (weightedEliminationWins + (weightedEliminationTies * 0.5)) /
                weightedEliminationMatches,
      strengthOfSchedule: weightedSchedule / weightedMatches,
      eventStrength: weightedEventStrength / weightedMatches,
      marginAvg: weightedMargin / weightedMatches,
      offenseAvg: weightedOffense / weightedMatches,
      defenseAvg: weightedDefense / weightedMatches,
      qualityWinRate:
          (((weightedQualityNet / weightedMatches).clamp(-1.0, 1.0)) + 1.0) /
          2.0,
    );
  }
}

class _PerformanceProfile {
  const _PerformanceProfile({required this.strength});

  final double strength;

  factory _PerformanceProfile.fromSnapshots({
    required _HistorySnapshot history,
    required _MatchHistorySnapshot matchHistory,
  }) {
    final hasSamples = history.events > 0 || matchHistory.matches > 0;
    if (!hasSamples) {
      return const _PerformanceProfile(strength: 0.5);
    }

    final marginNorm = ((matchHistory.marginAvg + 18) / 36)
        .clamp(0.0, 1.0)
        .toDouble();
    final topCutNorm = ((history.topCutRate * 1.1) + (history.podiumRate * 0.4))
        .clamp(0.0, 1.0)
        .toDouble();
    final eventStrengthNorm =
        ((math.max(history.eventStrength, matchHistory.eventStrength) - 0.8) /
                0.9)
            .clamp(0.0, 1.0)
            .toDouble();

    return _PerformanceProfile(
      strength:
          ((history.winRate * 0.26) +
                  (matchHistory.winRate * 0.28) +
                  (marginNorm * 0.18) +
                  ((matchHistory.eliminationMatches > 0
                          ? matchHistory.eliminationWinRate
                          : 0.5) *
                      0.14) +
                  (topCutNorm * 0.08) +
                  (eventStrengthNorm * 0.06))
              .clamp(0.0, 1.0)
              .toDouble(),
    );
  }
}

double _worldSkillPrior(WorldSkillsEntry entry) {
  final rankSignal = entry.rank <= 0
      ? 0.35
      : (1.0 - (math.log(entry.rank + 1) / math.log(4200)))
            .clamp(0.0, 1.0)
            .toDouble();
  final combinedSignal = (entry.combinedScore / 230).clamp(0.0, 1.0).toDouble();
  final programmingSignal = (entry.programmingScore / 120)
      .clamp(0.0, 1.0)
      .toDouble();
  final driverSignal = (entry.driverScore / 120).clamp(0.0, 1.0).toDouble();

  return ((rankSignal * 0.55) +
          (combinedSignal * 0.30) +
          (programmingSignal * 0.08) +
          (driverSignal * 0.07))
      .clamp(0.0, 1.0)
      .toDouble();
}

double _blendMetric({
  required double primary,
  required double fallback,
  required double confidence,
}) {
  if (primary.isNaN || primary.isInfinite) {
    return fallback;
  }
  final weight = confidence.clamp(0.0, 1.0).toDouble();
  return (primary * weight) + (fallback * (1 - weight));
}

double _eventTierWeight(String name) {
  final normalized = name.trim().toLowerCase();
  if (normalized.isEmpty) {
    return 1.0;
  }
  if (normalized.contains('world championship') ||
      normalized.contains('worlds')) {
    return 1.7;
  }
  if (normalized.contains('signature')) {
    return 1.45;
  }
  if (normalized.contains('national') ||
      normalized.contains('state championship') ||
      normalized.contains('regional championship') ||
      normalized.contains('provincial championship')) {
    return 1.28;
  }
  if (normalized.contains('league')) {
    return 0.92;
  }
  if (normalized.contains('scrimmage') || normalized.contains('practice')) {
    return 0.72;
  }
  return 1.0;
}

bool _isLikelyErrantLoss(
  _AnalyzedMatchSample sample,
  List<_AnalyzedMatchSample> population, {
  required double severeLossMarginFloor,
  required double severeLossScoreCeiling,
}) {
  if (sample.outcome != 0.0) {
    return false;
  }

  final severeMargin = sample.margin <= severeLossMarginFloor;
  final severeScoreDrop = sample.score <= severeLossScoreCeiling;
  if (!severeMargin || !severeScoreDrop) {
    return false;
  }

  final corroborated = _isCorroboratedHeavyLoss(
    sample,
    population,
    severeLossMarginFloor: severeLossMarginFloor,
  );
  if (corroborated) {
    return false;
  }

  return sample.opponentStrength < 0.72 &&
      !_isEliminationRound(sample.round) &&
      sample.eventWeight <= 1.1;
}

bool _isCorroboratedHeavyLoss(
  _AnalyzedMatchSample sample,
  List<_AnalyzedMatchSample> population, {
  required double severeLossMarginFloor,
}) {
  if (sample.outcome != 0.0) {
    return false;
  }

  final similarBadLosses = population.where((candidate) {
    return candidate.outcome == 0.0 &&
        candidate.margin <= (severeLossMarginFloor + 8) &&
        candidate.score <= (sample.score + 8);
  }).length;

  return similarBadLosses >= 2 ||
      sample.opponentStrength >= 0.72 ||
      _isEliminationRound(sample.round) ||
      sample.eventWeight >= 1.18;
}

double _roundWeight(MatchRound round) {
  switch (round) {
    case MatchRound.none:
    case MatchRound.practice:
      return 0.0;
    case MatchRound.qualification:
      return 1.0;
    case MatchRound.round128:
      return 1.12;
    case MatchRound.round64:
      return 1.16;
    case MatchRound.round32:
      return 1.2;
    case MatchRound.round16:
      return 1.28;
    case MatchRound.quarterfinals:
      return 1.42;
    case MatchRound.semifinals:
      return 1.58;
    case MatchRound.finals:
      return 1.78;
  }
}

bool _isEliminationRound(MatchRound round) {
  return round != MatchRound.none &&
      round != MatchRound.practice &&
      round != MatchRound.qualification;
}

double _averageOpponentStrength(
  List<TeamReference> teams, {
  required Map<String, _PerformanceProfile> performanceProfiles,
}) {
  var total = 0.0;
  var count = 0;
  for (final team in teams) {
    final profile = performanceProfiles[team.number.trim().toUpperCase()];
    if (profile == null) {
      continue;
    }
    total += profile.strength;
    count += 1;
  }

  if (count == 0) {
    return 0.5;
  }
  return total / count;
}

String _gradeLevelFromProgram(String program) {
  final normalized = program.trim().toLowerCase();
  if (normalized.contains('elementary')) {
    return 'Elementary School';
  }
  if (normalized.contains('middle')) {
    return 'Middle School';
  }
  return 'High School';
}

bool _hasOfficialScore(MatchSummary match) {
  final red = _allianceForColor(match, 'red');
  final blue = _allianceForColor(match, 'blue');
  return red != null &&
      blue != null &&
      red.score >= 0 &&
      blue.score >= 0 &&
      match.round != MatchRound.none &&
      match.round != MatchRound.practice;
}

MatchAlliance? _allianceForColor(MatchSummary match, String color) {
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

MatchAlliance? _findAllianceForTeam(MatchSummary match, String teamNumber) {
  for (final alliance in match.alliances) {
    for (final allianceTeam in alliance.teams) {
      if (allianceTeam.number.trim().toUpperCase() == teamNumber) {
        return alliance;
      }
    }
  }
  return null;
}

MatchAlliance? _opposingAlliance(MatchSummary match, MatchAlliance alliance) {
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

int _compareMatchesChronologically(MatchSummary left, MatchSummary right) {
  final leftAnchor = left.started ?? left.scheduled;
  final rightAnchor = right.started ?? right.scheduled;
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

double _median(Iterable<double> values) {
  final sorted = values.toList(growable: false)..sort();
  if (sorted.isEmpty) {
    return 0.0;
  }
  final middle = sorted.length ~/ 2;
  if (sorted.length.isOdd) {
    return sorted[middle];
  }
  return (sorted[middle - 1] + sorted[middle]) / 2;
}

double _mad(List<double> values, {required double center}) {
  if (values.isEmpty) {
    return 0.0;
  }
  final deviations = values
      .map((value) => (value - center).abs())
      .toList(growable: false);
  return _median(deviations);
}

class _AnalyzedMatchSample {
  const _AnalyzedMatchSample({
    required this.round,
    required this.score,
    required this.against,
    required this.outcome,
    required this.margin,
    required this.opponentStrength,
    required this.eventWeight,
    required this.roundWeight,
    required this.recencyWeight,
  });

  final MatchRound round;
  final int score;
  final int against;
  final double outcome;
  final int margin;
  final double opponentStrength;
  final double eventWeight;
  final double roundWeight;
  final double recencyWeight;
}
