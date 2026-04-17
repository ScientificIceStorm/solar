import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_session_controller.dart';
import '../../app/solar_app_scope.dart';
import '../../core/solar_competition_scope.dart';
import '../../models/robot_events_models.dart';
import '../pages/event_details_screen.dart';
import '../models/solar_match_prediction.dart';
import '../models/solar_notification_center_snapshot.dart';
import '../models/team_stats_snapshot.dart';
import '../widgets/solar_event_photo.dart';
import '../widgets/solar_match_row.dart';
import '../widgets/solar_navigation.dart';
import '../widgets/solar_screen_background.dart';
import '../widgets/solar_team_link.dart';
import '../widgets/solar_team_overview_card.dart';
import '../widgets/worlds_schedule_banner.dart';
import 'event_division_screen.dart';
import 'match_details_screen.dart';
import 'onboarding_screen.dart';
import 'search_screen.dart';
import 'team_profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const routeName = '/home';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _HomeSearchScope { all, teams, events }

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  AppSessionController? _sessionController;
  _HomeSearchScope _searchScope = _HomeSearchScope.all;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = SolarAppScope.of(context);
    if (!identical(_sessionController, controller)) {
      _sessionController = controller;
      unawaited(controller.preloadSearchEvents());
      unawaited(controller.preloadSearchTeams());
      unawaited(controller.syncIosCompanion());
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

  Future<void> _openSearchFilterSheet() async {
    final selection = await showModalBottomSheet<_HomeSearchScope>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFFF7F5F8),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Search Filter',
                  style: TextStyle(
                    color: Color(0xFF24243A),
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose what the homepage search should show.',
                  style: TextStyle(
                    color: Color(0xFF8E92A7),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                for (final scope in _HomeSearchScope.values)
                  _HomeSearchScopeTile(
                    label: _homeSearchScopeLabel(scope),
                    selected: scope == _searchScope,
                    onTap: () => Navigator.of(context).pop(scope),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted || selection == null || selection == _searchScope) {
      return;
    }

    setState(() {
      _searchScope = selection;
    });
  }

  Future<void> _openNotificationHub(AppSessionController controller) async {
    final snapshot = await controller.fetchNotificationCenterSnapshot();
    await controller.markNotificationCenterSeen(snapshot: snapshot);
    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFF7F5F8),
      builder: (context) {
        return SafeArea(
          top: false,
          child: _NotificationHubSheet(snapshot: snapshot),
        );
      },
    );
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
        final visibleTeamResults = _searchScope == _HomeSearchScope.events
            ? const <TeamSummary>[]
            : teamResults;
        final visibleEventResults = _searchScope == _HomeSearchScope.teams
            ? const <EventSummary>[]
            : eventResults;
        final teamStats =
            controller.teamStats ?? TeamStatsSnapshot(team: account.team);
        final notificationFuture = controller.fetchNotificationCenterSnapshot();
        final topInset = MediaQuery.paddingOf(context).top;

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Scaffold(
            extendBody: true,
            backgroundColor: Colors.black,
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
                  OnboardingScreen.routeName,
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
                child: StretchingOverscrollIndicator(
                  axisDirection: AxisDirection.down,
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
                        notificationFuture: notificationFuture,
                        onNotificationsTap: () {
                          _openNotificationHub(controller);
                        },
                        onFilterTap: _openSearchFilterSheet,
                        filterLabel: _homeSearchScopeLabel(_searchScope),
                      ),
                      const SizedBox(height: 24),
                      if (controller
                          .showWorldsScheduleReleaseBanner) ...<Widget>[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: WorldsScheduleBanner(
                            onOpen: () {
                              navigateToSolarDestination(
                                context,
                                SolarNavDestination.calendar,
                              );
                            },
                            onDismiss: () {
                              unawaited(
                                controller.dismissWorldsScheduleReleaseBanner(),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                      if (showSearchResults) ...<Widget>[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: _SearchResultsPanel(
                            query: query,
                            teamResults: visibleTeamResults,
                            eventResults: visibleEventResults,
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
                          child: _QuickviewTeamCarousel(
                            controller: controller,
                            accountTeam: account.team,
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
                        _UpcomingEventsSection(
                          events: teamStats.upcomingEvents,
                        ),
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
                          child: SolarTeamOverviewCard(
                            team: account.team,
                            teamStats: teamStats,
                            onTap: () {
                              openSolarTeamProfileForSummary(
                                context,
                                account.team,
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
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
    required this.notificationFuture,
    required this.onNotificationsTap,
    required this.onFilterTap,
    required this.filterLabel,
  });

  final double topInset;
  final bool isRefreshing;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final Future<SolarNotificationCenterSnapshot> notificationFuture;
  final VoidCallback onNotificationsTap;
  final VoidCallback onFilterTap;
  final String filterLabel;

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
              FutureBuilder<SolarNotificationCenterSnapshot>(
                future: notificationFuture,
                builder: (context, snapshot) {
                  final itemCount = snapshot.hasData
                      ? snapshot.data!.unreadCount(
                          SolarAppScope.of(
                            context,
                          ).notificationCenterSeenAtMillis,
                        )
                      : 0;
                  return InkWell(
                    onTap: onNotificationsTap,
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
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
                          if (itemCount > 0)
                            Positioned(
                              top: 12,
                              right: 12,
                              child: Container(
                                constraints: const BoxConstraints(
                                  minWidth: 22,
                                  minHeight: 22,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 4,
                                ),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2C97BF),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  itemCount > 9 ? '9+' : '$itemCount',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
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
              _FilterButton(label: filterLabel, onTap: onFilterTap),
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

class _NotificationHubSheet extends StatelessWidget {
  const _NotificationHubSheet({required this.snapshot});

  final SolarNotificationCenterSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 10, 22, 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Match Notifications',
              style: TextStyle(
                color: Color(0xFF24243A),
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your next published match and the latest completed results live here.',
              style: TextStyle(
                color: Color(0xFF8E92A7),
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                children: <Widget>[
                  if (snapshot.upcomingMatch != null)
                    _NotificationCard.upcoming(
                      event: snapshot.upcomingEvent,
                      match: snapshot.upcomingMatch!,
                    )
                  else
                    const _NotificationEmptyCard(
                      label: 'No upcoming published match right now.',
                    ),
                  const SizedBox(height: 18),
                  const Text(
                    'Recent Results',
                    style: TextStyle(
                      color: Color(0xFF24243A),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (snapshot.recentResults.isEmpty)
                    const _NotificationEmptyCard(
                      label:
                          'Completed match results will show up here after they post.',
                    )
                  else
                    ...snapshot.recentResults.map<Widget>(
                      _NotificationCard.result,
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

class _NotificationCard extends StatelessWidget {
  const _NotificationCard._({
    required this.eyebrow,
    required this.headline,
    required this.icon,
    required this.subtitle,
    required this.meta,
    required this.accentColor,
  });

  factory _NotificationCard.upcoming({
    required EventSummary? event,
    required MatchSummary match,
  }) {
    return _NotificationCard._(
      eyebrow: 'Up next',
      headline: match.name,
      icon: Icons.schedule_rounded,
      subtitle: event?.name ?? match.event.name,
      meta: <String>[
        if (match.division.name.trim().isNotEmpty) match.division.name.trim(),
        if (match.field.trim().isNotEmpty) match.field.trim(),
        solarMatchTimeLabel(match),
      ].join('  •  '),
      accentColor: const Color(0xFF2930FF),
    );
  }

  factory _NotificationCard.result(SolarRecentMatchResult result) {
    final scoreLabel = '${result.allianceScore} - ${result.opponentScore}';
    return _NotificationCard._(
      eyebrow: result.tied
          ? 'Tie'
          : result.won
          ? 'Win'
          : 'Loss',
      headline: '${result.match.name}  •  $scoreLabel',
      icon: result.tied
          ? Icons.drag_handle_rounded
          : result.won
          ? Icons.arrow_upward_rounded
          : Icons.arrow_downward_rounded,
      subtitle: result.event?.name ?? result.match.event.name,
      meta: <String>[
        result.match.division.name,
        if (result.match.field.trim().isNotEmpty) result.match.field.trim(),
        _notificationResultTimeLabel(result.completedAt),
      ].where((value) => value.trim().isNotEmpty).join('  •  '),
      accentColor: result.tied
          ? const Color(0xFF7A7F92)
          : result.won
          ? const Color(0xFF1F9D61)
          : const Color(0xFFD24E4E),
    );
  }

  final String eyebrow;
  final String headline;
  final IconData icon;
  final String subtitle;
  final String meta;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFDADAE3))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 10,
            height: 54,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      eyebrow.toUpperCase(),
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(icon, color: accentColor, size: 16),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  headline,
                  style: const TextStyle(
                    color: Color(0xFF24243A),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF4E5368),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  meta,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF8E92A7),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
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

class _NotificationEmptyCard extends StatelessWidget {
  const _NotificationEmptyCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFDADAE3))),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF8E92A7),
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.45,
        ),
      ),
    );
  }
}

String _notificationResultTimeLabel(DateTime? dateTime) {
  if (dateTime == null) {
    return 'Posted recently';
  }
  final local = dateTime.toLocal();
  final time = TimeOfDay.fromDateTime(local);
  final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
  final minute = local.minute.toString().padLeft(2, '0');
  final suffix = time.period == DayPeriod.am ? 'AM' : 'PM';
  return '${local.month}/${local.day}  $hour:$minute $suffix';
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
  const _FilterButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
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
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF22212E),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeSearchScopeTile extends StatelessWidget {
  const _HomeSearchScopeTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEEF0FF) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? const Color(0xFF5B61F6)
                  : const Color(0xFFE6E8F2),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF24243A),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
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
          const SizedBox(height: 10),
          TextButton(
            onPressed: () {
              Navigator.of(context).pushNamed(
                SearchScreen.routeName,
                arguments: SearchScreenArgs(initialQuery: query),
              );
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'See all results',
              style: TextStyle(
                color: Color(0xFF2930FF),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
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
                    Navigator.of(context).pushNamed(
                      SearchScreen.routeName,
                      arguments: SearchScreenArgs(
                        initialQuery: query,
                        initialScope: SearchResultScope.teams,
                      ),
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
                    Navigator.of(context).pushNamed(
                      SearchScreen.routeName,
                      arguments: SearchScreenArgs(
                        initialQuery: query,
                        initialScope: SearchResultScope.events,
                      ),
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
              Navigator.of(context).pushNamed(
                SearchScreen.routeName,
                arguments: SearchScreenArgs(
                  initialQuery: query,
                  initialScope: SearchResultScope.teams,
                ),
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
              Navigator.of(context).pushNamed(
                SearchScreen.routeName,
                arguments: SearchScreenArgs(
                  initialQuery: query,
                  initialScope: SearchResultScope.events,
                ),
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
    final controller = SolarAppScope.of(context);
    final isFavorite = controller.isFavoriteTeam(team.number);

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
            const SizedBox(width: 10),
            InkWell(
              onTap: () {
                controller.toggleFavoriteTeam(team);
              },
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(
                  isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: const Color(0xFF24243A),
                  size: 20,
                ),
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
                    event.name,
                    maxLines: 2,
                    overflow: TextOverflow.fade,
                    style: const TextStyle(
                      color: Color(0xFF24243A),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_eventRangeLabel(event)}  •  ${_locationLabel(event.location)}',
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

class _QuickviewSection extends StatefulWidget {
  const _QuickviewSection({
    required this.controller,
    required this.teamNumber,
    required this.teamGrade,
  });

  final AppSessionController controller;
  final String teamNumber;
  final String teamGrade;

  @override
  State<_QuickviewSection> createState() => _QuickviewSectionState();
}

class _QuickviewTeamCarousel extends StatefulWidget {
  const _QuickviewTeamCarousel({
    required this.controller,
    required this.accountTeam,
  });

  final AppSessionController controller;
  final TeamSummary accountTeam;

  @override
  State<_QuickviewTeamCarousel> createState() => _QuickviewTeamCarouselState();
}

class _QuickviewTeamCarouselState extends State<_QuickviewTeamCarousel> {
  int _selectedIndex = 0;
  int _slideDirection = 1;
  double _dragDeltaX = 0;

  List<TeamSummary> _availableTeams() {
    final byTeamNumber = <String, TeamSummary>{
      widget.accountTeam.number.trim().toUpperCase(): widget.accountTeam,
    };
    for (final team in widget.controller.favoriteTeams) {
      final normalized = team.number.trim().toUpperCase();
      if (normalized.isEmpty) {
        continue;
      }
      byTeamNumber[normalized] = team;
    }
    return byTeamNumber.values.toList(growable: false);
  }

  @override
  void didUpdateWidget(covariant _QuickviewTeamCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller) ||
        oldWidget.accountTeam.number != widget.accountTeam.number) {
      _selectedIndex = 0;
    }
  }

  void _shiftTeam(int delta) {
    final teams = _availableTeams();
    if (teams.length <= 1) {
      return;
    }

    var nextIndex = (_selectedIndex + delta) % teams.length;
    if (nextIndex < 0) {
      nextIndex += teams.length;
    }

    setState(() {
      _slideDirection = delta >= 0 ? 1 : -1;
      _selectedIndex = nextIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    final teams = _availableTeams();
    final selectedIndex = teams.isEmpty
        ? 0
        : (_selectedIndex >= teams.length ? teams.length - 1 : _selectedIndex);
    if (selectedIndex != _selectedIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        setState(() {
          _selectedIndex = selectedIndex;
        });
      });
    }

    final activeTeam = teams.isEmpty
        ? widget.accountTeam
        : teams[selectedIndex];
    final hasMultipleTeams = teams.length > 1;
    final isFavorite = widget.controller.isFavoriteTeam(activeTeam.number);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Team ${activeTeam.number}',
                    style: const TextStyle(
                      color: Color(0xFF24243A),
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    activeTeam.teamName.isEmpty
                        ? 'Quickview snapshot'
                        : activeTeam.teamName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF8E92A7),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            InkWell(
              onTap: () {
                widget.controller.toggleFavoriteTeam(activeTeam);
              },
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: const Color(0xFF24243A),
                  size: 19,
                ),
              ),
            ),
          ],
        ),
        if (hasMultipleTeams) ...<Widget>[
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              const Icon(
                Icons.swipe_rounded,
                size: 16,
                color: Color(0xFF8E92A7),
              ),
              const SizedBox(width: 6),
              Text(
                '${selectedIndex + 1}/${teams.length} • Swipe sideways to switch teams',
                style: const TextStyle(
                  color: Color(0xFF8E92A7),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) {
            _dragDeltaX = 0;
          },
          onHorizontalDragUpdate: (details) {
            _dragDeltaX += details.primaryDelta ?? 0;
          },
          onHorizontalDragEnd: (_) {
            if (_dragDeltaX.abs() < 20) {
              _dragDeltaX = 0;
              return;
            }
            _shiftTeam(_dragDeltaX < 0 ? 1 : -1);
            _dragDeltaX = 0;
          },
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 260),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final offsetAnimation = Tween<Offset>(
                begin: Offset(0.16 * _slideDirection, 0),
                end: Offset.zero,
              ).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: offsetAnimation, child: child),
              );
            },
            child: KeyedSubtree(
              key: ValueKey<String>(
                'quickview-${activeTeam.number.trim().toUpperCase()}',
              ),
              child: _QuickviewSection(
                controller: widget.controller,
                teamNumber: activeTeam.number,
                teamGrade: activeTeam.grade.isEmpty
                    ? widget.accountTeam.grade
                    : activeTeam.grade,
              ),
            ),
          ),
        ),
        if (hasMultipleTeams) ...<Widget>[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              for (var i = 0; i < teams.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: i == selectedIndex ? 16 : 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: i == selectedIndex
                        ? const Color(0xFF24243A)
                        : const Color(0xFFC9CCD9),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _QuickviewSectionState extends State<_QuickviewSection> {
  Future<SolarQuickviewSnapshot?>? _quickviewFuture;
  Future<_QuickviewHeroData>? _heroFuture;
  String? _heroCacheKey;

  @override
  void didUpdateWidget(covariant _QuickviewSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller) ||
        oldWidget.teamNumber != widget.teamNumber ||
        oldWidget.teamGrade != widget.teamGrade) {
      _quickviewFuture = null;
      _heroFuture = null;
      _heroCacheKey = null;
    }
  }

  Future<_QuickviewHeroData> _heroDataFor({
    required EventSummary event,
    required MatchSummary match,
    required DivisionSummary division,
  }) {
    final cacheKey =
        '${event.id}:${match.id}:${division.id}:${widget.teamNumber.trim().toUpperCase()}';
    if (_heroFuture != null && _heroCacheKey == cacheKey) {
      return _heroFuture!;
    }

    final future = _loadQuickviewHeroData(
      controller: widget.controller,
      event: event,
      match: match,
      division: division,
      teamNumber: widget.teamNumber,
    );
    _heroCacheKey = cacheKey;
    _heroFuture = future;
    return future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<SolarQuickviewSnapshot?>(
      future: _quickviewFuture ??= _loadQuickviewSnapshotForTeam(
        controller: widget.controller,
        teamNumber: widget.teamNumber,
        teamGrade: widget.teamGrade,
      ),
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
          return _QuickviewEventBannerCard(
            event: quickview.event,
            body: 'RobotEvents has not posted qualifying match pairings yet.',
          );
        }

        final remainingMatches = quickview.futureMatches
            .where((match) => match.id != nextMatch.id)
            .toList(growable: false);
        final accountTeamNumber = widget.controller.currentAccount?.team.number
            .trim()
            .toUpperCase();
        final quickviewTeamNumber = widget.teamNumber.trim().toUpperCase();
        final currentDivision =
            (accountTeamNumber == quickviewTeamNumber
                ? widget.controller.currentTeamDivisionForEvent(
                    quickview.event.id,
                  )
                : null) ??
            nextMatch.division;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            FutureBuilder<_QuickviewHeroData>(
              future: _heroDataFor(
                event: quickview.event,
                match: nextMatch,
                division: currentDivision,
              ),
              builder: (context, predictionSnapshot) {
                final heroData = predictionSnapshot.data;
                return _QuickviewHeroCard(
                  event: quickview.event,
                  match: nextMatch,
                  prediction: heroData?.prediction,
                  division: currentDivision,
                  currentRanking: heroData?.currentRanking,
                  teamNumber: widget.teamNumber,
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
                  highlightTeamNumber: widget.teamNumber,
                  onTap: () {
                    Navigator.of(context).pushNamed(
                      MatchDetailsScreen.routeName,
                      arguments: MatchDetailsScreenArgs(
                        match: match,
                        event: quickview.event,
                        highlightTeamNumber: widget.teamNumber,
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
    required this.division,
    required this.currentRanking,
    required this.teamNumber,
  });

  final EventSummary event;
  final MatchSummary match;
  final SolarMatchPrediction? prediction;
  final DivisionSummary division;
  final RankingRecord? currentRanking;
  final String teamNumber;

  @override
  Widget build(BuildContext context) {
    final palette = _quickviewPaletteFor(match);
    final yourAlliance = _allianceContainingTeam(match, teamNumber);
    final opponents = _opposingAlliance(match, yourAlliance);
    final favoredLabel = prediction == null
        ? '$solarizeLabel warming up'
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
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: palette.colors,
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
                      RichText(
                        text: TextSpan(
                          children: <InlineSpan>[
                            TextSpan(
                              text: solarMatchScreenLabel(match),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -1.2,
                              ),
                            ),
                            TextSpan(
                              text: '  ${solarMatchTimeLabel(match)}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.86),
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
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
                      const SizedBox(height: 6),
                      Text(
                        _quickviewMetaLine(match: match, event: event),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.62),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 16, top: 4),
                  child: Icon(
                    palette.icon,
                    color: Colors.white.withValues(alpha: 0.28),
                    size: 26,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 1,
              color: Colors.white.withValues(alpha: 0.08),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: () {
                Navigator.of(context).pushNamed(
                  EventDivisionScreen.routeName,
                  arguments: EventDivisionScreenArgs(
                    event: event,
                    division: division,
                    highlightTeamNumber: teamNumber,
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      currentRanking == null
                          ? division.name
                          : '#${currentRanking!.rank} in ${division.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentRanking == null
                          ? 'Tap to open division rankings'
                          : '${currentRanking!.wins}-${currentRanking!.losses}-${currentRanking!.ties}  •  WP ${_safeInt(currentRanking!.wp)}  •  AP ${_safeInt(currentRanking!.ap)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.72),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
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

class _QuickviewEventBannerCard extends StatelessWidget {
  const _QuickviewEventBannerCard({required this.event, required this.body});

  final EventSummary event;
  final String body;

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
        borderRadius: BorderRadius.circular(32),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(32),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: SizedBox(
                  height: 176,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      SolarEventPhoto(
                        location: event.location,
                        overlay: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[
                                Colors.black.withValues(alpha: 0.08),
                                Colors.black.withValues(alpha: 0.14),
                                Colors.black.withValues(alpha: 0.48),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 18,
                        right: 18,
                        bottom: 18,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              event.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                height: 1.05,
                                letterSpacing: -0.8,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${_eventRangeLabel(event)}  •  ${_locationLabel(event.location)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                body,
                style: const TextStyle(
                  color: Color(0xFF6F748B),
                  fontSize: 14,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickviewHeroData {
  const _QuickviewHeroData({
    required this.prediction,
    required this.currentRanking,
  });

  final SolarMatchPrediction? prediction;
  final RankingRecord? currentRanking;
}

class _QuickviewPalette {
  const _QuickviewPalette({required this.colors, required this.icon});

  final List<Color> colors;
  final IconData icon;
}

Future<SolarQuickviewSnapshot?> _loadQuickviewSnapshotForTeam({
  required AppSessionController controller,
  required String teamNumber,
  required String teamGrade,
}) async {
  final normalizedTeamNumber = teamNumber.trim().toUpperCase();
  if (normalizedTeamNumber.isEmpty) {
    return null;
  }

  final currentTeam = controller.currentAccount?.team;
  if (currentTeam != null &&
      currentTeam.number.trim().toUpperCase() == normalizedTeamNumber) {
    return controller.fetchQuickviewSnapshot();
  }

  final seedTeam = controller.resolveKnownTeamSummary(
    teamNumber: normalizedTeamNumber,
    grade: teamGrade,
  );
  final teamStats = await controller.fetchTeamStatsSnapshot(seedTeam);
  final resolvedTeam = teamStats.team;
  if (resolvedTeam.id <= 0) {
    return null;
  }

  final teamReference = TeamReference(
    id: resolvedTeam.id,
    number: resolvedTeam.number,
    name: resolvedTeam.teamName,
  );

  final futureEvents = teamStats.futureEvents;
  if (futureEvents.isEmpty) {
    return null;
  }

  final trackedEvents = futureEvents.take(4).toList(growable: false);
  final schedules =
      await Future.wait<MapEntry<EventSummary, List<MatchSummary>>>(
        trackedEvents.map((event) async {
          final schedule = await controller.fetchTeamMatchesForReference(
            teamReference,
            eventId: event.id,
          );
          return MapEntry<EventSummary, List<MatchSummary>>(event, schedule);
        }),
      );

  for (final entry in schedules) {
    final event = entry.key;
    final schedule = entry.value;
    final qualificationMatches = schedule
        .where((match) => match.round == MatchRound.qualification)
        .toList(growable: false);
    final futureMatches = qualificationMatches
        .where(_isFuturePendingQuickviewMatch)
        .toList(growable: false);

    if (futureMatches.isNotEmpty) {
      return SolarQuickviewSnapshot(
        event: event,
        nextQualifyingMatch: futureMatches.first,
        futureMatches: futureMatches,
      );
    }
  }

  final fallbackEntry = schedules.isEmpty ? null : schedules.first;
  final fallbackEvent = fallbackEntry?.key ?? futureEvents.first;
  final fallbackSchedule =
      fallbackEntry?.value ??
      await controller.fetchTeamMatchesForReference(
        teamReference,
        eventId: fallbackEvent.id,
      );
  final fallbackMatches = fallbackSchedule
      .where(_isFuturePendingQuickviewMatch)
      .toList(growable: false);

  return SolarQuickviewSnapshot(
    event: fallbackEvent,
    nextQualifyingMatch: fallbackMatches.isEmpty ? null : fallbackMatches.first,
    futureMatches: fallbackMatches,
  );
}

bool _isFuturePendingQuickviewMatch(MatchSummary match) {
  final now = DateTime.now();
  final anchor = match.scheduled ?? match.started;
  final hasOfficialScores =
      match.alliances.length >= 2 &&
      match.alliances.every((alliance) => alliance.score >= 0);
  return !hasOfficialScores && (anchor == null || !anchor.isBefore(now));
}

Future<_QuickviewHeroData> _loadQuickviewHeroData({
  required AppSessionController controller,
  required EventSummary event,
  required MatchSummary match,
  required DivisionSummary division,
  required String teamNumber,
}) async {
  final values = await Future.wait<Object?>(<Future<Object?>>[
    controller
        .predictMatch(match: match, event: event)
        .then<Object?>((value) => value),
    controller
        .fetchDivisionRankings(eventId: event.id, divisionId: division.id)
        .then<Object?>((value) => value),
  ]);

  final prediction = values[0] as SolarMatchPrediction?;
  final rankings = values[1] as List<RankingRecord>;
  RankingRecord? currentRanking;
  final normalizedTeamNumber = teamNumber.trim().toUpperCase();
  for (final entry in rankings) {
    if (entry.team.number.trim().toUpperCase() == normalizedTeamNumber) {
      currentRanking = entry;
      break;
    }
  }

  return _QuickviewHeroData(
    prediction: prediction,
    currentRanking: currentRanking,
  );
}

String _quickviewMetaLine({
  required MatchSummary match,
  required EventSummary event,
}) {
  final parts = <String>[
    if (match.field.trim().isNotEmpty) match.field.trim(),
    _locationLabel(event.location),
  ].where((value) => value.trim().isNotEmpty).toList(growable: false);
  return parts.join('  •  ');
}

_QuickviewPalette _quickviewPaletteFor(MatchSummary match) {
  final anchor = match.scheduled ?? match.started ?? DateTime.now();
  final hour = anchor.hour;
  if (hour >= 19 || hour < 6) {
    return const _QuickviewPalette(
      colors: <Color>[Color(0xFF0D1020), Color(0xFF1C2340)],
      icon: Icons.nightlight_round,
    );
  }
  if (hour >= 16) {
    return const _QuickviewPalette(
      colors: <Color>[Color(0xFF3A1F27), Color(0xFF7A4A32)],
      icon: Icons.wb_twilight,
    );
  }
  return const _QuickviewPalette(
    colors: <Color>[Color(0xFF20486A), Color(0xFF5B89B8)],
    icon: Icons.wb_sunny_rounded,
  );
}

String _safeInt(int value) {
  return value >= 0 ? '$value' : '--';
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
    if (events.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(28),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'No upcoming events yet',
                style: TextStyle(
                  color: Color(0xFF24243A),
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Once your team has another published event, it will show up here without any mock placeholders.',
                style: TextStyle(
                  color: Color(0xFF8E92A7),
                  fontSize: 14,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final visibleEvents = events.take(6).toList(growable: false);

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

String _homeSearchScopeLabel(_HomeSearchScope scope) {
  return switch (scope) {
    _HomeSearchScope.all => 'All',
    _HomeSearchScope.teams => 'Teams',
    _HomeSearchScope.events => 'Events',
  };
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
