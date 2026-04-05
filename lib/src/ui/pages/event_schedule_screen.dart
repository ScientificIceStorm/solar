import 'package:flutter/material.dart';

import '../../app/solar_app_scope.dart';
import '../../models/robot_events_models.dart';
import 'match_details_screen.dart';
import '../widgets/solar_event_subpage_scaffold.dart';
import '../widgets/solar_match_row.dart';

class EventScheduleScreen extends StatelessWidget {
  const EventScheduleScreen({required this.event, super.key});

  static const routeName = '/event-schedule';

  final EventSummary event;

  @override
  Widget build(BuildContext context) {
    final controller = SolarAppScope.of(context);
    final teamNumber = controller.currentAccount?.team.number ?? 'Team';

    return SolarEventSubpageScaffold(
      title: '$teamNumber Schedule',
      subtitle: event.name,
      body: FutureBuilder<List<MatchSummary>>(
        future: controller.fetchTeamScheduleForEvent(event.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const _CenteredLoader();
          }

          final matches = snapshot.data!;
          if (matches.isEmpty) {
            return const _EmptyEventState(
              title: 'No scheduled matches yet',
              body:
                  'When RobotEvents publishes this team schedule, it will show up here.',
            );
          }

          return StretchingOverscrollIndicator(
            axisDirection: AxisDirection.down,
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: matches.length,
              itemBuilder: (context, index) => SolarMatchRow(
                match: matches[index],
                highlightTeamNumber: teamNumber,
                onTap: () {
                  Navigator.of(context).pushNamed(
                    MatchDetailsScreen.routeName,
                    arguments: MatchDetailsScreenArgs(
                      match: matches[index],
                      event: event,
                      highlightTeamNumber: teamNumber,
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
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
