import 'package:flutter/material.dart';

import '../models/app_account.dart';
import 'solar_team_link.dart';

enum SolarNavDestination { home, rankings, search, calendar, profile }

enum SolarDrawerAction { profile, settings, calendar }

String solarRouteForDestination(SolarNavDestination destination) {
  switch (destination) {
    case SolarNavDestination.home:
      return '/home';
    case SolarNavDestination.rankings:
      return '/rankings';
    case SolarNavDestination.search:
      return '/search';
    case SolarNavDestination.calendar:
      return '/calendar';
    case SolarNavDestination.profile:
      return '/profile';
  }
}

String solarRouteForDrawerAction(SolarDrawerAction action) {
  switch (action) {
    case SolarDrawerAction.profile:
      return '/profile';
    case SolarDrawerAction.settings:
      return '/settings';
    case SolarDrawerAction.calendar:
      return '/calendar';
  }
}

void navigateToSolarDestination(
  BuildContext context,
  SolarNavDestination destination,
) {
  final routeName = solarRouteForDestination(destination);
  final currentRoute = ModalRoute.of(context)?.settings.name;
  if (currentRoute == routeName) {
    return;
  }

  Navigator.of(context).pushReplacementNamed(routeName);
}

void openSolarDrawerAction(BuildContext context, SolarDrawerAction action) {
  Navigator.of(context).pushNamed(solarRouteForDrawerAction(action));
}

class SolarMenuGlyph extends StatelessWidget {
  const SolarMenuGlyph({super.key, this.color = Colors.white});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 28,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _MenuLine(width: 34, color: color),
          _MenuLine(width: 24, color: color),
          _MenuLine(width: 34, color: color),
        ],
      ),
    );
  }
}

class SolarAppDrawer extends StatelessWidget {
  const SolarAppDrawer({
    required this.account,
    required this.onActionSelected,
    required this.onSignOut,
    super.key,
  });

  final AppAccount account;
  final ValueChanged<SolarDrawerAction> onActionSelected;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.sizeOf(context).width * 0.78,
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 20, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Text(
                    'Team ',
                    style: TextStyle(
                      color: Color(0xFF6F748B),
                      fontSize: 18,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  SolarTeamLinkText(
                    teamNumber: account.team.number,
                    teamId: account.team.id,
                    teamName: account.team.teamName,
                    organization: account.team.organization,
                    robotName: account.team.robotName,
                    grade: account.team.grade,
                    style: const TextStyle(
                      color: Color(0xFF6F748B),
                      fontSize: 18,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                account.fullName,
                style: const TextStyle(
                  color: Color(0xFF16182C),
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 42),
              _DrawerItem(
                key: const ValueKey<String>('drawer-profile'),
                icon: Icons.person_outline_rounded,
                label: 'My Profile',
                onTap: () => onActionSelected(SolarDrawerAction.profile),
              ),
              _DrawerItem(
                key: const ValueKey<String>('drawer-settings'),
                icon: Icons.settings_outlined,
                label: 'Settings',
                onTap: () => onActionSelected(SolarDrawerAction.settings),
              ),
              _DrawerItem(
                key: const ValueKey<String>('drawer-calendar'),
                icon: Icons.calendar_month_outlined,
                label: 'Calendar',
                onTap: () => onActionSelected(SolarDrawerAction.calendar),
              ),
              _DrawerItem(
                key: const ValueKey<String>('drawer-sign-out'),
                icon: Icons.logout_rounded,
                label: 'Sign Out',
                onTap: () async {
                  Navigator.of(context).pop();
                  await onSignOut();
                },
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class SolarBottomNavBar extends StatelessWidget {
  const SolarBottomNavBar({
    required this.current,
    required this.onSelected,
    super.key,
  });

  final SolarNavDestination? current;
  final ValueChanged<SolarNavDestination> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.only(bottom: 18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Container(
          height: 74,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(999),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x26000000),
                blurRadius: 30,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                _BottomBarIconButton(
                  key: const ValueKey<String>('nav-home'),
                  icon: Icons.home_outlined,
                  selected: current == SolarNavDestination.home,
                  onTap: () => onSelected(SolarNavDestination.home),
                ),
                _BottomBarIconButton(
                  key: const ValueKey<String>('nav-rankings'),
                  icon: Icons.public_outlined,
                  selected: current == SolarNavDestination.rankings,
                  onTap: () => onSelected(SolarNavDestination.rankings),
                ),
                _BottomBarIconButton(
                  key: const ValueKey<String>('nav-search'),
                  icon: Icons.search_rounded,
                  selected: current == SolarNavDestination.search,
                  onTap: () => onSelected(SolarNavDestination.search),
                ),
                _BottomBarIconButton(
                  key: const ValueKey<String>('nav-calendar'),
                  icon: Icons.calendar_month_outlined,
                  selected: current == SolarNavDestination.calendar,
                  onTap: () => onSelected(SolarNavDestination.calendar),
                ),
                _BottomBarIconButton(
                  key: const ValueKey<String>('nav-profile'),
                  icon: Icons.person_outline_rounded,
                  selected: current == SolarNavDestination.profile,
                  onTap: () => onSelected(SolarNavDestination.profile),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuLine extends StatelessWidget {
  const _MenuLine({required this.width, required this.color});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 3.2,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        minLeadingWidth: 22,
        leading: Icon(icon, color: const Color(0xFF7B7F92), size: 28),
        title: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF16182C),
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

class _BottomBarIconButton extends StatelessWidget {
  const _BottomBarIconButton({
    required this.icon,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Colors.white
        : Colors.white.withValues(alpha: 0.76);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: SizedBox(
        width: 46,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 6),
            Container(
              width: 20,
              height: 3,
              decoration: BoxDecoration(
                color: selected ? const Color(0xFF6B73FF) : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 3),
          ],
        ),
      ),
    );
  }
}
