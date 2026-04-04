import 'package:flutter/material.dart';

import '../../app/solar_app_scope.dart';
import '../../models/robot_events_models.dart';
import '../models/team_stats_snapshot.dart';
import 'event_details_screen.dart';
import '../widgets/solar_event_photo.dart';
import '../widgets/solar_page_scaffold.dart';
import '../widgets/solar_navigation.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  static const routeName = '/calendar';

  @override
  Widget build(BuildContext context) {
    final controller = SolarAppScope.of(context);

    return SolarPageScaffold(
      title: 'Team Calendar',
      currentDestination: SolarNavDestination.calendar,
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final account = controller.currentAccount;
          if (account == null) {
            return const SizedBox.shrink();
          }

          final teamStats =
              controller.teamStats ?? TeamStatsSnapshot(team: account.team);

          return RefreshIndicator(
            color: Colors.black,
            onRefresh: controller.refreshTeamStats,
            child: ListView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              padding: const EdgeInsets.only(bottom: 14),
              children: <Widget>[
                _CalendarSummary(teamStats: teamStats),
                const SizedBox(height: 22),
                _CalendarSection(
                  title: 'Upcoming',
                  emptyLabel: 'No upcoming events for this team right now.',
                  events: teamStats.futureEvents,
                ),
                const SizedBox(height: 22),
                _CalendarSection(
                  title: 'Past',
                  emptyLabel: 'No completed events yet.',
                  events: teamStats.pastEvents,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _CalendarSummary extends StatelessWidget {
  const _CalendarSummary({required this.teamStats});

  final TeamStatsSnapshot teamStats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Row(
        children: <Widget>[
          Expanded(
            child: _CountPill(
              label: 'Upcoming',
              value: '${teamStats.futureEvents.length}',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _CountPill(
              label: 'Past',
              value: '${teamStats.pastEvents.length}',
            ),
          ),
        ],
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
              color: Color(0xFF8E92A7),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF24243A),
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.7,
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarSection extends StatelessWidget {
  const _CalendarSection({
    required this.title,
    required this.emptyLabel,
    required this.events,
  });

  final String title;
  final String emptyLabel;
  final List<EventSummary> events;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF24243A),
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 14),
        if (events.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Text(
              emptyLabel,
              style: const TextStyle(
                color: Color(0xFF8E92A7),
                fontSize: 14,
                height: 1.45,
              ),
            ),
          )
        else
          ...events.map(_CalendarEventTile.new),
      ],
    );
  }
}

class _CalendarEventTile extends StatelessWidget {
  const _CalendarEventTile(this.event);

  final EventSummary event;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(
          context,
        ).pushNamed(EventDetailsScreen.routeName, arguments: event);
      },
      borderRadius: BorderRadius.circular(24),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        height: 184,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 22,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
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
                        Colors.black.withValues(alpha: 0.06),
                        Colors.black.withValues(alpha: 0.08),
                        Colors.black.withValues(alpha: 0.58),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _CalendarDateTile(date: event.start, dark: true),
                    const Spacer(),
                    Text(
                      event.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        height: 1.08,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            _eventLocation(event.location),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _eventSpan(event),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarDateTile extends StatelessWidget {
  const _CalendarDateTile({required this.date, this.dark = false});

  final DateTime? date;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final label = _eventDateTile(date);
    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.92)
            : const Color(0xFFF8F8FD),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: <Widget>[
          Text(
            label.day,
            style: const TextStyle(
              color: Color(0xFF24243A),
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.month,
            style: const TextStyle(
              color: Color(0xFF8E92A7),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

({String day, String month}) _eventDateTile(DateTime? date) {
  if (date == null) {
    return (day: '--', month: 'TBD');
  }

  const months = <String>[
    'JAN',
    'FEB',
    'MAR',
    'APR',
    'MAY',
    'JUN',
    'JUL',
    'AUG',
    'SEP',
    'OCT',
    'NOV',
    'DEC',
  ];
  return (day: '${date.day}', month: months[date.month - 1]);
}

String _eventLocation(LocationSummary location) {
  final parts = <String>[
    if (location.city.isNotEmpty) location.city,
    if (location.region.isNotEmpty) location.region,
  ];
  return parts.isEmpty ? 'Location pending' : parts.join(', ');
}

String _eventSpan(EventSummary event) {
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

  String format(DateTime value) =>
      '${months[value.month - 1]} ${value.day}, ${value.year}';

  if (start != null && end != null && start != end) {
    return '${format(start)} - ${format(end)}';
  }

  return format(start ?? end!);
}
