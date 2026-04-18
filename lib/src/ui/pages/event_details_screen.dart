import 'package:flutter/material.dart';

import '../../app/solar_app_scope.dart';
import '../../models/robot_events_models.dart';
import 'event_awards_screen.dart';
import 'event_division_screen.dart';
import 'event_schedule_screen.dart';
import 'event_skills_screen.dart';
import '../widgets/solar_event_photo.dart';
import '../widgets/solarize_team_list.dart';

class EventDetailsScreen extends StatefulWidget {
  const EventDetailsScreen({required this.event, super.key});

  static const routeName = '/event-details';

  final EventSummary event;

  @override
  State<EventDetailsScreen> createState() => _EventDetailsScreenState();
}

class _EventDetailsScreenState extends State<EventDetailsScreen> {
  Future<int?>? _teamCountFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _teamCountFuture ??= SolarAppScope.of(
      context,
    ).fetchEventTeamCount(widget.event.id);
  }

  @override
  Widget build(BuildContext context) {
    final controller = SolarAppScope.of(context);
    final teamNumber = controller.currentAccount?.team.number ?? 'Your team';
    final event = widget.event;
    final isBookmarked = controller.isBookmarkedEvent(event.id);
    final isCurrentTeamEvent = controller.isCurrentTeamEvent(event.id);
    final currentTeamDivision = controller.currentTeamDivisionForEvent(
      event.id,
    );
    final divisionsButtonLabel =
        isCurrentTeamEvent && currentTeamDivision != null
        ? 'View other divisions'
        : 'View divisions';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5F8),
      body: StretchingOverscrollIndicator(
        axisDirection: AxisDirection.down,
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
              Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  SizedBox(
                    height: 470,
                    child: SolarEventPhoto(
                      location: event.location,
                      overlay: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              Colors.black.withValues(alpha: 0.22),
                              Colors.black.withValues(alpha: 0.08),
                              Colors.black.withValues(alpha: 0.28),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                      child: Column(
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              _TopOverlayButton(
                                icon: Icons.arrow_back_ios_new_rounded,
                                onTap: () => Navigator.of(context).pop(),
                              ),
                              const SizedBox(width: 18),
                              const Expanded(
                                child: Text(
                                  'Event Details',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 30,
                                    fontWeight: FontWeight.w300,
                                    letterSpacing: -0.9,
                                  ),
                                ),
                              ),
                              _TopOverlayButton(
                                icon: isBookmarked
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_border_rounded,
                                onTap: () async {
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  await controller.toggleBookmarkedEvent(event);
                                  if (!mounted) {
                                    return;
                                  }
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        isBookmarked
                                            ? 'Removed from saved events.'
                                            : 'Saved event for later.',
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 28,
                    right: 28,
                    bottom: -44,
                    child: FutureBuilder<int?>(
                      future: _teamCountFuture,
                      builder: (context, snapshot) {
                        return _EventHeroMetaCard(
                          date: event.start,
                          locationLabel: _eventLocationLabel(event.location),
                          teamCount: snapshot.data,
                          divisionCount: event.divisions.length,
                        );
                      },
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 74, 28, 34),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _displayEventName(event.name),
                      style: const TextStyle(
                        color: Color(0xFF1A1B33),
                        fontSize: 42,
                        fontWeight: FontWeight.w300,
                        height: 1.05,
                        letterSpacing: -1.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _InfoLine(
                      icon: Icons.calendar_month_rounded,
                      label: _eventDateRangeLabel(
                        start: event.start,
                        end: event.end,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _InfoLine(
                      icon: Icons.location_on_rounded,
                      label: _eventLocationLabel(event.location),
                    ),
                    const SizedBox(height: 30),
                    if (isCurrentTeamEvent) ...<Widget>[
                      _EventActionButton(
                        label: 'View $teamNumber schedule',
                        color: const Color(0xFF5A67F3),
                        onTap: () {
                          Navigator.of(context).pushNamed(
                            EventScheduleScreen.routeName,
                            arguments: event,
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                    ],
                    if (currentTeamDivision != null) ...<Widget>[
                      _EventActionButton(
                        label: 'View your division',
                        color: const Color(0xFF111111),
                        onTap: () {
                          Navigator.of(context).pushNamed(
                            EventDivisionScreen.routeName,
                            arguments: EventDivisionScreenArgs(
                              event: event,
                              division: currentTeamDivision,
                              highlightTeamNumber:
                                  controller.currentAccount?.team.number,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 18),
                    ],
                    _EventActionButton(
                      label: divisionsButtonLabel,
                      color: const Color(0xFF111111),
                      onTap: () => _showDivisionPicker(context, event),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _SmallEventActionButton(
                            label: 'View skills',
                            onTap: () {
                              Navigator.of(context).pushNamed(
                                EventSkillsScreen.routeName,
                                arguments: event,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 18),
                        Expanded(
                          child: _SmallEventActionButton(
                            label: 'View awards',
                            onTap: () {
                              Navigator.of(context).pushNamed(
                                EventAwardsScreen.routeName,
                                arguments: event,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _SmallEventActionButton(
                      label: 'View Solarize team list',
                      onTap: () => _showSolarizeTeams(context, event),
                    ),
                  ],
                ),
              ),
            ],
        ),
      ),
    );
  }

  Future<void> _showDivisionPicker(BuildContext context, EventSummary event) {
    final controller = SolarAppScope.of(context);
    final highlightTeamNumber = controller.currentAccount?.team.number;

    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.82,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFFF7F5F8),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD5D4DD),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Divisions',
                    style: TextStyle(
                      color: Color(0xFF24243A),
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: event.divisions.length,
                      itemBuilder: (context, index) {
                        final division = event.divisions[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: InkWell(
                            onTap: () {
                              Navigator.of(context).pop();
                              Navigator.of(context).pushNamed(
                                EventDivisionScreen.routeName,
                                arguments: EventDivisionScreenArgs(
                                  event: event,
                                  division: division,
                                  highlightTeamNumber: highlightTeamNumber,
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.96),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      division.name,
                                      style: const TextStyle(
                                        color: Color(0xFF24243A),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    size: 16,
                                    color: Color(0xFF7C7F94),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showSolarizeTeams(BuildContext context, EventSummary event) {
    final controller = SolarAppScope.of(context);
    final highlightTeamNumber = controller.currentAccount?.team.number;
    final searchController = TextEditingController();

    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.sizeOf(context).height * 0.82,
              decoration: const BoxDecoration(
                color: Color(0xFFF7F5F8),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 14, 22, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Center(
                        child: Container(
                          width: 48,
                          height: 5,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD5D4DD),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Solarize Teams',
                        style: TextStyle(
                          color: Color(0xFF24243A),
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        event.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF8E92A7),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.96),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: TextField(
                          controller: searchController,
                          onChanged: (_) => setModalState(() {}),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Search Solarize teams',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: searchController.text.trim().isEmpty
                                ? null
                                : IconButton(
                                    onPressed: () {
                                      searchController.clear();
                                      setModalState(() {});
                                    },
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: FutureBuilder<List<TeamSummary>>(
                          future: controller.fetchEventTeams(event.id),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(
                                child: SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                  ),
                                ),
                              );
                            }

                            final query = searchController.text
                                .trim()
                                .toLowerCase();
                            final filteredTeams = snapshot.data!
                                .where((team) {
                                  if (query.isEmpty) {
                                    return true;
                                  }
                                  return team.number.toLowerCase().contains(
                                        query,
                                      ) ||
                                      team.teamName.toLowerCase().contains(
                                        query,
                                      ) ||
                                      team.organization.toLowerCase().contains(
                                        query,
                                      );
                                })
                                .toList(growable: false);

                            return SolarizeTeamList(
                              controller: controller,
                              teams: filteredTeams,
                              highlightTeamNumber: highlightTeamNumber,
                              emptyLabel: query.isEmpty
                                  ? 'No event teams available yet.'
                                  : 'No Solarize teams matched your search.',
                              event: event,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(searchController.dispose);
  }
}

class _TopOverlayButton extends StatelessWidget {
  const _TopOverlayButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: 58,
        height: 58,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}

class _EventHeroMetaCard extends StatelessWidget {
  const _EventHeroMetaCard({
    required this.date,
    required this.locationLabel,
    required this.teamCount,
    required this.divisionCount,
  });

  final DateTime? date;
  final String locationLabel;
  final int? teamCount;
  final int divisionCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _MetaPill(
              icon: Icons.calendar_month_rounded,
              title: _eventDateLabel(date),
              subtitle: teamCount == null
                  ? 'Teams loading'
                  : '$teamCount teams',
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _MetaPill(
              icon: Icons.location_on_rounded,
              title: locationLabel,
              subtitle: '$divisionCount divisions',
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: const Color(0xFFECEEFF),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, color: const Color(0xFF5A67F3), size: 30),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                maxLines: 2,
                style: const TextStyle(
                  color: Color(0xFF272844),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Color(0xFF8E92A7),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EventActionButton extends StatelessWidget {
  const _EventActionButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: color.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.1,
                ),
              ),
            ),
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withValues(
                  alpha: color == Color(0xFF111111) ? 1 : 0.14,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_forward_rounded,
                color: color == const Color(0xFF111111)
                    ? Colors.black
                    : Colors.white,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallEventActionButton extends StatelessWidget {
  const _SmallEventActionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Center(
          child: Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
  }
}

String _eventDateLabel(DateTime? date) {
  if (date == null) {
    return 'Date pending';
  }

  const months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}

String _eventDateRangeLabel({DateTime? start, DateTime? end}) {
  if (start == null && end == null) {
    return 'Date pending';
  }
  if (start != null && end != null) {
    final sameDay =
        start.year == end.year &&
        start.month == end.month &&
        start.day == end.day;
    if (sameDay) {
      return _eventDateLabel(start);
    }
    return '${_eventDateLabel(start)} to ${_eventDateLabel(end)}';
  }
  return _eventDateLabel(start ?? end);
}

String _eventLocationLabel(LocationSummary location) {
  final parts = <String>[
    if (location.venue.isNotEmpty) location.venue,
    if (location.city.isNotEmpty) location.city,
    if (location.region.isNotEmpty) location.region,
    if (location.country.isNotEmpty) location.country,
  ];
  return parts.isEmpty ? 'Location pending' : parts.join(', ');
}

String _displayEventName(String value) {
  return value
      .replaceAll('VEX V5 Robotics Competition High School', 'High School')
      .replaceAll('VEX V5 Robotics Competition Middle School', 'Middle School');
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 18, color: const Color(0xFF5A67F3)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF6B6F84),
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
