import 'package:flutter/material.dart';

import '../../app/solar_app_scope.dart';
import '../../models/open_skill_models.dart';
import '../../models/robot_events_models.dart';
import '../models/team_stats_snapshot.dart';
import '../widgets/solar_event_subpage_scaffold.dart';
import 'event_details_screen.dart';

class TeamProfileScreen extends StatefulWidget {
  const TeamProfileScreen({required this.team, super.key});

  static const routeName = '/team-profile';

  final TeamSummary team;

  @override
  State<TeamProfileScreen> createState() => _TeamProfileScreenState();
}

class _TeamProfileScreenState extends State<TeamProfileScreen> {
  Future<TeamStatsSnapshot>? _snapshotFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _snapshotFuture ??= _loadSnapshot();
  }

  Future<TeamStatsSnapshot> _loadSnapshot({bool force = false}) {
    final controller = SolarAppScope.of(context);
    return controller.fetchTeamStatsSnapshot(widget.team, force: force);
  }

  Future<void> _refresh() async {
    final future = _loadSnapshot(force: true);
    setState(() {
      _snapshotFuture = future;
    });
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return SolarEventSubpageScaffold(
      title: widget.team.number,
      subtitle: widget.team.teamName.isEmpty
          ? 'Team profile'
          : widget.team.teamName,
      body: FutureBuilder<TeamStatsSnapshot>(
        future: _snapshotFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const _CenteredLoader();
          }

          final teamStats = snapshot.data!;
          return RefreshIndicator(
            color: Colors.black,
            onRefresh: _refresh,
            child: StretchingOverscrollIndicator(
              axisDirection: AxisDirection.down,
              child: ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.only(bottom: 24),
                children: <Widget>[
                  _TeamHeader(teamStats: teamStats),
                  const SizedBox(height: 24),
                  if ((teamStats.errorMessage ?? '').isNotEmpty) ...<Widget>[
                    _InlineMessage(teamStats.errorMessage!),
                    const SizedBox(height: 24),
                  ],
                  _TeamSection(
                    title: 'Performance',
                    child: Column(
                      children: <Widget>[
                        _StatRow(
                          label: 'CCWM',
                          value: _decimalLabel(teamStats.ccwm, signed: true),
                        ),
                        _StatRow(
                          label: 'OPR',
                          value: _decimalLabel(teamStats.opr),
                        ),
                        _StatRow(
                          label: 'DPR',
                          value: _decimalLabel(teamStats.dpr),
                        ),
                        _StatRow(label: 'Record', value: teamStats.recordLabel),
                        _StatRow(
                          label: 'Win Rate',
                          value: teamStats.winRate == null
                              ? '--'
                              : '${teamStats.winRate!.toStringAsFixed(1)}%',
                        ),
                        _StatRow(
                          label: 'Matches',
                          value: '${teamStats.totalMatches}',
                          showDivider: false,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _TeamSection(
                    title: 'Skills',
                    child: Column(
                      children: <Widget>[
                        _StatRow(
                          label: 'World Rank',
                          value: teamStats.skillsRankLabel,
                        ),
                        _StatRow(
                          label: 'Combined',
                          value: teamStats.skillsScoreLabel,
                        ),
                        _StatRow(
                          label: 'Driver',
                          value: teamStats.driverScoreLabel,
                        ),
                        _StatRow(
                          label: 'Auton',
                          value: teamStats.programmingScoreLabel,
                          showDivider: false,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  _TeamSection(
                    title: 'Profile',
                    child: Column(
                      children: <Widget>[
                        _StatRow(
                          label: 'Organization',
                          value: _fallback(teamStats.team.organization),
                        ),
                        _StatRow(
                          label: 'Robot',
                          value: _fallback(teamStats.team.robotName),
                        ),
                        _StatRow(
                          label: 'Grade',
                          value: _fallback(teamStats.team.grade),
                        ),
                        _StatRow(
                          label: 'Location',
                          value: teamStats.locationLabel,
                          showDivider: false,
                        ),
                      ],
                    ),
                  ),
                  if (teamStats.openSkillEntry != null) ...<Widget>[
                    const SizedBox(height: 24),
                    _TeamSection(
                      title: 'Rating Source',
                      child: _OpenSkillSummary(
                        entry: teamStats.openSkillEntry!,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  _EventSection(
                    title: 'Upcoming Events',
                    emptyLabel: 'No upcoming events for this team.',
                    events: teamStats.futureEvents,
                  ),
                  const SizedBox(height: 24),
                  _EventSection(
                    title: 'Past Events',
                    emptyLabel: 'No past events published yet.',
                    events: teamStats.pastEvents,
                  ),
                  if (teamStats.rankings.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 24),
                    _TeamSection(
                      title: 'Ranking History',
                      child: Column(
                        children: <Widget>[
                          for (var i = 0; i < teamStats.rankings.length; i++)
                            _RankingHistoryRow(
                              ranking: teamStats.rankings[i],
                              showDivider: i != teamStats.rankings.length - 1,
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TeamHeader extends StatelessWidget {
  const _TeamHeader({required this.teamStats});

  final TeamStatsSnapshot teamStats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          teamStats.team.teamName.isEmpty
              ? 'Competition profile'
              : teamStats.team.teamName,
          style: const TextStyle(
            color: Color(0xFF24243A),
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          [
            if (teamStats.team.organization.isNotEmpty)
              teamStats.team.organization,
            if (teamStats.locationLabel.isNotEmpty) teamStats.locationLabel,
          ].join('  •  '),
          style: const TextStyle(
            color: Color(0xFF8E92A7),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _TeamSection extends StatelessWidget {
  const _TeamSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF24243A),
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.7,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  final String label;
  final String value;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: showDivider
          ? const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFDADAE3))),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF8E92A7),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Color(0xFF24243A),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpenSkillSummary extends StatelessWidget {
  const _OpenSkillSummary({required this.entry});

  final OpenSkillCacheEntry entry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _StatRow(label: 'OpenSkill Rank', value: '#${entry.ranking}'),
        _StatRow(
          label: 'OpenSkill Mu',
          value: entry.openSkillMu.toStringAsFixed(2),
        ),
        _StatRow(
          label: 'OpenSkill Sigma',
          value: entry.openSkillSigma.toStringAsFixed(2),
        ),
        _StatRow(label: 'Rating Source', value: _fallback(entry.ratingSource)),
        _StatRow(
          label: 'WP / Match',
          value: entry.wpPerMatch.toStringAsFixed(2),
        ),
        _StatRow(
          label: 'AP / Match',
          value: entry.apPerMatch.toStringAsFixed(2),
        ),
        _StatRow(
          label: 'Record',
          value: '${entry.totalWins}-${entry.totalLosses}-${entry.totalTies}',
        ),
        _StatRow(
          label: 'Worlds Qualified',
          value: entry.qualifiedForWorlds > 0 ? 'Yes' : 'No',
          showDivider: false,
        ),
      ],
    );
  }
}

class _EventSection extends StatelessWidget {
  const _EventSection({
    required this.title,
    required this.emptyLabel,
    required this.events,
  });

  final String title;
  final String emptyLabel;
  final List<EventSummary> events;

  @override
  Widget build(BuildContext context) {
    return _TeamSection(
      title: title,
      child: events.isEmpty
          ? _InlineMessage(emptyLabel)
          : Column(
              children: <Widget>[
                for (var i = 0; i < events.length; i++)
                  _TeamEventRow(
                    event: events[i],
                    showDivider: i != events.length - 1,
                  ),
              ],
            ),
    );
  }
}

class _TeamEventRow extends StatelessWidget {
  const _TeamEventRow({required this.event, required this.showDivider});

  final EventSummary event;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(
          context,
        ).pushNamed(EventDetailsScreen.routeName, arguments: event);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: showDivider
            ? const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFDADAE3))),
              )
            : null,
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    event.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF24243A),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _eventLocation(event.location),
                    style: const TextStyle(
                      color: Color(0xFF8E92A7),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  _eventDateLabel(event.start),
                  style: const TextStyle(
                    color: Color(0xFF24243A),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Color(0xFF8E92A7),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RankingHistoryRow extends StatelessWidget {
  const _RankingHistoryRow({required this.ranking, required this.showDivider});

  final RankingRecord ranking;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: showDivider
          ? const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFDADAE3))),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 44,
            child: Text(
              ranking.rank > 0 ? '#${ranking.rank}' : '--',
              style: const TextStyle(
                color: Color(0xFF24243A),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  ranking.event.name,
                  style: const TextStyle(
                    color: Color(0xFF24243A),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${ranking.division.name}  •  ${ranking.wins}-${ranking.losses}-${ranking.ties}',
                  style: const TextStyle(
                    color: Color(0xFF8E92A7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                'HS ${ranking.highScore > 0 ? ranking.highScore : '--'}',
                style: const TextStyle(
                  color: Color(0xFF24243A),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'AP ${ranking.averagePoints > 0 ? ranking.averagePoints.toStringAsFixed(1) : '--'}',
                style: const TextStyle(color: Color(0xFF8E92A7), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF8E92A7),
        fontSize: 14,
        height: 1.5,
      ),
    );
  }
}

class _CenteredLoader extends StatelessWidget {
  const _CenteredLoader();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2.4),
      ),
    );
  }
}

String _decimalLabel(double? value, {bool signed = false}) {
  if (value == null) {
    return '--';
  }
  final formatted = value.toStringAsFixed(1);
  if (!signed || value == 0) {
    return formatted;
  }
  return value > 0 ? '+$formatted' : formatted;
}

String _fallback(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? 'Not available' : trimmed;
}

String _eventLocation(LocationSummary location) {
  final pieces = <String>[
    if (location.city.isNotEmpty) location.city,
    if (location.region.isNotEmpty) location.region,
    if (location.country.isNotEmpty) location.country,
  ];
  return pieces.isEmpty ? 'Location pending' : pieces.join(', ');
}

String _eventDateLabel(DateTime? value) {
  if (value == null) {
    return 'TBD';
  }
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[value.month - 1]} ${value.day}';
}
