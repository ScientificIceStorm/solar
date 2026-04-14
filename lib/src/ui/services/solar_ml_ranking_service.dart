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

    final muRange = _MetricRange.fromValues(
      openSkillEntries
          .map((entry) => entry.openSkillMu)
          .where((value) => value > 0),
    );
    final ordinalRange = _MetricRange.fromValues(
      openSkillEntries
          .map((entry) => entry.openSkillOrdinal)
          .where((value) => value > 0),
    );
    final sigmaRange = _MetricRange.fromValues(
      openSkillEntries
          .map((entry) => entry.openSkillSigma)
          .where((value) => value > 0),
    );
    final ccwmRange = _MetricRange.fromValues(
      openSkillEntries
          .map((entry) => entry.ccwm ?? 0)
          .where((value) => value != 0),
    );
    final awpRange = _MetricRange.fromValues(
      openSkillEntries
          .map((entry) => entry.awpPerMatch)
          .where((value) => value > 0),
    );
    final wpRange = _MetricRange.fromValues(
      openSkillEntries
          .map((entry) => entry.wpPerMatch)
          .where((value) => value > 0),
    );
    final netRange = _MetricRange.fromValues(
      openSkillEntries
          .map((entry) => (entry.opr ?? 0) - (entry.dpr ?? 0))
          .where((value) => value != 0),
    );
    final scheduleRange = _MetricRange.fromValues(
      openSkillEntries
          .map((entry) => entry.strengthOfSchedule)
          .whereType<double>()
          .where((value) => value > 0),
    );
    final eliminationRange = _MetricRange.fromValues(
      openSkillEntries
          .where((entry) => entry.eliminationMatches > 0)
          .map((entry) => entry.eliminationWinRate)
          .whereType<double>()
          .where((value) => value > 0),
    );
    final eventStrengthRange = _MetricRange.fromValues(
      openSkillEntries
          .map((entry) => entry.eventStrength)
          .whereType<double>()
          .where((value) => value > 0),
    );

    final computed =
        worldSkills
            .map((entry) {
              final key = entry.teamNumber.trim().toUpperCase();
              final openSkill = openSkillByTeam[key];
              final muNorm = openSkill == null
                  ? 0.5
                  : muRange.normalize(openSkill.openSkillMu);
              final ordinalNorm = openSkill == null
                  ? 0.5
                  : ordinalRange.normalize(openSkill.openSkillOrdinal);
              final sigmaNorm = openSkill == null
                  ? 0.35
                  : sigmaRange.reverseNormalize(openSkill.openSkillSigma);
              final ccwmNorm = ccwmRange.normalize(openSkill?.ccwm ?? 0);
              final awpNorm = awpRange.normalize(openSkill?.awpPerMatch ?? 0);
              final wpNorm = wpRange.normalize(openSkill?.wpPerMatch ?? 0);
              final netNorm = netRange.normalize(
                (openSkill?.opr ?? 0) - (openSkill?.dpr ?? 0),
              );
              final scheduleNorm = openSkill?.strengthOfSchedule == null
                  ? 0.5
                  : scheduleRange.normalize(openSkill!.strengthOfSchedule!);
              final eliminationNorm =
                  openSkill == null ||
                      openSkill.eliminationMatches <= 0 ||
                      openSkill.eliminationWinRate == null
                  ? 0.5
                  : eliminationRange.normalize(openSkill.eliminationWinRate!);
              final eventStrengthNorm = openSkill?.eventStrength == null
                  ? 0.5
                  : eventStrengthRange.normalize(openSkill!.eventStrength!);

              final baseRating = openSkill?.openSkillOrdinal ?? 12.0;
              final solarizeAdjustment =
                  ((ordinalNorm - 0.5) * 4.1) +
                  ((muNorm - 0.5) * 2.2) +
                  ((ccwmNorm - 0.5) * 3.0) +
                  ((netNorm - 0.5) * 2.7) +
                  ((wpNorm - 0.5) * 2.2) +
                  ((scheduleNorm - 0.5) * 2.9) +
                  ((eliminationNorm - 0.5) * 3.4) +
                  ((eventStrengthNorm - 0.5) * 2.0) +
                  ((awpNorm - 0.5) * 0.9);
              final rating = baseRating + solarizeAdjustment;
              final stability = openSkill == null
                  ? 46.0
                  : ((1 - (openSkill.openSkillSigma / 12)).clamp(0.25, 1.0) *
                        100);
              final projectedWinShare =
                  (46 +
                          ((ordinalNorm - 0.5) * 22) +
                          ((ccwmNorm - 0.5) * 12) +
                          ((wpNorm - 0.5) * 9) +
                          ((scheduleNorm - 0.5) * 11) +
                          ((eliminationNorm - 0.5) * 13) +
                          ((eventStrengthNorm - 0.5) * 7) +
                          ((sigmaNorm - 0.5) * 8))
                      .clamp(26, 89)
                      .toDouble();
              final ceilingScore =
                  ((((openSkill?.opr ?? 32).clamp(10, 145)) * 0.45) +
                          (((((openSkill?.ccwm ?? 0) + 16).clamp(4, 34))) *
                              0.21) +
                          (((openSkill?.awpPerMatch ?? 0.5).clamp(0.0, 1.0)) *
                              18) +
                          (scheduleNorm * 10) +
                          (eliminationNorm * 15) +
                          (eventStrengthNorm * 14))
                      .toDouble();

              return SolarMlRankingEntry(
                rank: 0,
                teamId: entry.teamId,
                teamNumber: entry.teamNumber,
                teamName: entry.teamName,
                organization: entry.organization,
                city: entry.city,
                region: entry.region,
                country: entry.country,
                mlRating: rating,
                projectedWinShare: projectedWinShare,
                ceilingScore: ceilingScore,
                stability: stability,
                worldRank: entry.rank <= 0 ? null : entry.rank,
                combinedScore: entry.combinedScore,
                programmingScore: entry.programmingScore,
                driverScore: entry.driverScore,
                ordinal: openSkill?.openSkillOrdinal,
                openSkillMu: openSkill?.openSkillMu,
                openSkillSigma: openSkill?.openSkillSigma,
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
            final projectedCompare = b.projectedWinShare.compareTo(
              a.projectedWinShare,
            );
            if (projectedCompare != 0) {
              return projectedCompare;
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
        openSkillMu: item.openSkillMu,
        openSkillSigma: item.openSkillSigma,
        ccwm: item.ccwm,
        opr: item.opr,
        dpr: item.dpr,
        awpPerMatch: item.awpPerMatch,
      );
    });
  }
}

class _MetricRange {
  const _MetricRange({required this.minValue, required this.maxValue});

  final double minValue;
  final double maxValue;

  factory _MetricRange.fromValues(Iterable<double> values) {
    final iterator = values.iterator;
    if (!iterator.moveNext()) {
      return const _MetricRange(minValue: 0, maxValue: 0);
    }

    var minValue = iterator.current;
    var maxValue = iterator.current;
    while (iterator.moveNext()) {
      final value = iterator.current;
      if (value < minValue) {
        minValue = value;
      }
      if (value > maxValue) {
        maxValue = value;
      }
    }
    return _MetricRange(minValue: minValue, maxValue: maxValue);
  }

  double normalize(double value) {
    if (maxValue <= minValue) {
      return 0.5;
    }
    return ((value - minValue) / (maxValue - minValue)).clamp(0.0, 1.0);
  }

  double reverseNormalize(double value) {
    return 1 - normalize(value);
  }
}
