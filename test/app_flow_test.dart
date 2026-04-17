import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:solar_v6/src/app/app_session_controller.dart';
import 'package:solar_v6/src/models/open_skill_models.dart';
import 'package:solar_v6/src/app/solar_app.dart';
import 'package:solar_v6/src/models/robot_events_models.dart';
import 'package:solar_v6/src/models/world_skills_models.dart';
import 'package:solar_v6/src/ui/models/app_account.dart';
import 'package:solar_v6/src/ui/models/team_stats_snapshot.dart';
import 'package:solar_v6/src/ui/pages/calendar_screen.dart';
import 'package:solar_v6/src/ui/pages/rankings_screen.dart';
import 'package:solar_v6/src/ui/pages/settings_screen.dart';
import 'package:solar_v6/src/ui/services/in_memory_account_repository.dart';
import 'package:solar_v6/src/ui/services/team_directory_service.dart';

void main() {
  test('preferred season drives refresh and team validation', () async {
    final primaryTeam = TeamSummary(
      id: 17,
      number: '98601Y',
      teamName: 'Solar Squad',
      organization: 'Solar Robotics',
      robotName: 'Helios',
      location: _stLouisLocation,
      grade: 'High School',
      registered: true,
    );
    final secondaryTeam = TeamSummary(
      id: 18,
      number: '229V',
      teamName: 'Vector',
      organization: 'Solar Robotics',
      robotName: 'Nova',
      location: _stLouisLocation,
      grade: 'High School',
      registered: true,
    );
    final repository = InMemoryAccountRepository();
    await repository.saveAccount(
      AppAccount(
        fullName: 'Bob Smith',
        email: 'bob@solar.test',
        password: 'password123',
        team: primaryTeam,
        createdAt: DateTime(2026, 4, 4),
      ),
    );
    await repository.saveSettings(
      const AppSettings(
        hasCompletedOnboarding: true,
        currentUserEmail: 'bob@solar.test',
      ),
    );

    final teamDirectory = _RecordingTeamDirectoryService(
      teamsByNumber: <String, TeamSummary>{
        '98601Y': primaryTeam,
        '229V': secondaryTeam,
      },
      snapshotsByTeamId: <int, TeamStatsSnapshot>{
        17: TeamStatsSnapshot(team: primaryTeam),
        18: TeamStatsSnapshot(team: secondaryTeam),
      },
    );
    final controller = AppSessionController(
      repository: repository,
      teamDirectory: teamDirectory,
    );

    await controller.initialize();
    await Future<void>.delayed(Duration.zero);
    await controller.updatePreferredSeason(seasonId: 190);
    expect(teamDirectory.lastLoadedPreferredSeasonId, 190);

    await controller.updateTeam(teamNumber: '229V');
    expect(teamDirectory.lastValidatedPreferredSeasonId, 190);
    expect(teamDirectory.lastLoadedPreferredSeasonId, 190);
  });

  testWidgets('splash advances to onboarding and skip jumps to local setup', (
    tester,
  ) async {
    await tester.pumpWidget(SolarApp(controller: await _buildTestController()));

    expect(find.bySemanticsLabel('Solar logo'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pumpAndSettle();

    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Everything Solar has right now'), findsOneWidget);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('Competition'), findsOneWidget);
    expect(find.text('Team number'), findsOneWidget);
  });

  testWidgets('onboarding creates a local team profile and opens home', (
    tester,
  ) async {
    await tester.pumpWidget(SolarApp(controller: await _buildTestController()));

    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '98601Y');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Quickview'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('home-menu-button')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey<String>('home-menu-button')));
    await tester.pumpAndSettle();

    expect(find.text('Team '), findsOneWidget);
    expect(find.text('98601Y'), findsWidgets);
    expect(find.text('My Profile'), findsOneWidget);
    expect(find.text('Sign Out'), findsOneWidget);
  });

  testWidgets('home search shows both team and event results', (tester) async {
    final controller = await _buildTestController();
    await controller.signUp(
      fullName: 'Bob Smith',
      email: 'bob@solar.test',
      teamNumber: '98601Y',
      password: 'password123',
      confirmPassword: 'password123',
    );
    await controller.signIn(email: 'bob@solar.test', password: 'password123');

    await tester.pumpWidget(SolarApp(controller: controller));
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pumpAndSettle();

    expect(find.text('Quickview'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey<String>('home-search-field')),
      'm',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.textContaining('Search results for'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey<String>('home-search-field')),
      'st. louis',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    expect(find.text('Teams'), findsWidgets);
    expect(find.text('Events'), findsWidgets);
    expect(find.text('98601Y'), findsWidgets);
    expect(find.textContaining('World Championships'), findsWidgets);
  });

  testWidgets(
    'calendar, rankings, and settings pages open from nav and drawer',
    (tester) async {
      await tester.pumpWidget(
        SolarApp(controller: await _buildSignedInController()),
      );
      await tester.pump(const Duration(milliseconds: 1400));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('home-menu-button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('drawer-settings')));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(find.text('Settings'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey<String>('nav-rankings')));
      await tester.pumpAndSettle();

      expect(find.byType(RankingsScreen), findsOneWidget);
      expect(find.text('SKILL'), findsWidgets);

      await tester.tap(find.byKey(const ValueKey<String>('nav-calendar')));
      await tester.pumpAndSettle();

      expect(find.byType(CalendarScreen), findsOneWidget);
      expect(find.text('Team Calendar'), findsOneWidget);
    },
  );
}

Future<AppSessionController> _buildTestController() async {
  final team = TeamSummary(
    id: 17,
    number: '98601Y',
    teamName: 'Solar Squad',
    organization: 'Solar Robotics',
    robotName: 'Helios',
    location: _stLouisLocation,
    grade: 'High School',
    registered: true,
  );

  final controller = AppSessionController(
    repository: InMemoryAccountRepository(),
    teamDirectory: FakeTeamDirectoryService(
      teamsByNumber: <String, TeamSummary>{'98601Y': team},
      snapshotsByTeamId: <int, TeamStatsSnapshot>{
        17: TeamStatsSnapshot(
          team: team,
          upcomingEvents: <EventSummary>[
            EventSummary(
              id: 200,
              sku: 'RE-VRC-001',
              name: 'VEX Robotics World Championships - HS',
              start: DateTime(2026, 4, 21),
              end: DateTime(2026, 4, 23),
              seasonId: 190,
              location: const LocationSummary(
                venue: 'Convention Center',
                address1: '',
                city: 'St. Louis',
                region: 'Missouri',
                postcode: '',
                country: 'United States',
              ),
              divisions: const <DivisionSummary>[],
              livestreamLink: '',
            ),
          ],
          rankings: <RankingRecord>[
            RankingRecord(
              id: 88,
              team: const TeamReference(
                id: 17,
                number: '98601Y',
                name: 'Solar Squad',
              ),
              event: const EventReference(
                id: 200,
                sku: 'RE-VRC-001',
                name: 'VEX Robotics World Championships - HS',
              ),
              division: const DivisionSummary(id: 1, name: 'Science'),
              rank: 3,
              wins: 8,
              losses: 2,
              ties: 0,
              wp: 0,
              ap: 0,
              sp: 0,
              highScore: 121,
              averagePoints: 98.2,
              totalPoints: 982,
            ),
          ],
        ),
      },
    ),
  );

  await controller.initialize();
  return controller;
}

Future<AppSessionController> _buildSignedInController() async {
  final controller = await _buildTestController();
  await controller.signUp(
    fullName: 'Bob Smith',
    email: 'bob@solar.test',
    teamNumber: '98601Y',
    password: 'password123',
    confirmPassword: 'password123',
  );
  await controller.signIn(email: 'bob@solar.test', password: 'password123');
  return controller;
}

const _stLouisLocation = LocationSummary(
  venue: '',
  address1: '',
  city: 'St. Louis',
  region: 'Missouri',
  postcode: '',
  country: 'United States',
);

class _RecordingTeamDirectoryService extends FakeTeamDirectoryService {
  _RecordingTeamDirectoryService({
    required super.teamsByNumber,
    required super.snapshotsByTeamId,
  });

  int? lastLoadedPreferredSeasonId;
  int? lastValidatedPreferredSeasonId;

  @override
  Future<TeamStatsSnapshot> loadTeamStats(
    TeamSummary team, {
    int? preferredSeasonId,
    WorldSkillsEntry? seedWorldSkillsEntry,
    OpenSkillCacheEntry? seedOpenSkillEntry,
  }) async {
    lastLoadedPreferredSeasonId = preferredSeasonId;
    return super.loadTeamStats(team, preferredSeasonId: preferredSeasonId);
  }

  @override
  Future<TeamSummary> validateTeamNumber(
    String teamNumber, {
    int? preferredSeasonId,
    List<int> programIds = const <int>[],
  }) async {
    lastValidatedPreferredSeasonId = preferredSeasonId;
    return super.validateTeamNumber(
      teamNumber,
      preferredSeasonId: preferredSeasonId,
      programIds: programIds,
    );
  }
}
