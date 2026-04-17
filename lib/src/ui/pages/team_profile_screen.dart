import 'package:flutter/material.dart';

import '../../app/solar_app_scope.dart';
import '../../models/open_skill_models.dart';
import '../../models/robot_events_models.dart';
import '../models/team_stats_snapshot.dart';
import '../widgets/solar_event_subpage_scaffold.dart';
import '../widgets/solar_trend_chart.dart';
import 'event_details_screen.dart';

enum _TeamProfileTab { overview, trends, events }

class TeamProfileScreen extends StatefulWidget {
  const TeamProfileScreen({required this.team, super.key});

  static const routeName = '/team-profile';

  final TeamSummary team;

  @override
  State<TeamProfileScreen> createState() => _TeamProfileScreenState();
}

class _TeamProfileScreenState extends State<TeamProfileScreen> {
  Future<TeamStatsSnapshot>? _snapshotFuture;
  Future<_TeamProfileDetails>? _detailsFuture;
  TeamStatsSnapshot? _seedSnapshot;
  _TeamProfileTab _selectedTab = _TeamProfileTab.overview;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_snapshotFuture == null) {
      final controller = SolarAppScope.of(context);
      _seedSnapshot = controller.previewTeamStatsSnapshot(widget.team);
      _snapshotFuture = _loadSnapshot();
    }
  }

  Future<TeamStatsSnapshot> _loadSnapshot({bool force = false}) {
    final controller = SolarAppScope.of(context);
    return controller
        .ensureSolarizeCoverageForTeams(
          teams: <TeamSummary>[widget.team],
          force: force,
        )
        .then(
          (_) => controller.fetchTeamStatsSnapshot(widget.team, force: force),
        );
  }

  Future<void> _refresh() async {
    final future = _loadSnapshot(force: true);
    setState(() {
      _snapshotFuture = future;
      _detailsFuture = null;
    });
    await future;
  }

  Future<_TeamProfileDetails> _ensureDetailsFuture(
    TeamStatsSnapshot teamStats,
  ) {
    return _detailsFuture ??= _loadDetails(teamStats);
  }

  Future<_TeamProfileDetails> _loadDetails(TeamStatsSnapshot teamStats) async {
    final controller = SolarAppScope.of(context);
    final orderedPastEvents = teamStats.pastEvents.toList(growable: false)
      ..sort((a, b) {
        final aDate = a.start ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.start ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aDate.compareTo(bDate);
      });
    final trackedEvents = orderedPastEvents.length <= 10
        ? orderedPastEvents
        : orderedPastEvents.sublist(orderedPastEvents.length - 10);

    final awardsEntries = await Future.wait<MapEntry<int, List<AwardSummary>>>(
      trackedEvents.map((event) async {
        final awards = await controller.fetchEventAwards(event.id);
        return MapEntry<int, List<AwardSummary>>(
          event.id,
          _awardsForTeam(awards, widget.team.number),
        );
      }),
    );

    final skillsHistory = await Future.wait<_SkillsHistoryEntry?>(
      trackedEvents.map((event) async {
        final attempts = await controller.fetchEventSkills(event.id);
        return _skillsHistoryEntryForTeam(event, attempts, widget.team.number);
      }),
    );

    return _TeamProfileDetails(
      awardsByEvent: <int, List<AwardSummary>>{
        for (final entry in awardsEntries) entry.key: entry.value,
      },
      skillsHistory: skillsHistory.whereType<_SkillsHistoryEntry>().toList(),
    );
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
        initialData: _seedSnapshot?.hasLiveSignal ?? false
            ? _seedSnapshot
            : null,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const _CenteredLoader();
          }

          final teamStats = snapshot.data!;
          final isLoadingLiveData =
              snapshot.connectionState != ConnectionState.done;
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
                  if (isLoadingLiveData) ...<Widget>[
                    const _StatusBanner(label: 'Loading live team stats...'),
                    const SizedBox(height: 20),
                  ],
                  if ((teamStats.errorMessage ?? '').isNotEmpty) ...<Widget>[
                    _InlineMessage(teamStats.errorMessage!),
                    const SizedBox(height: 24),
                  ],
                  _TeamProfileTabBar(
                    selectedTab: _selectedTab,
                    onSelected: (tab) {
                      setState(() {
                        _selectedTab = tab;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  switch (_selectedTab) {
                    _TeamProfileTab.overview => _OverviewTab(
                      key: const ValueKey<String>('overview'),
                      teamStats: teamStats,
                    ),
                    _TeamProfileTab.trends =>
                      FutureBuilder<_TeamProfileDetails>(
                        key: const ValueKey<String>('trends'),
                        future: _ensureDetailsFuture(teamStats),
                        builder: (context, detailsSnapshot) {
                          if (!detailsSnapshot.hasData) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 44),
                              child: _CenteredLoader(compact: true),
                            );
                          }
                          return _TrendsTab(
                            teamStats: teamStats,
                            details: detailsSnapshot.data!,
                          );
                        },
                      ),
                    _TeamProfileTab.events =>
                      FutureBuilder<_TeamProfileDetails>(
                        key: const ValueKey<String>('events'),
                        future: _ensureDetailsFuture(teamStats),
                        builder: (context, detailsSnapshot) {
                          if (!detailsSnapshot.hasData) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 44),
                              child: _CenteredLoader(compact: true),
                            );
                          }
                          return _EventsTab(
                            teamStats: teamStats,
                            details: detailsSnapshot.data!,
                          );
                        },
                      ),
                  },
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
    final controller = SolarAppScope.of(context);
    final isFavorite = controller.isFavoriteTeam(teamStats.team.number);
    final subtitleParts = <String>[
      if (teamStats.team.organization.isNotEmpty) teamStats.team.organization,
      if (teamStats.locationLabel.isNotEmpty) teamStats.locationLabel,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Text(
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
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: () {
                controller.toggleFavoriteTeam(teamStats.team);
              },
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  shape: BoxShape.circle,
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 16,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: const Color(0xFF24243A),
                  size: 21,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          subtitleParts.isEmpty
              ? 'Location pending'
              : subtitleParts.join('  •  '),
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

class _TeamProfileTabBar extends StatelessWidget {
  const _TeamProfileTabBar({
    required this.selectedTab,
    required this.onSelected,
  });

  final _TeamProfileTab selectedTab;
  final ValueChanged<_TeamProfileTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F2F6),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: _TeamProfileTab.values
            .map((tab) {
              final selected = tab == selectedTab;
              final label = switch (tab) {
                _TeamProfileTab.overview => 'Overview',
                _TeamProfileTab.trends => 'Trends',
                _TeamProfileTab.events => 'Events',
              };
              return Expanded(
                child: GestureDetector(
                  onTap: () => onSelected(tab),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      style: TextStyle(
                        color: selected
                            ? const Color(0xFF24243A)
                            : const Color(0xFF7A7F92),
                        fontSize: 14,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.teamStats, super.key});

  final TeamStatsSnapshot teamStats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _TeamSection(
          title: 'Performance',
          child: Column(
            children: <Widget>[
              _StatRow(
                label: 'CCWM',
                value: _decimalLabel(teamStats.ccwm, signed: true),
              ),
              _StatRow(label: 'OPR', value: _decimalLabel(teamStats.opr)),
              _StatRow(label: 'DPR', value: _decimalLabel(teamStats.dpr)),
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
              _StatRow(label: 'World Rank', value: teamStats.skillsRankLabel),
              _StatRow(label: 'Combined', value: teamStats.skillsScoreLabel),
              _StatRow(label: 'Driver', value: teamStats.driverScoreLabel),
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
              _StatRow(label: 'Grade', value: _fallback(teamStats.team.grade)),
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
            title: 'Solarize Signals',
            child: _OpenSkillSummary(
              entry: teamStats.openSkillEntry!,
              teamStats: teamStats,
            ),
          ),
        ],
      ],
    );
  }
}

class _TrendsTab extends StatelessWidget {
  const _TrendsTab({required this.teamStats, required this.details});

  final TeamStatsSnapshot teamStats;
  final _TeamProfileDetails details;

  @override
  Widget build(BuildContext context) {
    final scoringPoints = _recentMarginPoints(teamStats);
    final skillsPoints = details.skillsHistory
        .map(
          (entry) => SolarTrendPoint(
            label: _eventDateLabel(entry.event.start),
            value: entry.combined.toDouble(),
            detail: 'Driver ${entry.driver} • Auton ${entry.programming}',
          ),
        )
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _TeamSection(
          title: 'Scoring Trend',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SolarTrendChart(
                points: scoringPoints,
                emptyLabel:
                    'Completed match history will show here once results are published.',
                valueLabel: 'Recent scoring margin by match',
                signed: true,
                lineColor: const Color(0xFF1D4ED8),
              ),
              if (teamStats.averageScored != null ||
                  teamStats.averageAllowed != null) ...<Widget>[
                const SizedBox(height: 14),
                Text(
                  'Avg scored ${_decimalLabel(teamStats.averageScored)}  •  Avg allowed ${_decimalLabel(teamStats.averageAllowed)}',
                  style: const TextStyle(
                    color: Color(0xFF6E7388),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
        _TeamSection(
          title: 'Skills History',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SolarTrendChart(
                points: skillsPoints,
                emptyLabel:
                    'Recent event skills history will appear here when published attempts are available.',
                valueLabel: 'Combined skills by recent event',
                lineColor: const Color(0xFF0F766E),
              ),
              if (details.skillsHistory.isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                Text(
                  'Latest split: Driver ${details.skillsHistory.last.driver}  •  Auton ${details.skillsHistory.last.programming}',
                  style: const TextStyle(
                    color: Color(0xFF6E7388),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
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
    );
  }
}

class _EventsTab extends StatelessWidget {
  const _EventsTab({required this.teamStats, required this.details});

  final TeamStatsSnapshot teamStats;
  final _TeamProfileDetails details;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
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
          awardsByEvent: details.awardsByEvent,
        ),
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
  const _OpenSkillSummary({required this.entry, required this.teamStats});

  final OpenSkillCacheEntry entry;
  final TeamStatsSnapshot teamStats;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _StatRow(label: 'Model Rank', value: '#${entry.ranking}'),
        _StatRow(
          label: 'Record',
          value: teamStats.totalMatches > 0
              ? teamStats.recordLabel
              : '${entry.totalWins}-${entry.totalLosses}-${entry.totalTies}',
        ),
        _StatRow(
          label: 'WP / Match',
          value: entry.wpPerMatch.toStringAsFixed(2),
        ),
        _StatRow(
          label: 'AP / Match',
          value: entry.apPerMatch.toStringAsFixed(2),
        ),
        _StatRow(
          label: 'Elim Win Rate',
          value: entry.eliminationWinRate == null
              ? '--'
              : '${(entry.eliminationWinRate! * 100).toStringAsFixed(0)}%',
        ),
        _StatRow(
          label: 'Event Strength',
          value: entry.eventStrength == null
              ? '--'
              : entry.eventStrength!.toStringAsFixed(2),
        ),
        _StatRow(
          label: 'Coverage',
          value: teamStats.totalMatches > 0
              ? '${teamStats.totalMatches} matches'
              : 'Waiting on more live matches',
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
    this.awardsByEvent = const <int, List<AwardSummary>>{},
  });

  final String title;
  final String emptyLabel;
  final List<EventSummary> events;
  final Map<int, List<AwardSummary>> awardsByEvent;

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
                    awards:
                        awardsByEvent[events[i].id] ?? const <AwardSummary>[],
                    showDivider: i != events.length - 1,
                  ),
              ],
            ),
    );
  }
}

class _TeamEventRow extends StatelessWidget {
  const _TeamEventRow({
    required this.event,
    required this.awards,
    required this.showDivider,
  });

  final EventSummary event;
  final List<AwardSummary> awards;
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
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
            if (awards.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: awards
                    .take(4)
                    .map(
                      (award) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: award.qualifications.isNotEmpty
                              ? const Color(0xFFEAF3FF)
                              : const Color(0xFFF3F4F8),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          award.title,
                          style: TextStyle(
                            color: award.qualifications.isNotEmpty
                                ? const Color(0xFF1D4ED8)
                                : const Color(0xFF5C6074),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
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
                'AP ${ranking.averagePoints > 0 ? ranking.averagePoints.toStringAsFixed(1) : '--'}',
                style: const TextStyle(
                  color: Color(0xFF24243A),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
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

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E4F7)),
      ),
      child: Row(
        children: <Widget>[
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.1),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF55607B),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CenteredLoader extends StatelessWidget {
  const _CenteredLoader({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: compact ? 24 : 28,
        height: compact ? 24 : 28,
        child: const CircularProgressIndicator(strokeWidth: 2.4),
      ),
    );
  }
}

class _TeamProfileDetails {
  const _TeamProfileDetails({
    required this.awardsByEvent,
    required this.skillsHistory,
  });

  final Map<int, List<AwardSummary>> awardsByEvent;
  final List<_SkillsHistoryEntry> skillsHistory;
}

class _SkillsHistoryEntry {
  const _SkillsHistoryEntry({
    required this.event,
    required this.driver,
    required this.programming,
  });

  final EventSummary event;
  final int driver;
  final int programming;

  int get combined => driver + programming;
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

List<AwardSummary> _awardsForTeam(
  List<AwardSummary> awards,
  String teamNumber,
) {
  final normalizedTeamNumber = teamNumber.trim().toUpperCase();
  return awards
      .where((award) {
        return award.recipients.any((recipient) {
          return recipient.trim().toUpperCase().contains(normalizedTeamNumber);
        });
      })
      .toList(growable: false);
}

_SkillsHistoryEntry? _skillsHistoryEntryForTeam(
  EventSummary event,
  List<SkillAttempt> attempts,
  String teamNumber,
) {
  final normalizedTeamNumber = teamNumber.trim().toUpperCase();
  var driver = 0;
  var programming = 0;

  for (final attempt in attempts) {
    if (attempt.team.number.trim().toUpperCase() != normalizedTeamNumber) {
      continue;
    }

    if (_isProgrammingAttempt(attempt.type)) {
      if (attempt.score > programming) {
        programming = attempt.score;
      }
    } else if (attempt.score > driver) {
      driver = attempt.score;
    }
  }

  if (driver <= 0 && programming <= 0) {
    return null;
  }

  return _SkillsHistoryEntry(
    event: event,
    driver: driver,
    programming: programming,
  );
}

bool _isProgrammingAttempt(String type) {
  final normalized = type.trim().toLowerCase();
  return normalized.contains('program') || normalized.contains('auton');
}

List<SolarTrendPoint> _recentMarginPoints(TeamStatsSnapshot teamStats) {
  final completedMatches = teamStats.completedMatches.toList(growable: false)
    ..sort((a, b) {
      final aTime =
          a.started ?? a.scheduled ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime =
          b.started ?? b.scheduled ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aTime.compareTo(bTime);
    });
  if (completedMatches.isEmpty) {
    return const <SolarTrendPoint>[];
  }

  final recentMatches = completedMatches.length <= 12
      ? completedMatches
      : completedMatches.sublist(completedMatches.length - 12);

  return recentMatches
      .map((match) {
        final teamScore = teamStats.scoreForTeam(match) ?? 0;
        final opponentScore = teamStats.opponentScoreForTeam(match) ?? 0;
        return SolarTrendPoint(
          label: match.name.trim().isEmpty
              ? _eventDateLabel(match.started)
              : match.name,
          value: (teamScore - opponentScore).toDouble(),
          detail: '$teamScore-$opponentScore',
        );
      })
      .toList(growable: false);
}
