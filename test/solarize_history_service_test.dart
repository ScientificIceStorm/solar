import 'package:flutter_test/flutter_test.dart';
import 'package:solar_v6/src/models/open_skill_models.dart';
import 'package:solar_v6/src/models/robot_events_models.dart';
import 'package:solar_v6/src/models/world_skills_models.dart';
import 'package:solar_v6/src/ui/services/solarize_history_service.dart';

void main() {
  test('recent form outranks stale form when skills are similar', () {
    const service = SolarizeHistoryService();
    final anchor = DateTime(2026, 1, 1);

    final teamA = _buildEntry(
      service,
      teamNumber: '100A',
      worldRank: 40,
      matches: <MatchSummary>[
        for (var i = 0; i < 6; i++)
          _match(
            id: i + 1,
            scheduled: anchor.add(Duration(days: i)),
            teamNumber: '100A',
            teamScore: 58,
            opponentScore: 46,
          ),
        for (var i = 0; i < 4; i++)
          _match(
            id: i + 101,
            scheduled: anchor.add(Duration(days: 30 + i)),
            teamNumber: '100A',
            teamScore: 42,
            opponentScore: 57,
          ),
      ],
    );

    final teamB = _buildEntry(
      service,
      teamNumber: '200B',
      worldRank: 44,
      matches: <MatchSummary>[
        for (var i = 0; i < 6; i++)
          _match(
            id: i + 201,
            scheduled: anchor.add(Duration(days: i)),
            teamNumber: '200B',
            teamScore: 44,
            opponentScore: 56,
          ),
        for (var i = 0; i < 4; i++)
          _match(
            id: i + 301,
            scheduled: anchor.add(Duration(days: 30 + i)),
            teamNumber: '200B',
            teamScore: 64,
            opponentScore: 49,
          ),
      ],
    );

    expect(teamB.openSkillOrdinal, greaterThan(teamA.openSkillOrdinal));
  });

  test(
    'isolated blowout losses are mostly ignored but repeated bad losses still count',
    () {
      const service = SolarizeHistoryService();
      final anchor = DateTime(2026, 2, 1);
      final baselineMatches = <MatchSummary>[
        for (var i = 0; i < 6; i++)
          _match(
            id: i + 1,
            scheduled: anchor.add(Duration(days: i)),
            teamNumber: '334C',
            teamScore: 61,
            opponentScore: 49,
          ),
        for (var i = 0; i < 2; i++)
          _match(
            id: i + 41,
            scheduled: anchor.add(Duration(days: 20 + i)),
            teamNumber: '334C',
            teamScore: 50,
            opponentScore: 54,
          ),
      ];

      final baseline = _buildEntry(
        service,
        teamNumber: '334C',
        worldRank: 58,
        matches: baselineMatches,
      );
      final isolated = _buildEntry(
        service,
        teamNumber: '334C',
        worldRank: 58,
        matches: <MatchSummary>[
          ...baselineMatches,
          _match(
            id: 99,
            scheduled: anchor.add(const Duration(days: 10)),
            teamNumber: '334C',
            teamScore: 4,
            opponentScore: 78,
            eventName: 'Winter Local Qualifier',
          ),
        ],
      );
      final repeated = _buildEntry(
        service,
        teamNumber: '334C',
        worldRank: 58,
        matches: <MatchSummary>[
          ...baselineMatches,
          _match(
            id: 199,
            scheduled: anchor.add(const Duration(days: 10)),
            teamNumber: '334C',
            teamScore: 6,
            opponentScore: 80,
            eventName: 'Winter Local Qualifier',
          ),
          _match(
            id: 200,
            scheduled: anchor.add(const Duration(days: 24)),
            teamNumber: '334C',
            teamScore: 10,
            opponentScore: 75,
            eventName: 'Winter Local Qualifier',
          ),
          _match(
            id: 201,
            scheduled: anchor.add(const Duration(days: 31)),
            teamNumber: '334C',
            round: MatchRound.quarterfinals,
            eventName: 'Signature Showdown',
            teamScore: 18,
            opponentScore: 72,
          ),
        ],
      );

      expect(
        (baseline.openSkillOrdinal - isolated.openSkillOrdinal).abs(),
        lessThan(0.85),
      );
      expect(
        repeated.openSkillOrdinal,
        lessThan(isolated.openSkillOrdinal - 1.8),
      );
    },
  );
}

WorldSkillsEntry _worldSkillEntry({
  required String teamNumber,
  required int rank,
}) {
  return WorldSkillsEntry(
    rank: rank,
    teamId: teamNumber.hashCode,
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
    combinedScore: 108,
    programmingScore: 54,
    driverScore: 54,
    maxProgrammingScore: 54,
    maxDriverScore: 54,
  );
}

MatchSummary _match({
  required int id,
  required DateTime scheduled,
  required String teamNumber,
  required int teamScore,
  required int opponentScore,
  MatchRound round = MatchRound.qualification,
  String eventName = 'Regional Qualifier',
}) {
  return MatchSummary(
    id: id,
    event: EventReference(id: id, sku: 'RE-V5RC-$id', name: eventName),
    division: const DivisionSummary(id: 1, name: 'Division 1'),
    field: 'Field 1',
    scheduled: scheduled,
    started: scheduled,
    round: round,
    instance: 1,
    matchNumber: id,
    name: 'Match $id',
    alliances: <MatchAlliance>[
      MatchAlliance(
        color: 'red',
        score: teamScore,
        teams: <TeamReference>[
          TeamReference(
            id: teamNumber.hashCode,
            number: teamNumber,
            name: teamNumber,
          ),
        ],
      ),
      MatchAlliance(
        color: 'blue',
        score: opponentScore,
        teams: <TeamReference>[
          TeamReference(id: 9000 + id, number: 'OPP$id', name: 'Opponent $id'),
        ],
      ),
    ],
  );
}

OpenSkillCacheEntry _buildEntry(
  SolarizeHistoryService service, {
  required String teamNumber,
  required int worldRank,
  required List<MatchSummary> matches,
}) {
  return service
      .build(
        worldSkills: <WorldSkillsEntry>[
          _worldSkillEntry(teamNumber: teamNumber, rank: worldRank),
        ],
        rankingsByTeam: <String, List<RankingRecord>>{
          teamNumber.toUpperCase(): const <RankingRecord>[],
        },
        matchesByTeam: <String, List<MatchSummary>>{
          teamNumber.toUpperCase(): matches,
        },
      )
      .single;
}
