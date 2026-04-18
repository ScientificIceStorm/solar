import 'package:flutter/material.dart';

import '../models/worlds_schedule_models.dart';
import 'solar_segmented_control.dart';

class WorldsScheduleSection extends StatefulWidget {
  const WorldsScheduleSection({required this.defaultTrack, super.key});

  final WorldsScheduleTrack defaultTrack;

  @override
  State<WorldsScheduleSection> createState() => _WorldsScheduleSectionState();
}

class _WorldsScheduleSectionState extends State<WorldsScheduleSection> {
  late WorldsScheduleTrack _selectedTrack = widget.defaultTrack;
  int _selectedDayIndex = 0;

  void _selectTrack(WorldsScheduleTrack track) {
    if (_selectedTrack == track) {
      return;
    }
    setState(() {
      _selectedTrack = track;
      _selectedDayIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final track = worldsScheduleForTrack(_selectedTrack);
    final selectedDay = track.days[_selectedDayIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Worlds 2026',
          style: TextStyle(
            color: Color(0xFF24243A),
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.7,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${track.title}  •  ${track.dateRangeLabel}',
          style: const TextStyle(
            color: Color(0xFF6E7388),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Verified against the official REC Foundation detailed agenda for St. Louis.',
          style: TextStyle(
            color: Color(0xFF8E92A7),
            fontSize: 14,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 16),
        SolarSegmentedControl<WorldsScheduleTrack>(
          options: worldsScheduleTracks
              .map(
                (entry) => SolarSegmentedControlOption<WorldsScheduleTrack>(
                  value: entry.track,
                  label: entry.shortLabel,
                ),
              )
              .toList(growable: false),
          selectedValue: _selectedTrack,
          onSelected: _selectTrack,
          compact: true,
          backgroundColor: const Color(0xFFF2F3F8),
          selectedColor: const Color(0xFF16182C),
          selectedTextColor: Colors.white,
          unselectedTextColor: const Color(0xFF5F657C),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 86,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: track.days.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final day = track.days[index];
              final selected = index == _selectedDayIndex;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDayIndex = index;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 114,
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFFF5F6FB)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected
                          ? const Color(0xFF16182C)
                          : const Color(0xFFE6E8F2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _weekdayLabel(day.date),
                        style: TextStyle(
                          color: selected
                              ? const Color(0xFF16182C)
                              : const Color(0xFF8E92A7),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${day.date.day}',
                        style: const TextStyle(
                          color: Color(0xFF24243A),
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _monthLabel(day.date),
                        style: const TextStyle(
                          color: Color(0xFF4F546A),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
        Text(
          selectedDay.headline,
          style: const TextStyle(
            color: Color(0xFF24243A),
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          selectedDay.note,
          style: const TextStyle(
            color: Color(0xFF8E92A7),
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < selectedDay.sessions.length; i++)
          _ScheduleSessionRow(
            session: selectedDay.sessions[i],
            showDivider: i != selectedDay.sessions.length - 1,
          ),
      ],
    );
  }
}

class _ScheduleSessionRow extends StatelessWidget {
  const _ScheduleSessionRow({required this.session, required this.showDivider});

  final WorldsScheduleSession session;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final accentColor = _toneAccentColor(session.tone);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: showDivider
          ? const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE9EBF4))),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 4,
            height: 54,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: Text(
              session.timeLabel,
              style: const TextStyle(
                color: Color(0xFF4D546C),
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  session.title,
                  style: const TextStyle(
                    color: Color(0xFF24243A),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  session.location,
                  style: const TextStyle(
                    color: Color(0xFF6E7388),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (session.detail.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    session.detail.trim(),
                    style: const TextStyle(
                      color: Color(0xFF8E92A7),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _weekdayLabel(DateTime date) {
  const weekdays = <String>['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
  return weekdays[date.weekday - 1];
}

String _monthLabel(DateTime date) {
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
  return months[date.month - 1];
}

Color _toneAccentColor(WorldsScheduleSessionTone tone) {
  return switch (tone) {
    WorldsScheduleSessionTone.logistics => const Color(0xFFB6BCCF),
    WorldsScheduleSessionTone.competition => const Color(0xFF1D4ED8),
    WorldsScheduleSessionTone.milestone => const Color(0xFF16182C),
  };
}
