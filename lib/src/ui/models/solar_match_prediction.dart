import '../../core/solar_competition_scope.dart';
import '../../models/robot_events_models.dart';

class SolarQuickviewSnapshot {
  const SolarQuickviewSnapshot({
    required this.event,
    required this.futureMatches,
    this.nextQualifyingMatch,
  });

  final EventSummary event;
  final MatchSummary? nextQualifyingMatch;
  final List<MatchSummary> futureMatches;

  bool get hasUpcomingMatch => nextQualifyingMatch != null;
}

class SolarMatchPrediction {
  const SolarMatchPrediction({
    required this.match,
    required this.event,
    required this.redAlliance,
    required this.blueAlliance,
    required this.redWinProbability,
    required this.blueWinProbability,
    required this.predictedRedScore,
    required this.predictedBlueScore,
    required this.confidence,
    required this.favoredAllianceColor,
    required this.evidenceMatches,
    required this.insights,
  });

  final MatchSummary match;
  final EventSummary? event;
  final SolarAlliancePrediction redAlliance;
  final SolarAlliancePrediction blueAlliance;
  final double redWinProbability;
  final double blueWinProbability;
  final int predictedRedScore;
  final int predictedBlueScore;
  final double confidence;
  final String favoredAllianceColor;
  final int evidenceMatches;
  final List<String> insights;

  bool get hasActualResult =>
      redAlliance.actualScore != null && blueAlliance.actualScore != null;

  int? get actualRedScore => redAlliance.actualScore;

  int? get actualBlueScore => blueAlliance.actualScore;

  String get favoredAllianceLabel =>
      favoredAllianceColor.toLowerCase() == 'red' ? 'Red' : 'Blue';

  double get favoredWinProbability =>
      favoredAllianceColor.toLowerCase() == 'red'
      ? redWinProbability
      : blueWinProbability;

  int get predictedMargin => predictedRedScore - predictedBlueScore;

  int? get actualMargin {
    if (!hasActualResult) {
      return null;
    }
    return actualRedScore! - actualBlueScore!;
  }

  int? get totalScoreError {
    if (!hasActualResult) {
      return null;
    }
    return (predictedRedScore - actualRedScore!).abs() +
        (predictedBlueScore - actualBlueScore!).abs();
  }

  int? get marginError {
    final actual = actualMargin;
    if (actual == null) {
      return null;
    }
    return (predictedMargin - actual).abs();
  }

  bool? get predictedCorrectly {
    if (!hasActualResult) {
      return null;
    }

    final actualMargin = actualRedScore! - actualBlueScore!;
    if (actualMargin == 0) {
      return null;
    }

    return predictedMargin == 0
        ? null
        : (predictedMargin.isNegative == actualMargin.isNegative);
  }

  String get predictionDeltaLabel {
    final total = totalScoreError;
    if (total == null) {
      return 'Pending result';
    }
    return 'Off by $total points';
  }

  String get predictionDeltaSummary {
    final total = totalScoreError;
    final margin = marginError;
    if (total == null || margin == null) {
      return '$solarizeLabel will grade itself after the match finishes.';
    }
    if (total >= 28 || (predictedCorrectly == false && margin >= 18)) {
      return 'This swung hard from the projection. A disconnect, tip, or auton miss likely changed the result.';
    }
    if (total >= 14 || margin >= 10) {
      return 'The match ran noticeably different than expected, likely because one alliance cycled faster or missed key scoring chances.';
    }
    return '$solarizeLabel tracked this one closely and stayed near the final result.';
  }

  bool get estimatedRedAwpAwarded {
    final winner = _actualWinnerColor ?? favoredAllianceColor.toLowerCase();
    return winner == 'red' && redAlliance.awpPotential >= 0.55;
  }

  bool get estimatedBlueAwpAwarded {
    final winner = _actualWinnerColor ?? favoredAllianceColor.toLowerCase();
    return winner == 'blue' && blueAlliance.awpPotential >= 0.55;
  }

  String? get _actualWinnerColor {
    if (!hasActualResult) {
      return null;
    }
    if (actualRedScore! > actualBlueScore!) {
      return 'red';
    }
    if (actualBlueScore! > actualRedScore!) {
      return 'blue';
    }
    return null;
  }
}

class SolarAlliancePrediction {
  const SolarAlliancePrediction({
    required this.color,
    required this.teams,
    required this.strength,
    required this.offense,
    required this.defense,
    required this.momentum,
    required this.awpPotential,
    required this.projectedScore,
    required this.actualScore,
  });

  final String color;
  final List<SolarTeamPrediction> teams;
  final double strength;
  final double offense;
  final double defense;
  final double momentum;
  final double awpPotential;
  final double projectedScore;
  final int? actualScore;
}

class SolarTeamPrediction {
  const SolarTeamPrediction({
    required this.team,
    required this.compositeRating,
    required this.offense,
    required this.defense,
    required this.momentum,
    required this.coverage,
    required this.winRate,
    required this.priorEventMatches,
    required this.priorSeasonMatches,
    required this.eventCombinedSkills,
    required this.eventDriverScore,
    required this.eventAutonScore,
    required this.worldRank,
    required this.worldCombinedScore,
    required this.openSkillOrdinal,
    required this.openSkillOpr,
    required this.openSkillDpr,
    required this.openSkillCcwm,
    required this.openSkillAwpPerMatch,
  });

  final TeamReference team;
  final double compositeRating;
  final double offense;
  final double defense;
  final double momentum;
  final double coverage;
  final double winRate;
  final int priorEventMatches;
  final int priorSeasonMatches;
  final int? eventCombinedSkills;
  final int? eventDriverScore;
  final int? eventAutonScore;
  final int? worldRank;
  final int? worldCombinedScore;
  final double? openSkillOrdinal;
  final double? openSkillOpr;
  final double? openSkillDpr;
  final double? openSkillCcwm;
  final double? openSkillAwpPerMatch;
}
