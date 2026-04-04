import '../../models/open_skill_models.dart';
import '../../models/robot_events_models.dart';
import '../../models/world_skills_models.dart';

class SolarScrimmagePackage {
  const SolarScrimmagePackage({
    required this.event,
    required this.division,
    required this.matches,
    required this.rankings,
    required this.skills,
    required this.teams,
  });

  final EventSummary event;
  final DivisionSummary division;
  final List<MatchSummary> matches;
  final List<RankingRecord> rankings;
  final List<SkillAttempt> skills;
  final List<TeamReference> teams;

  int get teamCount => teams.length;
}

class SolarScrimmageService {
  static const eventId = -9860101;
  static const divisionId = -9860101;

  const SolarScrimmageService();

  SolarScrimmagePackage build({
    required TeamSummary currentTeam,
    required List<WorldSkillsEntry> worldSkills,
    required Map<String, OpenSkillCacheEntry> openSkillByTeam,
    DateTime? now,
  }) {
    final anchorNow = now ?? DateTime.now();
    final baseTime = anchorNow.add(const Duration(minutes: 24));
    final division = const DivisionSummary(id: divisionId, name: 'Tonight');
    final event = EventSummary(
      id: eventId,
      sku: 'SCRIMMAGE-TONIGHT',
      name: 'Solar Quickview Test Scrimmage',
      start: baseTime,
      end: baseTime.add(const Duration(hours: 2, minutes: 10)),
      seasonId: _resolveSeasonId(worldSkills),
      location: currentTeam.location,
      divisions: const <DivisionSummary>[
        DivisionSummary(id: divisionId, name: 'Tonight'),
      ],
      livestreamLink: '',
    );
    final selectedTeams = _selectTeams(
      currentTeam: currentTeam,
      worldSkills: worldSkills,
    );

    final matches = _buildMatches(
      event: event,
      division: division,
      teams: selectedTeams,
      baseTime: baseTime,
    );
    final rankings = _buildRankings(
      event: event,
      division: division,
      teams: selectedTeams,
      worldSkills: worldSkills,
      openSkillByTeam: openSkillByTeam,
    );
    final skills = _buildSkills(
      event: event,
      teams: selectedTeams,
      worldSkills: worldSkills,
    );

    return SolarScrimmagePackage(
      event: event,
      division: division,
      matches: matches,
      rankings: rankings,
      skills: skills,
      teams: selectedTeams,
    );
  }

  List<TeamReference> _selectTeams({
    required TeamSummary currentTeam,
    required List<WorldSkillsEntry> worldSkills,
  }) {
    final selected = <String, TeamReference>{};

    void addReference(TeamReference reference) {
      selected.putIfAbsent(
        reference.number.trim().toUpperCase(),
        () => reference,
      );
    }

    addReference(
      TeamReference(
        id: currentTeam.id,
        number: currentTeam.number,
        name: currentTeam.teamName,
      ),
    );

    for (final mustInclude in const <String>['98601Y']) {
      final fromWorldSkills = worldSkills
          .where((entry) {
            return entry.teamNumber.trim().toUpperCase() ==
                mustInclude.trim().toUpperCase();
          })
          .toList(growable: false);
      if (fromWorldSkills.isNotEmpty) {
        addReference(
          TeamReference(
            id: fromWorldSkills.first.teamId,
            number: fromWorldSkills.first.teamNumber,
            name: fromWorldSkills.first.teamName,
          ),
        );
      } else if (currentTeam.number.trim().toUpperCase() ==
          mustInclude.trim().toUpperCase()) {
        addReference(
          TeamReference(
            id: currentTeam.id,
            number: currentTeam.number,
            name: currentTeam.teamName,
          ),
        );
      }
    }

    final sortedWorldSkills = List<WorldSkillsEntry>.from(worldSkills)
      ..sort((a, b) {
        final aRank = a.rank <= 0 ? 999999 : a.rank;
        final bRank = b.rank <= 0 ? 999999 : b.rank;
        return aRank.compareTo(bRank);
      });

    for (final entry in sortedWorldSkills) {
      addReference(
        TeamReference(
          id: entry.teamId,
          number: entry.teamNumber,
          name: entry.teamName,
        ),
      );
      if (selected.length >= 8) {
        break;
      }
    }

    var fallbackIndex = 1;
    for (final fallback in _fallbackTeams) {
      addReference(
        TeamReference(
          id: -1000 - fallbackIndex,
          number: fallback.$1,
          name: fallback.$2,
        ),
      );
      fallbackIndex += 1;
      if (selected.length >= 8) {
        break;
      }
    }

    return selected.values.take(8).toList(growable: false);
  }

  List<MatchSummary> _buildMatches({
    required EventSummary event,
    required DivisionSummary division,
    required List<TeamReference> teams,
    required DateTime baseTime,
  }) {
    final paddedTeams = List<TeamReference>.from(teams);
    while (paddedTeams.length < 8) {
      final seed = _fallbackTeams[paddedTeams.length % _fallbackTeams.length];
      paddedTeams.add(
        TeamReference(
          id: -2000 - paddedTeams.length,
          number: seed.$1,
          name: seed.$2,
        ),
      );
    }

    final pairings = <List<int>>[
      <int>[0, 1, 2, 3],
      <int>[4, 5, 6, 7],
      <int>[0, 2, 1, 4],
      <int>[3, 5, 6, 7],
      <int>[0, 6, 2, 5],
      <int>[1, 7, 3, 4],
    ];

    return pairings
        .asMap()
        .entries
        .map((entry) {
          final index = entry.key;
          final teamsForMatch = entry.value;
          final scheduled = baseTime.add(Duration(minutes: index * 18));
          return MatchSummary(
            id: eventId * 10 - index,
            event: EventReference(
              id: event.id,
              sku: event.sku,
              name: event.name,
            ),
            division: division,
            field: 'Solar Field',
            scheduled: scheduled,
            started: null,
            round: MatchRound.qualification,
            instance: 1,
            matchNumber: index + 1,
            name: 'Qualification ${index + 1}',
            alliances: <MatchAlliance>[
              MatchAlliance(
                color: 'red',
                score: -1,
                teams: <TeamReference>[
                  paddedTeams[teamsForMatch[0]],
                  paddedTeams[teamsForMatch[1]],
                ],
              ),
              MatchAlliance(
                color: 'blue',
                score: -1,
                teams: <TeamReference>[
                  paddedTeams[teamsForMatch[2]],
                  paddedTeams[teamsForMatch[3]],
                ],
              ),
            ],
          );
        })
        .toList(growable: false);
  }

  List<RankingRecord> _buildRankings({
    required EventSummary event,
    required DivisionSummary division,
    required List<TeamReference> teams,
    required List<WorldSkillsEntry> worldSkills,
    required Map<String, OpenSkillCacheEntry> openSkillByTeam,
  }) {
    final worldSkillsByTeam = <String, WorldSkillsEntry>{
      for (final entry in worldSkills)
        entry.teamNumber.trim().toUpperCase(): entry,
    };

    final sortedTeams = List<TeamReference>.from(teams)
      ..sort((a, b) {
        final aWorld =
            worldSkillsByTeam[a.number.trim().toUpperCase()]?.rank ?? 999999;
        final bWorld =
            worldSkillsByTeam[b.number.trim().toUpperCase()]?.rank ?? 999999;
        if (aWorld != bWorld) {
          return aWorld.compareTo(bWorld);
        }

        final aOrdinal =
            openSkillByTeam[a.number.trim().toUpperCase()]?.openSkillOrdinal ??
            0;
        final bOrdinal =
            openSkillByTeam[b.number.trim().toUpperCase()]?.openSkillOrdinal ??
            0;
        return bOrdinal.compareTo(aOrdinal);
      });

    return sortedTeams
        .asMap()
        .entries
        .map((entry) {
          final team = entry.value;
          final worldEntry =
              worldSkillsByTeam[team.number.trim().toUpperCase()];
          return RankingRecord(
            id: eventId * 100 - entry.key,
            team: team,
            event: EventReference(
              id: event.id,
              sku: event.sku,
              name: event.name,
            ),
            division: division,
            rank: entry.key + 1,
            wins: 0,
            losses: 0,
            ties: 0,
            wp: 0,
            ap: 0,
            sp: 0,
            highScore: worldEntry?.combinedScore ?? 0,
            averagePoints: (worldEntry?.combinedScore ?? 0).toDouble(),
            totalPoints: worldEntry?.combinedScore ?? 0,
          );
        })
        .toList(growable: false);
  }

  List<SkillAttempt> _buildSkills({
    required EventSummary event,
    required List<TeamReference> teams,
    required List<WorldSkillsEntry> worldSkills,
  }) {
    final worldSkillsByTeam = <String, WorldSkillsEntry>{
      for (final entry in worldSkills)
        entry.teamNumber.trim().toUpperCase(): entry,
    };

    var idSeed = 1;
    final attempts = <SkillAttempt>[];
    for (final team in teams) {
      final worldEntry = worldSkillsByTeam[team.number.trim().toUpperCase()];
      final driver = worldEntry?.driverScore ?? (85 - (attempts.length * 3));
      final auton =
          worldEntry?.programmingScore ?? (70 - (attempts.length * 2));
      attempts.add(
        SkillAttempt(
          id: eventId * 1000 - idSeed++,
          type: 'driver',
          rank: 0,
          score: driver < 0 ? 0 : driver,
          attempts: 3,
          team: team,
          event: EventReference(id: event.id, sku: event.sku, name: event.name),
        ),
      );
      attempts.add(
        SkillAttempt(
          id: eventId * 1000 - idSeed++,
          type: 'programming',
          rank: 0,
          score: auton < 0 ? 0 : auton,
          attempts: 3,
          team: team,
          event: EventReference(id: event.id, sku: event.sku, name: event.name),
        ),
      );
    }

    return attempts;
  }

  int _resolveSeasonId(List<WorldSkillsEntry> worldSkills) {
    for (final entry in worldSkills) {
      if (entry.eventSku.trim().isNotEmpty) {
        return 190;
      }
    }
    return 190;
  }
}

const List<(String, String)> _fallbackTeams = <(String, String)>[
  ('98601Y', 'Solar Squad'),
  ('229V', 'Omega'),
  ('334C', 'Tech Crew'),
  ('1698V', 'Stellar Drive'),
  ('1010G', 'Gravity'),
  ('2775V', 'Vector'),
  ('334W', 'Blue Orbit'),
  ('1658S', 'Signal'),
];
