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
      teamId: readInt(team['id']),
      program: readString(team['program']),
      teamNumber: readString(team['team']),
      teamName: readString(team['teamName']),
      organization: readString(team['organization']),
      city: readString(team['city']),
      region: readString(team['region']),
      country: readString(team['country']),
      eventRegion: readString(team['eventRegion']),
      eventRegionId: readInt(team['eventRegionId']),
      eventSku: readString(event['sku']),
      combinedScore: readInt(scores['score']),
      programmingScore: readInt(scores['programming']),
      driverScore: readInt(scores['driver']),
      maxProgrammingScore: readInt(scores['maxProgramming']),
      maxDriverScore: readInt(scores['maxDriver']),
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
