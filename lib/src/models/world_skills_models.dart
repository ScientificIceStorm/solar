import '../core/json_utils.dart';

class WorldSkillsEntry {
  const WorldSkillsEntry({
    required this.rank,
    required this.teamId,
    required this.program,
    required this.teamNumber,
    required this.teamName,
    required this.organization,
    required this.city,
    required this.region,
    required this.country,
    required this.eventRegion,
    required this.eventRegionId,
    required this.eventSku,
    required this.combinedScore,
    required this.programmingScore,
    required this.driverScore,
    required this.maxProgrammingScore,
    required this.maxDriverScore,
  });

  final int rank;
  final int teamId;
  final String program;
  final String teamNumber;
  final String teamName;
  final String organization;
  final String city;
  final String region;
  final String country;
  final String eventRegion;
  final int eventRegionId;
  final String eventSku;
  final int combinedScore;
  final int programmingScore;
  final int driverScore;
  final int maxProgrammingScore;
  final int maxDriverScore;

  factory WorldSkillsEntry.fromJson(JsonMap json) {
    final team = asJsonMap(json['team']);
    final event = asJsonMap(json['event']);
    final scores = asJsonMap(json['scores']);

    return WorldSkillsEntry(
      rank: readInt(json['rank']),
      teamId: readInt(team['id'] ?? json['teamId'] ?? json['team_id']),
      program: firstNonEmpty(<String?>[
        readString(team['program']),
        readString(json['program']),
        readString(json['program_name']),
      ]),
      teamNumber: firstNonEmpty(<String?>[
        readString(team['team']),
        readString(team['number']),
        readString(json['teamNumber']),
        readString(json['team_number']),
      ]),
      teamName: firstNonEmpty(<String?>[
        readString(team['teamName']),
        readString(json['teamName']),
        readString(json['team_name']),
      ]),
      organization: firstNonEmpty(<String?>[
        readString(team['organization']),
        readString(json['organization']),
      ]),
      city: firstNonEmpty(<String?>[
        readString(team['city']),
        readString(json['city']),
      ]),
      region: firstNonEmpty(<String?>[
        readString(team['region']),
        readString(json['region']),
      ]),
      country: firstNonEmpty(<String?>[
        readString(team['country']),
        readString(json['country']),
      ]),
      eventRegion: firstNonEmpty(<String?>[
        readString(team['eventRegion']),
        readString(json['eventRegion']),
        readString(json['event_region']),
      ]),
      eventRegionId: readInt(
        team['eventRegionId'] ??
            json['eventRegionId'] ??
            json['event_region_id'],
      ),
      eventSku: readString(
        event['sku'] ?? json['eventSku'] ?? json['event_sku'],
      ),
      combinedScore: readInt(
        scores['score'] ?? json['combinedScore'] ?? json['combined_score'],
      ),
      programmingScore: readInt(
        scores['programming'] ??
            json['programmingScore'] ??
            json['programming_score'],
      ),
      driverScore: readInt(
        scores['driver'] ?? json['driverScore'] ?? json['driver_score'],
      ),
      maxProgrammingScore: readInt(
        scores['maxProgramming'] ??
            json['maxProgrammingScore'] ??
            json['max_programming_score'],
      ),
      maxDriverScore: readInt(
        scores['maxDriver'] ??
            json['maxDriverScore'] ??
            json['max_driver_score'],
      ),
    );
  }

  JsonMap toJson() {
    return <String, dynamic>{
      'rank': rank,
      'teamId': teamId,
      'program': program,
      'teamNumber': teamNumber,
      'teamName': teamName,
      'organization': organization,
      'city': city,
      'region': region,
      'country': country,
      'eventRegion': eventRegion,
      'eventRegionId': eventRegionId,
      'eventSku': eventSku,
      'combinedScore': combinedScore,
      'programmingScore': programmingScore,
      'driverScore': driverScore,
      'maxProgrammingScore': maxProgrammingScore,
      'maxDriverScore': maxDriverScore,
    };
  }
}
