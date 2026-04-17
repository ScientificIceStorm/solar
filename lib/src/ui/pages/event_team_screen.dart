import 'package:flutter/material.dart';

import '../../app/app_session_controller.dart';
import '../../app/solar_app_scope.dart';
import '../../models/robot_events_models.dart';
import '../models/team_stats_snapshot.dart';
import '../widgets/solar_event_subpage_scaffold.dart';
import '../widgets/solar_match_row.dart';
import 'match_details_screen.dart';

class EventTeamScreenArgs {
  const EventTeamScreenArgs({
    required this.event,
    required this.team,
    this.highlightTeamNumber,
  });

  final EventSummary event;
  final TeamSummary team;
  final String? highlightTeamNumber;
}

enum _EventTeamTab { schedule, stats }

Future<void> openSolarEventTeamScreen(
  BuildContext context, {
  required EventSummary event,
  required TeamSummary team,
  String? highlightTeamNumber,
}) {
  return Navigator.of(context).pushNamed(
    EventTeamScreen.routeName,
    arguments: EventTeamScreenArgs(
      event: event,
      team: team,
      highlightTeamNumber: highlightTeamNumber,
    ),
  );
}

class EventTeamScreen extends StatefulWidget {
  const EventTeamScreen({required this.args, super.key});

  static const routeName = '/event-team';

  final EventTeamScreenArgs args;

  @override
  State<EventTeamScreen> createState() => _EventTeamScreenState();
}

class _EventTeamScreenState extends State<EventTeamScreen> {
  Future<TeamStatsSnapshot>? _teamStatsFuture;
  Future<List<MatchSummary>>? _scheduleFuture;
  _EventTeamTab _selectedTab = _EventTeamTab.schedule;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_teamStatsFuture != null && _scheduleFuture != null) {
      return;
    }
    final controller = SolarAppScope.of(context);
    _teamStatsFuture = _loadTeamStats(controller, force: false);
    _scheduleFuture = _loadSchedule(controller, force: false);
  }

  Future<TeamStatsSnapshot> _loadTeamStats(
    AppSessionController controller, {
    required bool force,
  }) async {
    await controller.ensureSolarizeCoverageForTeams(
      teams: <TeamSummary>[widget.args.team],
      force: force,
    );
    return controller.fetchTeamStatsSnapshot(widget.args.team, force: force);
  }

  Future<List<MatchSummary>> _loadSchedule(
    AppSessionController controller, {
    required bool force,
  }) {
    return controller.fetchTeamMatchesForReference(
      TeamReference(
        id: widget.args.team.id,
        number: widget.args.team.number,
        name: widget.args.team.teamName,
      ),
      eventId: widget.args.event.id,
      force: force,
    );
  }

  Future<void> _refresh() async {
    final controller = SolarAppScope.of(context);
    final statsFuture = _loadTeamStats(controller, force: true);
    final scheduleFuture = _loadSchedule(controller, force: true);
    setState(() {
      _teamStatsFuture = statsFuture;
      _scheduleFuture = scheduleFuture;
    });
    await Future.wait<Object>(<Future<Object>>[
      statsFuture.then<Object>((value) => value),
      scheduleFuture.then<Object>((value) => value),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.args.team.number;
    final subtitle = widget.args.team.teamName.trim().isEmpty
        ? widget.args.event.name
        : '${widget.args.team.teamName} | ${widget.args.event.name}';

    return SolarEventSubpageScaffold(
      title: title,
      subtitle: subtitle,
      body: RefreshIndicator(
        color: Colors.black,
        onRefresh: _refresh,
        child: FutureBuilder<List<Object>>(
          future: Future.wait<Object>(<Future<Object>>[
            _teamStatsFuture!.then<Object>((value) => value),
            _scheduleFuture!.then<Object>((value) => value),
          ]),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              );
            }

            final values = snapshot.data!;
            final teamStats = values[0] as TeamStatsSnapshot;
            final schedule = values[1] as List<MatchSummary>;
            final eventSnapshot = _EventTeamSnapshot.fromMatches(
              teamNumber: widget.args.team.number,
              matches: schedule,
            );

            return StretchingOverscrollIndicator(
              axisDirection: AxisDirection.down,
              child: ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.only(bottom: 12),
                children: <Widget>[
                  _EventTeamHeader(teamStats: teamStats),
                  const SizedBox(height: 20),
                  _EventTeamTabBar(
                    selectedTab: _selectedTab,
                    onSelected: (tab) {
                      setState(() {
                        _selectedTab = tab;
                      });
                    },
                  ),
                  const SizedBox(height: 22),
                  if (_selectedTab == _EventTeamTab.schedule)
                    _ScheduleTab(
                      event: widget.args.event,
                      matches: schedule,
                      highlightTeamNumber:
                          widget.args.highlightTeamNumber ??
                          widget.args.team.number,
                    )
                  else
                    _StatsTab(
                      teamStats: teamStats,
                      eventSnapshot: eventSnapshot,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EventTeamHeader extends StatelessWidget {
  const _EventTeamHeader({required this.teamStats});

  final TeamStatsSnapshot teamStats;

  @override
  Widget build(BuildContext context) {
    final pieces = <String>[
      if (teamStats.team.teamName.trim().isNotEmpty) teamStats.team.teamName.trim(),
      if (teamStats.team.organization.trim().isNotEmpty)
        teamStats.team.organization.trim(),
      if (teamStats.locationLabel != 'Location pending') teamStats.locationLabel,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          teamStats.team.number,
          style: const TextStyle(
            color: Color(0xFF24243A),
            fontSize: 34,
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          pieces.isEmpty ? 'Event team profile' : pieces.join(' | '),
          style: const TextStyle(
            color: Color(0xFF8E92A7),
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _EventTeamTabBar extends StatelessWidget {
  const _EventTeamTabBar({
    required this.selectedTab,
    required this.onSelected,
  });

  final _EventTeamTab selectedTab;
  final ValueChanged<_EventTeamTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F1F6),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: _EventTeamTab.values.map((tab) {
          final selected = tab == selectedTab;
          final label = switch (tab) {
            _EventTeamTab.schedule => 'Schedule',
            _EventTeamTab.stats => 'Stats',
          };
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelected(tab),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: selected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: selected
                      ? const <BoxShadow>[
                          BoxShadow(
                            color: Color(0x10000000),
                            blurRadius: 16,
                            offset: Offset(0, 8),
                          ),
                        ]
                      : const <BoxShadow>[],
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF24243A)
                        : const Color(0xFF7A7F92),
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _ScheduleTab extends StatelessWidget {
  const _ScheduleTab({
    required this.event,
    required this.matches,
    required this.highlightTeamNumber,
  });

  final EventSummary event;
  final List<MatchSummary> matches;
  final String highlightTeamNumber;

  @override
  Widget build(BuildContext context) {
    final controller = SolarAppScope.of(context);
    if (matches.isEmpty) {
      return const _InlineEmptyState(
        title: 'No published event schedule yet',
        body:
            'When RobotEvents posts this team\'s event matches, they will appear here.',
      );
    }

    return Column(
      children: <Widget>[
        for (final match in matches)
          SolarMatchRow(
            match: match,
            highlightTeamNumber: highlightTeamNumber,
            onTap: () {
              Navigator.of(context).pushNamed(
                MatchDetailsScreen.routeName,
                arguments: MatchDetailsScreenArgs(
                  match: match,
                  event: event,
                  highlightTeamNumber: highlightTeamNumber,
                ),
              );
            },
            onTeamTap: (reference) {
              final resolvedTeam = controller.resolveKnownTeamSummary(
                teamNumber: reference.number,
                teamId: reference.id,
                teamName: reference.name,
              );
              openSolarEventTeamScreen(
                context,
                event: event,
                team: resolvedTeam,
                highlightTeamNumber: reference.number,
              );
            },
          ),
      ],
    );
  }
}

class _StatsTab extends StatelessWidget {
  const _StatsTab({required this.teamStats, required this.eventSnapshot});

  final TeamStatsSnapshot teamStats;
  final _EventTeamSnapshot eventSnapshot;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _StatsSection(
          title: 'Event Snapshot',
          rows: <MapEntry<String, String>>[
            MapEntry('Record', eventSnapshot.recordLabel),
            MapEntry('Matches', '${eventSnapshot.totalMatches}'),
            MapEntry('Avg Scored', _decimalLabel(eventSnapshot.averageScored)),
            MapEntry('Avg Allowed', _decimalLabel(eventSnapshot.averageAllowed)),
            MapEntry('Margin', _decimalLabel(eventSnapshot.margin, signed: true)),
          ],
        ),
        const SizedBox(height: 18),
        _StatsSection(
          title: 'Season Snapshot',
          rows: <MapEntry<String, String>>[
            MapEntry('CCWM', _decimalLabel(teamStats.ccwm, signed: true)),
            MapEntry('OPR', _decimalLabel(teamStats.opr)),
            MapEntry('DPR', _decimalLabel(teamStats.dpr)),
            MapEntry('Record', teamStats.recordLabel),
            MapEntry('Skills Rank', teamStats.skillsRankLabel),
            MapEntry('Skills Score', teamStats.skillsScoreLabel),
          ],
        ),
      ],
    );
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection({required this.title, required this.rows});

  final String title;
  final List<MapEntry<String, String>> rows;

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
        for (var index = 0; index < rows.length; index++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: index == rows.length - 1
                ? null
                : const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Color(0xFFDADAE3))),
                  ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    rows[index].key,
                    style: const TextStyle(
                      color: Color(0xFF8E92A7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  rows[index].value,
                  style: const TextStyle(
                    color: Color(0xFF24243A),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _InlineEmptyState extends StatelessWidget {
  const _InlineEmptyState({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF24243A),
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              color: Color(0xFF8E92A7),
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventTeamSnapshot {
  const _EventTeamSnapshot({
    required this.wins,
    required this.losses,
    required this.ties,
    required this.totalMatches,
    required this.averageScored,
    required this.averageAllowed,
    required this.margin,
  });

  factory _EventTeamSnapshot.fromMatches({
    required String teamNumber,
    required List<MatchSummary> matches,
  }) {
    var wins = 0;
    var losses = 0;
    var ties = 0;
    var scoreTotal = 0.0;
    var allowedTotal = 0.0;
    var scoredMatches = 0;
    final normalizedTeamNumber = teamNumber.trim().toUpperCase();

    for (final match in matches) {
      if (match.alliances.length < 2 ||
          match.alliances.any((alliance) => alliance.score < 0)) {
        continue;
      }

      MatchAlliance? alliance;
      MatchAlliance? opponent;
      for (final candidate in match.alliances) {
        final containsTeam = candidate.teams.any((team) {
          return team.number.trim().toUpperCase() == normalizedTeamNumber;
        });
        if (containsTeam) {
          alliance = candidate;
        } else {
          opponent = candidate;
        }
      }

      if (alliance == null || opponent == null) {
        continue;
      }

      if (alliance.score > opponent.score) {
        wins += 1;
      } else if (alliance.score < opponent.score) {
        losses += 1;
      } else {
        ties += 1;
      }
      scoreTotal += alliance.score;
      allowedTotal += opponent.score;
      scoredMatches += 1;
    }

    final averageScored = scoredMatches == 0 ? null : scoreTotal / scoredMatches;
    final averageAllowed = scoredMatches == 0
        ? null
        : allowedTotal / scoredMatches;
    return _EventTeamSnapshot(
      wins: wins,
      losses: losses,
      ties: ties,
      totalMatches: scoredMatches,
      averageScored: averageScored,
      averageAllowed: averageAllowed,
      margin: averageScored == null || averageAllowed == null
          ? null
          : averageScored - averageAllowed,
    );
  }

  final int wins;
  final int losses;
  final int ties;
  final int totalMatches;
  final double? averageScored;
  final double? averageAllowed;
  final double? margin;

  String get recordLabel {
    if (totalMatches == 0) {
      return '--';
    }
    return '$wins-$losses-$ties';
  }
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
