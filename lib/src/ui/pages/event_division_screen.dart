import 'package:flutter/material.dart';

import '../../app/app_session_controller.dart';
import '../../app/solar_app_scope.dart';
import '../../models/open_skill_models.dart';
import '../../models/robot_events_models.dart';
import '../models/solar_match_prediction.dart';
import '../widgets/solar_event_subpage_scaffold.dart';
import '../widgets/solar_match_row.dart';
import 'event_team_screen.dart';
import 'match_details_screen.dart';

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
    final eventTeamsFuture = controller.fetchEventTeams(args.event.id);

    return DefaultTabController(
      length: 4,
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
                isScrollable: true,
                indicatorColor: Color(0xFF5A67F3),
                labelColor: Color(0xFF24243A),
                unselectedLabelColor: Color(0xFF8E92A7),
                tabs: <Widget>[
                  Tab(text: 'Rankings'),
                  Tab(text: 'Matches'),
                  Tab(text: 'Teams'),
                  Tab(text: 'Predictions'),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: TabBarView(
                children: <Widget>[
                  _DivisionRankingsTab(
                    controller: controller,
                    event: args.event,
                    highlightTeamNumber: args.highlightTeamNumber,
                    rankingsFuture: rankingsFuture,
                    matchesFuture: matchesFuture,
                    eventTeamsFuture: eventTeamsFuture,
                  ),
                  _DivisionMatchesTab(
                    controller: controller,
                    event: args.event,
                    highlightTeamNumber: args.highlightTeamNumber,
                    matchesFuture: matchesFuture,
                    eventTeamsFuture: eventTeamsFuture,
                  ),
                  _DivisionTeamsTab(
                    controller: controller,
                    event: args.event,
                    highlightTeamNumber: args.highlightTeamNumber,
                    rankingsFuture: rankingsFuture,
                    eventTeamsFuture: eventTeamsFuture,
                  ),
                  FutureBuilder<List<Object>>(
                    future: Future.wait<Object>(<Future<Object>>[
                      rankingsFuture.then<Object>((value) => value),
                      matchesFuture.then<Object>((value) => value),
                      eventTeamsFuture.then<Object>((value) => value),
                    ]),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const _CenteredLoader();
                      }

                      final values = snapshot.data!;
                      final rankings = values[0] as List<RankingRecord>;
                      final matches = values[1] as List<MatchSummary>;
                      final eventTeams = values[2] as List<TeamSummary>;
                      if (rankings.isEmpty) {
                        return const _EmptyEventState(
                          title: 'No ranking data yet',
                          body:
                              'Alliance forecasts open up once the division publishes rankings.',
                        );
                      }

                      final teamsByKey = _eventTeamsByKey(
                        controller: controller,
                        rankings: rankings,
                        eventTeams: eventTeams,
                      );
                      final performanceTable =
                          _DivisionPerformanceTable.fromMatches(matches);
                      final predictions = _PredictedAllianceSelection.build(
                        rankings: rankings,
                        teamsByKey: teamsByKey,
                        performanceTable: performanceTable,
                        openSkillByTeam: <String, OpenSkillCacheEntry>{
                          for (final team in teamsByKey.values)
                            if (controller.openSkillEntryForTeam(team.number) !=
                                null)
                              team.number.trim().toUpperCase(): controller
                                  .openSkillEntryForTeam(team.number)!,
                        },
                      );

                      return _PredictionsTab(
                        predictions: predictions,
                        onOpenTeam: (team) {
                          openSolarEventTeamScreen(
                            context,
                            event: args.event,
                            team: team,
                            highlightTeamNumber: args.highlightTeamNumber,
                          );
                        },
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

Map<String, TeamSummary> _eventTeamsByKey({
  required AppSessionController controller,
  required List<RankingRecord> rankings,
  required List<TeamSummary> eventTeams,
}) {
  final teamsByKey = <String, TeamSummary>{
    for (final team in eventTeams) team.number.trim().toUpperCase(): team,
  };
  for (final ranking in rankings) {
    final key = ranking.team.number.trim().toUpperCase();
    teamsByKey.putIfAbsent(key, () => _teamFromRanking(controller, ranking));
  }
  return teamsByKey;
}

TeamSummary _teamFromRanking(
  AppSessionController controller,
  RankingRecord ranking,
) {
  return controller.resolveKnownTeamSummary(
    teamNumber: ranking.team.number,
    teamId: ranking.team.id,
    teamName: ranking.team.name,
    grade: 'High School',
  );
}

enum _DivisionRankingSortMode { rank, opr, dpr, ccwm, wp, ap, sp }

class _DivisionRankingsTab extends StatefulWidget {
  const _DivisionRankingsTab({
    required this.controller,
    required this.event,
    required this.highlightTeamNumber,
    required this.rankingsFuture,
    required this.matchesFuture,
    required this.eventTeamsFuture,
  });

  final AppSessionController controller;
  final EventSummary event;
  final String? highlightTeamNumber;
  final Future<List<RankingRecord>> rankingsFuture;
  final Future<List<MatchSummary>> matchesFuture;
  final Future<List<TeamSummary>> eventTeamsFuture;

  @override
  State<_DivisionRankingsTab> createState() => _DivisionRankingsTabState();
}

class _DivisionRankingsTabState extends State<_DivisionRankingsTab> {
  final TextEditingController _searchController = TextEditingController();
  _DivisionRankingSortMode _sortMode = _DivisionRankingSortMode.rank;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Object>>(
      future: Future.wait<Object>(<Future<Object>>[
        widget.rankingsFuture.then<Object>((value) => value),
        widget.matchesFuture.then<Object>((value) => value),
        widget.eventTeamsFuture.then<Object>((value) => value),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const _CenteredLoader();
        }

        final values = snapshot.data!;
        final rankings = values[0] as List<RankingRecord>;
        final matches = values[1] as List<MatchSummary>;
        final eventTeams = values[2] as List<TeamSummary>;
        if (rankings.isEmpty) {
          return const _EmptyEventState(
            title: 'No rankings yet',
            body: 'This division has no published rankings right now.',
          );
        }

        final teamsByKey = _eventTeamsByKey(
          controller: widget.controller,
          rankings: rankings,
          eventTeams: eventTeams,
        );
        final performanceTable = _DivisionPerformanceTable.fromMatches(matches);
        final sortedRankings = _sortDivisionRankings(
          rankings: rankings,
          performanceTable: performanceTable,
          sortMode: _sortMode,
        );
        final query = _searchController.text.trim().toLowerCase();
        final visibleRankings = query.isEmpty
            ? sortedRankings
            : sortedRankings
                  .where((ranking) {
                    final team =
                        teamsByKey[ranking.team.number.trim().toUpperCase()] ??
                        _teamFromRanking(widget.controller, ranking);
                    final haystack =
                        '${team.number} ${team.teamName} ${team.organization}'
                            .toLowerCase();
                    return haystack.contains(query);
                  })
                  .toList(growable: false);

        return Stack(
          children: <Widget>[
            StretchingOverscrollIndicator(
              axisDirection: AxisDirection.down,
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 94),
                itemCount: visibleRankings.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return _DivisionRankingSortStrip(
                      selectedMode: _sortMode,
                      onModeSelected: (value) {
                        setState(() {
                          _sortMode = value;
                        });
                      },
                    );
                  }

                  final ranking = visibleRankings[index - 1];
                  final team =
                      teamsByKey[ranking.team.number.trim().toUpperCase()] ??
                      _teamFromRanking(widget.controller, ranking);
                  return _RankingCard(
                    event: widget.event,
                    ranking: ranking,
                    team: team,
                    highlightTeamNumber: widget.highlightTeamNumber,
                    metrics: performanceTable.forTeam(team.number),
                  );
                },
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _DivisionRankingSearchBar(
                controller: _searchController,
                resultCount: visibleRankings.length,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        );
      },
    );
  }
}

enum _DivisionTeamSortMode { solarize, alphabetical }

class _DivisionMatchesTab extends StatefulWidget {
  const _DivisionMatchesTab({
    required this.controller,
    required this.event,
    required this.highlightTeamNumber,
    required this.matchesFuture,
    required this.eventTeamsFuture,
  });

  final AppSessionController controller;
  final EventSummary event;
  final String? highlightTeamNumber;
  final Future<List<MatchSummary>> matchesFuture;
  final Future<List<TeamSummary>> eventTeamsFuture;

  @override
  State<_DivisionMatchesTab> createState() => _DivisionMatchesTabState();
}

class _DivisionMatchesTabState extends State<_DivisionMatchesTab> {
  final TextEditingController _searchController = TextEditingController();
  bool _predictionModeEnabled = false;
  Future<Map<int, SolarMatchPrediction?>>? _predictionFuture;
  String? _predictionCacheKey;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _predictionKey(List<MatchSummary> matches) {
    final ids = matches.map((match) => '${match.id}').join(',');
    return '${widget.event.id}|$ids';
  }

  Future<Map<int, SolarMatchPrediction?>> _loadPredictions(
    List<MatchSummary> matches,
  ) async {
    final predictionMap = <int, SolarMatchPrediction?>{};
    for (final match in matches) {
      if (match.alliances.length < 2) {
        predictionMap[match.id] = null;
        continue;
      }

      try {
        predictionMap[match.id] = await widget.controller.predictMatch(
          match: match,
          event: widget.event,
        );
      } catch (_) {
        predictionMap[match.id] = null;
      }
    }
    return predictionMap;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Object>>(
      future: Future.wait<Object>(<Future<Object>>[
        widget.matchesFuture.then<Object>((value) => value),
        widget.eventTeamsFuture.then<Object>((value) => value),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const _CenteredLoader();
        }

        final values = snapshot.data!;
        final matches = values[0] as List<MatchSummary>;
        final eventTeams = values[1] as List<TeamSummary>;
        if (matches.isEmpty) {
          return const _EmptyEventState(
            title: 'No matches yet',
            body: 'When division match data is available, it will show up here.',
          );
        }

        final teamsByKey = <String, TeamSummary>{
          for (final team in eventTeams) team.number.trim().toUpperCase(): team,
        };
        final query = _searchController.text.trim().toLowerCase();
        final visibleMatches = query.isEmpty
            ? matches
            : matches.where((match) {
                final matchLabel = solarMatchScreenLabel(match).toLowerCase();
                if (matchLabel.contains(query)) {
                  return true;
                }
                for (final alliance in match.alliances) {
                  for (final team in alliance.teams) {
                    final teamLabel =
                        '${team.number} ${team.name}'.trim().toLowerCase();
                    if (teamLabel.contains(query)) {
                      return true;
                    }
                  }
                }
                return false;
              }).toList(growable: false);

        Widget matchesList(Map<int, SolarMatchPrediction?> predictionsByMatch) {
          return StretchingOverscrollIndicator(
            axisDirection: AxisDirection.down,
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: visibleMatches.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _DivisionMatchesToolbar(
                    controller: _searchController,
                    predictionModeEnabled: _predictionModeEnabled,
                    matchCount: visibleMatches.length,
                    onChanged: (_) => setState(() {}),
                    onPredictionModeChanged: (value) {
                      setState(() {
                        _predictionModeEnabled = value;
                      });
                    },
                  );
                }

                final match = visibleMatches[index - 1];
                final prediction = predictionsByMatch[match.id];
                final hasOfficialScore = _matchHasOfficialScore(match);

                final scoreOverride =
                    _predictionModeEnabled && !hasOfficialScore
                    ? _predictedScoreText(prediction)
                    : null;
                final stripeColor =
                    _predictionModeEnabled && !hasOfficialScore
                    ? _predictionStripeColor(prediction)
                    : null;

                return SolarMatchRow(
                  match: match,
                  highlightTeamNumber: widget.highlightTeamNumber,
                  stripeColorOverride: stripeColor,
                  scoreTextOverride: scoreOverride,
                  onTap: () {
                    Navigator.of(context).pushNamed(
                      MatchDetailsScreen.routeName,
                      arguments: MatchDetailsScreenArgs(
                        match: match,
                        event: widget.event,
                        highlightTeamNumber: widget.highlightTeamNumber,
                      ),
                    );
                  },
                  onTeamTap: (team) {
                    final resolvedTeam =
                        teamsByKey[team.number.trim().toUpperCase()] ??
                        widget.controller.resolveKnownTeamSummary(
                          teamNumber: team.number,
                          teamId: team.id,
                          teamName: team.name,
                          grade: 'High School',
                        );
                    openSolarEventTeamScreen(
                      context,
                      event: widget.event,
                      team: resolvedTeam,
                      highlightTeamNumber: widget.highlightTeamNumber,
                    );
                  },
                );
              },
            ),
          );
        }

        if (!_predictionModeEnabled) {
          return matchesList(const <int, SolarMatchPrediction?>{});
        }

        final predictionKey = _predictionKey(visibleMatches);
        if (_predictionFuture == null || _predictionCacheKey != predictionKey) {
          _predictionCacheKey = predictionKey;
          _predictionFuture = _loadPredictions(visibleMatches);
        }

        return FutureBuilder<Map<int, SolarMatchPrediction?>>(
          future: _predictionFuture,
          builder: (context, predictionSnapshot) {
            if (!predictionSnapshot.hasData) {
              return const _CenteredLoader();
            }
            return matchesList(predictionSnapshot.data!);
          },
        );
      },
    );
  }
}

class _DivisionMatchesToolbar extends StatelessWidget {
  const _DivisionMatchesToolbar({
    required this.controller,
    required this.predictionModeEnabled,
    required this.matchCount,
    required this.onChanged,
    required this.onPredictionModeChanged,
  });

  final TextEditingController controller;
  final bool predictionModeEnabled;
  final int matchCount;
  final ValueChanged<String> onChanged;
  final ValueChanged<bool> onPredictionModeChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD7DBEA)),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF6F748B),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isCollapsed: true,
                      hintText: 'Search matches or teams',
                      hintStyle: TextStyle(
                        color: Color(0xFF8E92A7),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: const TextStyle(
                      color: Color(0xFF24243A),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$matchCount',
                  style: const TextStyle(
                    color: Color(0xFF6F748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => onPredictionModeChanged(!predictionModeEnabled),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: predictionModeEnabled
                      ? const Color(0xFF16182C)
                      : const Color(0xFFE2E4F0),
                ),
                color: predictionModeEnabled
                    ? const Color(0xFF16182C)
                    : Colors.transparent,
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.analytics_outlined,
                    size: 16,
                    color: predictionModeEnabled
                        ? Colors.white
                        : const Color(0xFF24243A),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    predictionModeEnabled
                        ? 'Prediction mode on'
                        : 'Prediction mode off',
                    style: TextStyle(
                      color: predictionModeEnabled
                          ? Colors.white
                          : const Color(0xFF24243A),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Switch.adaptive(
                    value: predictionModeEnabled,
                    onChanged: onPredictionModeChanged,
                    activeColor: Colors.white,
                    activeTrackColor: const Color(0xFF5F66FF),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DivisionTeamsTab extends StatefulWidget {
  const _DivisionTeamsTab({
    required this.controller,
    required this.event,
    required this.highlightTeamNumber,
    required this.rankingsFuture,
    required this.eventTeamsFuture,
  });

  final AppSessionController controller;
  final EventSummary event;
  final String? highlightTeamNumber;
  final Future<List<RankingRecord>> rankingsFuture;
  final Future<List<TeamSummary>> eventTeamsFuture;

  @override
  State<_DivisionTeamsTab> createState() => _DivisionTeamsTabState();
}

class _DivisionTeamsTabState extends State<_DivisionTeamsTab> {
  final TextEditingController _searchController = TextEditingController();
  _DivisionTeamSortMode _sortMode = _DivisionTeamSortMode.solarize;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Object>>(
      future: Future.wait<Object>(<Future<Object>>[
        widget.rankingsFuture.then<Object>((value) => value),
        widget.eventTeamsFuture.then<Object>((value) async {
          await widget.controller.ensureSolarizeCoverageForTeams(teams: value);
          return value;
        }),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const _CenteredLoader();
        }

        final values = snapshot.data!;
        final rankings = values[0] as List<RankingRecord>;
        final eventTeams = values[1] as List<TeamSummary>;
        final teamsByKey = <String, TeamSummary>{
          for (final team in eventTeams) team.number.trim().toUpperCase(): team,
        };

        for (final ranking in rankings) {
          final key = ranking.team.number.trim().toUpperCase();
          teamsByKey.putIfAbsent(
            key,
            () => _teamFromRanking(widget.controller, ranking),
          );
        }

        final query = _searchController.text.trim().toLowerCase();
        final teams = teamsByKey.values.where((team) {
          if (query.isEmpty) {
            return true;
          }
          final haystack =
              '${team.number} ${team.teamName} ${team.organization}'.toLowerCase();
          return haystack.contains(query);
        }).toList(growable: false)
          ..sort((a, b) {
            if (_sortMode == _DivisionTeamSortMode.alphabetical) {
              return a.number.compareTo(b.number);
            }

            final aRank = widget.controller.openSkillEntryForTeam(a.number)?.ranking;
            final bRank = widget.controller.openSkillEntryForTeam(b.number)?.ranking;
            final aValue = (aRank == null || aRank <= 0) ? 999999 : aRank;
            final bValue = (bRank == null || bRank <= 0) ? 999999 : bRank;
            final rankCompare = aValue.compareTo(bValue);
            if (rankCompare != 0) {
              return rankCompare;
            }
            return a.number.compareTo(b.number);
          });

        if (teams.isEmpty) {
          return const _EmptyEventState(
            title: 'No teams found',
            body: 'Try a different search to find teams in this division.',
          );
        }

        return StretchingOverscrollIndicator(
          axisDirection: AxisDirection.down,
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 8),
            itemCount: teams.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _DivisionTeamsToolbar(
                  controller: _searchController,
                  sortMode: _sortMode,
                  teamCount: teams.length,
                  onChanged: (_) => setState(() {}),
                  onSortModeChanged: (value) {
                    setState(() {
                      _sortMode = value;
                    });
                  },
                );
              }

              final team = teams[index - 1];
              final highlighted =
                  widget.highlightTeamNumber != null &&
                  team.number.trim().toUpperCase() ==
                      widget.highlightTeamNumber!.trim().toUpperCase();

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    openSolarEventTeamScreen(
                      context,
                      event: widget.event,
                      team: team,
                      highlightTeamNumber: widget.highlightTeamNumber,
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFDADAE3)),
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Text(
                          team.number,
                          style: TextStyle(
                            color: highlighted
                                ? const Color(0xFF2930FF)
                                : const Color(0xFF24243A),
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.8,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            team.teamName.trim().isEmpty
                                ? 'Team profile'
                                : team.teamName.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF6F748B),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: Color(0xFF8E92A7),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _DivisionTeamsToolbar extends StatelessWidget {
  const _DivisionTeamsToolbar({
    required this.controller,
    required this.sortMode,
    required this.teamCount,
    required this.onChanged,
    required this.onSortModeChanged,
  });

  final TextEditingController controller;
  final _DivisionTeamSortMode sortMode;
  final int teamCount;
  final ValueChanged<String> onChanged;
  final ValueChanged<_DivisionTeamSortMode> onSortModeChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD7DBEA)),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF6F748B),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isCollapsed: true,
                      hintText: 'Search division teams',
                      hintStyle: TextStyle(
                        color: Color(0xFF8E92A7),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: const TextStyle(
                      color: Color(0xFF24243A),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$teamCount',
                  style: const TextStyle(
                    color: Color(0xFF6F748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: _DivisionTeamSortMode.values.map((mode) {
              final selected = mode == sortMode;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => onSortModeChanged(mode),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF16182C) : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF16182C)
                            : const Color(0xFFE2E4F0),
                      ),
                    ),
                    child: Text(
                      _divisionTeamSortModeLabel(mode),
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : const Color(0xFF24243A),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(growable: false),
          ),
        ],
      ),
    );
  }
}

TextSpan _predictedScoreText(SolarMatchPrediction? prediction) {
  if (prediction == null) {
    return const TextSpan(
      text: '-- - --',
      style: TextStyle(
        color: Colors.black,
        fontSize: 20,
        fontWeight: FontWeight.w400,
        letterSpacing: -0.5,
      ),
    );
  }

  final redScore = prediction.predictedRedScore;
  final blueScore = prediction.predictedBlueScore;
  final redWins = redScore > blueScore;
  final blueWins = blueScore > redScore;

  TextStyle scoreStyle(bool emphasized) {
    return TextStyle(
      color: Colors.black,
      fontSize: 20,
      fontWeight: emphasized ? FontWeight.w800 : FontWeight.w400,
      letterSpacing: -0.5,
    );
  }

  return TextSpan(
    children: <InlineSpan>[
      TextSpan(
        text: '$redScore',
        style: scoreStyle(redWins || (!redWins && !blueWins)),
      ),
      const TextSpan(
        text: ' - ',
        style: TextStyle(
          color: Colors.black,
          fontSize: 20,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.5,
        ),
      ),
      TextSpan(
        text: '$blueScore',
        style: scoreStyle(blueWins || (!redWins && !blueWins)),
      ),
    ],
  );
}

Color _predictionStripeColor(SolarMatchPrediction? prediction) {
  if (prediction == null) {
    return const Color(0xFFDADAE3);
  }
  if (prediction.predictedRedScore == prediction.predictedBlueScore) {
    return const Color(0xFFD6AF52);
  }
  return prediction.predictedRedScore > prediction.predictedBlueScore
      ? const Color(0xFF3FCB73)
      : const Color(0xFFFF6B64);
}

bool _matchHasOfficialScore(MatchSummary match) {
  if (match.alliances.length < 2) {
    return false;
  }

  MatchAlliance? red;
  MatchAlliance? blue;
  for (final alliance in match.alliances) {
    final color = alliance.color.toLowerCase();
    if (color == 'red') {
      red = alliance;
    } else if (color == 'blue') {
      blue = alliance;
    }
  }

  red ??= match.alliances.first;
  blue ??= match.alliances.length > 1 ? match.alliances[1] : match.alliances.first;
  return red.score >= 0 && blue.score >= 0;
}

String _divisionTeamSortModeLabel(_DivisionTeamSortMode mode) {
  switch (mode) {
    case _DivisionTeamSortMode.solarize:
      return 'Sort: Solarize';
    case _DivisionTeamSortMode.alphabetical:
      return 'Sort: A-Z';
  }
}

class _DivisionRankingSortStrip extends StatelessWidget {
  const _DivisionRankingSortStrip({
    required this.selectedMode,
    required this.onModeSelected,
  });

  final _DivisionRankingSortMode selectedMode;
  final ValueChanged<_DivisionRankingSortMode> onModeSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _DivisionRankingSortMode.values
              .map((mode) {
                final selected = mode == selectedMode;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () => onModeSelected(mode),
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? const Color(0xFF16182C)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFF16182C)
                              : const Color(0xFFE2E4F0),
                        ),
                      ),
                      child: Text(
                        _divisionSortModeLabel(mode),
                        style: TextStyle(
                          color: selected
                              ? Colors.white
                              : const Color(0xFF24243A),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }
}

List<RankingRecord> _sortDivisionRankings({
  required List<RankingRecord> rankings,
  required _DivisionPerformanceTable performanceTable,
  required _DivisionRankingSortMode sortMode,
}) {
  final sorted = rankings.toList(growable: false);
  sorted.sort((a, b) {
    final aMetrics = performanceTable.forTeam(a.team.number);
    final bMetrics = performanceTable.forTeam(b.team.number);

    int metricCompare;
    switch (sortMode) {
      case _DivisionRankingSortMode.rank:
        metricCompare = _safeRank(a.rank).compareTo(_safeRank(b.rank));
        break;
      case _DivisionRankingSortMode.opr:
        metricCompare = _compareDescendingDouble(
          aMetrics?.opr ?? _fallbackOpr(a),
          bMetrics?.opr ?? _fallbackOpr(b),
        );
        break;
      case _DivisionRankingSortMode.dpr:
        metricCompare = _compareAscendingDouble(aMetrics?.dpr, bMetrics?.dpr);
        break;
      case _DivisionRankingSortMode.ccwm:
        metricCompare = _compareDescendingDouble(
          aMetrics?.ccwm,
          bMetrics?.ccwm,
        );
        break;
      case _DivisionRankingSortMode.wp:
        metricCompare = _compareDescendingInt(a.wp, b.wp);
        break;
      case _DivisionRankingSortMode.ap:
        metricCompare = _compareDescendingInt(a.ap, b.ap);
        break;
      case _DivisionRankingSortMode.sp:
        metricCompare = _compareDescendingInt(a.sp, b.sp);
        break;
    }

    if (metricCompare != 0) {
      return metricCompare;
    }
    return _safeRank(a.rank).compareTo(_safeRank(b.rank));
  });
  return sorted;
}

String _divisionSortModeLabel(_DivisionRankingSortMode mode) {
  switch (mode) {
    case _DivisionRankingSortMode.rank:
      return 'RANK';
    case _DivisionRankingSortMode.opr:
      return 'OPR';
    case _DivisionRankingSortMode.dpr:
      return 'DPR';
    case _DivisionRankingSortMode.ccwm:
      return 'CCWM';
    case _DivisionRankingSortMode.wp:
      return 'WP';
    case _DivisionRankingSortMode.ap:
      return 'AP';
    case _DivisionRankingSortMode.sp:
      return 'SP';
  }
}

int _safeRank(int value) => value > 0 ? value : 999999;

int _compareDescendingInt(int a, int b) {
  final aValue = a < 0 ? -999999 : a;
  final bValue = b < 0 ? -999999 : b;
  return bValue.compareTo(aValue);
}

int _compareDescendingDouble(double? a, double? b) {
  final aValue = a ?? -999999;
  final bValue = b ?? -999999;
  return bValue.compareTo(aValue);
}

int _compareAscendingDouble(double? a, double? b) {
  final aValue = a ?? 999999;
  final bValue = b ?? 999999;
  return aValue.compareTo(bValue);
}

double _fallbackOpr(RankingRecord ranking) {
  if (ranking.averagePoints >= 0) {
    return ranking.averagePoints;
  }
  return -999999;
}

class _RankingCard extends StatelessWidget {
  const _RankingCard({
    required this.event,
    required this.ranking,
    required this.team,
    required this.highlightTeamNumber,
    required this.metrics,
  });

  final EventSummary event;
  final RankingRecord ranking;
  final TeamSummary team;
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          openSolarEventTeamScreen(
            context,
            event: event,
            team: team,
            highlightTeamNumber: highlightTeamNumber,
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
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
                          child: Text(
                            team.number,
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
                      _teamSubtitle(team),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF8E92A7),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(
                        style: const TextStyle(
                          color: Color(0xFF8E92A7),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        children: <TextSpan>[
                          TextSpan(
                            text:
                                '${_rankingRecordLabel(ranking, metrics)}  •  ',
                          ),
                          TextSpan(
                            text: 'WP ${_intLabel(ranking.wp)}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const TextSpan(text: '  •  '),
                          TextSpan(
                            text: 'AP ${_intLabel(ranking.ap)}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const TextSpan(text: '  •  '),
                          TextSpan(
                            text: 'SP ${_intLabel(ranking.sp)}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
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
        ),
      ),
    );
  }
}

class _DivisionRankingSearchBar extends StatelessWidget {
  const _DivisionRankingSearchBar({
    required this.controller,
    required this.resultCount,
    required this.onChanged,
  });

  final TextEditingController controller;
  final int resultCount;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 18, 0, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            const Color(0xFFF7F5F8).withValues(alpha: 0),
            const Color(0xFFF7F5F8),
            const Color(0xFFF7F5F8),
          ],
        ),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.98),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            const Icon(Icons.search_rounded, color: Color(0xFF6F748B)),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: 'Search rankings',
                  hintStyle: TextStyle(
                    color: Color(0xFF8E92A7),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: const TextStyle(
                  color: Color(0xFF24243A),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '$resultCount',
              style: const TextStyle(
                color: Color(0xFF6F748B),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _teamSubtitle(TeamSummary team) {
  final parts = <String>[
    if (team.teamName.trim().isNotEmpty) team.teamName.trim(),
    if (team.organization.trim().isNotEmpty) team.organization.trim(),
  ];
  if (parts.isNotEmpty) {
    return parts.join('  •  ');
  }
  return 'Team profile pending';
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
      if (alliance.score > opponent.score) {
        accumulator.wins += 1;
      } else if (alliance.score < opponent.score) {
        accumulator.losses += 1;
      } else {
        accumulator.ties += 1;
      }
    }
  }
}

class _TeamPerformanceAccumulator {
  int matches = 0;
  int wins = 0;
  int losses = 0;
  int ties = 0;
  double offenseTotal = 0;
  double defenseTotal = 0;
  double marginTotal = 0;

  _DivisionPerformanceMetrics toMetrics() {
    if (matches == 0) {
      return const _DivisionPerformanceMetrics(
        opr: null,
        dpr: null,
        ccwm: null,
        wins: 0,
        losses: 0,
        ties: 0,
        matches: 0,
      );
    }

    return _DivisionPerformanceMetrics(
      opr: offenseTotal / matches,
      dpr: defenseTotal / matches,
      ccwm: marginTotal / matches,
      wins: wins,
      losses: losses,
      ties: ties,
      matches: matches,
    );
  }
}

class _DivisionPerformanceMetrics {
  const _DivisionPerformanceMetrics({
    required this.opr,
    required this.dpr,
    required this.ccwm,
    required this.wins,
    required this.losses,
    required this.ties,
    required this.matches,
  });

  final double? opr;
  final double? dpr;
  final double? ccwm;
  final int wins;
  final int losses;
  final int ties;
  final int matches;

  String get oprLabel => _decimalLabel(opr);
  String get dprLabel => _decimalLabel(dpr);
  String get ccwmLabel => _decimalLabel(ccwm, signed: true);
  String get recordLabel =>
      matches == 0 ? 'Record pending' : '$wins-$losses-$ties';
}

String _rankingRecordLabel(
  RankingRecord ranking,
  _DivisionPerformanceMetrics? metrics,
) {
  final liveMetrics = metrics;
  if (liveMetrics != null && liveMetrics.matches > 0) {
    final officialHasRecord =
        ranking.wins > 0 || ranking.losses > 0 || ranking.ties > 0;
    if (!officialHasRecord) {
      return liveMetrics.recordLabel;
    }
  }
  if (ranking.wins < 0 || ranking.losses < 0 || ranking.ties < 0) {
    return 'Record pending';
  }
  return '${ranking.wins}-${ranking.losses}-${ranking.ties}';
}

class _PredictionsTab extends StatelessWidget {
  const _PredictionsTab({required this.predictions, required this.onOpenTeam});

  final List<_PredictedAllianceSelection> predictions;
  final ValueChanged<TeamSummary> onOpenTeam;

  @override
  Widget build(BuildContext context) {
    if (predictions.isEmpty) {
      return const _EmptyEventState(
        title: 'Not enough data yet',
        body:
            'Predicted alliances will appear here once the division has enough ranked teams to model selection order.',
      );
    }

    return StretchingOverscrollIndicator(
      axisDirection: AxisDirection.down,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 8),
        children: <Widget>[
          const Text(
            'Predicted Alliances',
            style: TextStyle(
              color: Color(0xFF24243A),
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Forecast uses live seeding, event scoring, and matchup fit. Alliance count scales with available teams and can project up to 16 alliances when enough teams are ranked.',
            style: TextStyle(
              color: Color(0xFF8E92A7),
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < predictions.length; index++)
            _PredictionRow(
              prediction: predictions[index],
              showDivider: index != predictions.length - 1,
              onOpenTeam: onOpenTeam,
            ),
        ],
      ),
    );
  }
}

class _PredictionRow extends StatelessWidget {
  const _PredictionRow({
    required this.prediction,
    required this.showDivider,
    required this.onOpenTeam,
  });

  final _PredictedAllianceSelection prediction;
  final bool showDivider;
  final ValueChanged<TeamSummary> onOpenTeam;

  @override
  Widget build(BuildContext context) {
    final statusColor = prediction.wasDeclined
      ? const Color(0xFFB26828)
      : const Color(0xFF1F8A52);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
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
              Text(
                '${prediction.seed}',
                style: const TextStyle(
                  color: Color(0xFF16182C),
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.9,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _PredictionTeamChip(
                      team: prediction.captain,
                      emphasized: true,
                      onTap: () => onOpenTeam(prediction.captain),
                    ),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Color(0xFF8E92A7),
                      size: 18,
                    ),
                    _PredictionTeamChip(
                      team: prediction.pick,
                      emphasized: false,
                      onTap: () => onOpenTeam(prediction.pick),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  prediction.wasDeclined ? 'Reroute' : 'Locked',
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            prediction.summary,
            style: const TextStyle(
              color: Color(0xFF5F6478),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          if (prediction.declinedTarget != null) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              'First look: ${prediction.declinedTarget!.number} likely protects captain position, so this seed reaches to the next fit.',
              style: const TextStyle(
                color: Color(0xFF8E92A7),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PredictionTeamChip extends StatelessWidget {
  const _PredictionTeamChip({
    required this.team,
    required this.emphasized,
    required this.onTap,
  });

  final TeamSummary team;
  final bool emphasized;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: emphasized ? const Color(0xFF16182C) : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: emphasized
              ? null
              : Border.all(color: const Color(0xFFE4E5EE)),
        ),
        child: Text(
          team.number,
          style: TextStyle(
            color: emphasized ? Colors.white : const Color(0xFF16182C),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _PredictedAllianceSelection {
  const _PredictedAllianceSelection({
    required this.seed,
    required this.captain,
    required this.pick,
    required this.summary,
    required this.wasDeclined,
    this.declinedTarget,
  });

  final int seed;
  final TeamSummary captain;
  final TeamSummary pick;
  final String summary;
  final bool wasDeclined;
  final TeamSummary? declinedTarget;

  static List<_PredictedAllianceSelection> build({
    required List<RankingRecord> rankings,
    required Map<String, TeamSummary> teamsByKey,
    required _DivisionPerformanceTable performanceTable,
    required Map<String, OpenSkillCacheEntry> openSkillByTeam,
  }) {
    final rankedTeams =
        rankings.where((ranking) => ranking.rank > 0).toList(growable: false)
          ..sort((a, b) => a.rank.compareTo(b.rank));
    final allianceCount = _predictedAllianceCount(rankedTeams.length);
    if (allianceCount <= 0 || rankedTeams.length < allianceCount * 2) {
      return const <_PredictedAllianceSelection>[];
    }

    final predicted = <_PredictedAllianceSelection>[];
    final captains = rankedTeams
        .take(allianceCount)
        .map((entry) => entry.team.number)
        .toList();
    var nextCaptainIndex = allianceCount;
    final unavailable = <String>{};

    TeamSummary teamForNumber(String teamNumber) {
      return teamsByKey[teamNumber.trim().toUpperCase()]!;
    }

    String teamFamily(String teamNumber) {
      final normalized = teamNumber.trim().toUpperCase();
      final match = RegExp(r'[0-9]+').firstMatch(normalized);
      if (match == null) {
        return normalized;
      }
      return match.group(0)!;
    }

    double captainScore(RankingRecord ranking) {
      final metrics = performanceTable.forTeam(ranking.team.number);
      final openSkill =
          openSkillByTeam[ranking.team.number.trim().toUpperCase()];
      final recordStrength =
          ((ranking.wins + (ranking.ties * 0.5)) - ranking.losses) * 1.35;
      final liveMargin = metrics?.ccwm ?? 0;
      final liveOffense = metrics?.opr ?? ranking.averagePoints;
      final openSkillBoost = openSkill == null
          ? 0.0
          : (openSkill.openSkillOrdinal / 6.2);
      return ((100 - ranking.rank.clamp(1, 100)) * 0.46) +
          recordStrength +
          (liveMargin * 1.2) +
          (liveOffense * 0.08) +
          openSkillBoost;
    }

    double partnerFit(RankingRecord captain, RankingRecord candidate) {
      final captainMetrics = performanceTable.forTeam(captain.team.number);
      final candidateMetrics = performanceTable.forTeam(candidate.team.number);
      final openSkill =
          openSkillByTeam[candidate.team.number.trim().toUpperCase()];
      final candidateScore = captainScore(candidate);
      final captainOffense = captainMetrics?.opr ?? captain.averagePoints;
      final candidateDefense = candidateMetrics?.dpr ?? 0;
      final candidateMargin = candidateMetrics?.ccwm ?? 0;
      final complement =
          (captainOffense >= 55 ? candidateDefense * 0.05 : 0) +
          (candidateMargin * 0.9) +
          ((openSkill?.awpPerMatch ?? 0.4) * 3.2);
      final sameFamilyPenalty =
          teamFamily(captain.team.number) == teamFamily(candidate.team.number)
          ? 14.0
          : 0.0;
      return candidateScore + complement - sameFamilyPenalty;
    }

    bool wouldDecline(RankingRecord captain, RankingRecord candidate) {
      if (captain.rank == 1 && candidate.rank == 2) {
        return false;
      }

      final candidateScore = captainScore(candidate);
      final captainSeedScore = captainScore(captain);
      if (candidate.rank < captain.rank) {
        return true;
      }
      if (candidate.rank <= 2) {
        return candidateScore >= captainSeedScore + 2.8;
      }
      if (candidate.rank <= 4) {
        return candidateScore >= captainSeedScore + 2.3;
      }
      if (candidate.rank <= allianceCount) {
        return candidateScore >= captainSeedScore + 2.9;
      }
      return candidateScore >= captainSeedScore + 3.4;
    }

    for (var seedIndex = 0; seedIndex < allianceCount; seedIndex++) {
      final captainNumber = captains[seedIndex].trim().toUpperCase();
      if (unavailable.contains(captainNumber)) {
        continue;
      }

      final captainRanking = rankedTeams.firstWhere(
        (entry) => entry.team.number.trim().toUpperCase() == captainNumber,
      );
      unavailable.add(captainNumber);

      RankingRecord? acceptedCandidate;
      RankingRecord? declinedCandidate;
      RankingRecord? fallbackCandidate;
      RankingRecord? fallbackNonFamily;
      final candidates =
          rankedTeams
              .where((candidate) {
                final key = candidate.team.number.trim().toUpperCase();
                return !unavailable.contains(key) && key != captainNumber;
              })
              .toList(growable: false)
            ..sort((a, b) {
              final fitCompare = partnerFit(
                captainRanking,
                b,
              ).compareTo(partnerFit(captainRanking, a));
              if (fitCompare != 0) {
                return fitCompare;
              }
              return a.rank.compareTo(b.rank);
            });

      final captainFamily = teamFamily(captainRanking.team.number);
      for (final candidate in candidates) {
        final candidateKey = candidate.team.number.trim().toUpperCase();
        final candidateIsCaptain = captains.any(
          (captain) => captain.trim().toUpperCase() == candidateKey,
        );
        final candidateFamily = teamFamily(candidate.team.number);
        final sameFamily = candidateFamily == captainFamily;

        fallbackCandidate ??= candidate;
        if (!sameFamily) {
          fallbackNonFamily ??= candidate;
        }

        if (candidateIsCaptain && wouldDecline(captainRanking, candidate)) {
          declinedCandidate ??= candidate;
          continue;
        }

        if (sameFamily && fallbackNonFamily != null) {
          continue;
        }

        acceptedCandidate = candidate;
        break;
      }

      if (acceptedCandidate == null) {
        acceptedCandidate = fallbackNonFamily ?? fallbackCandidate;
      }

      if (acceptedCandidate == null) {
        continue;
      }

      final acceptedCandidateKey =
          acceptedCandidate.team.number.trim().toUpperCase();
      unavailable.add(acceptedCandidateKey);
      final acceptedIsCaptain = captains.any(
        (captain) => captain.trim().toUpperCase() == acceptedCandidateKey,
      );
      if (acceptedIsCaptain) {
        while (nextCaptainIndex < rankedTeams.length) {
          final promoted = rankedTeams[nextCaptainIndex];
          nextCaptainIndex += 1;
          final promotedKey = promoted.team.number.trim().toUpperCase();
          if (!unavailable.contains(promotedKey) &&
              !captains.any(
                (captain) => captain.trim().toUpperCase() == promotedKey,
              )) {
            captains.add(promoted.team.number);
            break;
          }
        }
      }

      final captainTeam = teamForNumber(captainRanking.team.number);
      final pickTeam = teamForNumber(acceptedCandidate.team.number);
      final pickMetrics = performanceTable.forTeam(pickTeam.number);
      final summary =
          '${captainTeam.number} leans toward ${pickTeam.number} for ${(pickMetrics?.ccwm ?? 0).toStringAsFixed(1)} CCWM and ${(pickMetrics?.opr ?? acceptedCandidate.averagePoints).toStringAsFixed(1)} projected offense.';

      predicted.add(
        _PredictedAllianceSelection(
          seed: seedIndex + 1,
          captain: captainTeam,
          pick: pickTeam,
          summary: summary,
          wasDeclined: declinedCandidate != null,
          declinedTarget: declinedCandidate == null
              ? null
              : teamForNumber(declinedCandidate.team.number),
        ),
      );
    }

    return predicted;
  }

  static int _predictedAllianceCount(int rankedTeamCount) {
    final maxAlliances = rankedTeamCount ~/ 2;
    if (maxAlliances >= 16) {
      return 16;
    }
    if (maxAlliances >= 8) {
      return 8;
    }
    if (maxAlliances >= 4) {
      return 4;
    }
    return 0;
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
