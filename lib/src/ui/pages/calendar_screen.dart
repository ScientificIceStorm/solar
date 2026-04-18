import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_session_controller.dart';
import '../../app/solar_app_scope.dart';
import '../../models/robot_events_models.dart';
import '../models/app_account.dart';
import '../models/team_stats_snapshot.dart';
import '../models/worlds_schedule_models.dart';
import '../widgets/solar_navigation.dart';
import '../widgets/solar_page_scaffold.dart';
import '../widgets/worlds_schedule_section.dart';
import 'event_details_screen.dart';

enum _CalendarView { team, worlds }

enum _TeamCalendarPresentation { list, calendar }

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  static const routeName = '/calendar';

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  AppSessionController? _sessionController;
  _CalendarView _selectedView = _CalendarView.team;
  _TeamCalendarPresentation _teamPresentation = _TeamCalendarPresentation.list;
  DateTime _focusedMonth = _monthStart(DateTime.now());
  DateTime _selectedDay = _dateOnly(DateTime.now())!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = SolarAppScope.of(context);
    if (!identical(_sessionController, controller)) {
      _sessionController = controller;
      unawaited(controller.preloadSearchEvents());
    }
  }

  void _setDisplayedMonth(DateTime month) {
    setState(() {
      _focusedMonth = _monthStart(month);
    });
  }

  void _selectDay(DateTime day) {
    setState(() {
      _selectedDay = _dateOnly(day)!;
      _focusedMonth = _monthStart(day);
    });
  }

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
          final teamEvents = _teamCalendarEvents(teamStats);
          final mergedEvents = _mergeCalendarEvents(
            teamEvents: teamEvents,
            allEvents: controller.preloadedSearchEvents,
          );

          return RefreshIndicator(
            color: Colors.white,
            onRefresh: () async {
              await controller.refreshTeamStats();
              await controller.preloadSearchEvents(force: true);
            },
            child: StretchingOverscrollIndicator(
              axisDirection: AxisDirection.down,
              child: ListView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                padding: const EdgeInsets.only(bottom: 28),
                children: <Widget>[
                  _CalendarViewBar(
                    selectedView: _selectedView,
                    onSelected: (view) {
                      setState(() {
                        _selectedView = view;
                      });
                    },
                  ),
                  const SizedBox(height: 22),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _selectedView == _CalendarView.team
                        ? _TeamCalendarBody(
                            key: const ValueKey<String>('team-calendar'),
                            teamStats: teamStats,
                            teamPresentation: _teamPresentation,
                            onPresentationChanged: (presentation) {
                              setState(() {
                                _teamPresentation = presentation;
                              });
                            },
                            focusedMonth: _focusedMonth,
                            selectedDay: _selectedDay,
                            mergedEvents: mergedEvents,
                            isLoadingAllEvents:
                                controller.isPreloadingSearchEvents &&
                                controller.preloadedSearchEvents.isEmpty,
                            onDisplayedMonthChanged: _setDisplayedMonth,
                            onDaySelected: _selectDay,
                          )
                        : _WorldsCalendarBody(
                            key: const ValueKey<String>('worlds-calendar'),
                            defaultTrack: _defaultWorldsTrack(
                              controller.competitionPreference,
                              teamStats.team.grade,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CalendarViewBar extends StatelessWidget {
  const _CalendarViewBar({
    required this.selectedView,
    required this.onSelected,
  });

  final _CalendarView selectedView;
  final ValueChanged<_CalendarView> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F2F6),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: _CalendarView.values
            .map((view) {
              final selected = view == selectedView;
              final label = view == _CalendarView.team ? 'Team' : 'Worlds 2026';
              return Expanded(
                child: GestureDetector(
                  onTap: () => onSelected(view),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: selected ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: selected
                          ? const <BoxShadow>[
                              BoxShadow(
                                color: Color(0x0E000000),
                                blurRadius: 16,
                                offset: Offset(0, 8),
                              ),
                            ]
                          : const <BoxShadow>[],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      label,
                      style: TextStyle(
                        color: selected
                            ? const Color(0xFF24243A)
                            : const Color(0xFF7A7F92),
                        fontSize: 14,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            })
            .toList(growable: false),
      ),
    );
  }
}

class _TeamCalendarBody extends StatelessWidget {
  const _TeamCalendarBody({
    required this.teamStats,
    required this.teamPresentation,
    required this.onPresentationChanged,
    required this.focusedMonth,
    required this.selectedDay,
    required this.mergedEvents,
    required this.isLoadingAllEvents,
    required this.onDisplayedMonthChanged,
    required this.onDaySelected,
    super.key,
  });

  final TeamStatsSnapshot teamStats;
  final _TeamCalendarPresentation teamPresentation;
  final ValueChanged<_TeamCalendarPresentation> onPresentationChanged;
  final DateTime focusedMonth;
  final DateTime selectedDay;
  final List<_CalendarEventItem> mergedEvents;
  final bool isLoadingAllEvents;
  final ValueChanged<DateTime> onDisplayedMonthChanged;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _TeamPresentationBar(
          selectedPresentation: teamPresentation,
          onSelected: onPresentationChanged,
        ),
        const SizedBox(height: 18),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: teamPresentation == _TeamCalendarPresentation.list
              ? _TeamCalendarListBody(
                  key: const ValueKey<String>('team-calendar-list'),
                  teamStats: teamStats,
                )
              : _TeamCalendarMonthBody(
                  key: const ValueKey<String>('team-calendar-month'),
                  focusedMonth: focusedMonth,
                  selectedDay: selectedDay,
                  mergedEvents: mergedEvents,
                  isLoadingAllEvents: isLoadingAllEvents,
                  onDisplayedMonthChanged: onDisplayedMonthChanged,
                  onDaySelected: onDaySelected,
                ),
        ),
      ],
    );
  }
}

class _TeamPresentationBar extends StatelessWidget {
  const _TeamPresentationBar({
    required this.selectedPresentation,
    required this.onSelected,
  });

  final _TeamCalendarPresentation selectedPresentation;
  final ValueChanged<_TeamCalendarPresentation> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE3E6F0)),
      ),
      child: Row(
        children: _TeamCalendarPresentation.values.map((presentation) {
          final selected = presentation == selectedPresentation;
          final label = presentation == _TeamCalendarPresentation.list
              ? 'List'
              : 'Calendar';
          return Expanded(
            child: InkWell(
              onTap: () => onSelected(presentation),
              borderRadius: BorderRadius.circular(11),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF16182C) : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.white : const Color(0xFF5F6478),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        }).toList(growable: false),
      ),
    );
  }
}

class _TeamCalendarListBody extends StatelessWidget {
  const _TeamCalendarListBody({required this.teamStats, super.key});

  final TeamStatsSnapshot teamStats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _CalendarSection(
          title: 'Upcoming',
          emptyLabel: 'No upcoming events for this team right now.',
          events: teamStats.futureEvents,
        ),
        const SizedBox(height: 24),
        _CalendarSection(
          title: 'Past',
          emptyLabel: 'No completed events yet.',
          events: teamStats.pastEvents,
        ),
      ],
    );
  }
}

class _TeamCalendarMonthBody extends StatelessWidget {
  const _TeamCalendarMonthBody({
    required this.focusedMonth,
    required this.selectedDay,
    required this.mergedEvents,
    required this.isLoadingAllEvents,
    required this.onDisplayedMonthChanged,
    required this.onDaySelected,
    super.key,
  });

  final DateTime focusedMonth;
  final DateTime selectedDay;
  final List<_CalendarEventItem> mergedEvents;
  final bool isLoadingAllEvents;
  final ValueChanged<DateTime> onDisplayedMonthChanged;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final monthBuckets = _bucketEventsByDay(mergedEvents, focusedMonth);
    final selectedEvents =
        monthBuckets[_dayKey(selectedDay)] ?? const <_CalendarEventItem>[];
    final monthEventIds = <int>{
      for (final events in monthBuckets.values)
        for (final event in events) event.event.id,
    };
    final monthTeamEventIds = <int>{
      for (final events in monthBuckets.values)
        for (final event in events)
          if (event.isTeamEvent) event.event.id,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '${monthTeamEventIds.length} team events • ${monthEventIds.length} VEX events',
                style: const TextStyle(
                  color: Color(0xFF7C8093),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (isLoadingAllEvents)
              const Text(
                'Loading season events...',
                style: TextStyle(
                  color: Color(0xFF8E92A7),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFFE3E6F0)),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: const Color(0xFF1D4ED8),
                onPrimary: Colors.white,
                onSurface: const Color(0xFF24243A),
              ),
            ),
            child: CalendarDatePicker(
              key: const ValueKey<String>('team-calendar-date-picker'),
              initialDate: selectedDay,
              firstDate: DateTime(2000, 1, 1),
              lastDate: DateTime(2100, 12, 31),
              currentDate: DateTime.now(),
              onDateChanged: onDaySelected,
              onDisplayedMonthChanged: onDisplayedMonthChanged,
            ),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                _selectedDayLabel(selectedDay),
                style: const TextStyle(
                  color: Color(0xFF24243A),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (selectedEvents.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE3E6F0)),
            ),
            child: const Text(
              'No events scheduled on this day.',
              style: TextStyle(
                color: Color(0xFF8E92A7),
                fontSize: 14,
                height: 1.45,
              ),
            ),
          )
        else
          ...selectedEvents.map(_CalendarAgendaRow.new),
      ],
    );
  }
}

class _CalendarAgendaRow extends StatelessWidget {
  const _CalendarAgendaRow(this.item);

  final _CalendarEventItem item;

  @override
  Widget build(BuildContext context) {
    final event = item.event;
    return InkWell(
      onTap: () {
        Navigator.of(
          context,
        ).pushNamed(EventDetailsScreen.routeName, arguments: event);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 12),
        decoration: BoxDecoration(
          border: const Border(bottom: BorderSide(color: Color(0xFFDADAE3))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 7,
              height: 46,
              decoration: BoxDecoration(
                color: item.isTeamEvent
                    ? const Color(0xFF2A5FFF)
                    : const Color(0xFF9BA1B5),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    event.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF24243A),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _eventLocation(event.location),
                    style: const TextStyle(
                      color: Color(0xFF6E7388),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _eventSpan(event),
                    style: const TextStyle(
                      color: Color(0xFF8E92A7),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: item.isTeamEvent
                        ? const Color(0xFFE8F0FF)
                        : const Color(0xFFF1F2F6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    item.isTeamEvent ? 'TEAM' : 'VEX',
                    style: TextStyle(
                      color: item.isTeamEvent
                          ? const Color(0xFF2A5FFF)
                          : const Color(0xFF697087),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Color(0xFF8E92A7),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WorldsCalendarBody extends StatelessWidget {
  const _WorldsCalendarBody({required this.defaultTrack, super.key});

  final WorldsScheduleTrack defaultTrack;

  @override
  Widget build(BuildContext context) {
    return WorldsScheduleSection(defaultTrack: defaultTrack);
  }
}

WorldsScheduleTrack _defaultWorldsTrack(
  AppCompetitionPreference preference,
  String grade,
) {
  switch (preference) {
    case AppCompetitionPreference.vexIQ:
      return WorldsScheduleTrack.viqrc;
    case AppCompetitionPreference.vexU:
      return WorldsScheduleTrack.v5rcMiddleSchoolAndVurc;
    case AppCompetitionPreference.vexAI:
    case AppCompetitionPreference.vexV5:
      final normalized = grade.trim().toLowerCase();
      if (normalized.contains('middle')) {
        return WorldsScheduleTrack.v5rcMiddleSchoolAndVurc;
      }
      return WorldsScheduleTrack.v5rcHighSchool;
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
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
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
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 14),
        decoration: BoxDecoration(
          border: const Border(bottom: BorderSide(color: Color(0xFFDADAE3))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _CalendarDateChip(date: event.start, compact: true),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    event.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF24243A),
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _eventLocation(event.location),
                    style: const TextStyle(
                      color: Color(0xFF6E7388),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _eventSpan(event),
                    style: const TextStyle(
                      color: Color(0xFF8E92A7),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Color(0xFF8E92A7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarDateChip extends StatelessWidget {
  const _CalendarDateChip({required this.date, this.compact = false});

  final DateTime? date;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final label = _eventDateTile(date);
    return Container(
      width: compact ? 58 : 66,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FB),
        borderRadius: BorderRadius.circular(compact ? 14 : 16),
      ),
      child: Column(
        children: <Widget>[
          Text(
            label.day,
            style: TextStyle(
              color: Color(0xFF24243A),
              fontSize: compact ? 18 : 22,
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
              fontWeight: FontWeight.w700,
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
  final start = event.start?.toLocal();
  final end = event.end?.toLocal();
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

class _CalendarEventItem {
  const _CalendarEventItem({required this.event, required this.isTeamEvent});

  final EventSummary event;
  final bool isTeamEvent;
}

List<EventSummary> _teamCalendarEvents(TeamStatsSnapshot teamStats) {
  final source = teamStats.allEvents.isNotEmpty
      ? teamStats.allEvents
      : <EventSummary>[...teamStats.futureEvents, ...teamStats.pastEvents];
  final deduped = <int, EventSummary>{};
  for (final event in source) {
    if (_isLeagueEvent(event)) {
      continue;
    }
    deduped[event.id] = event;
  }
  return deduped.values.toList(growable: false)..sort((a, b) {
    final aStart = a.start ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bStart = b.start ?? DateTime.fromMillisecondsSinceEpoch(0);
    return aStart.compareTo(bStart);
  });
}

List<_CalendarEventItem> _mergeCalendarEvents({
  required List<EventSummary> teamEvents,
  required List<EventSummary> allEvents,
}) {
  final teamIds = <int>{for (final event in teamEvents) event.id};
  final merged = <int, _CalendarEventItem>{
    for (final event in allEvents)
      if (!_isLeagueEvent(event))
        event.id: _CalendarEventItem(
          event: event,
          isTeamEvent: teamIds.contains(event.id),
        ),
  };
  for (final event in teamEvents) {
    if (_isLeagueEvent(event)) {
      continue;
    }
    merged[event.id] = _CalendarEventItem(event: event, isTeamEvent: true);
  }
  return merged.values.toList(growable: false)..sort((a, b) {
    if (a.isTeamEvent != b.isTeamEvent) {
      return a.isTeamEvent ? -1 : 1;
    }
    final aStart = a.event.start ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bStart = b.event.start ?? DateTime.fromMillisecondsSinceEpoch(0);
    final dateCompare = aStart.compareTo(bStart);
    if (dateCompare != 0) {
      return dateCompare;
    }
    return a.event.name.compareTo(b.event.name);
  });
}

bool _isLeagueEvent(EventSummary event) {
  return event.name.trim().toLowerCase().contains('league');
}

Map<int, List<_CalendarEventItem>> _bucketEventsByDay(
  List<_CalendarEventItem> events,
  DateTime month,
) {
  final monthStart = _monthStart(month);
  final monthEnd = DateTime(month.year, month.month + 1, 0);
  final buckets = <int, List<_CalendarEventItem>>{};

  for (final item in events) {
    final start = _dateOnly(item.event.start ?? item.event.end);
    final end = _dateOnly(item.event.end ?? item.event.start);
    if (start == null || end == null) {
      continue;
    }

    var cursor = start.isBefore(monthStart) ? monthStart : start;
    final last = end.isAfter(monthEnd) ? monthEnd : end;
    while (!cursor.isAfter(last)) {
      final key = _dayKey(cursor);
      final bucket = buckets.putIfAbsent(key, () => <_CalendarEventItem>[]);
      bucket.add(item);
      cursor = cursor.add(const Duration(days: 1));
    }
  }

  for (final bucket in buckets.values) {
    bucket.sort((a, b) {
      if (a.isTeamEvent != b.isTeamEvent) {
        return a.isTeamEvent ? -1 : 1;
      }
      final aStart = a.event.start ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bStart = b.event.start ?? DateTime.fromMillisecondsSinceEpoch(0);
      final dateCompare = aStart.compareTo(bStart);
      if (dateCompare != 0) {
        return dateCompare;
      }
      return a.event.name.compareTo(b.event.name);
    });
  }

  return buckets;
}

DateTime _monthStart(DateTime value) {
  return DateTime(value.year, value.month);
}

DateTime? _dateOnly(DateTime? value) {
  if (value == null) {
    return null;
  }
  return DateTime(value.year, value.month, value.day);
}

int _dayKey(DateTime day) {
  return (day.year * 10000) + (day.month * 100) + day.day;
}

String _selectedDayLabel(DateTime day) {
  const weekdays = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
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
  return '${weekdays[day.weekday - 1]}, ${months[day.month - 1]} ${day.day}';
}
