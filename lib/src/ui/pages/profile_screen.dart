import 'package:flutter/material.dart';

import '../../app/solar_app_scope.dart';
import '../models/team_stats_snapshot.dart';
import '../widgets/solar_page_scaffold.dart';
import '../widgets/solar_navigation.dart';
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
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const <BoxShadow>[
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 20,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      account.fullName,
                      style: const TextStyle(
                        color: Color(0xFF24243A),
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      account.email,
                      style: const TextStyle(
                        color: Color(0xFF8E92A7),
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: <Widget>[
                        _ProfilePill(
                          label: 'Team',
                          value: account.team.number,
                          onTap: () {
                            openSolarTeamProfileForSummary(
                              context,
                              account.team,
                            );
                          },
                        ),
                        _ProfilePill(
                          label: 'Skills Rank',
                          value: teamStats.skillsRankLabel,
                        ),
                        _ProfilePill(
                          label: 'CCWM',
                          value: teamStats.ccwm?.toStringAsFixed(1) ?? '--',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
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
              const SizedBox(height: 18),
              _InfoCard(
                title: 'Account Info',
                rows: <MapEntry<String, String>>[
                  MapEntry('Email', account.email),
                  MapEntry('Joined', _formatDate(account.createdAt)),
                  MapEntry(
                    'Status',
                    account.team.registered ? 'Registered' : 'Pending',
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfilePill extends StatelessWidget {
  const _ProfilePill({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F8FD),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF8E92A7),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFF24243A),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
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
