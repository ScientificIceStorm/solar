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

  factory SolarMlRankingEntry.fromJson(Map<String, dynamic> json) {
    return SolarMlRankingEntry(
      rank: (json['rank'] as num?)?.toInt() ?? 0,
      teamId: (json['teamId'] as num?)?.toInt() ?? 0,
      teamNumber: (json['teamNumber'] as String?) ?? '',
      teamName: (json['teamName'] as String?) ?? '',
      organization: (json['organization'] as String?) ?? '',
      city: (json['city'] as String?) ?? '',
      region: (json['region'] as String?) ?? '',
      country: (json['country'] as String?) ?? '',
      mlRating: (json['mlRating'] as num?)?.toDouble() ?? 0,
      projectedWinShare:
          (json['projectedWinShare'] as num?)?.toDouble() ?? 0,
      ceilingScore: (json['ceilingScore'] as num?)?.toDouble() ?? 0,
      stability: (json['stability'] as num?)?.toDouble() ?? 0,
      worldRank: json['worldRank'] is num
          ? (json['worldRank'] as num).toInt()
          : null,
      combinedScore: (json['combinedScore'] as num?)?.toInt() ?? 0,
      programmingScore: (json['programmingScore'] as num?)?.toInt() ?? 0,
      driverScore: (json['driverScore'] as num?)?.toInt() ?? 0,
      ordinal: (json['ordinal'] as num?)?.toDouble(),
      openSkillMu: (json['openSkillMu'] as num?)?.toDouble(),
      openSkillSigma: (json['openSkillSigma'] as num?)?.toDouble(),
      ccwm: (json['ccwm'] as num?)?.toDouble(),
      opr: (json['opr'] as num?)?.toDouble(),
      dpr: (json['dpr'] as num?)?.toDouble(),
      awpPerMatch: (json['awpPerMatch'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'rank': rank,
      'teamId': teamId,
      'teamNumber': teamNumber,
      'teamName': teamName,
      'organization': organization,
      'city': city,
      'region': region,
      'country': country,
      'mlRating': mlRating,
      'projectedWinShare': projectedWinShare,
      'ceilingScore': ceilingScore,
      'stability': stability,
      'worldRank': worldRank,
      'combinedScore': combinedScore,
      'programmingScore': programmingScore,
      'driverScore': driverScore,
      'ordinal': ordinal,
      'openSkillMu': openSkillMu,
      'openSkillSigma': openSkillSigma,
      'ccwm': ccwm,
      'opr': opr,
      'dpr': dpr,
      'awpPerMatch': awpPerMatch,
    };
  }
}
