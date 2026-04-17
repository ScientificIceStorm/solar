import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_session_controller.dart';
import '../../app/solar_app_scope.dart';
import '../../models/robot_events_models.dart';
import '../models/solar_match_prediction.dart';
import '../widgets/solar_match_row.dart';
import '../widgets/solar_navigation.dart';
import '../widgets/solar_page_scaffold.dart';
import '../widgets/solar_team_link.dart';
import 'event_details_screen.dart';
import 'match_details_screen.dart';
import 'team_profile_screen.dart';

enum SearchResultScope { all, teams, events, matches }

class SearchScreenArgs {
  const SearchScreenArgs({
    this.initialQuery = '',
    this.initialScope = SearchResultScope.all,
  });

  final String initialQuery;
  final SearchResultScope initialScope;
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.args = const SearchScreenArgs()});

  static const routeName = '/search';

  final SearchScreenArgs args;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _searchController = TextEditingController(
    text: widget.args.initialQuery,
  );
  late SearchResultScope _scope = widget.args.initialScope;
  AppSessionController? _sessionController;
  Future<SolarQuickviewSnapshot?>? _quickviewFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = SolarAppScope.of(context);
    if (!identical(_sessionController, controller)) {
      _sessionController = controller;
      _quickviewFuture = controller.fetchQuickviewSnapshot();
      unawaited(controller.preloadSearchEvents());
      unawaited(controller.preloadSearchTeams());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = SolarAppScope.of(context);

    return SolarPageScaffold(
      title: 'Search',
      currentDestination: SolarNavDestination.home,
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final query = _searchController.text.trim();
          final teamResults = controller.searchCachedTeams(query);
          final eventResults = controller.searchCachedEvents(query);

          return FutureBuilder<SolarQuickviewSnapshot?>(
            future: _quickviewFuture,
            builder: (context, quickviewSnapshot) {
              final quickview = quickviewSnapshot.data;
              final matchedTeam = teamResults.isEmpty
                  ? null
                  : teamResults.first;

              return ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.only(bottom: 14),
                children: <Widget>[
                  _SearchInputCard(
                    controller: _searchController,
                    scope: _scope,
                    onChanged: (_) => setState(() {}),
                    onScopeSelected: (scope) {
                      setState(() {
                        _scope = scope;
                      });
                    },
                  ),
                  const SizedBox(height: 18),
                  if (query.length < 2)
                    const _SearchHintCard()
                  else ...<Widget>[
                    _SearchSummaryCard(
                      query: query,
                      scope: _scope,
                      teamCount: teamResults.length,
                      eventCount: eventResults.length,
                    ),
                    if (_scope != SearchResultScope.events &&
                        _scope != SearchResultScope.matches) ...<Widget>[
                      const SizedBox(height: 18),
                      _SearchTeamSection(teams: teamResults),
                    ],
                    if (_scope != SearchResultScope.teams &&
                        _scope != SearchResultScope.matches) ...<Widget>[
                      const SizedBox(height: 18),
                      _SearchEventSection(events: eventResults),
                    ],
                    if (_scope != SearchResultScope.events &&
                        matchedTeam != null) ...<Widget>[
                      const SizedBox(height: 18),
                      _SearchTeamMatchesSection(
                        controller: controller,
                        team: matchedTeam,
                        event: quickview?.event,
                      ),
                    ],
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _SearchInputCard extends StatelessWidget {
  const _SearchInputCard({
    required this.controller,
    required this.scope,
    required this.onChanged,
    required this.onScopeSelected,
  });

  final TextEditingController controller;
  final SearchResultScope scope;
  final ValueChanged<String> onChanged;
  final ValueChanged<SearchResultScope> onScopeSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 28,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            onChanged: onChanged,
            textInputAction: TextInputAction.search,
            style: const TextStyle(
              color: Color(0xFF181A33),
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'Search teams, events, or team matches',
              hintStyle: const TextStyle(
                color: Color(0xFF8E92A7),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: controller.text.trim().isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        controller.clear();
                        onChanged('');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: SearchResultScope.values
                .map((option) {
                  final selected = option == scope;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () => onScopeSelected(option),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFF16182C)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: selected
                                ? const Color(0xFF16182C)
                                : const Color(0xFFE1E4EF),
                          ),
                        ),
                        child: Text(
                          _searchScopeLabel(option),
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : const Color(0xFF24243A),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  );
                })
                .toList(growable: false),
          ),
        ),
      ],
    );
  }
}

class _SearchSummaryCard extends StatelessWidget {
  const _SearchSummaryCard({
    required this.query,
    required this.scope,
    required this.teamCount,
    required this.eventCount,
  });

  final String query;
  final SearchResultScope scope;
  final int teamCount;
  final int eventCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Results for "$query"',
            style: const TextStyle(
              color: Color(0xFF24243A),
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Searching ${_searchScopeDescription(scope)}.',
            style: const TextStyle(
              color: Color(0xFF6F748B),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              _SearchMetricPill(label: 'Teams', value: '$teamCount'),
              const SizedBox(width: 10),
              _SearchMetricPill(label: 'Events', value: '$eventCount'),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchMetricPill extends StatelessWidget {
  const _SearchMetricPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7FB),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF7A7F92),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF24243A),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchTeamSection extends StatelessWidget {
  const _SearchTeamSection({required this.teams});

  final List<TeamSummary> teams;

  @override
  Widget build(BuildContext context) {
    return _SearchSectionCard(
      title: 'Teams',
      body: teams.isEmpty
          ? const _SectionEmptyLabel('No teams matched this search yet.')
          : Column(
              children: teams
                  .map((team) => _SearchTeamTile(team: team))
                  .toList(growable: false),
            ),
    );
  }
}

class _SearchEventSection extends StatelessWidget {
  const _SearchEventSection({required this.events});

  final List<EventSummary> events;

  @override
  Widget build(BuildContext context) {
    return _SearchSectionCard(
      title: 'Events',
      body: events.isEmpty
          ? const _SectionEmptyLabel('No events matched this search yet.')
          : Column(
              children: events
                  .map((event) => _SearchEventTile(event: event))
                  .toList(growable: false),
            ),
    );
  }
}

class _SearchTeamMatchesSection extends StatelessWidget {
  const _SearchTeamMatchesSection({
    required this.controller,
    required this.team,
    required this.event,
  });

  final AppSessionController controller;
  final TeamSummary team;
  final EventSummary? event;

  @override
  Widget build(BuildContext context) {
    return _SearchSectionCard(
      title: 'Team Matches',
      trailing: event == null
          ? null
          : Flexible(
              child: Text(
                event!.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Color(0xFF8E92A7),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
      body: event == null
          ? const _SectionEmptyLabel(
              'Quickview is not focused on an event right now, so team match filtering is waiting for the next tracked competition.',
            )
          : FutureBuilder<List<MatchSummary>>(
              future: controller.fetchTeamMatchesForReference(
                TeamReference(
                  id: team.id,
                  number: team.number,
                  name: team.teamName,
                ),
                eventId: event!.id,
              ),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      ),
                    ),
                  );
                }

                final matches = snapshot.data!;
                if (matches.isEmpty) {
                  return Text(
                    '${team.number} does not have published matches at ${event!.name} yet.',
                    style: const TextStyle(
                      color: Color(0xFF8E92A7),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.45,
                    ),
                  );
                }

                final upcoming = matches
                    .where(_isUpcomingSearchMatch)
                    .toList(growable: false);
                final completed =
                    matches
                        .where((match) => !_isUpcomingSearchMatch(match))
                        .toList(growable: false)
                      ..sort((a, b) {
                        final aTime =
                            a.started ??
                            a.scheduled ??
                            DateTime.fromMillisecondsSinceEpoch(0);
                        final bTime =
                            b.started ??
                            b.scheduled ??
                            DateTime.fromMillisecondsSinceEpoch(0);
                        return bTime.compareTo(aTime);
                      });

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (upcoming.isNotEmpty) ...<Widget>[
                      const _InlineSectionLabel('Upcoming'),
                      for (final match in upcoming)
                        SolarMatchRow(
                          match: match,
                          highlightTeamNumber: team.number,
                          onTap: () {
                            Navigator.of(context).pushNamed(
                              MatchDetailsScreen.routeName,
                              arguments: MatchDetailsScreenArgs(
                                match: match,
                                event: event,
                                highlightTeamNumber: team.number,
                              ),
                            );
                          },
                          onTeamTap: (reference) {
                            openSolarTeamProfileForReference(
                              context,
                              teamNumber: reference.number,
                              teamId: reference.id,
                              teamName: reference.name,
                            );
                          },
                        ),
                    ],
                    if (completed.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 12),
                      const _InlineSectionLabel('Completed'),
                      for (final match in completed)
                        SolarMatchRow(
                          match: match,
                          highlightTeamNumber: team.number,
                          onTap: () {
                            Navigator.of(context).pushNamed(
                              MatchDetailsScreen.routeName,
                              arguments: MatchDetailsScreenArgs(
                                match: match,
                                event: event,
                                highlightTeamNumber: team.number,
                              ),
                            );
                          },
                          onTeamTap: (reference) {
                            openSolarTeamProfileForReference(
                              context,
                              teamNumber: reference.number,
                              teamId: reference.id,
                              teamName: reference.name,
                            );
                          },
                        ),
                    ],
                  ],
                );
              },
            ),
    );
  }
}

class _SearchSectionCard extends StatelessWidget {
  const _SearchSectionCard({
    required this.title,
    required this.body,
    this.trailing,
  });

  final String title;
  final Widget body;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF24243A),
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              // ignore: use_null_aware_elements
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          body,
        ],
      ),
    );
  }
}

class _SearchTeamTile extends StatelessWidget {
  const _SearchTeamTile({required this.team});

  final TeamSummary team;

  @override
  Widget build(BuildContext context) {
    final controller = SolarAppScope.of(context);
    final rating = controller.teamRatingFor(team.number);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(
            context,
          ).pushNamed(TeamProfileScreen.routeName, arguments: team);
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFDADAE3))),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF16182C),
                  borderRadius: BorderRadius.circular(16),
                ),
                alignment: Alignment.center,
                child: Text(
                  team.number.characters.take(2).toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      team.number,
                      style: const TextStyle(
                        color: Color(0xFF24243A),
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      team.teamName.trim().isEmpty
                          ? 'Team profile'
                          : team.teamName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF6F748B),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: List<Widget>.generate(5, (index) {
                        final selected = index < rating;
                        return Padding(
                          padding: const EdgeInsets.only(right: 2),
                          child: Icon(
                            selected
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: 15,
                            color: selected
                                ? const Color(0xFFFFB13B)
                                : const Color(0xFFBCC0D1),
                          ),
                        );
                      }),
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

class _SearchEventTile extends StatelessWidget {
  const _SearchEventTile({required this.event});

  final EventSummary event;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.of(
            context,
          ).pushNamed(EventDetailsScreen.routeName, arguments: event);
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFDADAE3))),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF101010),
                  borderRadius: BorderRadius.circular(18),
                ),
                alignment: Alignment.center,
                child: Text(
                  _eventDateDay(event),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
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
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _eventDateLabel(event),
                      style: const TextStyle(
                        color: Color(0xFF6F748B),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _eventLocationLabel(event.location),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF8E92A7),
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

class _InlineSectionLabel extends StatelessWidget {
  const _InlineSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF7A7F92),
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _SectionEmptyLabel extends StatelessWidget {
  const _SectionEmptyLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF8E92A7),
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.45,
      ),
    );
  }
}

class _SearchHintCard extends StatelessWidget {
  const _SearchHintCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Text(
        'Type at least two characters to search teams, events, and the currently tracked Quickview event schedule for matching teams.',
        style: TextStyle(
          color: Color(0xFF6F748B),
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.45,
        ),
      ),
    );
  }
}

String _searchScopeLabel(SearchResultScope scope) {
  switch (scope) {
    case SearchResultScope.all:
      return 'ALL';
    case SearchResultScope.teams:
      return 'TEAMS';
    case SearchResultScope.events:
      return 'EVENTS';
    case SearchResultScope.matches:
      return 'MATCHES';
  }
}

String _searchScopeDescription(SearchResultScope scope) {
  switch (scope) {
    case SearchResultScope.all:
      return 'teams, events, and current-event match filters';
    case SearchResultScope.teams:
      return 'teams only';
    case SearchResultScope.events:
      return 'events only';
    case SearchResultScope.matches:
      return 'team matches at the active Quickview event';
  }
}

bool _isUpcomingSearchMatch(MatchSummary match) {
  final hasOfficialScores =
      match.alliances.length >= 2 &&
      match.alliances.every((alliance) => alliance.score >= 0);
  final anchor = match.scheduled ?? match.started;
  return !hasOfficialScores &&
      (anchor == null || !anchor.isBefore(DateTime.now()));
}

String _eventDateDay(EventSummary event) {
  final date = event.start ?? event.end;
  if (date == null) {
    return '--';
  }
  return '${date.toLocal().day}';
}

String _eventDateLabel(EventSummary event) {
  final start = event.start?.toLocal();
  final end = event.end?.toLocal();
  if (start == null && end == null) {
    return 'Date pending';
  }
  if (start != null && end != null) {
    if (start.year == end.year &&
        start.month == end.month &&
        start.day == end.day) {
      return '${start.month}/${start.day}/${start.year}';
    }
    return '${start.month}/${start.day} - ${end.month}/${end.day}/${end.year}';
  }
  final date = start ?? end!;
  return '${date.month}/${date.day}/${date.year}';
}

String _eventLocationLabel(LocationSummary location) {
  final parts = <String>[
    if (location.city.trim().isNotEmpty) location.city.trim(),
    if (location.region.trim().isNotEmpty) location.region.trim(),
    if (location.country.trim().isNotEmpty) location.country.trim(),
  ];
  return parts.isEmpty ? 'Location pending' : parts.join(', ');
}
