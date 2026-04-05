import 'package:flutter_test/flutter_test.dart';
import 'package:solar_v6/src/models/robot_events_models.dart';
import 'package:solar_v6/src/models/world_skills_models.dart';
import 'package:solar_v6/src/ui/services/solarize_history_service.dart';

void main() {
  test('Solarize history rankings reward sustained event performance', () {
    const service = SolarizeHistoryService();

    final rankings = service.build(
      worldSkills: <WorldSkillsEntry>[
        _worldSkillEntry(teamId: 1, teamNumber: '111A', rank: 1, combined: 229),
        _worldSkillEntry(teamId: 2, teamNumber: '222B', rank: 3, combined: 219),
        _worldSkillEntry(teamId: 3, teamNumber: '333C', rank: 5, combined: 219),
        _worldSkillEntry(teamId: 4, teamNumber: '444D', rank: 7, combined: 215),
      ],
      rankingsByTeam: <String, List<RankingRecord>>{
        '111A': <RankingRecord>[
          _ranking(
            teamNumber: '111A',
            rank: 3,
            wins: 7,
            losses: 2,
            ap: 70,
            averagePoints: 62,
          ),
          _ranking(
            teamNumber: '111A',
            rank: 6,
            wins: 8,
            losses: 3,
            ap: 60,
            averagePoints: 58,
          ),
          _ranking(
            teamNumber: '111A',
            rank: 9,
            wins: 6,
            losses: 3,
            ap: 55,
            averagePoints: 61,
          ),
          _ranking(
            teamNumber: '111A',
            rank: 12,
            wins: 5,
            losses: 3,
            ap: 50,
            averagePoints: 54,
          ),
          _ranking(
            teamNumber: '111A',
            rank: 16,
            wins: 5,
            losses: 3,
            ap: 50,
            averagePoints: 57,
          ),
          _ranking(
            teamNumber: '111A',
            rank: 21,
            wins: 2,
            losses: 4,
            ap: 40,
            averagePoints: 49,
          ),
        ],
        '222B': <RankingRecord>[
          _ranking(
            teamNumber: '222B',
            rank: 1,
            wins: 7,
            losses: 0,
            ap: 60,
            averagePoints: 102,
          ),
          _ranking(
            teamNumber: '222B',
            rank: 1,
            wins: 6,
            losses: 0,
            ap: 58,
            averagePoints: 98,
          ),
          _ranking(
            teamNumber: '222B',
            rank: 2,
            wins: 7,
            losses: 1,
            ap: 55,
            averagePoints: 90,
          ),
          _ranking(
            teamNumber: '222B',
            rank: 1,
            wins: 7,
            losses: 0,
            ap: 52,
            averagePoints: 96,
          ),
          _ranking(
            teamNumber: '222B',
            rank: 4,
            wins: 6,
            losses: 1,
            ap: 40,
            averagePoints: 86,
          ),
          _ranking(
            teamNumber: '222B',
            rank: 1,
            wins: 6,
            losses: 1,
            ap: 48,
            averagePoints: 92,
          ),
        ],
        '333C': <RankingRecord>[
          _ranking(
            teamNumber: '333C',
            rank: 2,
            wins: 8,
            losses: 0,
            ap: 70,
            averagePoints: 70,
          ),
          _ranking(
            teamNumber: '333C',
            rank: 2,
            wins: 9,
            losses: 1,
            ap: 90,
            averagePoints: 67,
          ),
          _ranking(
            teamNumber: '333C',
            rank: 29,
            wins: 4,
            losses: 4,
            ap: 50,
            averagePoints: 52,
          ),
          _ranking(
            teamNumber: '333C',
            rank: 6,
            wins: 5,
            losses: 1,
            ap: 10,
            averagePoints: 72,
          ),
        ],
        '444D': <RankingRecord>[
          _ranking(
            teamNumber: '444D',
            rank: 4,
            wins: 7,
            losses: 1,
            ap: 52,
            averagePoints: 84,
          ),
          _ranking(
            teamNumber: '444D',
            rank: 5,
            wins: 6,
            losses: 2,
            ap: 48,
            averagePoints: 79,
          ),
          _ranking(
            teamNumber: '444D',
            rank: 7,
            wins: 6,
            losses: 2,
            ap: 46,
            averagePoints: 76,
          ),
          _ranking(
            teamNumber: '444D',
            rank: 3,
            wins: 8,
            losses: 1,
            ap: 58,
            averagePoints: 88,
          ),
          _ranking(
            teamNumber: '444D',
            rank: 10,
            wins: 5,
            losses: 3,
            ap: 44,
            averagePoints: 73,
          ),
          _ranking(
            teamNumber: '444D',
            rank: 8,
            wins: 6,
            losses: 2,
            ap: 42,
            averagePoints: 75,
          ),
        ],
      },
    );

    expect(rankings, hasLength(4));
    expect(rankings.first.teamNumber, '222B');
    expect(rankings.first.ranking, 1);
    expect(
      rankings.first.openSkillOrdinal,
      greaterThan(rankings[1].openSkillOrdinal),
    );
    expect(
      rankings.firstWhere((entry) => entry.teamNumber == '333C').ranking,
      greaterThan(3),
    );
  });

  test(
    'Solarize history rankings still build a prior when no events exist',
    () {
      const service = SolarizeHistoryService();

      final rankings = service.build(
        worldSkills: <WorldSkillsEntry>[
          _worldSkillEntry(
            teamId: 9,
            teamNumber: '999Z',
            rank: 14,
            combined: 209,
          ),
        ],
        rankingsByTeam: const <String, List<RankingRecord>>{},
      );

      expect(rankings.single.teamNumber, '999Z');
      expect(rankings.single.ratingSource, 'solarize-prior');
      expect(rankings.single.openSkillMu, greaterThan(0));
      expect(rankings.single.openSkillSigma, greaterThan(0));
      expect(rankings.single.openSkillOrdinal, isNotNaN);
    },
  );
}

WorldSkillsEntry _worldSkillEntry({
  required int teamId,
  required String teamNumber,
  required int rank,
  required int combined,
}) {
  return WorldSkillsEntry(
    rank: rank,
    teamId: teamId,
    program: 'V5RC',
    teamNumber: teamNumber,
    teamName: 'Team $teamNumber',
    organization: 'Solar',
    city: 'Irvine',
    region: 'California',
    country: 'United States',
    eventRegion: 'California',
    eventRegionId: 1,
    eventSku: 'RE-V5RC-TEST',
    combinedScore: combined,
    programmingScore: combined ~/ 2,
    driverScore: combined - (combined ~/ 2),
    maxProgrammingScore: combined ~/ 2,
    maxDriverScore: combined - (combined ~/ 2),
  );
}

RankingRecord _ranking({
  required String teamNumber,
  required int rank,
  required int wins,
  required int losses,
  required int ap,
  required double averagePoints,
}) {
  return RankingRecord(
    id: rank * 100 + teamNumber.hashCode,
    team: TeamReference(
      id: teamNumber.hashCode,
      number: teamNumber,
      name: 'Team $teamNumber',
    ),
    event: EventReference(
      id: rank,
      sku: 'RE-V5RC-TEST-$rank',
      name: 'Event $rank',
    ),
    division: const DivisionSummary(id: 1, name: 'Division 1'),
    rank: rank,
    wins: wins,
    losses: losses,
    ties: 0,
    wp: wins * 2,
    ap: ap,
    sp: 0,
    highScore: averagePoints.round(),
    averagePoints: averagePoints,
    totalPoints: averagePoints.round() * (wins + losses),
  );
}
