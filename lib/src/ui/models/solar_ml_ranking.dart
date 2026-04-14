class SolarMlRankingEntry {
  const SolarMlRankingEntry({
    required this.rank,
    required this.teamId,
    required this.teamNumber,
    required this.teamName,
    required this.organization,
    required this.city,
    required this.region,
    required this.country,
    required this.mlRating,
    required this.projectedWinShare,
    required this.ceilingScore,
    required this.stability,
    required this.worldRank,
    required this.combinedScore,
    required this.programmingScore,
    required this.driverScore,
    required this.ordinal,
    required this.openSkillMu,
    required this.openSkillSigma,
    required this.ccwm,
    required this.opr,
    required this.dpr,
    required this.awpPerMatch,
  });

  final int rank;
  final int teamId;
  final String teamNumber;
  final String teamName;
  final String organization;
  final String city;
  final String region;
  final String country;
  final double mlRating;
  final double projectedWinShare;
  final double ceilingScore;
  final double stability;
  final int? worldRank;
  final int combinedScore;
  final int programmingScore;
  final int driverScore;
  final double? ordinal;
  final double? openSkillMu;
  final double? openSkillSigma;
  final double? ccwm;
  final double? opr;
  final double? dpr;
  final double? awpPerMatch;

  double get solarRating => mlRating;
}
