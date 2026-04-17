import 'package:flutter/material.dart';

import '../../models/robot_events_models.dart';
import '../models/team_stats_snapshot.dart';

class SolarTeamOverviewCard extends StatelessWidget {
  const SolarTeamOverviewCard({
    required this.team,
    required this.teamStats,
    super.key,
    this.awardsCount,
    this.onTap,
  });

  final TeamSummary team;
  final TeamStatsSnapshot teamStats;
  final int? awardsCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final solarizeRank = teamStats.openSkillEntry?.ranking;
    final winRateLabel = teamStats.winRate == null
        ? '--'
        : '${teamStats.winRate!.toStringAsFixed(1)}%';
    final totalEvents = teamStats.allEvents.isNotEmpty
        ? teamStats.allEvents.length
        : teamStats.futureEvents.length + teamStats.pastEvents.length;
    final metricRows = <_TeamPosterMetric>[
      _TeamPosterMetric(label: 'W/L/T', value: teamStats.recordLabel),
      _TeamPosterMetric(label: 'WIN RATE', value: winRateLabel),
      _TeamPosterMetric(label: 'MATCHES', value: '${teamStats.totalMatches}'),
      _TeamPosterMetric(
        label: 'AWARDS',
        value: awardsCount == null ? '--' : '$awardsCount',
      ),
      _TeamPosterMetric(
        label: 'SKILLS SCORE',
        value: teamStats.skillsScoreLabel,
      ),
      _TeamPosterMetric(label: 'SKILLS RANK', value: teamStats.skillsRankLabel),
      _TeamPosterMetric(
        label: 'SOLARIZE RANK',
        value: solarizeRank == null || solarizeRank <= 0
            ? '--'
            : '#$solarizeRank',
      ),
      _TeamPosterMetric(
        label: 'UPCOMING',
        value: '${teamStats.futureEvents.length}/$totalEvents',
      ),
      _TeamPosterMetric(
        label: 'CCWM',
        value: _decimalLabel(teamStats.ccwm, signed: true),
      ),
      _TeamPosterMetric(label: 'OPR', value: _decimalLabel(teamStats.opr)),
      _TeamPosterMetric(label: 'DPR', value: _decimalLabel(teamStats.dpr)),
    ];

    final title = team.teamName.trim().isEmpty
        ? 'Team profile'
        : team.teamName.trim();
    final organization = team.organization.trim();
    final location = _heroLocationLabel(teamStats);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(36),
      child: Container(
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.fromLTRB(26, 24, 26, 26),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(36),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF030815),
              Color(0xFF0C1734),
              Color(0xFF1E2F68),
            ],
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 28,
              offset: Offset(0, 18),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              team.number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 54,
                fontWeight: FontWeight.w800,
                letterSpacing: -2.2,
                height: 0.95,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.6,
                height: 1.1,
              ),
            ),
            if (organization.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                organization,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              location.toUpperCase(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 18),
            for (var index = 0; index < metricRows.length; index++) ...<Widget>[
              _PosterMetricRow(metric: metricRows[index]),
              if (index != metricRows.length - 1)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.22),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TeamPosterMetric {
  const _TeamPosterMetric({required this.label, required this.value});

  final String label;
  final String value;
}

class _PosterMetricRow extends StatelessWidget {
  const _PosterMetricRow({required this.metric});

  final _TeamPosterMetric metric;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            metric.label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.94),
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Text(
          metric.value,
          textAlign: TextAlign.right,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

String _heroLocationLabel(TeamStatsSnapshot teamStats) {
  final location = teamStats.team.location;
  final pieces = <String>[
    if (location.region.trim().isNotEmpty) location.region.trim(),
    if (location.country.trim().isNotEmpty) location.country.trim(),
  ];
  if (pieces.isNotEmpty) {
    return pieces.join(', ');
  }
  return teamStats.locationLabel;
}

String _decimalLabel(double? value, {bool signed = false}) {
  if (value == null) {
    return '--';
  }
  if (signed && value > 0) {
    return '+${value.toStringAsFixed(1)}';
  }
  return value.toStringAsFixed(1);
}
