import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_session_controller.dart';
import '../../app/solar_app_scope.dart';
import '../../models/robot_events_models.dart';
import '../models/team_stats_snapshot.dart';
import '../widgets/solar_navigation.dart';
import '../widgets/solar_page_scaffold.dart';
import '../widgets/solar_team_overview_card.dart';
import '../widgets/solar_team_link.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const routeName = '/profile';

  @override
  Widget build(BuildContext context) {
    final controller = SolarAppScope.of(context);

    return SolarPageScaffold(
      title: 'My Profile',
      currentDestination: SolarNavDestination.profile,
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final account = controller.currentAccount;
          if (account == null) {
            return const SizedBox.shrink();
          }

          if (controller.favoriteTeamNumbers.isNotEmpty &&
              controller.preloadedSearchTeams.isEmpty &&
              !controller.isPreloadingSearchTeams) {
            unawaited(controller.preloadSearchTeams());
          }

          final teamStats =
              controller.teamStats ?? TeamStatsSnapshot(team: account.team);
            final followedTeams = controller.followedTeams;
            final favoriteTeams = followedTeams
              .where(
                (team) =>
                    team.number.trim().toUpperCase() !=
                    account.team.number.trim().toUpperCase(),
              )
              .toList(growable: false);

          return ListView(
            padding: const EdgeInsets.only(bottom: 14),
            children: <Widget>[
              FutureBuilder<int>(
                future: controller.fetchTeamAwardsCount(teamStats.team),
                builder: (context, snapshot) {
                  return SolarTeamOverviewCard(
                    team: account.team,
                    teamStats: teamStats,
                    awardsCount: snapshot.data,
                    onTap: () {
                      openSolarTeamProfileForSummary(context, account.team);
                    },
                  );
                },
              ),
              if (favoriteTeams.isNotEmpty) ...<Widget>[
                const SizedBox(height: 22),
                _FavoriteTeamsSection(teams: favoriteTeams),
              ],
              const SizedBox(height: 22),
              _ProfileTeamGraphDeck(
                controller: controller,
                teams: followedTeams,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FavoriteTeamsSection extends StatelessWidget {
  const _FavoriteTeamsSection({required this.teams});

  final List<TeamSummary> teams;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Favorite Teams',
            style: TextStyle(
              color: Color(0xFF24243A),
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < teams.length; index++)
            _FavoriteTeamRow(
              team: teams[index],
              showDivider: index != teams.length - 1,
            ),
        ],
      ),
    );
  }
}

class _FavoriteTeamRow extends StatelessWidget {
  const _FavoriteTeamRow({required this.team, required this.showDivider});

  final TeamSummary team;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final subtitle = <String>[
      if (team.teamName.trim().isNotEmpty) team.teamName.trim(),
      if (team.organization.trim().isNotEmpty) team.organization.trim(),
    ].join(' | ');

    return InkWell(
      onTap: () {
        openSolarTeamProfileForSummary(context, team);
      },
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: showDivider
            ? const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFDADAE3))),
              )
            : null,
        child: Row(
          children: <Widget>[
            const Icon(Icons.star_rounded, color: Color(0xFF24243A), size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SolarTeamLinkText(
                    teamNumber: team.number,
                    teamId: team.id,
                    teamName: team.teamName,
                    organization: team.organization,
                    onTap: () {
                      openSolarTeamProfileForSummary(context, team);
                    },
                    style: const TextStyle(
                      color: Color(0xFF24243A),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF8E92A7),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Color(0xFF8E92A7),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTeamGraphDeck extends StatefulWidget {
  const _ProfileTeamGraphDeck({
    required this.controller,
    required this.teams,
  });

  final AppSessionController controller;
  final List<TeamSummary> teams;

  @override
  State<_ProfileTeamGraphDeck> createState() => _ProfileTeamGraphDeckState();
}

class _ProfileTeamGraphDeckState extends State<_ProfileTeamGraphDeck> {
  Future<_ProfileGraphDeckData>? _graphFuture;
  int _selectedIndex = 0;
  String? _activeTeamKey;
  double _dragDeltaX = 0;

  String _teamSignature(List<TeamSummary> teams) {
    return teams
        .map((team) => team.number.trim().toUpperCase())
        .join('|');
  }

  @override
  void didUpdateWidget(covariant _ProfileTeamGraphDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller) ||
        _teamSignature(oldWidget.teams) != _teamSignature(widget.teams)) {
      _graphFuture = null;
      _activeTeamKey = null;
      _selectedIndex = 0;
    }
  }

  void _shiftTeam(int delta) {
    final teams = widget.teams;
    if (teams.length <= 1) {
      return;
    }

    var nextIndex = (_selectedIndex + delta) % teams.length;
    if (nextIndex < 0) {
      nextIndex += teams.length;
    }

    setState(() {
      _selectedIndex = nextIndex;
      _graphFuture = null;
      _activeTeamKey = null;
    });
  }

  Future<_ProfileGraphDeckData> _loadGraphDeckData(TeamSummary team) async {
    await widget.controller.ensureSolarizeCoverageForTeams(
      teams: <TeamSummary>[team],
    );
    final teamStats = await widget.controller.fetchTeamStatsSnapshot(team);
    return _hydrateGraphDeckData(
      headline: 'Team ${teamStats.team.number}',
      teamStats: teamStats,
    );
  }

  Future<_ProfileGraphDeckData> _hydrateGraphDeckData({
    required String headline,
    required TeamStatsSnapshot teamStats,
  }) async {
    final skillsHistory = await _skillsHistoryFromPastEvents(
      controller: widget.controller,
      teamStats: teamStats,
    );
    final awardsHistory = await _awardsHistoryFromPastEvents(
      controller: widget.controller,
      teamStats: teamStats,
    );

    return _ProfileGraphDeckData(
      headline: headline,
      teamStats: teamStats,
      skillsHistory: skillsHistory,
      awardsHistory: awardsHistory,
    );
  }

  @override
  Widget build(BuildContext context) {
    final teams = widget.teams;
    if (teams.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_selectedIndex >= teams.length) {
      _selectedIndex = teams.length - 1;
    }
    final activeTeam = teams[_selectedIndex];
    final activeKey = activeTeam.number.trim().toUpperCase();
    if (_activeTeamKey != activeKey) {
      _activeTeamKey = activeKey;
      _graphFuture = null;
    }

    final hasMultipleTeams = teams.length > 1;

    return GestureDetector(
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
      child: FutureBuilder<_ProfileGraphDeckData>(
        future: _graphFuture ??= _loadGraphDeckData(activeTeam),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Row(
                children: <Widget>[
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Loading team history lists...',
                      style: TextStyle(
                        color: Color(0xFF6F748B),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final data = snapshot.data!;
          final teamStats = data.teamStats;

          return Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Team History Lists',
                  style: TextStyle(
                    color: Color(0xFF24243A),
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${data.headline} skills and awards in a clean list view',
                  style: const TextStyle(
                    color: Color(0xFF8E92A7),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (hasMultipleTeams) ...<Widget>[
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.swipe_rounded,
                        size: 16,
                        color: Color(0xFF8E92A7),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${_selectedIndex + 1}/${teams.length} • Swipe to switch teams',
                        style: const TextStyle(
                          color: Color(0xFF8E92A7),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
                if ((teamStats.errorMessage ?? '').isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  Text(
                    teamStats.errorMessage!,
                    style: const TextStyle(
                      color: Color(0xFF8E92A7),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                _ProfileGraphSection(
                  title: 'Skills History',
                  child: data.skillsHistory.isEmpty
                      ? const Text(
                          'Past event skills history will appear here once published attempts are available.',
                          style: TextStyle(
                            color: Color(0xFF8E92A7),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F8FC),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE7E8F2)),
                          ),
                          child: Column(
                            children: <Widget>[
                              for (var i = 0; i < data.skillsHistory.length; i++)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: i == data.skillsHistory.length - 1
                                      ? null
                                      : const BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Color(0xFFE3E5F0),
                                            ),
                                          ),
                                        ),
                                  child: Row(
                                    children: <Widget>[
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              data.skillsHistory[i].eventName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Color(0xFF24243A),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              '${data.skillsHistory[i].label} • Driver ${data.skillsHistory[i].driver} • Auton ${data.skillsHistory[i].programming}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Color(0xFF7B8198),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEEF2FF),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          '${data.skillsHistory[i].combined}',
                                          style: const TextStyle(
                                            color: Color(0xFF1E2A4E),
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
                const SizedBox(height: 18),
                _ProfileGraphSection(
                  title: 'Awards',
                  child: data.awardsHistory.isEmpty
                      ? const Text(
                          'Team awards will appear here when recipients are published for your past events.',
                          style: TextStyle(
                            color: Color(0xFF8E92A7),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F8FC),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE7E8F2)),
                          ),
                          child: Column(
                            children: <Widget>[
                              for (var i = 0; i < data.awardsHistory.length; i++)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  decoration: i == data.awardsHistory.length - 1
                                      ? null
                                      : const BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Color(0xFFE3E5F0),
                                            ),
                                          ),
                                        ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      const Padding(
                                        padding: EdgeInsets.only(top: 2),
                                        child: Icon(
                                          Icons.emoji_events_rounded,
                                          size: 16,
                                          color: Color(0xFF8B6B00),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              data.awardsHistory[i].awardTitle,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Color(0xFF24243A),
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                height: 1.25,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              '${data.awardsHistory[i].eventName} • ${data.awardsHistory[i].eventLabel}',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Color(0xFF7B8198),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            if (data
                                                .awardsHistory[i]
                                                .recipientLabel
                                                .trim()
                                                .isNotEmpty) ...<Widget>[
                                              const SizedBox(height: 3),
                                              Text(
                                                data.awardsHistory[i]
                                                    .recipientLabel,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Color(0xFF9A9FB3),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProfileGraphDeckData {
  const _ProfileGraphDeckData({
    required this.headline,
    required this.teamStats,
    required this.skillsHistory,
    required this.awardsHistory,
  });

  final String headline;
  final TeamStatsSnapshot teamStats;
  final List<_ProfileSkillsHistoryEntry> skillsHistory;
  final List<_ProfileAwardsHistoryEntry> awardsHistory;
}

class _ProfileSkillsHistoryEntry {
  const _ProfileSkillsHistoryEntry({
    required this.label,
    required this.eventName,
    required this.driver,
    required this.programming,
  });

  final String label;
  final String eventName;
  final int driver;
  final int programming;

  int get combined => driver + programming;
}

class _ProfileAwardsHistoryEntry {
  const _ProfileAwardsHistoryEntry({
    required this.eventLabel,
    required this.eventName,
    required this.awardTitle,
    required this.recipientLabel,
  });

  final String eventLabel;
  final String eventName;
  final String awardTitle;
  final String recipientLabel;
}

class _ProfileGraphSection extends StatelessWidget {
  const _ProfileGraphSection({required this.title, required this.child});

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
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

Future<List<_ProfileSkillsHistoryEntry>> _skillsHistoryFromPastEvents({
  required AppSessionController controller,
  required TeamStatsSnapshot teamStats,
}) async {
  if (teamStats.pastEvents.isEmpty) {
    return const <_ProfileSkillsHistoryEntry>[];
  }

  final teamNumber = teamStats.team.number.trim().toUpperCase();
  final sortedPastEvents = teamStats.pastEvents.toList(growable: false)
    ..sort((a, b) {
      final aDate = a.start ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.start ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aDate.compareTo(bDate);
    });
  final trackedEvents = sortedPastEvents.length <= 10
      ? sortedPastEvents
      : sortedPastEvents.sublist(sortedPastEvents.length - 10);

  final skillsEntries = await Future.wait<_ProfileSkillsHistoryEntry?>(
    trackedEvents.map((event) async {
      final attempts = await controller.fetchEventSkills(event.id);
      var driver = 0;
      var programming = 0;
      for (final attempt in attempts) {
        if (attempt.team.number.trim().toUpperCase() != teamNumber) {
          continue;
        }
        final type = attempt.type.trim().toLowerCase();
        final score = attempt.score;
        if (score <= 0) {
          continue;
        }
        if (type.contains('program') || type.contains('auton')) {
          if (score > programming) {
            programming = score;
          }
        } else if (score > driver) {
          driver = score;
        }
      }

      if (driver <= 0 && programming <= 0) {
        return null;
      }

      return _ProfileSkillsHistoryEntry(
        label: _eventLabel(event.start),
        eventName: event.name.trim().isEmpty ? event.sku : event.name.trim(),
        driver: driver,
        programming: programming,
      );
    }),
  );

  return skillsEntries.whereType<_ProfileSkillsHistoryEntry>().toList(
    growable: false,
  );
}

Future<List<_ProfileAwardsHistoryEntry>> _awardsHistoryFromPastEvents({
  required AppSessionController controller,
  required TeamStatsSnapshot teamStats,
}) async {
  if (teamStats.pastEvents.isEmpty) {
    return const <_ProfileAwardsHistoryEntry>[];
  }

  final teamNumber = teamStats.team.number.trim().toUpperCase();
  final sortedPastEvents = teamStats.pastEvents.toList(growable: false)
    ..sort((a, b) {
      final aDate = a.start ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.start ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
  final trackedEvents = sortedPastEvents.length <= 10
      ? sortedPastEvents
      : sortedPastEvents.sublist(0, 10);

  final awardChunks = await Future.wait<List<_ProfileAwardsHistoryEntry>>(
    trackedEvents.map((event) async {
      final awards = await controller.fetchEventAwards(event.id);
      final entries = <_ProfileAwardsHistoryEntry>[];
      for (final award in awards) {
        if (!_awardMentionsTeam(award, teamNumber)) {
          continue;
        }

        final recipient = award.recipients.firstWhere(
          (value) => value.trim().isNotEmpty,
          orElse: () => '',
        );

        entries.add(
          _ProfileAwardsHistoryEntry(
            eventLabel: _eventLabel(event.start),
            eventName: event.name.trim().isEmpty
                ? event.sku
                : event.name.trim(),
            awardTitle: award.title.trim().isEmpty
                ? 'Award'
                : award.title.trim(),
            recipientLabel: recipient,
          ),
        );
      }
      return entries;
    }),
  );

  final flattened = awardChunks
      .expand((entries) => entries)
      .toList(growable: false);
  if (flattened.length <= 18) {
    return flattened;
  }
  return flattened.sublist(0, 18);
}

bool _awardMentionsTeam(AwardSummary award, String teamNumber) {
  return award.recipients.any((recipient) {
    return recipient.trim().toUpperCase().contains(teamNumber);
  });
}

String _eventLabel(DateTime? date) {
  if (date == null) {
    return 'Event';
  }
  const monthNames = <String>[
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
  return '${monthNames[date.month - 1]} ${date.day}';
}
