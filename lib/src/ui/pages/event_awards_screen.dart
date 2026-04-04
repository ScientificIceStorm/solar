import 'package:flutter/material.dart';

import '../../app/solar_app_scope.dart';
import '../../models/robot_events_models.dart';
import '../widgets/solar_event_subpage_scaffold.dart';

class EventAwardsScreen extends StatelessWidget {
  const EventAwardsScreen({required this.event, super.key});

  static const routeName = '/event-awards';

  final EventSummary event;

  @override
  Widget build(BuildContext context) {
    final controller = SolarAppScope.of(context);

    return SolarEventSubpageScaffold(
      title: 'Awards',
      subtitle: event.name,
      body: FutureBuilder<List<AwardSummary>>(
        future: controller.fetchEventAwards(event.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const _CenteredLoader();
          }

          final awards = snapshot.data!;
          if (awards.isEmpty) {
            return const _EmptyEventState(
              title: 'No awards published yet',
              body:
                  'When RobotEvents posts the award results, they will appear here.',
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 8),
            itemCount: awards.length,
            itemBuilder: (context, index) => _AwardRow(
              award: awards[index],
              showDivider: index != awards.length - 1,
            ),
          );
        },
      ),
    );
  }
}

class _AwardRow extends StatelessWidget {
  const _AwardRow({required this.award, required this.showDivider});

  final AwardSummary award;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            award.title.isEmpty ? 'Award' : award.title,
            style: const TextStyle(
              color: Color(0xFF24243A),
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          ...award.recipients
              .take(4)
              .map(
                (recipient) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    recipient,
                    style: const TextStyle(
                      color: Color(0xFF5A67F3),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          if (award.qualifications.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              award.qualifications.join(' • '),
              style: const TextStyle(
                color: Color(0xFF7C7F94),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (showDivider) ...<Widget>[
            const SizedBox(height: 14),
            Container(height: 1, color: const Color(0xFFDADAE3)),
          ],
        ],
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
