import 'package:flutter_test/flutter_test.dart';
import 'package:solar_v6/src/models/open_skill_models.dart';
import 'package:solar_v6/src/models/world_skills_models.dart';
import 'package:solar_v6/src/ui/services/solar_ml_ranking_service.dart';

void main() {
  test('Solarize rankings lean on rating data over raw skills rank', () {
    const service = SolarMlRankingService();

    final entries = service.build(
      worldSkills: <WorldSkillsEntry>[
        _worldSkillEntry(
          teamNumber: '100A',
          rank: 1,
          combined: 118,
          driver: 60,
          programming: 58,
        ),
        _worldSkillEntry(
          teamNumber: '200B',
          rank: 7,
          combined: 107,
          driver: 55,
          programming: 52,
        ),
      ],
      openSkillEntries: <OpenSkillCacheEntry>[
        _openSkillEntry(
          teamNumber: '100A',
          ordinal: 18,
          sigma: 5.4,
          ccwm: 1.1,
          awpPerMatch: 0.42,
          wpPerMatch: 0.55,
          opr: 20.0,
          dpr: 18.5,
        ),
        _openSkillEntry(
          teamNumber: '200B',
          ordinal: 34,
          sigma: 2.6,
          ccwm: 7.8,
          awpPerMatch: 0.79,
          wpPerMatch: 0.86,
          opr: 29.0,
          dpr: 13.2,
        ),
      ],
    );

    expect(entries, hasLength(2));
    expect(entries.first.teamNumber, '200B');
    expect(entries.first.solarRating, greaterThan(entries.last.solarRating));
  });
}

WorldSkillsEntry _worldSkillEntry({
  required String teamNumber,
  required int rank,
  required int combined,
  required int driver,
  required int programming,
}) {
  return WorldSkillsEntry(
    rank: rank,
    teamId: rank,
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
    programmingScore: programming,
    driverScore: driver,
    maxProgrammingScore: programming,
    maxDriverScore: driver,
  );
}

OpenSkillCacheEntry _openSkillEntry({
  required String teamNumber,
  required double ordinal,
  required double sigma,
  required double ccwm,
  required double awpPerMatch,
  required double wpPerMatch,
  required double opr,
  required double dpr,
}) {
  return OpenSkillCacheEntry(
    ranking: 1,
    rankingChange: 0,
    teamNumber: teamNumber,
    id: teamNumber.hashCode,
    gradeLevel: 'High School',
    region: 'California',
    country: 'United States',
    trueSkill: 25,
    openSkillMu: 25,
    openSkillSigma: sigma,
    openSkillOrdinal: ordinal,
    ratingSource: 'cache',
    ccwm: ccwm,
    totalWins: 12,
    totalLosses: 2,
    totalTies: 1,
    apPerMatch: 14.5,
    awpPerMatch: awpPerMatch,
    wpPerMatch: wpPerMatch,
    opr: opr,
    dpr: dpr,
    strengthOfSchedule: 0.62,
    eliminationWinRate: 0.71,
    eliminationMatches: 6,
    eventStrength: 1.18,
    qualifiedForRegionals: 1,
    qualifiedForWorlds: 1,
  );
}
