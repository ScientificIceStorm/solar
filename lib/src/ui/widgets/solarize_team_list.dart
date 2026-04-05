import 'package:flutter/material.dart';

import '../../app/app_session_controller.dart';
import '../../models/open_skill_models.dart';
import '../../models/robot_events_models.dart';
import '../../models/world_skills_models.dart';
import '../models/solar_ml_ranking.dart';
import '../services/solar_ml_ranking_service.dart';
import 'solar_team_link.dart';

class SolarizeTeamList extends StatelessWidget {
  const SolarizeTeamList({
    required this.controller,
    required this.teams,
    super.key,
    this.highlightTeamNumber,
    this.emptyLabel = 'No teams available.',
    this.padding = const EdgeInsets.only(bottom: 8),
  });

  final AppSessionController controller;
  final List<TeamSummary> teams;
  final String? highlightTeamNumber;
  final String emptyLabel;
  final EdgeInsets padding;

  static const _solarMlService = SolarMlRankingService();

  @override
  Widget build(BuildContext context) {
    if (teams.isEmpty) {
      return Center(
        child: Text(
          emptyLabel,
          style: const TextStyle(
            color: Color(0xFF8E92A7),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    if (controller.worldSkillsRankings.isEmpty &&
        !controller.isPreloadingSearchTeams) {
      controller.preloadSearchTeams();
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final worldSkillsByTeam = <String, WorldSkillsEntry>{
          for (final entry in controller.worldSkillsRankings)
            entry.teamNumber.trim().toUpperCase(): entry,
        };

        final openSkillEntries = <OpenSkillCacheEntry>[
          for (final team in teams)
            if (controller.openSkillEntryForTeam(team.number) != null)
              controller.openSkillEntryForTeam(team.number)!,
        ];
        final worldSkills = <WorldSkillsEntry>[
          for (final team in teams)
            if (worldSkillsByTeam[team.number.trim().toUpperCase()] != null)
              worldSkillsByTeam[team.number.trim().toUpperCase()]!,
        ];
        final mlByTeam = <String, SolarMlRankingEntry>{
          for (final entry in _solarMlService.build(
            worldSkills: worldSkills,
            openSkillEntries: openSkillEntries,
          ))
            entry.teamNumber.trim().toUpperCase(): entry,
        };

        final rows =
            teams
                .map((team) {
                  final key = team.number.trim().toUpperCase();
                  final mlEntry = mlByTeam[key];
                  final openSkillEntry = controller.openSkillEntryForTeam(
                    team.number,
                  );
                  final worldSkillsEntry = worldSkillsByTeam[key];
                  final sortScore =
                      mlEntry?.mlRating ??
                      openSkillEntry?.openSkillOrdinal ??
                      worldSkillsEntry?.combinedScore.toDouble() ??
                      0;

                  return _SolarizeTeamRowModel(
                    team: team,
                    mlEntry: mlEntry,
                    openSkillEntry: openSkillEntry,
                    worldSkillsEntry: worldSkillsEntry,
                    sortScore: sortScore,
                  );
                })
                .toList(growable: false)
              ..sort((a, b) {
                final aRank = a.mlEntry?.rank;
                final bRank = b.mlEntry?.rank;
                if (aRank != null && bRank != null) {
                  final rankCompare = aRank.compareTo(bRank);
                  if (rankCompare != 0) {
                    return rankCompare;
                  }
                }

                final scoreCompare = b.sortScore.compareTo(a.sortScore);
                if (scoreCompare != 0) {
                  return scoreCompare;
                }
                return a.team.number.compareTo(b.team.number);
              });

        return StretchingOverscrollIndicator(
          axisDirection: AxisDirection.down,
          child: ListView.builder(
            padding: padding,
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              return _SolarizeTeamRow(
                index: index,
                row: row,
                highlightTeamNumber: highlightTeamNumber,
                showDivider: index != rows.length - 1,
              );
            },
          ),
        );
      },
    );
  }
}

class _SolarizeTeamRow extends StatelessWidget {
  const _SolarizeTeamRow({
    required this.index,
    required this.row,
    required this.highlightTeamNumber,
    required this.showDivider,
  });

  final int index;
  final _SolarizeTeamRowModel row;
  final String? highlightTeamNumber;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final normalizedHighlight = highlightTeamNumber?.trim().toUpperCase();
    final highlighted =
        normalizedHighlight != null &&
        normalizedHighlight == row.team.number.trim().toUpperCase();
    final labelColor = highlighted
        ? const Color(0xFF2930FF)
        : const Color(0xFF16182C);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: Color(0xFFDADAE3)))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 34,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                color: labelColor,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.8,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SolarTeamLinkText(
                  teamNumber: row.team.number,
                  teamId: row.team.id,
                  teamName: row.team.teamName,
                  organization: row.team.organization,
                  robotName: row.team.robotName,
                  grade: row.team.grade,
                  style: TextStyle(
                    color: labelColor,
                    fontSize: 22,
                    fontWeight: highlighted ? FontWeight.w600 : FontWeight.w400,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  row.team.teamName.trim().isEmpty
                      ? 'Team profile'
                      : row.team.teamName.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF8E92A7),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _metaLabel(row),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF707487),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SolarizeTeamRowModel {
  const _SolarizeTeamRowModel({
    required this.team,
    required this.mlEntry,
    required this.openSkillEntry,
    required this.worldSkillsEntry,
    required this.sortScore,
  });

  final TeamSummary team;
  final SolarMlRankingEntry? mlEntry;
  final OpenSkillCacheEntry? openSkillEntry;
  final WorldSkillsEntry? worldSkillsEntry;
  final double sortScore;
}

String _metaLabel(_SolarizeTeamRowModel row) {
  final parts = <String>[
    if (row.mlEntry != null) 'Solarize #${row.mlEntry!.rank}',
    if (row.openSkillEntry != null)
      'Mu ${row.openSkillEntry!.openSkillMu.toStringAsFixed(1)}',
    if (row.worldSkillsEntry != null) 'Skills ${row.worldSkillsEntry!.rank}',
  ];
  if (parts.isEmpty) {
    return 'Solarize data still loading';
  }
  return parts.join('  •  ');
}
