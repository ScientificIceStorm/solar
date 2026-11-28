import 'package:flutter/material.dart';
import '../../app/app_session_controller.dart';
import '../../models/robot_events_models.dart';
import '../pages/event_team_screen.dart';
import 'solar_team_link.dart';

/// An event roster. Rendering a roster never fetches per-team histories.
class SolarEventTeamList extends StatelessWidget {
  const SolarEventTeamList({
    required this.controller,
    required this.teams,
    super.key,
    this.highlightTeamNumber,
    this.emptyLabel = 'No teams available.',
    this.padding = const EdgeInsets.only(bottom: 8),
    this.event,
  });

  final AppSessionController controller;
  final List<TeamSummary> teams;
  final String? highlightTeamNumber;
  final String emptyLabel;
  final EdgeInsets padding;
  final EventSummary? event;

  @override
  Widget build(BuildContext context) {
    if (teams.isEmpty) return Center(child: Text(emptyLabel));
    final ordered = [...teams]..sort((a, b) => a.number.compareTo(b.number));
    return ListView.separated(
      padding: padding,
      itemCount: ordered.length,
      separatorBuilder: (_, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final team = ordered[index];
        final highlighted =
            team.number.toUpperCase() == highlightTeamNumber?.toUpperCase();
        final tile = ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
          title: Text(
            team.number,
            style: TextStyle(
              fontSize: 22,
              color: highlighted
                  ? const Color(0xFF2930FF)
                  : const Color(0xFF16182C),
              fontWeight: highlighted ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
          subtitle: Text(
            team.teamName.isEmpty ? team.organization : team.teamName,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: event == null
              ? () => openSolarTeamProfileForSummary(context, team)
              : () => openSolarEventTeamScreen(
                  context,
                  event: event!,
                  team: team,
                  highlightTeamNumber: highlightTeamNumber,
                ),
        );
        return tile;
      },
    );
  }
}
