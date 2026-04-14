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
const worldsScheduleOfficialSourceLabel = 'REC Foundation calendar view';
const worldsScheduleOfficialSourceUrl =
    'https://recf.org/vex-robotics-world-championship/vex-robotics-world-championship-detailed-agenda/';

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
        note: 'Inspection closes at 11:00 AM CT before the first HS quals.',
        sessions: <WorldsScheduleSession>[
          WorldsScheduleSession(
            timeLabel: '7:45 AM',
            title: 'Venue opens and teams set up pits',
            location: 'Halls 1-5',
            tone: WorldsScheduleSessionTone.logistics,
          ),
          WorldsScheduleSession(
            timeLabel: '8:00 AM - 11:00 AM',
            title: 'Inspection in divisions',
            location: 'Halls 1-5',
            tone: WorldsScheduleSessionTone.logistics,
          ),
          WorldsScheduleSession(
            timeLabel: '8:00 AM - 12:00 PM',
            title: 'Skills Challenge',
            location: 'Rooms 100-106',
            tone: WorldsScheduleSessionTone.competition,
          ),
          WorldsScheduleSession(
            timeLabel: '1:00 PM - 2:00 PM',
            title: 'Opening Ceremonies',
            location: 'Dome',
            tone: WorldsScheduleSessionTone.milestone,
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
        ],
      ),
      WorldsScheduleDay(
        date: DateTime(2026, 4, 22),
        headline: 'Full qualification day',
        note: 'Morning and afternoon blocks run in parallel with skills.',
        sessions: <WorldsScheduleSession>[
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
        ],
      ),
      WorldsScheduleDay(
        date: DateTime(2026, 4, 23),
        headline: 'Last full HS qualifier block',
        note: 'Practice fields and skills stay open around each quals block.',
        sessions: <WorldsScheduleSession>[
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
        ],
      ),
      WorldsScheduleDay(
        date: DateTime(2026, 4, 24),
        headline: 'Playoffs, finals, and game unveil',
        note:
            'Alliance selection happens immediately after the last HS quals match.',
        sessions: <WorldsScheduleSession>[
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
        note: 'MS and VURC follow the same published opening cadence as HS.',
        sessions: <WorldsScheduleSession>[
          WorldsScheduleSession(
            timeLabel: '7:45 AM',
            title: 'Venue opens and teams set up pits',
            location: 'Halls 1-5',
            tone: WorldsScheduleSessionTone.logistics,
          ),
          WorldsScheduleSession(
            timeLabel: '8:00 AM - 11:00 AM',
            title: 'Inspection in divisions',
            location: 'Halls 1-5',
            tone: WorldsScheduleSessionTone.logistics,
          ),
          WorldsScheduleSession(
            timeLabel: '8:00 AM - 12:00 PM',
            title: 'Skills Challenge',
            location: 'Rooms 100-106',
            tone: WorldsScheduleSessionTone.competition,
          ),
          WorldsScheduleSession(
            timeLabel: '1:00 PM - 2:00 PM',
            title: 'Opening Ceremonies',
            location: 'Dome',
            tone: WorldsScheduleSessionTone.milestone,
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
        ],
      ),
      WorldsScheduleDay(
        date: DateTime(2026, 4, 26),
        headline: 'Deep qualifier grind',
        note: 'Sunday is the longest published V5RC MS/VURC competition day.',
        sessions: <WorldsScheduleSession>[
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
        ],
      ),
      WorldsScheduleDay(
        date: DateTime(2026, 4, 27),
        headline: 'Playoffs and Dome finals',
        note:
            'Alliance selection follows the last morning qualification match.',
        sessions: <WorldsScheduleSession>[
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
            'Tuesday starts with inspection and shifts into short practice and quals blocks.',
        sessions: <WorldsScheduleSession>[
          WorldsScheduleSession(
            timeLabel: '7:45 AM',
            title: 'Venue opens and teams set up pits',
            location: 'Halls 1-5',
            tone: WorldsScheduleSessionTone.logistics,
          ),
          WorldsScheduleSession(
            timeLabel: '8:00 AM - 11:00 AM',
            title: 'Inspection in divisions',
            location: 'Halls 1-5',
            tone: WorldsScheduleSessionTone.logistics,
          ),
          WorldsScheduleSession(
            timeLabel: '8:00 AM - 12:00 PM',
            title: 'Skills Challenge',
            location: 'Rooms 100-106',
            tone: WorldsScheduleSessionTone.competition,
          ),
          WorldsScheduleSession(
            timeLabel: '1:00 PM - 2:00 PM',
            title: 'Opening Ceremonies',
            location: 'Dome',
            tone: WorldsScheduleSessionTone.milestone,
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
        ],
      ),
      WorldsScheduleDay(
        date: DateTime(2026, 4, 29),
        headline: 'Full VIQRC qualifier day',
        note:
            'ES and MS practice fields stay split by room group throughout the day.',
        sessions: <WorldsScheduleSession>[
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
        ],
      ),
      WorldsScheduleDay(
        date: DateTime(2026, 4, 30),
        headline: 'Divisional playoffs and IQ finals',
        note: 'Published finals block runs from the Dome in the afternoon.',
        sessions: <WorldsScheduleSession>[
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
        ],
      ),
    ],
  ),
];

WorldsScheduleTrackData worldsScheduleForTrack(WorldsScheduleTrack track) {
  return worldsScheduleTracks.firstWhere((entry) => entry.track == track);
}
