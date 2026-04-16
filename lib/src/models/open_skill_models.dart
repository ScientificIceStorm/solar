import '../core/json_utils.dart';

class OpenSkillCacheEntry {
  const OpenSkillCacheEntry({
    required this.ranking,
    required this.rankingChange,
    required this.teamNumber,
    required this.id,
    required this.region,
    required this.country,
    required this.trueSkill,
    required this.openSkillMu,
    required this.openSkillSigma,
    required this.openSkillOrdinal,
    required this.ratingSource,
    required this.ccwm,
    required this.totalWins,
    required this.totalLosses,
    required this.totalTies,
    required this.apPerMatch,
    required this.awpPerMatch,
    required this.wpPerMatch,
    required this.opr,
    required this.dpr,
    required this.strengthOfSchedule,
    required this.eliminationWinRate,
    required this.eliminationMatches,
    required this.eventStrength,
    required this.qualifiedForRegionals,
    required this.qualifiedForWorlds,
  });

  final int ranking;
  final int rankingChange;
  final String teamNumber;
  final int id;
  final String region;
  final String country;
  final double trueSkill;
  final double openSkillMu;
  final double openSkillSigma;
  final double openSkillOrdinal;
  final String ratingSource;
  final double? ccwm;
  final int totalWins;
  final int totalLosses;
  final int totalTies;
  final double apPerMatch;
  final double awpPerMatch;
  final double wpPerMatch;
  final double? opr;
  final double? dpr;
  final double? strengthOfSchedule;
  final double? eliminationWinRate;
  final int eliminationMatches;
  final double? eventStrength;
  final int qualifiedForRegionals;
  final int qualifiedForWorlds;

  factory OpenSkillCacheEntry.fromJson(JsonMap json) {
    return OpenSkillCacheEntry(
      ranking: readInt(json['ts_ranking'] ?? json['ranking'] ?? json['rank']),
      rankingChange: readInt(json['ranking_change'] ?? json['rankingChange']),
      teamNumber: firstNonEmpty(<String?>[
        readString(json['team_number']),
        readString(json['teamNumber']),
        readString(json['number']),
      ]),
      id: readInt(json['id'] ?? json['team_id']),
      region: firstNonEmpty(<String?>[
        readString(json['loc_region']),
        readString(json['locRegion']),
        readString(json['region']),
      ]),
      country: firstNonEmpty(<String?>[
        readString(json['loc_country']),
        readString(json['locCountry']),
        readString(json['country']),
      ]),
      trueSkill: readDouble(json['trueskill'] ?? json['trueSkill']),
      openSkillMu: readDouble(json['openskill_mu'] ?? json['openSkillMu'], 25),
      openSkillSigma: readDouble(
        json['openskill_sigma'] ?? json['openSkillSigma'],
        25 / 3,
      ),
      openSkillOrdinal: readDouble(
        json['openskill_ordinal'] ?? json['openSkillOrdinal'],
      ),
      ratingSource: readString(json['rating_source'] ?? json['ratingSource']),
      ccwm: json['ccwm'] == null ? null : readDouble(json['ccwm']),
      totalWins: readInt(json['total_wins'] ?? json['totalWins']),
      totalLosses: readInt(json['total_losses'] ?? json['totalLosses']),
      totalTies: readInt(json['total_ties'] ?? json['totalTies']),
      apPerMatch: readDouble(json['ap_per_match'] ?? json['apPerMatch']),
      awpPerMatch: readDouble(json['awp_per_match'] ?? json['awpPerMatch']),
      wpPerMatch: readDouble(json['wp_per_match'] ?? json['wpPerMatch']),
      opr: json['opr'] == null ? null : readDouble(json['opr']),
      dpr: json['dpr'] == null ? null : readDouble(json['dpr']),
      strengthOfSchedule:
          json['strength_of_schedule'] == null &&
              json['strengthOfSchedule'] == null
          ? null
          : readDouble(
              json['strength_of_schedule'] ?? json['strengthOfSchedule'],
            ),
      eliminationWinRate:
          json['elimination_win_rate'] == null &&
              json['eliminationWinRate'] == null
          ? null
          : readDouble(
              json['elimination_win_rate'] ?? json['eliminationWinRate'],
            ),
      eliminationMatches: readInt(
        json['elimination_matches'] ?? json['eliminationMatches'],
      ),
      eventStrength:
          json['event_strength'] == null && json['eventStrength'] == null
          ? null
          : readDouble(json['event_strength'] ?? json['eventStrength']),
      qualifiedForRegionals: readInt(
        json['qualified_for_regionals'] ?? json['qualifiedForRegionals'],
      ),
      qualifiedForWorlds: readInt(
        json['qualified_for_worlds'] ?? json['qualifiedForWorlds'],
      ),
    );
  }

  JsonMap toJson() {
    return <String, dynamic>{
      'ranking': ranking,
      'rankingChange': rankingChange,
      'teamNumber': teamNumber,
      'id': id,
      'region': region,
      'country': country,
      'trueSkill': trueSkill,
      'openSkillMu': openSkillMu,
      'openSkillSigma': openSkillSigma,
      'openSkillOrdinal': openSkillOrdinal,
      'ratingSource': ratingSource,
      'ccwm': ccwm,
      'totalWins': totalWins,
      'totalLosses': totalLosses,
      'totalTies': totalTies,
      'apPerMatch': apPerMatch,
      'awpPerMatch': awpPerMatch,
      'wpPerMatch': wpPerMatch,
      'opr': opr,
      'dpr': dpr,
      'strengthOfSchedule': strengthOfSchedule,
      'eliminationWinRate': eliminationWinRate,
      'eliminationMatches': eliminationMatches,
      'eventStrength': eventStrength,
      'qualifiedForRegionals': qualifiedForRegionals,
      'qualifiedForWorlds': qualifiedForWorlds,
    };
  }
}

class OpenSkillPlayer {
  const OpenSkillPlayer({
    required this.name,
    required this.mu,
    required this.sigma,
  });

  final String name;
  final double mu;
  final double sigma;

  factory OpenSkillPlayer.fromJson(JsonMap json) {
    return OpenSkillPlayer(
      name: readString(json['name']),
      mu: readDouble(json['mu'], 25),
      sigma: readDouble(json['sigma'], 25 / 3),
    );
  }

  JsonMap toJson() {
    return <String, dynamic>{'name': name, 'mu': mu, 'sigma': sigma};
  }
}

class OpenSkillPredictionRequest {
  const OpenSkillPredictionRequest({required this.teams});

  final List<List<OpenSkillPlayer>> teams;

  factory OpenSkillPredictionRequest.fromJson(JsonMap json) {
    final rawTeams = json['teams'];
    if (rawTeams is! List) {
      return const OpenSkillPredictionRequest(teams: <List<OpenSkillPlayer>>[]);
    }

    final teams = rawTeams
        .map((team) {
          if (team is! List) {
            return const <OpenSkillPlayer>[];
          }
          return team
              .whereType<Map>()
              .map((player) => OpenSkillPlayer.fromJson(asJsonMap(player)))
              .toList(growable: false);
        })
        .toList(growable: false);

    return OpenSkillPredictionRequest(teams: teams);
  }

  JsonMap toJson() {
    return <String, dynamic>{
      'teams': teams
          .map((team) => team.map((player) => player.toJson()).toList())
          .toList(),
    };
  }
}

class OpenSkillPredictionResponse {
  const OpenSkillPredictionResponse({required this.probabilities});

  final List<double> probabilities;

  factory OpenSkillPredictionResponse.fromJson(JsonMap json) {
    final values = json['probabilities'];
    if (values is! List) {
      return const OpenSkillPredictionResponse(probabilities: <double>[]);
    }
    return OpenSkillPredictionResponse(
      probabilities: values
          .map((value) => readDouble(value))
          .toList(growable: false),
    );
  }

  JsonMap toJson() {
    return <String, dynamic>{'probabilities': probabilities};
  }
}
