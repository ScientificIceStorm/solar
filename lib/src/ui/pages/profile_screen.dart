import 'package:flutter/material.dart';

import '../../app/solar_app_scope.dart';
import '../models/team_stats_snapshot.dart';
import '../widgets/solar_page_scaffold.dart';
import '../widgets/solar_navigation.dart';
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

          final teamStats =
              controller.teamStats ?? TeamStatsSnapshot(team: account.team);

          return ListView(
            padding: const EdgeInsets.only(bottom: 14),
            children: <Widget>[
              SolarTeamOverviewCard(
                team: account.team,
                teamStats: teamStats,
                statusLabel: account.team.registered ? 'REGISTERED' : 'PENDING',
                onTap: () {
                  openSolarTeamProfileForSummary(context, account.team);
                },
              ),
              const SizedBox(height: 22),
              _InfoCard(
                title: 'Account',
                rows: <MapEntry<String, String>>[
                  MapEntry('Name', account.fullName),
                  MapEntry('Email', account.email),
                  MapEntry('Joined', _formatDate(account.createdAt)),
                  MapEntry(
                    'Status',
                    account.team.registered ? 'Registered' : 'Pending',
                  ),
                ],
              ),
              _InfoCard(
                title: 'Team Info',
                rows: <MapEntry<String, String>>[
                  MapEntry(
                    'Team name',
                    account.team.teamName.isEmpty
                        ? 'Team profile'
                        : account.team.teamName,
                  ),
                  MapEntry(
                    'Organization',
                    account.team.organization.isEmpty
                        ? 'Not available'
                        : account.team.organization,
                  ),
                  MapEntry(
                    'Robot name',
                    account.team.robotName.isEmpty
                        ? 'Not available'
                        : account.team.robotName,
                  ),
                  MapEntry('Location', teamStats.locationLabel),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.rows});

  final String title;
  final List<MapEntry<String, String>> rows;

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
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF24243A),
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 108,
                    child: Text(
                      row.key,
                      style: const TextStyle(
                        color: Color(0xFF8E92A7),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.value,
                      style: const TextStyle(
                        color: Color(0xFF24243A),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
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

String _formatDate(DateTime value) {
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
  return '${months[value.month - 1]} ${value.day}, ${value.year}';
}
