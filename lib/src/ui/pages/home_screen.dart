import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_session_controller.dart';
import '../../app/solar_app_scope.dart';
import '../../models/robot_events_models.dart';
import '../pages/event_details_screen.dart';
import '../models/app_account.dart';
import '../models/solar_match_prediction.dart';
import '../models/team_stats_snapshot.dart';
import '../widgets/solar_event_photo.dart';
import '../widgets/solar_match_row.dart';
import '../widgets/solar_navigation.dart';
import '../widgets/solar_screen_background.dart';
import '../widgets/solar_team_link.dart';
import 'match_details_screen.dart';
import 'sign_in_screen.dart';
import 'team_profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const routeName = '/home';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  AppSessionController? _sessionController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = SolarAppScope.of(context);
    if (!identical(_sessionController, controller)) {
      _sessionController = controller;
      unawaited(controller.preloadSearchEvents());
      unawaited(controller.preloadSearchTeams());
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearchChanged(String value) {
    final normalizedQuery = value.trim();
    final controller = _sessionController;

    if (controller == null) {
      setState(() {});
      return;
    }

    if (normalizedQuery.length >= 2) {
      unawaited(controller.preloadSearchEvents());
      unawaited(controller.preloadSearchTeams());
    }

    setState(() {});
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = SolarAppScope.of(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final account = controller.currentAccount;
        if (account == null) {
          return const Scaffold(body: SizedBox.shrink());
        }

        final query = _searchController.text.trim();
        final showSearchResults = query.length >= 2;
        final teamResults = controller.searchCachedTeams(query);
        final eventResults = controller.searchCachedEvents(query);
        final teamStats =
            controller.teamStats ?? TeamStatsSnapshot(team: account.team);
        final topInset = MediaQuery.paddingOf(context).top;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Scaffold(
            extendBody: true,
            backgroundColor: Colors.transparent,
            drawerEnableOpenDragGesture: true,
            drawerEdgeDragWidth: 36,
            drawer: SolarAppDrawer(
              account: account,
              onActionSelected: (action) {
                Navigator.of(context).pop();
                openSolarDrawerAction(context, action);
              },
              onSignOut: () async {
                await controller.signOut();
                if (!context.mounted) {
                  return;
                }
                Navigator.of(context).pushNamedAndRemoveUntil(
                  SignInScreen.routeName,
                  (route) => false,
                );
              },
            ),
            body: SolarScreenBackground(
              padding: EdgeInsets.zero,
              respectSafeArea: false,
              child: RefreshIndicator(
                color: Colors.black,
                onRefresh: () async {
                  await controller.refreshTeamStats();
                  await controller.preloadSearchEvents(force: true);
                },
                child: ListView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: const EdgeInsets.only(bottom: 148),
                  children: <Widget>[
                    _HomeHeader(
                      topInset: topInset,
                      isRefreshing: controller.isRefreshingTeamStats,
                      searchController: _searchController,
                      onSearchChanged: _handleSearchChanged,
                      onClearSearch: _clearSearch,
                    ),
                    const SizedBox(height: 30),
                    if (showSearchResults) ...<Widget>[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: _SearchResultsPanel(
                          query: query,
                          teamResults: teamResults,
                          eventResults: eventResults,
                          isLoadingTeams:
                              controller.isPreloadingSearchTeams &&
                              controller.preloadedSearchTeams.isEmpty,
                          isLoadingEvents:
                              controller.isPreloadingSearchEvents &&
                              controller.preloadedSearchEvents.isEmpty,
                        ),
                      ),
                    ] else ...<Widget>[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: _SectionHeader(
                          title: 'Quickview',
                          trailingLabel: 'Calendar',
                          onTap: () {
                            navigateToSolarDestination(
                              context,
                              SolarNavDestination.calendar,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: _QuickviewSection(
                          controller: controller,
                          teamNumber: account.team.number,
                        ),
                      ),
                      const SizedBox(height: 28),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: _SectionHeader(
                          title: 'Upcoming Events',
                          trailingLabel: 'See All',
                          onTap: () {
                            navigateToSolarDestination(
                              context,
                              SolarNavDestination.calendar,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                      _UpcomingEventsSection(events: teamStats.upcomingEvents),
                      const SizedBox(height: 28),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: _SectionHeader(
                          title: 'Team Stats',
                          trailingLabel: 'See All',
                          onTap: () {
                            openSolarTeamProfileForSummary(
                              context,
                              account.team,
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 18),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: _TeamStatsPanel(
                          account: account,
                          teamStats: teamStats,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            bottomNavigationBar: SolarBottomNavBar(
              current: SolarNavDestination.home,
              onSelected: (destination) {
                navigateToSolarDestination(context, destination);
              },
            ),
          ),
        );
      },
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.topInset,
    required this.isRefreshing,
    required this.searchController,
    required this.onSearchChanged,
    required this.onClearSearch,
  });

  final double topInset;
  final bool isRefreshing;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(28, topInset + 22, 28, 34),
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(58),
          bottomRight: Radius.circular(58),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Builder(
                builder: (context) {
                  return InkWell(
                    key: const ValueKey<String>('home-menu-button'),
                    onTap: () => Scaffold.of(context).openDrawer(),
                    borderRadius: BorderRadius.circular(20),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: SolarMenuGlyph(),
                    ),
                  );
                },
              ),
              const Spacer(),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    const Icon(
                      Icons.notifications_none_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                    Positioned(
                      top: 15,
                      right: 16,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2C97BF),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 42),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: _SearchStrip(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  onClear: onClearSearch,
                ),
              ),
              const SizedBox(width: 20),
              const _FilterButton(),
            ],
          ),
          if (isRefreshing) ...<Widget>[
            const SizedBox(height: 14),
            Text(
              'Refreshing live team stats...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 12,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SearchStrip extends StatelessWidget {
  const _SearchStrip({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: Row(
        children: <Widget>[
          const Icon(Icons.search_rounded, color: Colors.white, size: 38),
          const SizedBox(width: 14),
          Container(width: 1.5, height: 34, color: const Color(0xFF7C7BFF)),
          const SizedBox(width: 15),
          Expanded(
            child: TextField(
              key: const ValueKey<String>('home-search-field'),
              controller: controller,
              onChanged: onChanged,
              cursorColor: Colors.white,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.5,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: 'Search teams or events...',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.22),
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: onClear,
              child: Icon(
                Icons.close_rounded,
                color: Colors.white.withValues(alpha: 0.6),
                size: 24,
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.tune_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Filters',
            style: TextStyle(
              color: Color(0xFF22212E),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.trailingLabel,
    this.onTap,
  });

  final String title;
  final String trailingLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF2A2942),
            fontSize: 30,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.9,
          ),
        ),
        const Spacer(),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: <Widget>[
                Text(
                  trailingLabel,
                  style: const TextStyle(
                    color: Color(0xFFA2A3B8),
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Color(0xFFC8C8D7),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchResultsPanel extends StatelessWidget {
  const _SearchResultsPanel({
    required this.query,
    required this.teamResults,
    required this.eventResults,
    required this.isLoadingTeams,
    required this.isLoadingEvents,
  });

  final String query;
  final List<TeamSummary> teamResults;
  final List<EventSummary> eventResults;
  final bool isLoadingTeams;
  final bool isLoadingEvents;

  @override
  Widget build(BuildContext context) {
    final previewTeams = teamResults.take(3).toList(growable: false);
    final previewEvents = eventResults.take(3).toList(growable: false);

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(32),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Search results for "$query"',
            style: const TextStyle(
              color: Color(0xFF24243A),
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Teams and preloaded events update as you type.',
            style: const TextStyle(
              color: Color(0xFF8E92A7),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: _SearchCategoryButton(
                  key: const ValueKey<String>('search-all-teams-button'),
                  icon: Icons.groups_2_outlined,
                  label: 'Teams',
                  count: teamResults.length,
                  onTap: () {
                    _showSearchResultsSheet<TeamSummary>(
                      context: context,
                      title: 'Teams',
                      query: query,
                      items: teamResults,
                      itemBuilder: (team) => _TeamSearchTile(team: team),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SearchCategoryButton(
                  key: const ValueKey<String>('search-all-events-button'),
                  icon: Icons.event_outlined,
                  label: 'Events',
                  count: eventResults.length,
                  onTap: () {
                    _showSearchResultsSheet<EventSummary>(
                      context: context,
                      title: 'Events',
                      query: query,
                      items: eventResults,
                      itemBuilder: (event) => _EventSearchTile(event: event),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SearchSectionHeader(
            label: 'Teams',
            total: teamResults.length,
            onTap: () {
              _showSearchResultsSheet<TeamSummary>(
                context: context,
                title: 'Teams',
                query: query,
                items: teamResults,
                itemBuilder: (team) => _TeamSearchTile(team: team),
              );
            },
          ),
          const SizedBox(height: 10),
          if (isLoadingTeams)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: _SearchLoadingLabel('Loading teams...'),
            )
          else if (previewTeams.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: _SearchEmptyLabel('No matching teams yet'),
            )
          else
            ...previewTeams.map((team) => _TeamSearchTile(team: team)),
          const SizedBox(height: 18),
          _SearchSectionHeader(
            label: 'Events',
            total: eventResults.length,
            onTap: () {
              _showSearchResultsSheet<EventSummary>(
                context: context,
                title: 'Events',
                query: query,
                items: eventResults,
                itemBuilder: (event) => _EventSearchTile(event: event),
              );
            },
          ),
          const SizedBox(height: 10),
          if (isLoadingEvents)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: _SearchLoadingLabel('Loading cached events...'),
            )
          else if (previewEvents.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: _SearchEmptyLabel('No matching preloaded events'),
            )
          else
            ...previewEvents.map((event) => _EventSearchTile(event: event)),
        ],
      ),
    );
  }
}

class _SearchCategoryButton extends StatelessWidget {
  const _SearchCategoryButton({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8FD),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: <Widget>[
            Icon(icon, color: const Color(0xFF24243A), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF24243A),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '$count',
              style: const TextStyle(
                color: Color(0xFF8E92A7),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchSectionHeader extends StatelessWidget {
  const _SearchSectionHeader({
    required this.label,
    required this.total,
    required this.onTap,
  });

  final String label;
  final int total;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF8E92A7),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            total > 3 ? 'View all' : 'Open',
            style: const TextStyle(
              color: Color(0xFF7C7F94),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchLoadingLabel extends StatelessWidget {
  const _SearchLoadingLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 10),
        Text(
          text,
          style: const TextStyle(color: Color(0xFF6F748B), fontSize: 14),
        ),
      ],
    );
  }
}

class _SearchEmptyLabel extends StatelessWidget {
  const _SearchEmptyLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(color: Color(0xFF8E92A7), fontSize: 14),
    );
  }
}

class _TeamSearchTile extends StatelessWidget {
  const _TeamSearchTile({required this.team});

  final TeamSummary team;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(
          context,
        ).pushNamed(TeamProfileScreen.routeName, arguments: team);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFDADAE3))),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                team.number.characters.take(2).toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
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
                    team.number,
                    style: const TextStyle(
                      color: Color(0xFF24243A),
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    team.teamName.isEmpty ? 'Team profile' : team.teamName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF6F748B),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _locationLabel(team.location),
              style: const TextStyle(
                color: Color(0xFF9FA1B5),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventSearchTile extends StatelessWidget {
  const _EventSearchTile({required this.event});

  final EventSummary event;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(
          context,
        ).pushNamed(EventDetailsScreen.routeName, arguments: event);
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFDADAE3))),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF101010),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: Text(
                _DateBadgeData.fromDate(event.start).day,
                style: const TextStyle(
                  color: Colors.white,
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
                    _displayEventTitle(event.name),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF24243A),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _locationLabel(event.location),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF6F748B),
                      fontSize: 13,
                    ),
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

Future<void> _showSearchResultsSheet<T>({
  required BuildContext context,
  required String title,
  required String query,
  required List<T> items,
  required Widget Function(T item) itemBuilder,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return _SearchResultsBottomSheet<T>(
        title: title,
        query: query,
        items: items,
        itemBuilder: itemBuilder,
      );
    },
  );
}

class _SearchResultsBottomSheet<T> extends StatelessWidget {
  const _SearchResultsBottomSheet({
    required this.title,
    required this.query,
    required this.items,
    required this.itemBuilder,
  });

  final String title;
  final String query;
  final List<T> items;
  final Widget Function(T item) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * 0.84,
      decoration: const BoxDecoration(
        color: Color(0xFFF7F5F8),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD5D4DD),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
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
                        const SizedBox(height: 4),
                        Text(
                          'Results for "$query" (${items.length})',
                          style: const TextStyle(
                            color: Color(0xFF8E92A7),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Expanded(
                child: items.isEmpty
                    ? const Center(
                        child: Text(
                          'No results yet',
                          style: TextStyle(
                            color: Color(0xFF8E92A7),
                            fontSize: 15,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          return itemBuilder(items[index]);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickviewSection extends StatelessWidget {
  const _QuickviewSection({required this.controller, required this.teamNumber});

  final AppSessionController controller;
  final String teamNumber;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SolarQuickviewSnapshot?>(
      future: controller.fetchQuickviewSnapshot(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _QuickviewLoadingState();
        }

        final quickview = snapshot.data;
        if (quickview == null) {
          return const _QuickviewEmptyState(
            title: 'No upcoming competitions yet',
            body:
                'As soon as your team has another event on the schedule, Quickview will lock onto the next qualifying match here.',
          );
        }

        final nextMatch = quickview.nextQualifyingMatch;
        if (nextMatch == null) {
          return _QuickviewEmptyState(
            title: quickview.event.name,
            body:
                'This competition is on your calendar, but RobotEvents has not posted qualifying match pairings yet.',
          );
        }

        final remainingMatches = quickview.futureMatches
            .where((match) => match.id != nextMatch.id)
            .toList(growable: false);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            FutureBuilder<SolarMatchPrediction?>(
              future: controller.predictMatch(
                match: nextMatch,
                event: quickview.event,
              ),
              builder: (context, predictionSnapshot) {
                final prediction = predictionSnapshot.data;
                return _QuickviewHeroCard(
                  event: quickview.event,
                  match: nextMatch,
                  prediction: prediction,
                  teamNumber: teamNumber,
                );
              },
            ),
            const SizedBox(height: 18),
            if (remainingMatches.isNotEmpty) ...<Widget>[
              const Text(
                'Future Matches',
                style: TextStyle(
                  color: Color(0xFF2A2942),
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 10),
              for (final match in remainingMatches)
                SolarMatchRow(
                  match: match,
                  highlightTeamNumber: teamNumber,
                  onTap: () {
                    Navigator.of(context).pushNamed(
                      MatchDetailsScreen.routeName,
                      arguments: MatchDetailsScreenArgs(
                        match: match,
                        event: quickview.event,
                        highlightTeamNumber: teamNumber,
                      ),
                    );
                  },
                ),
            ] else
              const Text(
                'This is the only remaining published qualifier for now.',
                style: TextStyle(
                  color: Color(0xFF8E92A7),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _QuickviewHeroCard extends StatelessWidget {
  const _QuickviewHeroCard({
    required this.event,
    required this.match,
    required this.prediction,
    required this.teamNumber,
  });

  final EventSummary event;
  final MatchSummary match;
  final SolarMatchPrediction? prediction;
  final String teamNumber;

  @override
  Widget build(BuildContext context) {
    final yourAlliance = _allianceContainingTeam(match, teamNumber);
    final opponents = _opposingAlliance(match, yourAlliance);
    final favoredLabel = prediction == null
        ? 'Model warming up'
        : '${prediction!.favoredAllianceLabel} ${(prediction!.favoredWinProbability * 100).round()}%';
    final probabilityColor = prediction?.favoredAllianceColor == 'blue'
        ? const Color(0xFF8FB0FF)
        : const Color(0xFFFF8E87);

    return InkWell(
      onTap: () {
        Navigator.of(context).pushNamed(
          MatchDetailsScreen.routeName,
          arguments: MatchDetailsScreenArgs(
            match: match,
            event: event,
            highlightTeamNumber: teamNumber,
          ),
        );
      },
      borderRadius: BorderRadius.circular(32),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF101118), Color(0xFF1F2236)],
          ),
          borderRadius: BorderRadius.circular(32),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x1E000000),
              blurRadius: 30,
              offset: Offset(0, 18),
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
                        'Next qualifier',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.62),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        solarMatchScreenLabel(match),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _displayEventTitle(event.name),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        solarMatchTimeLabel(match),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _locationLabel(event.location),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    favoredLabel,
                    style: TextStyle(
                      color: probabilityColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (prediction != null)
                  Text(
                    '${prediction!.predictedRedScore} - ${prediction!.predictedBlueScore}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: _AlliancePreviewColumn(
                    label: 'Your alliance',
                    teams: yourAlliance?.teams ?? const <TeamReference>[],
                    color: const Color(0xFFFF8E87),
                    highlightTeamNumber: teamNumber,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: _AlliancePreviewColumn(
                    label: 'Opponents',
                    teams: opponents?.teams ?? const <TeamReference>[],
                    color: const Color(0xFF8FB0FF),
                    highlightTeamNumber: teamNumber,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AlliancePreviewColumn extends StatelessWidget {
  const _AlliancePreviewColumn({
    required this.label,
    required this.teams,
    required this.color,
    required this.highlightTeamNumber,
  });

  final String label;
  final List<TeamReference> teams;
  final Color color;
  final String highlightTeamNumber;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.58),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        if (teams.isEmpty)
          Text(
            'TBD',
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          )
        else
          for (final team in teams)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: SolarTeamLinkText(
                teamNumber: team.number,
                teamId: team.id,
                teamName: team.name,
                style: TextStyle(
                  color:
                      team.number.trim().toUpperCase() ==
                          highlightTeamNumber.trim().toUpperCase()
                      ? Colors.white
                      : color,
                  fontSize: 18,
                  fontWeight:
                      team.number.trim().toUpperCase() ==
                          highlightTeamNumber.trim().toUpperCase()
                      ? FontWeight.w700
                      : FontWeight.w500,
                ),
              ),
            ),
      ],
    );
  }
}

class _QuickviewLoadingState extends StatelessWidget {
  const _QuickviewLoadingState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 34),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(32),
      ),
      child: const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ),
    );
  }
}

class _QuickviewEmptyState extends StatelessWidget {
  const _QuickviewEmptyState({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF24243A),
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: const TextStyle(
              color: Color(0xFF8E92A7),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

MatchAlliance? _allianceContainingTeam(MatchSummary match, String teamNumber) {
  final normalized = teamNumber.trim().toUpperCase();
  for (final alliance in match.alliances) {
    for (final team in alliance.teams) {
      if (team.number.trim().toUpperCase() == normalized) {
        return alliance;
      }
    }
  }
  return null;
}

MatchAlliance? _opposingAlliance(
  MatchSummary match,
  MatchAlliance? selectedAlliance,
) {
  if (selectedAlliance == null) {
    return match.alliances.length > 1 ? match.alliances[1] : null;
  }

  for (final alliance in match.alliances) {
    if (!identical(alliance, selectedAlliance) &&
        alliance.color.toLowerCase() != selectedAlliance.color.toLowerCase()) {
      return alliance;
    }
  }

  for (final alliance in match.alliances) {
    if (!identical(alliance, selectedAlliance)) {
      return alliance;
    }
  }

  return null;
}

class _UpcomingEventsSection extends StatelessWidget {
  const _UpcomingEventsSection({required this.events});

  final List<EventSummary> events;

  @override
  Widget build(BuildContext context) {
    final visibleEvents = events.isEmpty
        ? <EventSummary>[_MockEventSummary()]
        : events.take(6).toList(growable: false);

    return SizedBox(
      height: 340,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        scrollDirection: Axis.horizontal,
        itemCount: visibleEvents.length,
        separatorBuilder: (_, _) => const SizedBox(width: 20),
        itemBuilder: (context, index) {
          return _EventCard(event: visibleEvents[index]);
        },
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final EventSummary event;

  @override
  Widget build(BuildContext context) {
    final badge = _DateBadgeData.fromDate(event.start);

    return InkWell(
      onTap: () {
        Navigator.of(
          context,
        ).pushNamed(EventDetailsScreen.routeName, arguments: event);
      },
      borderRadius: BorderRadius.circular(32),
      child: Container(
        width: 360,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: const Color(0xFFEAE7F6)),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x13000000),
              blurRadius: 26,
              offset: Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: SizedBox(
                    height: 186,
                    width: double.infinity,
                    child: SolarEventPhoto(
                      location: event.location,
                      overlay: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              Colors.black.withValues(alpha: 0.06),
                              Colors.black.withValues(alpha: 0.04),
                              Colors.black.withValues(alpha: 0.22),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(top: 14, left: 14, child: _DateBadge(badge: badge)),
                const Positioned(top: 14, right: 14, child: _BookmarkBadge()),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: -20,
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: _CardMetaChip(
                          icon: Icons.location_on_rounded,
                          label: _locationLabel(event.location),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _CardMetaChip(
                        icon: Icons.splitscreen_rounded,
                        label: '${event.divisions.length} divs',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 34),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                _displayEventTitle(event.name),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF24243A),
                  fontSize: 21,
                  fontWeight: FontWeight.w500,
                  height: 1.05,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      _eventRangeLabel(event),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF9191A8),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEF0FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Color(0xFF5A67F3),
                      size: 22,
                    ),
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

class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.badge});

  final _DateBadgeData badge;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 74,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: <Widget>[
          Text(
            badge.day,
            style: const TextStyle(
              color: Color(0xFFFF655A),
              fontSize: 26,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            badge.month,
            style: const TextStyle(
              color: Color(0xFFFF655A),
              fontSize: 12,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.9,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _BookmarkBadge extends StatelessWidget {
  const _BookmarkBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Icon(
        Icons.bookmark_rounded,
        color: Color(0xFFFF655A),
        size: 24,
      ),
    );
  }
}

class _CardMetaChip extends StatelessWidget {
  const _CardMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, color: const Color(0xFF6C72F4), size: 16),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF4A4C69),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DateBadgeData {
  const _DateBadgeData({required this.day, required this.month});

  final String day;
  final String month;

  factory _DateBadgeData.fromDate(DateTime? value) {
    if (value == null) {
      return const _DateBadgeData(day: '--', month: 'TBD');
    }

    const months = <String>[
      'JANUARY',
      'FEBRUARY',
      'MARCH',
      'APRIL',
      'MAY',
      'JUNE',
      'JULY',
      'AUGUST',
      'SEPTEMBER',
      'OCTOBER',
      'NOVEMBER',
      'DECEMBER',
    ];

    return _DateBadgeData(
      day: value.day.toString(),
      month: months[value.month - 1],
    );
  }
}

class _TeamStatsPanel extends StatelessWidget {
  const _TeamStatsPanel({required this.account, required this.teamStats});

  final AppAccount account;
  final TeamStatsSnapshot teamStats;

  @override
  Widget build(BuildContext context) {
    final ccwm = teamStats.ccwm;
    final winRate = teamStats.winRate;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(32),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x13000000),
            blurRadius: 26,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              SolarTeamLinkText(
                teamNumber: account.team.number,
                teamId: account.team.id,
                teamName: account.team.teamName,
                organization: account.team.organization,
                robotName: account.team.robotName,
                grade: account.team.grade,
                style: const TextStyle(
                  color: Color(0xFF24243A),
                  fontSize: 25,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  account.team.teamName.isEmpty
                      ? 'Competition profile'
                      : account.team.teamName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF9FA1B5),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: _CompactStatBlock(
                  label: 'CCWM',
                  value: ccwm == null ? '--' : ccwm.toStringAsFixed(1),
                  onTap: () {
                    openSolarTeamProfileForSummary(context, account.team);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CompactStatBlock(
                  label: 'Record',
                  value: teamStats.recordLabel,
                  onTap: () {
                    openSolarTeamProfileForSummary(context, account.team);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CompactStatBlock(
                  label: 'Skills',
                  value: teamStats.skillsRankLabel,
                  onTap: () {
                    openSolarTeamProfileForSummary(context, account.team);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: _CompactStatBlock(
                  label: 'Score',
                  value: teamStats.skillsScoreLabel,
                  onTap: () {
                    openSolarTeamProfileForSummary(context, account.team);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CompactStatBlock(
                  label: 'Driver',
                  value: teamStats.driverScoreLabel,
                  onTap: () {
                    openSolarTeamProfileForSummary(context, account.team);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CompactStatBlock(
                  label: 'Prog',
                  value: teamStats.programmingScoreLabel,
                  onTap: () {
                    openSolarTeamProfileForSummary(context, account.team);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: <Widget>[
              _InlineMeta(
                label: 'Win rate',
                value: winRate == null
                    ? '--'
                    : '${winRate.toStringAsFixed(0)}%',
              ),
              _InlineMeta(label: 'Ordinal', value: teamStats.ordinalLabel),
              _InlineMeta(
                label: 'Status',
                value: account.team.registered ? 'Live' : 'Pending',
              ),
            ],
          ),
          if (teamStats.errorMessage != null) ...<Widget>[
            const SizedBox(height: 10),
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
    );
  }
}

class _CompactStatBlock extends StatelessWidget {
  const _CompactStatBlock({
    required this.label,
    required this.value,
    this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8FD),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF9FA1B5),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF24243A),
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineMeta extends StatelessWidget {
  const _InlineMeta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          '$label ',
          style: const TextStyle(
            color: Color(0xFF9FA1B5),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF24243A),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

String _displayEventTitle(String value) {
  final lower = value.toLowerCase();
  if (lower.contains('world championship') && lower.contains('high school')) {
    return 'VEX Robotics World Championships - HS';
  }
  if (lower.contains('world championship') && lower.contains('middle school')) {
    return 'VEX Robotics World Championships - MS';
  }

  return value
      .replaceAll('VEX V5 Robotics Competition High School', 'HS')
      .replaceAll('VEX V5 Robotics Competition Middle School', 'MS')
      .replaceAll('World Championship', 'World Championships');
}

String _locationLabel(LocationSummary location) {
  final region = _stateAbbreviations[location.region] ?? location.region;
  final parts = <String>[
    if (location.city.isNotEmpty) location.city,
    if (region.isNotEmpty) region,
  ];
  return parts.isEmpty ? 'Location pending' : parts.join(', ');
}

String _eventRangeLabel(EventSummary event) {
  final start = event.start;
  final end = event.end;
  if (start == null && end == null) {
    return 'Date pending';
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

  String format(DateTime value) => '${months[value.month - 1]} ${value.day}';

  if (start != null && end != null && start != end) {
    return '${format(start)} - ${format(end)}';
  }

  return format(start ?? end!);
}

const Map<String, String> _stateAbbreviations = <String, String>{
  'Alabama': 'AL',
  'Alaska': 'AK',
  'Arizona': 'AZ',
  'Arkansas': 'AR',
  'California': 'CA',
  'Colorado': 'CO',
  'Connecticut': 'CT',
  'Delaware': 'DE',
  'Florida': 'FL',
  'Georgia': 'GA',
  'Hawaii': 'HI',
  'Idaho': 'ID',
  'Illinois': 'IL',
  'Indiana': 'IN',
  'Iowa': 'IA',
  'Kansas': 'KS',
  'Kentucky': 'KY',
  'Louisiana': 'LA',
  'Maine': 'ME',
  'Maryland': 'MD',
  'Massachusetts': 'MA',
  'Michigan': 'MI',
  'Minnesota': 'MN',
  'Mississippi': 'MS',
  'Missouri': 'MO',
  'Montana': 'MT',
  'Nebraska': 'NE',
  'Nevada': 'NV',
  'New Hampshire': 'NH',
  'New Jersey': 'NJ',
  'New Mexico': 'NM',
  'New York': 'NY',
  'North Carolina': 'NC',
  'North Dakota': 'ND',
  'Ohio': 'OH',
  'Oklahoma': 'OK',
  'Oregon': 'OR',
  'Pennsylvania': 'PA',
  'Rhode Island': 'RI',
  'South Carolina': 'SC',
  'South Dakota': 'SD',
  'Tennessee': 'TN',
  'Texas': 'TX',
  'Utah': 'UT',
  'Vermont': 'VT',
  'Virginia': 'VA',
  'Washington': 'WA',
  'West Virginia': 'WV',
  'Wisconsin': 'WI',
  'Wyoming': 'WY',
};

class _MockEventSummary extends EventSummary {
  _MockEventSummary()
    : super(
        id: -1,
        sku: 'MOCK',
        name: 'VEX Robotics World Championships - HS',
        start: _mockDate,
        end: _mockDate,
        seasonId: 0,
        location: const LocationSummary(
          venue: '',
          address1: '',
          city: 'St. Louis',
          region: 'Missouri',
          postcode: '',
          country: 'United States',
        ),
        divisions: const <DivisionSummary>[],
        livestreamLink: '',
      );

  static final DateTime _mockDate = DateTime(2026, 4, 21);
}
