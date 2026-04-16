import '../core/json_utils.dart';

class SeasonSummary {
  const SeasonSummary({
    required this.id,
    required this.name,
    required this.programId,
    required this.programName,
  });

  final int id;
  final String name;
  final int programId;
  final String programName;

  factory SeasonSummary.fromJson(JsonMap json) {
    final program = asJsonMap(json['program']);
    return SeasonSummary(
      id: readInt(json['id']),
      name: readString(json['name']),
      programId: readInt(program['id'] ?? json['programId']),
      programName: readString(program['name'] ?? json['programName']),
    );
  }

  JsonMap toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'programId': programId,
      'programName': programName,
    };
  }
}

class DivisionSummary {
  const DivisionSummary({required this.id, required this.name});

  final int id;
  final String name;

  factory DivisionSummary.fromJson(JsonMap json) {
    return DivisionSummary(
      id: readInt(json['id']),
      name: readString(json['name']),
    );
  }

  JsonMap toJson() {
    return <String, dynamic>{'id': id, 'name': name};
  }
}

class LocationSummary {
  const LocationSummary({
    required this.venue,
    required this.address1,
    required this.city,
    required this.region,
    required this.postcode,
    required this.country,
  });

  final String venue;
  final String address1;
  final String city;
  final String region;
  final String postcode;
  final String country;

  factory LocationSummary.fromJson(JsonMap json) {
    return LocationSummary(
      venue: readString(json['venue']),
      address1: readString(json['address_1'] ?? json['address1']),
      city: readString(json['city']),
      region: readString(json['region']),
      postcode: readString(json['postcode']),
      country: readString(json['country']),
    );
  }

  JsonMap toJson() {
    return <String, dynamic>{
      'venue': venue,
      'address1': address1,
      'city': city,
      'region': region,
      'postcode': postcode,
      'country': country,
    };
  }
}

class TeamReference {
  const TeamReference({
    required this.id,
    required this.number,
    required this.name,
  });

  final int id;
  final String number;
  final String name;

  factory TeamReference.fromJson(JsonMap json) {
    return TeamReference(
      id: readInt(json['id']),
      number: firstNonEmpty(<String?>[
        readString(json['number']),
        readString(json['name']),
        readString(json['team_number']),
      ]),
      name: firstNonEmpty(<String?>[
        readString(json['team_name']),
        readString(json['name']),
      ]),
    );
  }

  JsonMap toJson() {
    return <String, dynamic>{'id': id, 'number': number, 'name': name};
  }
}

class EventReference {
  const EventReference({
    required this.id,
    required this.sku,
    required this.name,
  });

  final int id;
  final String sku;
  final String name;

  factory EventReference.fromJson(JsonMap json) {
    return EventReference(
      id: readInt(json['id']),
      sku: readString(json['sku']),
      name: readString(json['name']),
    );
  }

  JsonMap toJson() {
    return <String, dynamic>{'id': id, 'sku': sku, 'name': name};
  }
}

class TeamSummary {
  const TeamSummary({
    required this.id,
    required this.number,
    required this.teamName,
    required this.organization,
    required this.robotName,
    required this.location,
    required this.grade,
    required this.registered,
  });

  final int id;
  final String number;
  final String teamName;
  final String organization;
  final String robotName;
  final LocationSummary location;
  final String grade;
  final bool registered;

  factory TeamSummary.fromJson(JsonMap json) {
    return TeamSummary(
      id: readInt(json['id']),
      number: firstNonEmpty(<String?>[
        readString(json['number']),
        readString(json['name']),
      ]),
      teamName: firstNonEmpty(<String?>[
        readString(json['team_name']),
        readString(json['teamName']),
        readString(json['name']),
      ]),
      organization: readString(json['organization']),
      robotName: readString(json['robot_name'] ?? json['robotName']),
      location: LocationSummary.fromJson(asJsonMap(json['location'])),
      grade: readString(json['grade']),
      registered: readBool(json['registered']),
    );
  }

  JsonMap toJson() {
    return <String, dynamic>{
      'id': id,
      'number': number,
      'teamName': teamName,
      'organization': organization,
      'robotName': robotName,
      'location': location.toJson(),
      'grade': grade,
      'registered': registered,
    };
  }
}

class EventSummary {
  const EventSummary({
    required this.id,
    required this.sku,
    required this.name,
    required this.start,
    required this.end,
    required this.seasonId,
    required this.location,
    required this.divisions,
    required this.livestreamLink,
  });

  final int id;
  final String sku;
  final String name;
  final DateTime? start;
  final DateTime? end;
  final int seasonId;
  final LocationSummary location;
  final List<DivisionSummary> divisions;
  final String livestreamLink;

  factory EventSummary.fromJson(JsonMap json) {
    final season = asJsonMap(json['season']);
    return EventSummary(
      id: readInt(json['id']),
      sku: readString(json['sku']),
      name: readString(json['name']),
      start: readDateTime(json['start']),
      end: readDateTime(json['end']),
      seasonId: readInt(season['id'] ?? json['seasonId']),
      location: LocationSummary.fromJson(asJsonMap(json['location'])),
      divisions: asJsonMapList(
        json['divisions'],
      ).map(DivisionSummary.fromJson).toList(growable: false),
      livestreamLink: readString(
        json['livestream_link'] ?? json['livestreamLink'],
      ),
    );
  }

  JsonMap toJson() {
    return <String, dynamic>{
      'id': id,
      'sku': sku,
      'name': name,
      'start': start?.toIso8601String(),
      'end': end?.toIso8601String(),
      'seasonId': seasonId,
      'location': location.toJson(),
      'divisions': divisions.map((division) => division.toJson()).toList(),
      'livestreamLink': livestreamLink,
    };
  }
}

enum MatchRound {
  none,
  practice,
  qualification,
  round128,
  round64,
  round32,
  round16,
  quarterfinals,
  semifinals,
  finals,
}

extension MatchRoundX on MatchRound {
  static MatchRound fromStored(dynamic value, {dynamic roundCode}) {
    if (roundCode != null) {
      final code = readInt(roundCode);
      if (code > 0) {
        return MatchRoundX.fromCode(code);
      }
    }

    if (value is int) {
      return MatchRoundX.fromCode(value);
    }
    if (value is num) {
      return MatchRoundX.fromCode(value.toInt());
    }
    final label = '$value'.trim().toLowerCase();
    switch (label) {
      case 'practice':
        return MatchRound.practice;
      case 'qualification':
        return MatchRound.qualification;
      case 'quarterfinals':
        return MatchRound.quarterfinals;
      case 'semifinals':
        return MatchRound.semifinals;
      case 'finals':
        return MatchRound.finals;
      case 'round16':
        return MatchRound.round16;
      case 'round32':
        return MatchRound.round32;
      case 'round64':
        return MatchRound.round64;
      case 'round128':
        return MatchRound.round128;
      default:
        return MatchRound.none;
    }
  }

  static MatchRound fromCode(int code) {
    switch (code) {
      case 1:
        return MatchRound.practice;
      case 2:
        return MatchRound.qualification;
      case 3:
        return MatchRound.quarterfinals;
      case 4:
        return MatchRound.semifinals;
      case 5:
        return MatchRound.finals;
      case 6:
        return MatchRound.round16;
      case 7:
        return MatchRound.round32;
      case 8:
        return MatchRound.round64;
      case 9:
        return MatchRound.round128;
      default:
        return MatchRound.none;
    }
  }

  int get code {
    switch (this) {
      case MatchRound.none:
        return 0;
      case MatchRound.practice:
        return 1;
      case MatchRound.qualification:
        return 2;
      case MatchRound.quarterfinals:
        return 3;
      case MatchRound.semifinals:
        return 4;
      case MatchRound.finals:
        return 5;
      case MatchRound.round16:
        return 6;
      case MatchRound.round32:
        return 7;
      case MatchRound.round64:
        return 8;
      case MatchRound.round128:
        return 9;
    }
  }

  String get label {
    switch (this) {
      case MatchRound.none:
        return 'none';
      case MatchRound.practice:
        return 'practice';
      case MatchRound.qualification:
        return 'qualification';
      case MatchRound.quarterfinals:
        return 'quarterfinals';
      case MatchRound.semifinals:
        return 'semifinals';
      case MatchRound.finals:
        return 'finals';
      case MatchRound.round16:
        return 'round16';
      case MatchRound.round32:
        return 'round32';
      case MatchRound.round64:
        return 'round64';
      case MatchRound.round128:
        return 'round128';
    }
  }
}

class MatchAlliance {
  const MatchAlliance({
    required this.color,
    required this.score,
    required this.teams,
  });

  final String color;
  final int score;
  final List<TeamReference> teams;

  factory MatchAlliance.fromJson(JsonMap json) {
    return MatchAlliance(
      color: readString(json['color']),
      score: readInt(json['score'], -1),
      teams: asJsonMapList(json['teams'])
          .map((teamRow) {
            final teamJson = asJsonMap(teamRow['team']);
            return TeamReference.fromJson(
              teamJson.isEmpty ? teamRow : teamJson,
            );
          })
          .toList(growable: false),
    );
  }

  JsonMap toJson() {
    return <String, dynamic>{
      'color': color,
      'score': score,
      'teams': teams.map((team) => team.toJson()).toList(),
    };
  }
}

class MatchSummary {
  const MatchSummary({
    required this.id,
    required this.event,
    required this.division,
    required this.field,
    required this.scheduled,
    required this.started,
    required this.round,
    required this.instance,
    required this.matchNumber,
    required this.name,
    required this.alliances,
  });

  final int id;
  final EventReference event;
  final DivisionSummary division;
  final String field;
  final DateTime? scheduled;
  final DateTime? started;
  final MatchRound round;
  final int instance;
  final int matchNumber;
  final String name;
  final List<MatchAlliance> alliances;

  factory MatchSummary.fromJson(JsonMap json) {
    return MatchSummary(
      id: readInt(json['id']),
      event: EventReference.fromJson(asJsonMap(json['event'])),
      division: DivisionSummary.fromJson(asJsonMap(json['division'])),
      field: readString(json['field']),
      scheduled: readDateTime(json['scheduled']),
      started: readDateTime(json['started']),
      round: MatchRoundX.fromStored(
        json['round'],
        roundCode: json['roundCode'],
      ),
      instance: readInt(json['instance']),
      matchNumber: readInt(json['matchnum'] ?? json['matchNumber']),
      name: readString(json['name']),
      alliances: asJsonMapList(
        json['alliances'],
      ).map(MatchAlliance.fromJson).toList(growable: false),
    );
  }

  JsonMap toJson() {
    return <String, dynamic>{
      'id': id,
      'event': event.toJson(),
      'division': division.toJson(),
      'field': field,
      'scheduled': scheduled?.toIso8601String(),
      'started': started?.toIso8601String(),
      'round': round.label,
      'roundCode': round.code,
      'instance': instance,
      'matchNumber': matchNumber,
      'name': name,
      'alliances': alliances.map((alliance) => alliance.toJson()).toList(),
    };
  }
}

class RankingRecord {
  const RankingRecord({
    required this.id,
    required this.team,
    required this.event,
    required this.division,
    required this.rank,
    required this.wins,
    required this.losses,
    required this.ties,
    required this.wp,
    required this.ap,
    required this.sp,
    required this.highScore,
    required this.averagePoints,
    required this.totalPoints,
  });

  final int id;
  final TeamReference team;
  final EventReference event;
  final DivisionSummary division;
  final int rank;
  final int wins;
  final int losses;
  final int ties;
  final int wp;
  final int ap;
  final int sp;
  final int highScore;
  final double averagePoints;
  final int totalPoints;

  factory RankingRecord.fromJson(JsonMap json) {
    return RankingRecord(
      id: readInt(json['id']),
      team: TeamReference.fromJson(asJsonMap(json['team'])),
      event: EventReference.fromJson(asJsonMap(json['event'])),
      division: DivisionSummary.fromJson(asJsonMap(json['division'])),
      rank: readInt(json['rank'], -1),
      wins: readInt(json['wins'], -1),
      losses: readInt(json['losses'], -1),
      ties: readInt(json['ties'], -1),
      wp: readInt(json['wp'], -1),
      ap: readInt(json['ap'], -1),
      sp: readInt(json['sp'], -1),
      highScore: readInt(json['high_score'] ?? json['highScore'], -1),
      averagePoints: readDouble(
        json['average_points'] ?? json['averagePoints'],
        -1,
      ),
      totalPoints: readInt(json['total_points'] ?? json['totalPoints'], -1),
    );
  }

  JsonMap toJson() {
    return <String, dynamic>{
      'id': id,
      'team': team.toJson(),
      'event': event.toJson(),
      'division': division.toJson(),
      'rank': rank,
      'wins': wins,
      'losses': losses,
      'ties': ties,
      'wp': wp,
      'ap': ap,
      'sp': sp,
      'highScore': highScore,
      'averagePoints': averagePoints,
      'totalPoints': totalPoints,
    };
  }
}

class SkillAttempt {
  const SkillAttempt({
    required this.id,
    required this.type,
    required this.rank,
    required this.score,
    required this.attempts,
    required this.team,
    required this.event,
  });

  final int id;
  final String type;
  final int rank;
  final int score;
  final int attempts;
  final TeamReference team;
  final EventReference event;

  factory SkillAttempt.fromJson(JsonMap json) {
    return SkillAttempt(
      id: readInt(json['id']),
      type: readString(json['type']),
      rank: readInt(json['rank']),
      score: readInt(json['score']),
      attempts: readInt(json['attempts']),
      team: TeamReference.fromJson(asJsonMap(json['team'])),
      event: EventReference.fromJson(asJsonMap(json['event'])),
    );
  }

  JsonMap toJson() {
    return <String, dynamic>{
      'id': id,
      'type': type,
      'rank': rank,
      'score': score,
      'attempts': attempts,
      'team': team.toJson(),
      'event': event.toJson(),
    };
  }
}

class AwardSummary {
  const AwardSummary({
    required this.id,
    required this.order,
    required this.title,
    required this.qualifications,
    required this.event,
    required this.recipients,
  });

  final int id;
  final int order;
  final String title;
  final List<String> qualifications;
  final EventReference event;
  final List<String> recipients;

  factory AwardSummary.fromJson(JsonMap json) {
    final team = asJsonMap(json['team']);
    final teamWinners = asJsonMapList(json['teamWinners']);
    final qualifications = readStringList(
      json['qualifications'] ?? json['qualifies_for'],
    );

    final recipientLabels = <String>[
      if (team.isNotEmpty)
        firstNonEmpty(<String?>[
          readString(team['number']),
          readString(team['team']),
          readString(team['name']),
        ]),
      ...teamWinners.map((winner) {
        final winnerTeam = asJsonMap(winner['team']);
        final winnerPerson = asJsonMap(winner['person']);
        return firstNonEmpty(<String?>[
          readString(winnerTeam['number']),
          readString(winnerTeam['team']),
          readString(winnerTeam['name']),
          readString(winnerPerson['name']),
          readString(winner['name']),
        ]);
      }),
      ...readStringList(json['recipients']),
      readString(json['winner']),
    ].where((value) => value.trim().isNotEmpty).toList(growable: false);

    return AwardSummary(
      id: readInt(json['id']),
      order: readInt(json['order']),
      title: readString(json['title']),
      qualifications: qualifications,
      event: EventReference.fromJson(asJsonMap(json['event'])),
      recipients: recipientLabels.isEmpty
          ? const <String>['Recipient pending']
          : recipientLabels,
    );
  }

  JsonMap toJson() {
    return <String, dynamic>{
      'id': id,
      'order': order,
      'title': title,
      'qualifications': qualifications,
      'event': event.toJson(),
      'recipients': recipients,
    };
  }
}
