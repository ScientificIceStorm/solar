import 'dart:async';

import 'package:flutter/material.dart';

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
          final favoriteTeams = controller.favoriteTeams
              .where(
                (team) =>
                    team.number.trim().toUpperCase() !=
                    account.team.number.trim().toUpperCase(),
              )
              .toList(growable: false);

          return ListView(
            padding: const EdgeInsets.only(bottom: 14),
            children: <Widget>[
              SolarTeamOverviewCard(
                team: account.team,
                teamStats: teamStats,
                onTap: () {
                  openSolarTeamProfileForSummary(context, account.team);
                },
              ),
              if (favoriteTeams.isNotEmpty) ...<Widget>[
                const SizedBox(height: 22),
                _FavoriteTeamsSection(teams: favoriteTeams),
              ],
              const SizedBox(height: 20),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'This profile is stored on this device for now.',
                  style: TextStyle(
                    color: Color(0xFF8E92A7),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
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
  const _FavoriteTeamRow({
    required this.team,
    required this.showDivider,
  });

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
