import 'package:flutter/material.dart';

import '../../app/solar_app_scope.dart';
import '../../models/robot_events_models.dart';
import 'match_details_screen.dart';
import '../widgets/solar_match_row.dart';
import '../widgets/solar_team_link.dart';
import '../widgets/solar_event_subpage_scaffold.dart';

class EventDivisionScreenArgs {
  const EventDivisionScreenArgs({
    required this.event,
    required this.division,
    this.highlightTeamNumber,
  });

  final EventSummary event;
  final DivisionSummary division;
  final String? highlightTeamNumber;
}

class EventDivisionScreen extends StatelessWidget {
  const EventDivisionScreen({required this.args, super.key});

  static const routeName = '/event-division';

  final EventDivisionScreenArgs args;

  @override
  Widget build(BuildContext context) {
    final controller = SolarAppScope.of(context);
    final rankingsFuture = controller.fetchDivisionRankings(
      eventId: args.event.id,
      divisionId: args.division.id,
    );
    final matchesFuture = controller.fetchDivisionMatches(
      eventId: args.event.id,
      divisionId: args.division.id,
    );

    return DefaultTabController(
      length: 2,
      child: SolarEventSubpageScaffold(
        title: args.division.name,
        subtitle: args.event.name,
        body: Column(
          children: <Widget>[
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const TabBar(
                indicatorColor: Color(0xFF5A67F3),
                labelColor: Color(0xFF24243A),
                unselectedLabelColor: Color(0xFF8E92A7),
                tabs: <Widget>[
                  Tab(text: 'Rankings'),
                  Tab(text: 'Matches'),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: TabBarView(
                children: <Widget>[
                  FutureBuilder<List<Object>>(
                    future: Future.wait<Object>(<Future<Object>>[
                      rankingsFuture.then<Object>((value) => value),
                      matchesFuture.then<Object>((value) => value),
                    ]),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const _CenteredLoader();
                      }

                      final values = snapshot.data!;
                      final rankings = values[0] as List<RankingRecord>;
                      final matches = values[1] as List<MatchSummary>;
                      if (rankings.isEmpty) {
                        return const _EmptyEventState(
                          title: 'No rankings yet',
                          body:
                              'This division has no published rankings right now.',
                        );
                      }

                      final performanceTable =
                          _DivisionPerformanceTable.fromMatches(matches);

                      return ListView.builder(
                        padding: const EdgeInsets.only(bottom: 8),
                        itemCount: rankings.length,
                        itemBuilder: (context, index) => _RankingCard(
                          ranking: rankings[index],
                          highlightTeamNumber: args.highlightTeamNumber,
                          metrics: performanceTable.forTeam(
                            rankings[index].team.number,
                          ),
                        ),
                      );
                    },
                  ),
                  FutureBuilder<List<MatchSummary>>(
                    future: matchesFuture,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const _CenteredLoader();
                      }
                      final matches = snapshot.data!;
                      if (matches.isEmpty) {
                        return const _EmptyEventState(
                          title: 'No matches yet',
                          body:
                              'When division match data is available, it will show up here.',
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.only(bottom: 8),
                        itemCount: matches.length,
                        itemBuilder: (context, index) => SolarMatchRow(
                          match: matches[index],
                          highlightTeamNumber: args.highlightTeamNumber,
                          onTap: () {
                            Navigator.of(context).pushNamed(
                              MatchDetailsScreen.routeName,
                              arguments: MatchDetailsScreenArgs(
                                match: matches[index],
                                event: args.event,
                                highlightTeamNumber: args.highlightTeamNumber,
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankingCard extends StatelessWidget {
  const _RankingCard({
    required this.ranking,
    required this.highlightTeamNumber,
    required this.metrics,
  });

  final RankingRecord ranking;
  final String? highlightTeamNumber;
  final _DivisionPerformanceMetrics? metrics;

  @override
  Widget build(BuildContext context) {
    final isHighlighted =
        highlightTeamNumber != null &&
        ranking.team.number.trim().toUpperCase() ==
            highlightTeamNumber!.trim().toUpperCase();
    final labelColor = isHighlighted
        ? const Color(0xFF2930FF)
        : const Color(0xFF16182C);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFDADAE3))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 44,
            child: Text(
              ranking.rank > 0 ? '${ranking.rank}' : '--',
              style: TextStyle(
                color: labelColor,
                fontSize: 30,
                fontWeight: FontWeight.w600,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: SolarTeamLinkText(
                        teamNumber: ranking.team.number,
                        teamId: ranking.team.id,
                        teamName: ranking.team.name,
                        style: TextStyle(
                          color: labelColor,
                          fontSize: 24,
                          fontWeight: isHighlighted
                              ? FontWeight.w500
                              : FontWeight.w300,
                          letterSpacing: -0.9,
                        ),
                      ),
                    ),
                    if (isHighlighted)
                      const Text(
                        'YOU',
                        style: TextStyle(
                          color: Color(0xFF2930FF),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.9,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${_recordLabel(ranking)}  •  WP ${_intLabel(ranking.wp)}',
                  style: const TextStyle(
                    color: Color(0xFF8E92A7),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'OPR ${metrics?.oprLabel ?? '--'}  •  DPR ${metrics?.dprLabel ?? '--'}  •  CCWM ${metrics?.ccwmLabel ?? '--'}',
                  style: const TextStyle(
                    color: Color(0xFF6F748B),
                    fontSize: 13,
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

class _DivisionPerformanceTable {
  const _DivisionPerformanceTable._(this._teams);

  final Map<String, _DivisionPerformanceMetrics> _teams;

  factory _DivisionPerformanceTable.fromMatches(List<MatchSummary> matches) {
    final accumulators = <String, _TeamPerformanceAccumulator>{};

    for (final match in matches) {
      if (match.alliances.length < 2) {
        continue;
      }

      final first = match.alliances[0];
      final second = match.alliances[1];
      if (first.score < 0 || second.score < 0) {
        continue;
      }

      _applyAlliance(
        accumulatorMap: accumulators,
        alliance: first,
        opponent: second,
      );
      _applyAlliance(
        accumulatorMap: accumulators,
        alliance: second,
        opponent: first,
      );
    }

    return _DivisionPerformanceTable._(<String, _DivisionPerformanceMetrics>{
      for (final entry in accumulators.entries)
        entry.key: entry.value.toMetrics(),
    });
  }

  _DivisionPerformanceMetrics? forTeam(String teamNumber) {
    return _teams[teamNumber.trim().toUpperCase()];
  }

  static void _applyAlliance({
    required Map<String, _TeamPerformanceAccumulator> accumulatorMap,
    required MatchAlliance alliance,
    required MatchAlliance opponent,
  }) {
    for (final team in alliance.teams) {
      final key = team.number.trim().toUpperCase();
      final accumulator = accumulatorMap.putIfAbsent(
        key,
        () => _TeamPerformanceAccumulator(),
      );
      accumulator.matches += 1;
      accumulator.offenseTotal += alliance.score;
      accumulator.defenseTotal += opponent.score;
      accumulator.marginTotal += alliance.score - opponent.score;
    }
  }
}

class _TeamPerformanceAccumulator {
  int matches = 0;
  double offenseTotal = 0;
  double defenseTotal = 0;
  double marginTotal = 0;

  _DivisionPerformanceMetrics toMetrics() {
    if (matches == 0) {
      return const _DivisionPerformanceMetrics(
        opr: null,
        dpr: null,
        ccwm: null,
      );
    }

    return _DivisionPerformanceMetrics(
      opr: offenseTotal / matches,
      dpr: defenseTotal / matches,
      ccwm: marginTotal / matches,
    );
  }
}

class _DivisionPerformanceMetrics {
  const _DivisionPerformanceMetrics({
    required this.opr,
    required this.dpr,
    required this.ccwm,
  });

  final double? opr;
  final double? dpr;
  final double? ccwm;

  String get oprLabel => _decimalLabel(opr);
  String get dprLabel => _decimalLabel(dpr);
  String get ccwmLabel => _decimalLabel(ccwm, signed: true);
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

class _EmptyEventState extends StatelessWidget {
  const _EmptyEventState({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF24243A),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF8E92A7),
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _recordLabel(RankingRecord ranking) {
  if (ranking.wins < 0 || ranking.losses < 0 || ranking.ties < 0) {
    return 'Record pending';
  }
  return '${ranking.wins}-${ranking.losses}-${ranking.ties}';
}

String _intLabel(int value) => value < 0 ? '--' : '$value';

String _decimalLabel(double? value, {bool signed = false}) {
  if (value == null) {
    return '--';
  }
  if (signed && value > 0) {
    return '+${value.toStringAsFixed(1)}';
  }
  return value.toStringAsFixed(1);
}
