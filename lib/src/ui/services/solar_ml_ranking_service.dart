import '../../models/open_skill_models.dart';
import '../../models/world_skills_models.dart';
import '../models/solar_ml_ranking.dart';

class SolarMlRankingService {
  const SolarMlRankingService();

  List<SolarMlRankingEntry> build({
    required List<WorldSkillsEntry> worldSkills,
    required List<OpenSkillCacheEntry> openSkillEntries,
  }) {
    final openSkillByTeam = <String, OpenSkillCacheEntry>{
      for (final entry in openSkillEntries)
        entry.teamNumber.trim().toUpperCase(): entry,
    };

    final combinedValues = worldSkills
        .map((entry) => entry.combinedScore.toDouble())
        .where((value) => value > 0)
        .toList(growable: false);
    final driverValues = worldSkills
        .map((entry) => entry.maxDriverScore.toDouble())
        .where((value) => value > 0)
        .toList(growable: false);
    final programmingValues = worldSkills
        .map((entry) => entry.maxProgrammingScore.toDouble())
        .where((value) => value > 0)
        .toList(growable: false);
    final ordinalValues = openSkillEntries
        .map((entry) => entry.openSkillOrdinal)
        .where((value) => value > 0)
        .toList(growable: false);
    final ccwmValues = openSkillEntries
        .map((entry) => entry.ccwm ?? 0)
        .where((value) => value != 0)
        .toList(growable: false);
    final awpValues = openSkillEntries
        .map((entry) => entry.awpPerMatch)
        .where((value) => value > 0)
        .toList(growable: false);
    final wpValues = openSkillEntries
        .map((entry) => entry.wpPerMatch)
        .where((value) => value > 0)
        .toList(growable: false);
    final netValues = openSkillEntries
        .map((entry) => (entry.opr ?? 0) - (entry.dpr ?? 0))
        .where((value) => value != 0)
        .toList(growable: false);

    final computed =
        worldSkills
            .map((entry) {
              final key = entry.teamNumber.trim().toUpperCase();
              final openSkill = openSkillByTeam[key];
              final combinedNorm = _normalize(
                entry.combinedScore.toDouble(),
                combinedValues,
              );
              final driverNorm = _normalize(
                entry.maxDriverScore.toDouble(),
                driverValues,
              );
              final programmingNorm = _normalize(
                entry.maxProgrammingScore.toDouble(),
                programmingValues,
              );
              final ordinalNorm = _normalize(
                openSkill?.openSkillOrdinal ?? 0,
                ordinalValues,
              );
              final ccwmNorm = _normalize(openSkill?.ccwm ?? 0, ccwmValues);
              final awpNorm = _normalize(
                openSkill?.awpPerMatch ?? 0,
                awpValues,
              );
              final wpNorm = _normalize(openSkill?.wpPerMatch ?? 0, wpValues);
              final netNorm = _normalize(
                (openSkill?.opr ?? 0) - (openSkill?.dpr ?? 0),
                netValues,
              );
              final rawScore =
                  (combinedNorm * 0.28) +
                  (driverNorm * 0.12) +
                  (programmingNorm * 0.12) +
                  (ordinalNorm * 0.18) +
                  (ccwmNorm * 0.10) +
                  (awpNorm * 0.08) +
                  (wpNorm * 0.06) +
                  (netNorm * 0.06);
              final stability = openSkill == null
                  ? 52.0
                  : ((1 - (openSkill.openSkillSigma / 12)).clamp(0.25, 1.0) *
                        100);
              final ceilingScore =
                  (entry.combinedScore * 0.58) +
                  (entry.maxDriverScore * 0.22) +
                  (entry.maxProgrammingScore * 0.20);

              return SolarMlRankingEntry(
                rank: 0,
                teamId: entry.teamId,
                teamNumber: entry.teamNumber,
                teamName: entry.teamName,
                organization: entry.organization,
                city: entry.city,
                region: entry.region,
                country: entry.country,
                mlRating: 100 + (rawScore * 100),
                projectedWinShare: 42 + (rawScore * 48),
                ceilingScore: ceilingScore,
                stability: stability,
                worldRank: entry.rank <= 0 ? null : entry.rank,
                combinedScore: entry.combinedScore,
                programmingScore: entry.programmingScore,
                driverScore: entry.driverScore,
                ordinal: openSkill?.openSkillOrdinal,
                ccwm: openSkill?.ccwm,
                opr: openSkill?.opr,
                dpr: openSkill?.dpr,
                awpPerMatch: openSkill?.awpPerMatch,
              );
            })
            .toList(growable: false)
          ..sort((a, b) {
            final mlCompare = b.mlRating.compareTo(a.mlRating);
            if (mlCompare != 0) {
              return mlCompare;
            }
            return a.teamNumber.compareTo(b.teamNumber);
          });

    return List<SolarMlRankingEntry>.generate(computed.length, (index) {
      final item = computed[index];
      return SolarMlRankingEntry(
        rank: index + 1,
        teamId: item.teamId,
        teamNumber: item.teamNumber,
        teamName: item.teamName,
        organization: item.organization,
        city: item.city,
        region: item.region,
        country: item.country,
        mlRating: item.mlRating,
        projectedWinShare: item.projectedWinShare,
        ceilingScore: item.ceilingScore,
        stability: item.stability,
        worldRank: item.worldRank,
        combinedScore: item.combinedScore,
        programmingScore: item.programmingScore,
        driverScore: item.driverScore,
        ordinal: item.ordinal,
        ccwm: item.ccwm,
        opr: item.opr,
        dpr: item.dpr,
        awpPerMatch: item.awpPerMatch,
      );
    });
  }

  double _normalize(double value, List<double> population) {
    if (population.isEmpty) {
      return 0.5;
    }
    final minValue = population.reduce((a, b) => a < b ? a : b);
    final maxValue = population.reduce((a, b) => a > b ? a : b);
    if (maxValue == minValue) {
      return 0.5;
    }
    return ((value - minValue) / (maxValue - minValue)).clamp(0.0, 1.0);
  }
}
