import 'package:flutter_test/flutter_test.dart';
import 'package:solar_v6/src/core/query_encoder.dart';
import 'package:solar_v6/src/models/open_skill_models.dart';
import 'package:solar_v6/src/models/robot_events_models.dart';
import 'package:solar_v6/src/models/world_skills_models.dart';

void main() {
  test('QueryEncoder preserves base path and expands indexed arrays', () {
    final uri = QueryEncoder.buildUri(
      'http://127.0.0.1:8080/api',
      '/openskill-cache',
      <String, Object?>{
        'season': 190,
        'grade_level': 'High School',
        'program': <int>[1],
      },
    );

    expect(
      uri.toString(),
      'http://127.0.0.1:8080/api/openskill-cache?season=190&grade_level=High+School&program%5B0%5D=1',
    );
  });

  test('TeamSummary parses nested location fields', () {
    final team = TeamSummary.fromJson(<String, dynamic>{
      'id': 17,
      'number': '24B',
      'team_name': 'Solar Squad',
      'organization': 'Solar Robotics',
      'robot_name': 'Helios',
      'grade': 'High School',
      'registered': true,
      'location': <String, dynamic>{
        'city': 'Irvine',
        'region': 'California',
        'country': 'United States',
      },
    });

    expect(team.id, 17);
    expect(team.number, '24B');
    expect(team.teamName, 'Solar Squad');
    expect(team.location.city, 'Irvine');
    expect(team.location.region, 'California');
    expect(team.location.country, 'United States');
  });

  test('OpenSkill prediction request round-trips', () {
    final request = OpenSkillPredictionRequest.fromJson(<String, dynamic>{
      'teams': <Object>[
        <Object>[
          <String, dynamic>{'name': '1692A', 'mu': 31.2, 'sigma': 4.8},
          <String, dynamic>{'name': '8059B', 'mu': 28.1, 'sigma': 5.0},
        ],
        <Object>[
          <String, dynamic>{'name': '25K', 'mu': 29.4, 'sigma': 4.6},
        ],
      ],
    });

    expect(request.teams.length, 2);
    expect(request.teams.first.first.name, '1692A');
    expect(request.toJson(), <String, dynamic>{
      'teams': <Object>[
        <Object>[
          <String, dynamic>{'name': '1692A', 'mu': 31.2, 'sigma': 4.8},
          <String, dynamic>{'name': '8059B', 'mu': 28.1, 'sigma': 5.0},
        ],
        <Object>[
          <String, dynamic>{'name': '25K', 'mu': 29.4, 'sigma': 4.6},
        ],
      ],
    });
  });

  test('WorldSkillsEntry flattens nested payloads', () {
    final entry = WorldSkillsEntry.fromJson(<String, dynamic>{
      'rank': 4,
      'team': <String, dynamic>{
        'id': 99,
        'program': 'VRC',
        'team': '24B',
        'teamName': 'Solar Squad',
        'organization': 'Solar Robotics',
        'city': 'Irvine',
        'region': 'California',
        'country': 'United States',
        'eventRegion': 'United States',
        'eventRegionId': 1,
      },
      'event': <String, dynamic>{'sku': 'RE-VRC-TEST'},
      'scores': <String, dynamic>{
        'score': 74,
        'programming': 39,
        'driver': 35,
        'maxProgramming': 50,
        'maxDriver': 50,
      },
    });

    expect(entry.rank, 4);
    expect(entry.teamNumber, '24B');
    expect(entry.eventSku, 'RE-VRC-TEST');
    expect(entry.combinedScore, 74);
    expect(entry.programmingScore, 39);
    expect(entry.driverScore, 35);
  });
}
