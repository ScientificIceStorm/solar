enum WorldsScheduleTrack { v5rcHighSchool, v5rcMiddleSchoolAndVurc, viqrc }

enum WorldsScheduleSessionTone { logistics, competition, milestone }

class WorldsScheduleTrackData {
  const WorldsScheduleTrackData({
    required this.track,
    required this.title,
    required this.shortLabel,
    required this.subtitle,
    required this.dateRangeLabel,
    required this.days,
  });

  final WorldsScheduleTrack track;
  final String title;
  final String shortLabel;
  final String subtitle;
  final String dateRangeLabel;
  final List<WorldsScheduleDay> days;
}

class WorldsScheduleDay {
  const WorldsScheduleDay({
    required this.date,
    required this.headline,
    required this.note,
    required this.sessions,
  });

  final DateTime date;
  final String headline;
  final String note;
  final List<WorldsScheduleSession> sessions;
}

class WorldsScheduleSession {
  const WorldsScheduleSession({
    required this.timeLabel,
    required this.title,
    required this.location,
    required this.tone,
    this.detail = '',
  });

  final String timeLabel;
  final String title;
  final String location;
  final WorldsScheduleSessionTone tone;
  final String detail;
}

const worldsScheduleAnnouncementId = 'worlds-2026-official-agenda-v1';

final worldsScheduleTracks = <WorldsScheduleTrackData>[
  WorldsScheduleTrackData(
    track: WorldsScheduleTrack.v5rcHighSchool,
    title: 'V5RC High School',
    shortLabel: 'HS',
    subtitle: 'St. Louis Convention Center and Dome',
    dateRangeLabel: 'April 21-24, 2026',
    days: <WorldsScheduleDay>[
      WorldsScheduleDay(
        date: DateTime(2026, 4, 21),
        headline: 'Check-in and opening day',
        note:
            'Official RECF agenda: inspection closes at 11:00 AM CT, then HS opens with ceremonies, practice, and the first qualification block.',
        sessions: <WorldsScheduleSession>[
          WorldsScheduleSession(
            timeLabel: '7:45 AM',
            title: 'Venue opens',
            location: 'Halls 1-5',
            tone: WorldsScheduleSessionTone.logistics,
          ),
          WorldsScheduleSession(
            timeLabel: '8:00 AM - 11:00 AM',
            title: 'Inspection in divisions',
            location: 'Halls 1-5',
            tone: WorldsScheduleSessionTone.logistics,
            detail: 'Teams must be inspected by 11:00 AM CT.',
          ),
          WorldsScheduleSession(
            timeLabel: '8:00 AM - 12:00 PM',
            title: 'Skills Challenge',
            location: 'Rooms 100-106',
            tone: WorldsScheduleSessionTone.competition,
          ),
          WorldsScheduleSession(
            timeLabel: '8:00 AM - 12:30 PM',
            title: 'Practice fields open',
            location: 'Rooms 120-127, 130-132',
            tone: WorldsScheduleSessionTone.logistics,
          ),
          WorldsScheduleSession(
            timeLabel: '12:00 PM - 1:00 PM',
            title: 'Lunch break',
            location: 'All locations',
            tone: WorldsScheduleSessionTone.logistics,
          ),
          WorldsScheduleSession(
            timeLabel: '1:00 PM - 2:00 PM',
            title: 'Opening Ceremonies',
            location: 'Dome',
            tone: WorldsScheduleSessionTone.milestone,
          ),
          WorldsScheduleSession(
            timeLabel: '2:30 PM - 5:45 PM',
            title: 'Skills Challenge',
            location: 'Rooms 100-106',
            tone: WorldsScheduleSessionTone.competition,
          ),
          WorldsScheduleSession(
            timeLabel: '2:30 PM - 5:45 PM',
            title: 'Practice fields open',
            location: 'Rooms 120-127, 130-132',
            tone: WorldsScheduleSessionTone.logistics,
          ),
          WorldsScheduleSession(
            timeLabel: '3:00 PM - 4:30 PM',
            title: 'Practice matches',
            location: 'Halls 1-5',
            tone: WorldsScheduleSessionTone.competition,
          ),
          WorldsScheduleSession(
            timeLabel: '4:30 PM - 6:00 PM',
            title: 'Qualification matches',
            location: 'Halls 1-5',
            tone: WorldsScheduleSessionTone.competition,
          ),
          WorldsScheduleSession(
            timeLabel: '6:15 PM',
            title: 'Venue closes',
            location: 'All locations',
            tone: WorldsScheduleSessionTone.logistics,
          ),
        ],
      ),
      WorldsScheduleDay(
        date: DateTime(2026, 4, 22),
        headline: 'Full qualification day',
        note:
            'Morning and afternoon skills windows run in parallel with HS qualification matches.',
        sessions: <WorldsScheduleSession>[
          WorldsScheduleSession(
            timeLabel: '7:45 AM',
            title: 'Venue opens',
            location: 'Halls 1-5',
            tone: WorldsScheduleSessionTone.logistics,
          ),
          WorldsScheduleSession(
            timeLabel: '8:00 AM - 12:00 PM',
            title: 'Practice fields open',
            location: 'Rooms 120-127, 130-132',
            tone: WorldsScheduleSessionTone.logistics,
          ),
          WorldsScheduleSession(
            timeLabel: '8:00 AM - 12:00 PM',
            title: 'Skills Challenge',
            location: 'Rooms 100-106',
            tone: WorldsScheduleSessionTone.competition,
          ),
          WorldsScheduleSession(
            timeLabel: '8:30 AM - 11:45 AM',
            title: 'Qualification matches',
            location: 'Halls 1-5',
            tone: WorldsScheduleSessionTone.competition,
          ),
          WorldsScheduleSession(
            timeLabel: '12:00 PM - 1:00 PM',
            title: 'Lunch break',
            location: 'All locations',
            tone: WorldsScheduleSessionTone.logistics,
          ),
          WorldsScheduleSession(
            timeLabel: '1:00 PM - 4:15 PM',
            title: 'Practice fields open',
            location: 'Rooms 120-127, 130-132',
            tone: WorldsScheduleSessionTone.logistics,
          ),
          WorldsScheduleSession(
            timeLabel: '1:00 PM - 4:15 PM',
            title: 'Skills Challenge',
            location: 'Rooms 100-106',
            tone: WorldsScheduleSessionTone.competition,
          ),
          WorldsScheduleSession(
            timeLabel: '1:00 PM - 4:30 PM',
            title: 'Qualification matches',
            location: 'Halls 1-5',
            tone: WorldsScheduleSessionTone.competition,
          ),
          WorldsScheduleSession(
            timeLabel: '4:30 PM',
            title: 'Venue closes',
            location: 'All locations',
            tone: WorldsScheduleSessionTone.logistics,
          ),
        ],
      ),
      WorldsScheduleDay(
        date: DateTime(2026, 4, 23),
        headline: 'Final qualification day',
        note:
            'Thursday mirrors Wednesday, with the final full HS qualification schedule before playoffs.',
        sessions: <WorldsScheduleSession>[
          WorldsScheduleSession(
            timeLabel: '7:45 AM',
            title: 'Venue opens',
            location: 'Halls 1-5',
            tone: WorldsScheduleSessionTone.logistics,
          ),
          WorldsScheduleSession(
            timeLabel: '8:00 AM - 12:00 PM',
            title: 'Practice fields open',
            location: 'Rooms 120-127, 130-132',
            tone: WorldsScheduleSessionTone.logistics,
          ),
          WorldsScheduleSession(
            timeLabel: '8:00 AM - 12:00 PM',
            title: 'Skills Challenge',
            location: 'Rooms 100-106',
            tone: WorldsScheduleSessionTone.competition,
          ),
          WorldsScheduleSession(
            timeLabel: '8:30 AM - 11:45 AM',
            title: 'Qualification matches',
            location: 'Halls 1-5',
            tone: WorldsScheduleSessionTone.competition,
          ),
          WorldsScheduleSession(
            timeLabel: '12:00 PM - 1:00 PM',
            title: 'Lunch break',
            location: 'All locations',
            tone: WorldsScheduleSessionTone.logistics,
          ),
          WorldsScheduleSession(
            timeLabel: '1:00 PM - 4:15 PM',
            title: 'Practice fields open',
            location: 'Rooms 120-127, 130-132',
            tone: WorldsScheduleSessionTone.logistics,
          ),
          WorldsScheduleSession(
            timeLabel: '1:00 PM - 4:30 PM',
            title: 'Skills Challenge',
            location: 'Rooms 100-106',
            tone: WorldsScheduleSessionTone.competition,
          ),
          WorldsScheduleSession(
            timeLabel: '1:00 PM - 4:15 PM',
            title: 'Qualification matches',
            location: 'Halls 1-5',
            tone: WorldsScheduleSessionTone.competition,
          ),
          WorldsScheduleSession(
            timeLabel: '4:30 PM',
            title: 'Venue closes',
            location: 'All locations',
            tone: WorldsScheduleSessionTone.logistics,
          ),
        ],
      ),
      WorldsScheduleDay(
        date: DateTime(2026, 4, 24),
        headline: 'Playoffs, finals, and game unveil',
        note:
            'Alliance selection follows the final HS qualification block, then divisional playoffs roll into finals and the game unveil.',
        sessions: <WorldsScheduleSession>[
          WorldsScheduleSession(
            timeLabel: '7:45 AM',
            title: 'Venue opens',
            location: 'Halls 1-5',
            tone: WorldsScheduleSessionTone.logistics,
          ),
          WorldsScheduleSession(
            timeLabel: '8:00 AM - 12:15 PM',
            title: 'Practice fields open',
            location: 'Rooms 120-127, 130-132',
            tone: WorldsScheduleSessionTone.logistics,
          ),
          WorldsScheduleSession(
            timeLabel: '8:00 AM - 10:15 AM',
            title: 'Final Skills Challenge window',
            location: 'Rooms 100-106',
            tone: WorldsScheduleSessionTone.competition,
          ),
          WorldsScheduleSession(
            timeLabel: '8:30 AM - 10:30 AM',
            title: 'Qualification matches',
            location: 'Halls 1-5',
            tone: WorldsScheduleSessionTone.competition,
            detail: 'Senior recognition happens in division.',
          ),
          WorldsScheduleSession(
            timeLabel: '12:00 PM - 1:00 PM',
            title: 'Lunch break',
            location: 'All locations',
            tone: WorldsScheduleSessionTone.logistics,
          ),
          WorldsScheduleSession(
            timeLabel: '12:30 PM',
            title: 'Alliances report for inspection',
            location: 'Halls 1-5',
            tone: WorldsScheduleSessionTone.logistics,
          ),
          WorldsScheduleSession(
            timeLabel: '1:00 PM - 3:30 PM',
            title: 'Divisional Playoffs and Awards',
            location: 'Halls 1-5',
            tone: WorldsScheduleSessionTone.milestone,
          ),
          WorldsScheduleSession(
            timeLabel: '4:00 PM - 7:00 PM',
            title: 'Finals, Closing Ceremonies, and Game Unveil',
            location: 'Dome',
            tone: WorldsScheduleSessionTone.milestone,
          ),
          WorldsScheduleSession(
            timeLabel: '7:00 PM',
            title: 'Venue closes',
            location: 'All locations',
            tone: WorldsScheduleSessionTone.logistics,
          ),
        ],
      ),
    ],
  ),
  WorldsScheduleTrackData(
    track: WorldsScheduleTrack.v5rcMiddleSchoolAndVurc,
    title: 'V5RC Middle School and VURC',
    shortLabel: 'MS / VURC',
    subtitle: 'St. Louis Convention Center and Dome',
    dateRangeLabel: 'April 25-27, 2026',
    days: <WorldsScheduleDay>[
      WorldsScheduleDay(
        date: DateTime(2026, 4, 25),
        headline: 'Check-in and opening day',
        note:
            'MS and VURC follow the same official opening cadence as HS, including inspection, ceremonies, and an evening qualification block.',
        sessions: <WorldsScheduleSession>[
          WorldsScheduleSession(
            timeLabel: '7:45 AM',
            title: 'Venue opens',
            location: 'Halls 1-5',
            tone: WorldsScheduleSessionTone.logistics,
          ),
          WorldsScheduleSession(
            timeLabel: '8:00 AM - 11:00 AM',
            title: 'Inspection in divisions',
            location: 'Halls 1-5',
            tone: WorldsScheduleSessionTone.logistics,
            detail: 'Teams must be inspected by 11:00 AM CT.',
          ),
          WorldsScheduleSession(
            timeLabel: '8:00 AM - 12:00 PM',
            title: 'Skills Challenge',
            location: 'Rooms 100-106',
            tone: WorldsScheduleSessionTone.competition,
          ),
          WorldsScheduleSession(
            timeLabel: '8:00 AM - 12:30 PM',
            title: 'Practice fields open',
            location: 'Rooms 120-127, 130-132',
            tone: WorldsScheduleSessionTone.logistics,
          ),
          WorldsScheduleSession(
            timeLabel: '12:00 PM - 1:00 PM',
            title: 'Lunch break',
            location: 'All locations',
            tone: WorldsScheduleSessionTone.logistics,
          ),
          WorldsScheduleSession(
            timeLabel: '1:00 PM - 2:00 PM',
            title: 'Opening Ceremonies',
            location: 'Dome',
            tone: WorldsScheduleSessionTone.milestone,
          ),
          WorldsScheduleSession(
            timeLabel: '2:30 PM - 5:45 PM',
            title: 'Skills Challenge',
            location: 'Rooms 100-106',
            tone: WorldsScheduleSessionTone.competition,
          ),
          WorldsScheduleSession(
            timeLabel: '2:30 PM - 5:45 PM',
            title: 'Practice fields open',
            location: 'Rooms 120-127, 130-132',
            tone: WorldsScheduleSessionTone.logistics,
          ),
          WorldsScheduleSession(
            timeLabel: '3:00 PM - 4:30 PM',
            title: 'Practice matches',
            location: 'Halls 1-5',
            tone: WorldsScheduleSessionTone.competition,
          ),
          WorldsScheduleSession(
            timeLabel: '4:30 PM - 6:00 PM',
            title: 'Qualification matches',
            location: 'Halls 1-5',
            tone: WorldsScheduleSessionTone.competition,
          ),
          WorldsScheduleSession(
            timeLabel: '6:15 PM',
            title: 'Venue closes',
            location: 'All locations',
            tone: WorldsScheduleSessionTone.logistics,
          ),
        ],
      ),
      WorldsScheduleDay(
        date: DateTime(2026, 4, 26),
        headline: 'Qualification and skills day',
        note:
            'Sunday is the longest official MS/VURC competition day, with parallel skills, practice-field access, and qualification blocks into the evening.',
        sessions: <WorldsScheduleSession>[
          WorldsScheduleSession(
            timeLabel: '7:45 AM',
            title: 'Venue opens',
            location: 'Halls 1-5',
            tone: WorldsScheduleSessionTone.logistics,
          ),
          WorldsScheduleSession(
            timeLabel: '8:00 AM - 12:00 PM',
            title: 'Practice fields open',
            location: 'Rooms 120-127, 130-132',
            tone: WorldsScheduleSessionTone.logistics,
          ),
          WorldsScheduleSession(
            timeLabel: '8:00 AM - 12:00 PM',
            title: 'Skills Challenge',
            location: 'Rooms 100-106',
            tone: WorldsScheduleSessionTone.competition,
          ),
          WorldsScheduleSession(
            timeLabel: '8:15 AM - 12:00 PM',
            title: 'Qualification matches',
            location: 'Halls 1-5',
            tone: WorldsScheduleSessionTone.competition,
          ),
          WorldsScheduleSession(
            timeLabel: '12:00 PM - 1:00 PM',
            title: 'Lunch break',
            location: 'All locations',
            tone: WorldsScheduleSessionTone.logistics,
          ),
          WorldsScheduleSession(
            timeLabel: '1:00 PM - 6:15 PM',
            title: 'Practice fields open',
            location: 'Rooms 120-127, 130-132',
            tone: WorldsScheduleSessionTone.logistics,
          ),
          WorldsScheduleSession(
            timeLabel: '1:00 PM - 6:15 PM',
            title: 'Skills Challenge',
            location: 'Rooms 100-106',
            tone: WorldsScheduleSessionTone.competition,
          ),
          WorldsScheduleSession(
            timeLabel: '1:00 PM - 6:15 PM',
            title: 'Qualification matches',
            location: 'Halls 1-5',
            tone: WorldsScheduleSessionTone.competition,
          ),
          WorldsScheduleSession(
            timeLabel: '6:30 PM',
            title: 'Venue closes',
            location: 'All locations',
            tone: WorldsScheduleSessionTone.logistics,
          ),
        ],
      ),
      WorldsScheduleDay(
        date: DateTime(2026, 4, 27),
        headline: 'Playoffs and finals',
        note:
            'Alliance selection follows the final morning MS/VURC qualification block before divisional playoffs and Dome finals.',
        sessions: <WorldsScheduleSession>[
          WorldsScheduleSession(
            timeLabel: '7:45 AM',
            title: 'Venue opens',
            location: 'Halls 1-5',
            tone: WorldsScheduleSessionTone.logistics,
          ),
          WorldsScheduleSession(
            timeLabel: '8:00 AM - 12:15 PM',
            title: 'Practice fields open',
            location: 'Rooms 120-127, 130-132',
            tone: WorldsScheduleSessionTone.logistics,
          ),
          WorldsScheduleSession(
            timeLabel: '8:00 AM - 10:15 AM',
            title: 'Final Skills Challenge window',
            location: 'Rooms 100-106',
            tone: WorldsScheduleSessionTone.competition,
          ),
          WorldsScheduleSession(
            timeLabel: '8:15 AM - 11:15 AM',
            title: 'Qualification matches',
            location: 'Halls 1-5',
            tone: WorldsScheduleSessionTone.competition,
          ),
          WorldsScheduleSession(
            timeLabel: '12:30 PM',
            title: 'Alliances report for inspection',
            location: 'Halls 1-5',
            tone: WorldsScheduleSessionTone.logistics,
          ),
          WorldsScheduleSession(
            timeLabel: '1:00 PM - 3:30 PM',
            title: 'Divisional Playoffs and Awards',
            location: 'Halls 1-5',
            tone: WorldsScheduleSessionTone.milestone,
          ),
          WorldsScheduleSession(
            timeLabel: '4:00 PM - 7:00 PM',
            title: 'Finals, Closing Ceremonies, and Game Unveil',
            location: 'Dome',
            tone: WorldsScheduleSessionTone.milestone,
          ),
          WorldsScheduleSession(
            timeLabel: '7:00 PM',
            title: 'Venue closes',
            location: 'All locations',
            tone: WorldsScheduleSessionTone.logistics,
          ),
        ],
      ),
    ],
  ),
  WorldsScheduleTrackData(
    track: WorldsScheduleTrack.viqrc,
    title: 'VIQRC Elementary and Middle School',
    shortLabel: 'IQ',
    subtitle: 'St. Louis Convention Center and Dome',
    dateRangeLabel: 'April 28-30, 2026',
    days: <WorldsScheduleDay>[
      WorldsScheduleDay(
        date: DateTime(2026, 4, 28),
        headline: 'Check-in and opening day',
        note:
            'Tuesday opens with inspection, then shifts into VIQRC practice matches and the first qualification block after ceremonies.',
        sessions: <WorldsScheduleSession>[
          WorldsScheduleSession(
            timeLabel: '7:45 AM',
            title: 'Venue opens',
            location: 'Halls 1-5',
            tone: WorldsScheduleSessionTone.logistics,
          ),
          WorldsScheduleSession(
            timeLabel: '8:00 AM - 11:00 AM',
            title: 'Inspection in divisions',
            location: 'Halls 1-5',
            tone: WorldsScheduleSessionTone.logistics,
            detail: 'Teams must be inspected by 11:00 AM CT.',
          ),
          WorldsScheduleSession(
            timeLabel: '8:00 AM - 12:00 PM',
            title: 'Skills Challenge',
            location: 'Rooms 100-106',
            tone: WorldsScheduleSessionTone.competition,
          ),
          WorldsScheduleSession(
            timeLabel: '8:00 AM - 12:30 PM',
            title: 'Practice fields open',
            location:
                'ES: Rooms 120-127, 130-132  •  MS: Rooms 260-267, 274-276',
            tone: WorldsScheduleSessionTone.logistics,
          ),
          WorldsScheduleSession(
            timeLabel: '12:00 PM - 1:00 PM',
            title: 'Lunch break',
            location: 'All locations',
            tone: WorldsScheduleSessionTone.logistics,
          ),
          WorldsScheduleSession(
            timeLabel: '1:00 PM - 2:00 PM',
            title: 'Opening Ceremonies',
            location: 'Dome',
            tone: WorldsScheduleSessionTone.milestone,
          ),
          WorldsScheduleSession(
            timeLabel: '2:30 PM - 5:30 PM',
            title: 'Skills Challenge',
            location: 'Rooms 100-106',
            tone: WorldsScheduleSessionTone.competition,
          ),
          WorldsScheduleSession(
            timeLabel: '2:30 PM - 5:30 PM',
            title: 'Practice fields open',
            location:
                'ES: Rooms 120-127, 130-132  •  MS: Rooms 260-267, 274-276',
            tone: WorldsScheduleSessionTone.logistics,
          ),
          WorldsScheduleSession(
            timeLabel: '2:30 PM - 3:55 PM',
            title: 'Practice matches',
            location: 'Halls 1-5',
            tone: WorldsScheduleSessionTone.competition,
          ),
          WorldsScheduleSession(
            timeLabel: '4:00 PM - 5:25 PM',
            title: 'Qualification matches',
            location: 'Halls 1-5',
            tone: WorldsScheduleSessionTone.competition,
          ),
          WorldsScheduleSession(
            timeLabel: '5:30 PM',
            title: 'Venue closes',
            location: 'All locations',
            tone: WorldsScheduleSessionTone.logistics,
          ),
        ],
      ),
      WorldsScheduleDay(
        date: DateTime(2026, 4, 29),
        headline: 'Full VIQRC qualifier day',
        note:
            'ES and MS practice fields stay split by room group throughout the official Wednesday qualifier schedule.',
        sessions: <WorldsScheduleSession>[
          WorldsScheduleSession(
            timeLabel: '7:45 AM',
            title: 'Venue opens',
            location: 'Halls 1-5',
            tone: WorldsScheduleSessionTone.logistics,
          ),
          WorldsScheduleSession(
            timeLabel: '8:00 AM - 12:00 PM',
            title: 'Practice fields open',
            location:
                'ES: Rooms 120-127, 130-132  •  MS: Rooms 260-267, 274-276',
            tone: WorldsScheduleSessionTone.logistics,
          ),
          WorldsScheduleSession(
            timeLabel: '8:00 AM - 12:00 PM',
            title: 'Skills Challenge',
            location: 'Rooms 100-106',
            tone: WorldsScheduleSessionTone.competition,
          ),
          WorldsScheduleSession(
            timeLabel: '8:15 AM - 12:00 PM',
            title: 'Qualification matches',
            location: 'Halls 1-5',
            tone: WorldsScheduleSessionTone.competition,
          ),
          WorldsScheduleSession(
            timeLabel: '12:00 PM - 1:00 PM',
            title: 'Lunch break',
            location: 'All locations',
            tone: WorldsScheduleSessionTone.logistics,
          ),
          WorldsScheduleSession(
            timeLabel: '1:00 PM - 5:15 PM',
            title: 'Practice fields open',
            location:
                'ES: Rooms 120-127, 130-132  •  MS: Rooms 260-267, 274-276',
            tone: WorldsScheduleSessionTone.logistics,
          ),
          WorldsScheduleSession(
            timeLabel: '1:00 PM - 5:15 PM',
            title: 'Skills Challenge',
            location: 'Rooms 100-106',
            tone: WorldsScheduleSessionTone.competition,
          ),
          WorldsScheduleSession(
            timeLabel: '1:00 PM - 5:20 PM',
            title: 'Qualification matches',
            location: 'Halls 1-5',
            tone: WorldsScheduleSessionTone.competition,
          ),
          WorldsScheduleSession(
            timeLabel: '5:30 PM',
            title: 'Venue closes',
            location: 'All locations',
            tone: WorldsScheduleSessionTone.logistics,
          ),
        ],
      ),
      WorldsScheduleDay(
        date: DateTime(2026, 4, 30),
        headline: 'Divisional playoffs and IQ finals',
        note:
            'Thursday wraps with divisional playoffs, Dome finals, and the game unveil on the official RECF agenda.',
        sessions: <WorldsScheduleSession>[
          WorldsScheduleSession(
            timeLabel: '7:45 AM',
            title: 'Venue opens',
            location: 'Halls 1-5',
            tone: WorldsScheduleSessionTone.logistics,
          ),
          WorldsScheduleSession(
            timeLabel: '8:00 AM - 12:15 PM',
            title: 'Practice fields open',
            location:
                'ES: Rooms 120-127, 130-132  •  MS: Rooms 260-267, 274-276',
            tone: WorldsScheduleSessionTone.logistics,
          ),
          WorldsScheduleSession(
            timeLabel: '8:00 AM - 10:15 AM',
            title: 'Final Skills Challenge window',
            location: 'Rooms 100-106',
            tone: WorldsScheduleSessionTone.competition,
          ),
          WorldsScheduleSession(
            timeLabel: '8:15 AM - 11:45 AM',
            title: 'Qualification matches',
            location: 'Halls 1-5',
            tone: WorldsScheduleSessionTone.competition,
          ),
          WorldsScheduleSession(
            timeLabel: '12:00 PM - 1:00 PM',
            title: 'Lunch break',
            location: 'All locations',
            tone: WorldsScheduleSessionTone.logistics,
          ),
          WorldsScheduleSession(
            timeLabel: '12:30 PM',
            title: 'Finals teams report for inspection',
            location: 'Halls 1-5',
            tone: WorldsScheduleSessionTone.logistics,
          ),
          WorldsScheduleSession(
            timeLabel: '1:00 PM - 2:30 PM',
            title: 'Divisional Playoffs and Awards',
            location: 'Halls 1-5',
            tone: WorldsScheduleSessionTone.milestone,
          ),
          WorldsScheduleSession(
            timeLabel: '3:00 PM - 5:00 PM',
            title: 'Finals, Closing Ceremonies, and Game Unveil',
            location: 'Dome',
            tone: WorldsScheduleSessionTone.milestone,
          ),
          WorldsScheduleSession(
            timeLabel: '5:00 PM',
            title: 'Venue closes',
            location: 'All locations',
            tone: WorldsScheduleSessionTone.logistics,
          ),
        ],
      ),
    ],
  ),
];

WorldsScheduleTrackData worldsScheduleForTrack(WorldsScheduleTrack track) {
  return worldsScheduleTracks.firstWhere((entry) => entry.track == track);
}
