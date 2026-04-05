import 'package:flutter/material.dart';

import '../../models/robot_events_models.dart';
import '../models/team_stats_snapshot.dart';

class SolarTeamOverviewCard extends StatelessWidget {
  const SolarTeamOverviewCard({
    required this.team,
    required this.teamStats,
    super.key,
    this.onTap,
    this.statusLabel,
  });

  final TeamSummary team;
  final TeamStatsSnapshot teamStats;
  final VoidCallback? onTap;
  final String? statusLabel;

  @override
  Widget build(BuildContext context) {
    final location = teamStats.locationLabel;
    final subline = <String>[
      if (team.organization.isNotEmpty) team.organization,
      if (location != 'Location pending') location,
    ].join('  •  ');
    final winRateLabel = teamStats.winRate == null
        ? '--'
        : '${teamStats.winRate!.toStringAsFixed(0)}%';
    final skillLineParts = <String>[
      if (teamStats.skillsScoreLabel != '--')
        'Combined ${teamStats.skillsScoreLabel}',
      if (teamStats.driverScoreLabel != '--')
        'Driver ${teamStats.driverScoreLabel}',
      if (teamStats.programmingScoreLabel != '--')
        'Auton ${teamStats.programmingScoreLabel}',
    ];

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(28),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 20,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        team.number,
                        style: const TextStyle(
                          color: Color(0xFF24243A),
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        team.teamName.isEmpty ? 'Team profile' : team.teamName,
                        style: const TextStyle(
                          color: Color(0xFF24243A),
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (statusLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F2F8),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusLabel!,
                      style: const TextStyle(
                        color: Color(0xFF5C6074),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
              ],
            ),
            if (subline.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                subline,
                style: const TextStyle(
                  color: Color(0xFF8E92A7),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 18),
            Wrap(
              spacing: 20,
              runSpacing: 14,
              children: <Widget>[
                _SolarTeamOverviewMetric(
                  label: 'Record',
                  value: teamStats.recordLabel,
                ),
                _SolarTeamOverviewMetric(
                  label: 'Skills',
                  value: teamStats.skillsRankLabel,
                ),
                _SolarTeamOverviewMetric(
                  label: 'CCWM',
                  value: teamStats.ccwm?.toStringAsFixed(1) ?? '--',
                ),
                _SolarTeamOverviewMetric(
                  label: 'OPR',
                  value: teamStats.opr?.toStringAsFixed(1) ?? '--',
                ),
                _SolarTeamOverviewMetric(
                  label: 'DPR',
                  value: teamStats.dpr?.toStringAsFixed(1) ?? '--',
                ),
                _SolarTeamOverviewMetric(
                  label: 'Win Rate',
                  value: winRateLabel,
                ),
              ],
            ),
            if (skillLineParts.isNotEmpty) ...<Widget>[
              const SizedBox(height: 18),
              Text(
                skillLineParts.join('  •  '),
                style: const TextStyle(
                  color: Color(0xFF6F748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (teamStats.errorMessage != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                teamStats.errorMessage!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF8D90A7),
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SolarTeamOverviewMetric extends StatelessWidget {
  const _SolarTeamOverviewMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8E92A7),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF24243A),
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
