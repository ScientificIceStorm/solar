import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/solar_config.dart';
import '../models/open_skill_models.dart';
import '../models/robot_events_models.dart';
import '../models/world_skills_models.dart';
import '../solar_api.dart';
import 'app_solar_config_loader.dart';
import '../ui/models/app_account.dart';
import '../ui/models/solar_match_prediction.dart';
import '../ui/models/team_stats_snapshot.dart';
import '../ui/services/account_repository.dart';
import '../ui/services/in_memory_account_repository.dart';
import '../ui/services/local_account_repository.dart';
import '../ui/services/solar_match_prediction_service.dart';
import '../ui/services/solar_scrimmage_service.dart';
import '../ui/services/team_directory_service.dart';

class AppSessionController extends ChangeNotifier {
  AppSessionController({
    required AccountRepository repository,
    required TeamDirectoryService teamDirectory,
    SolarApi? api,
  }) : _repository = repository,
       _teamDirectory = teamDirectory,
       _api = api;

  final AccountRepository _repository;
  final TeamDirectoryService _teamDirectory;
  final SolarApi? _api;
  static const _matchPredictionService = SolarMatchPredictionService();
  static const _scrimmageService = SolarScrimmageService();

  AppAccount? _currentAccount;
  TeamStatsSnapshot? _teamStats;
  bool _hasCompletedOnboarding = false;
  int? _preferredSeasonId;
  bool _isRefreshingTeamStats = false;
  bool _isPreloadingSearchEvents = false;
  bool _isPreloadingSearchTeams = false;
  int? _preloadedSearchSeasonId;
  List<EventSummary> _preloadedSearchEvents = const <EventSummary>[];
  int? _preloadedSearchTeamsSeasonId;
  String? _preloadedSearchTeamsGradeLevel;
  List<TeamSummary> _preloadedSearchTeams = const <TeamSummary>[];
  List<WorldSkillsEntry> _preloadedWorldSkillsRankings =
      const <WorldSkillsEntry>[];
  Map<String, OpenSkillCacheEntry> _preloadedOpenSkillEntriesByTeam =
      const <String, OpenSkillCacheEntry>{};
  final Map<String, Future<List<SeasonSummary>>> _worldSkillsSeasonsCache =
      <String, Future<List<SeasonSummary>>>{};
  final Map<String, Future<List<WorldSkillsEntry>>> _worldSkillsRankingsCache =
      <String, Future<List<WorldSkillsEntry>>>{};
  final Map<String, Future<List<OpenSkillCacheEntry>>> _openSkillRankingsCache =
      <String, Future<List<OpenSkillCacheEntry>>>{};
  final Map<int, Future<int?>> _eventTeamCountCache = <int, Future<int?>>{};
  final Map<String, Future<List<RankingRecord>>> _divisionRankingsCache =
      <String, Future<List<RankingRecord>>>{};
  final Map<String, Future<List<MatchSummary>>> _divisionMatchesCache =
      <String, Future<List<MatchSummary>>>{};
  final Map<int, Future<List<SkillAttempt>>> _eventSkillsCache =
      <int, Future<List<SkillAttempt>>>{};
  final Map<int, Future<List<AwardSummary>>> _eventAwardsCache =
      <int, Future<List<AwardSummary>>>{};
  final Map<String, Future<List<MatchSummary>>> _teamScheduleCache =
      <String, Future<List<MatchSummary>>>{};
  final Map<String, Future<List<MatchSummary>>> _teamMatchHistoryCache =
      <String, Future<List<MatchSummary>>>{};
  final Map<String, Future<SolarMatchPrediction?>> _matchPredictionCache =
      <String, Future<SolarMatchPrediction?>>{};
  final Map<String, Future<TeamStatsSnapshot>> _teamStatsCache =
      <String, Future<TeamStatsSnapshot>>{};
  Future<SolarQuickviewSnapshot?>? _quickviewSnapshotFuture;
  SolarScrimmagePackage? _scrimmagePackage;
  String? _scrimmageTeamKey;

  AppAccount? get currentAccount => _currentAccount;

  TeamStatsSnapshot? get teamStats => _teamStats;

  bool get hasCompletedOnboarding => _hasCompletedOnboarding;

  int? get preferredSeasonId => _preferredSeasonId;

  bool get isRefreshingTeamStats => _isRefreshingTeamStats;

  bool get isPreloadingSearchEvents => _isPreloadingSearchEvents;

  bool get isPreloadingSearchTeams => _isPreloadingSearchTeams;

  List<EventSummary> get preloadedSearchEvents => _preloadedSearchEvents;

  List<TeamSummary> get preloadedSearchTeams => _preloadedSearchTeams;

  List<WorldSkillsEntry> get worldSkillsRankings =>
      _preloadedWorldSkillsRankings;

  String get defaultWorldSkillsGradeLevel {
    final grade = _currentAccount?.team.grade ?? 'High School';
    return _worldSkillsGradeLevel(grade);
  }

  bool get isSignedIn => _currentAccount != null;

  static Future<AppSessionController> bootstrap() async {
    final repository = await _openRepository();
    final api = await _openApi();
    final controller = AppSessionController(
      repository: repository,
      teamDirectory: SolarTeamDirectoryService(api: api),
      api: api,
    );
    await controller.initialize();
    return controller;
  }

  static Future<AccountRepository> _openRepository() async {
    try {
      return await LocalAccountRepository.openDefault();
    } catch (error, stackTrace) {
      debugPrint(
        'Solar startup warning: local account database unavailable. Falling back to in-memory storage.\n$error',
      );
      debugPrintStack(stackTrace: stackTrace);
      return InMemoryAccountRepository();
    }
  }

  static Future<SolarApi> _openApi() async {
    try {
      final config = await AppSolarConfigLoader.load();
      return SolarApi(config: config);
    } catch (error, stackTrace) {
      debugPrint(
        'Solar startup warning: local API config unavailable. Using default config.\n$error',
      );
      debugPrintStack(stackTrace: stackTrace);
      return SolarApi(config: SolarConfig.defaults);
    }
  }

  Future<void> initialize() async {
    final settings = await _repository.loadSettings();
    _hasCompletedOnboarding = settings.hasCompletedOnboarding;
    _preferredSeasonId = settings.preferredSeasonId;

    final currentUserEmail = settings.currentUserEmail;
    if (currentUserEmail != null) {
      _currentAccount = await _repository.findByEmail(currentUserEmail);
    }

    if (_currentAccount != null) {
      _teamStats = _withLocalScrimmage(
        TeamStatsSnapshot(team: _currentAccount!.team),
      );
      _primeSearchEvents(_teamStats!.allEvents);
      unawaited(refreshTeamStats());
    }
  }

  Future<void> completeOnboarding() async {
    _hasCompletedOnboarding = true;
    await _saveSettings(currentUserEmail: _currentAccount?.normalizedEmail);
    notifyListeners();
  }

  Future<void> signIn({required String email, required String password}) async {
    final normalizedEmail = _validateEmail(email);
    if (password.trim().isEmpty) {
      throw const FormatException('Enter your password.');
    }

    final account = await _repository.findByEmail(normalizedEmail);
    if (account == null || account.password != password) {
      throw const FormatException(
        'We could not find an account with that email and password.',
      );
    }

    _currentAccount = account;
    _teamStats = _withLocalScrimmage(TeamStatsSnapshot(team: account.team));
    _primeSearchEvents(_teamStats!.allEvents);
    await _saveSettings(currentUserEmail: account.normalizedEmail);
    notifyListeners();
    await refreshTeamStats();
    unawaited(preloadSearchEvents());
    unawaited(preloadSearchTeams());
  }

  Future<void> signUp({
    required String fullName,
    required String email,
    required String teamNumber,
    required String password,
    required String confirmPassword,
  }) async {
    final normalizedName = fullName.trim();
    if (normalizedName.isEmpty) {
      throw const FormatException('Enter your full name.');
    }

    final normalizedEmail = _validateEmail(email);

    if (password.trim().isEmpty) {
      throw const FormatException('Create a password.');
    }

    if (password != confirmPassword) {
      throw const FormatException('Passwords do not match yet.');
    }

    final existingAccount = await _repository.findByEmail(normalizedEmail);
    if (existingAccount != null) {
      throw const FormatException('An account with that email already exists.');
    }

    final team = await _teamDirectory.validateTeamNumber(
      teamNumber,
      preferredSeasonId: await _resolveActiveSeasonId(),
    );
    final account = AppAccount(
      fullName: normalizedName,
      email: normalizedEmail,
      password: password,
      team: team,
      createdAt: DateTime.now(),
    );

    await _repository.saveAccount(account);
  }

  Future<void> sendResetPassword({required String email}) async {
    final normalizedEmail = _validateEmail(email);
    final account = await _repository.findByEmail(normalizedEmail);
    if (account == null) {
      throw const FormatException(
        'We could not find an account with that email.',
      );
    }
  }

  Future<void> signOut() async {
    _currentAccount = null;
    _teamStats = null;
    _clearTeamDerivedCaches();
    await _saveSettings(clearCurrentUserEmail: true);
    notifyListeners();
  }

  Future<void> refreshTeamStats() async {
    final account = _currentAccount;
    if (account == null || _isRefreshingTeamStats) {
      return;
    }

    _isRefreshingTeamStats = true;
    notifyListeners();

    try {
      final snapshot = await _teamDirectory.loadTeamStats(
        account.team,
        preferredSeasonId: await _resolveActiveSeasonId(),
      );
      if (_currentAccount?.normalizedEmail != account.normalizedEmail) {
        return;
      }

      _teamStats = _withLocalScrimmage(snapshot);
      _quickviewSnapshotFuture = null;
      _primeSearchEvents(
        snapshot.allEvents.isEmpty
            ? snapshot.upcomingEvents
            : snapshot.allEvents,
      );
      _currentAccount = account.copyWith(team: snapshot.team);
      await _repository.saveAccount(_currentAccount!);
      unawaited(preloadSearchEvents());
      unawaited(preloadSearchTeams(force: true));
    } finally {
      _isRefreshingTeamStats = false;
      notifyListeners();
    }
  }

  Future<void> preloadSearchEvents({bool force = false}) async {
    final api = _api;
    if (api == null ||
        !api.config.hasRobotEventsApiKey ||
        _isPreloadingSearchEvents) {
      return;
    }

    final seasonId = await _resolveSearchSeasonId();
    if (seasonId == null) {
      return;
    }

    if (!force &&
        _preloadedSearchSeasonId == seasonId &&
        _preloadedSearchEvents.isNotEmpty) {
      return;
    }

    _isPreloadingSearchEvents = true;
    notifyListeners();

    try {
      final events = await api.robotEvents.fetchEvents(season: seasonId);
      final uniqueEvents = <int, EventSummary>{};
      for (final event in events) {
        uniqueEvents[event.id] = event;
      }

      final sortedEvents = uniqueEvents.values.toList(growable: false)
        ..sort((a, b) {
          final aStart = a.start ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bStart = b.start ?? DateTime.fromMillisecondsSinceEpoch(0);
          return aStart.compareTo(bStart);
        });

      _preloadedSearchSeasonId = seasonId;
      _preloadedSearchEvents = sortedEvents;
      _primeSearchEvents(
        _teamStats?.allEvents ??
            _teamStats?.upcomingEvents ??
            const <EventSummary>[],
      );
    } catch (_) {
      // Keep the locally primed events if the broader preload fails.
    } finally {
      _isPreloadingSearchEvents = false;
      notifyListeners();
    }
  }

  Future<void> preloadSearchTeams({bool force = false}) async {
    final api = _api;
    final account = _currentAccount;
    if (api == null || account == null || _isPreloadingSearchTeams) {
      return;
    }

    final seasonId = await _resolveSearchSeasonId();
    if (seasonId == null) {
      return;
    }

    final gradeLevel = _worldSkillsGradeLevel(account.team.grade);
    if (!force &&
        _preloadedSearchTeamsSeasonId == seasonId &&
        _preloadedSearchTeamsGradeLevel == gradeLevel &&
        _preloadedSearchTeams.isNotEmpty) {
      return;
    }

    _isPreloadingSearchTeams = true;
    notifyListeners();

    try {
      final results = await Future.wait<Object>(<Future<Object>>[
        api.worldSkills
            .fetchRankings(seasonId: seasonId, gradeLevel: gradeLevel)
            .then<Object>((value) => value)
            .catchError((_) => const <WorldSkillsEntry>[]),
        api.roboServer
            .fetchOpenSkillCache(season: seasonId, gradeLevel: gradeLevel)
            .then<Object>((value) => value)
            .catchError((_) => const <OpenSkillCacheEntry>[]),
      ]);

      final worldSkillsEntries = results[0] as List<WorldSkillsEntry>;
      final openSkillEntries = results[1] as List<OpenSkillCacheEntry>;

      final mergedTeams = <String, TeamSummary>{};
      for (final entry in worldSkillsEntries) {
        final team = _teamFromWorldSkills(entry, gradeLevel);
        mergedTeams[team.number.trim().toUpperCase()] = team;
      }

      for (final entry in openSkillEntries) {
        final key = entry.teamNumber.trim().toUpperCase();
        mergedTeams.putIfAbsent(
          key,
          () => _teamFromOpenSkill(entry, account.team.grade),
        );
      }

      mergedTeams[account.team.number.trim().toUpperCase()] = account.team;

      final teams = mergedTeams.values.toList(growable: false)
        ..sort((a, b) => a.number.compareTo(b.number));
      final openSkillByTeam = <String, OpenSkillCacheEntry>{
        for (final entry in openSkillEntries)
          entry.teamNumber.trim().toUpperCase(): entry,
      };
      final rankings = List<WorldSkillsEntry>.from(worldSkillsEntries)
        ..sort((a, b) {
          final aRank = a.rank <= 0 ? 999999 : a.rank;
          final bRank = b.rank <= 0 ? 999999 : b.rank;
          return aRank.compareTo(bRank);
        });

      _preloadedSearchTeamsSeasonId = seasonId;
      _preloadedSearchTeamsGradeLevel = gradeLevel;
      _preloadedSearchTeams = teams;
      _preloadedWorldSkillsRankings = rankings;
      _preloadedOpenSkillEntriesByTeam = openSkillByTeam;
      _scrimmagePackage = null;
      _scrimmageTeamKey = null;
      _quickviewSnapshotFuture = null;
      if (_teamStats != null) {
        _teamStats = _withLocalScrimmage(_teamStats!);
      }
    } catch (_) {
      // Keep the current team-only fallback if the wider preload fails.
    } finally {
      _isPreloadingSearchTeams = false;
      notifyListeners();
    }
  }

  OpenSkillCacheEntry? openSkillEntryForTeam(String teamNumber) {
    return _preloadedOpenSkillEntriesByTeam[teamNumber.trim().toUpperCase()];
  }

  Future<int?> resolveDefaultWorldSkillsSeasonId() {
    return _resolveActiveSeasonId();
  }

  Future<List<SeasonSummary>> fetchWorldSkillsSeasons({
    String programFilter = 'V5RC',
    bool force = false,
  }) {
    final cacheKey = programFilter.trim().toLowerCase();
    if (force) {
      _worldSkillsSeasonsCache.remove(cacheKey);
    }

    return _worldSkillsSeasonsCache.putIfAbsent(cacheKey, () async {
      final api = _api;
      if (api == null || !api.config.hasRobotEventsApiKey) {
        return const <SeasonSummary>[];
      }

      try {
        final seasons = await api.robotEvents.fetchSeasons();
        seasons.sort((a, b) => b.id.compareTo(a.id));
        return seasons
            .where((season) {
              return _matchesSeasonProgramFilter(season, programFilter);
            })
            .toList(growable: false);
      } catch (_) {
        return const <SeasonSummary>[];
      }
    });
  }

  Future<List<WorldSkillsEntry>> fetchWorldSkillsRankings({
    required int seasonId,
    required String gradeLevel,
    bool force = false,
  }) {
    final cacheKey = '$seasonId|${gradeLevel.trim().toLowerCase()}';
    if (force) {
      _worldSkillsRankingsCache.remove(cacheKey);
    }

    return _worldSkillsRankingsCache.putIfAbsent(cacheKey, () async {
      final api = _api;
      if (api == null) {
        return const <WorldSkillsEntry>[];
      }

      try {
        final entries = await api.worldSkills.fetchRankings(
          seasonId: seasonId,
          gradeLevel: gradeLevel,
        );
        entries.sort((a, b) {
          final aRank = a.rank <= 0 ? 999999 : a.rank;
          final bRank = b.rank <= 0 ? 999999 : b.rank;
          return aRank.compareTo(bRank);
        });
        return entries;
      } catch (_) {
        return const <WorldSkillsEntry>[];
      }
    });
  }

  Future<List<OpenSkillCacheEntry>> fetchOpenSkillRankings({
    required int seasonId,
    required String gradeLevel,
    bool force = false,
  }) {
    final cacheKey = '$seasonId|${gradeLevel.trim().toLowerCase()}';
    if (force) {
      _openSkillRankingsCache.remove(cacheKey);
    }

    return _openSkillRankingsCache.putIfAbsent(cacheKey, () async {
      final api = _api;
      if (api == null) {
        return const <OpenSkillCacheEntry>[];
      }

      try {
        final entries = await api.roboServer.fetchOpenSkillCache(
          season: seasonId,
          gradeLevel: gradeLevel,
          forceRefresh: force,
        );
        entries.sort((a, b) {
          final aRank = a.ranking <= 0 ? 999999 : a.ranking;
          final bRank = b.ranking <= 0 ? 999999 : b.ranking;
          return aRank.compareTo(bRank);
        });
        return entries;
      } catch (_) {
        return const <OpenSkillCacheEntry>[];
      }
    });
  }

  List<EventSummary> searchCachedEvents(String query, {int? limit}) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.length < 2) {
      return const <EventSummary>[];
    }

    final matchingEvents = _preloadedSearchEvents.where((event) {
      final haystack = <String>[
        event.name,
        event.sku,
        event.location.city,
        event.location.region,
        event.location.country,
      ].join(' ').toLowerCase();
      return haystack.contains(normalizedQuery);
    }).toList();

    matchingEvents.sort((a, b) {
      final aExact = _eventRelevance(a, normalizedQuery);
      final bExact = _eventRelevance(b, normalizedQuery);
      if (aExact != bExact) {
        return bExact.compareTo(aExact);
      }

      final aStart = a.start ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bStart = b.start ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aStart.compareTo(bStart);
    });

    if (limit == null) {
      return matchingEvents;
    }
    return matchingEvents.take(limit).toList(growable: false);
  }

  List<TeamSummary> searchCachedTeams(String query, {int? limit}) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.length < 2) {
      return const <TeamSummary>[];
    }

    final mergedTeams = <String, TeamSummary>{};
    final currentTeam = _currentAccount?.team;

    if (currentTeam != null &&
        _matchesTeamQuery(currentTeam, normalizedQuery)) {
      mergedTeams[currentTeam.number.trim().toUpperCase()] = currentTeam;
    }

    for (final team in _preloadedSearchTeams) {
      if (_matchesTeamQuery(team, normalizedQuery)) {
        mergedTeams[team.number.trim().toUpperCase()] = team;
      }
    }

    final teams = mergedTeams.values.toList(growable: false)
      ..sort((a, b) {
        final aScore = _teamRelevance(a, normalizedQuery);
        final bScore = _teamRelevance(b, normalizedQuery);
        if (aScore != bScore) {
          return bScore.compareTo(aScore);
        }
        return a.number.compareTo(b.number);
      });

    if (limit == null) {
      return teams;
    }
    return teams.take(limit).toList(growable: false);
  }

  Future<TeamStatsSnapshot> fetchTeamStatsSnapshot(
    TeamSummary team, {
    bool force = false,
  }) async {
    final normalizedKey = team.number.trim().toUpperCase();
    final activeSeasonId = await _resolveActiveSeasonId();
    final cacheKey = '$normalizedKey|${activeSeasonId ?? 0}';
    final currentTeam = _currentAccount?.team;

    if (currentTeam != null &&
        currentTeam.number.trim().toUpperCase() == normalizedKey) {
      if (force) {
        await refreshTeamStats();
      }
      if (_teamStats != null) {
        return _teamStats!;
      }
    }

    if (force) {
      _teamStatsCache.remove(cacheKey);
    }

    return _teamStatsCache.putIfAbsent(cacheKey, () async {
      return _teamDirectory.loadTeamStats(
        team,
        preferredSeasonId: activeSeasonId,
      );
    });
  }

  Future<int?> _resolveSearchSeasonId() async {
    return _resolveActiveSeasonId();
  }

  Future<int?> _resolveActiveSeasonId() async {
    if (_preferredSeasonId != null) {
      return _preferredSeasonId;
    }

    final seasons = await fetchWorldSkillsSeasons();
    if (seasons.isNotEmpty) {
      return seasons.first.id;
    }

    final upcomingEvents = _teamStats?.futureEvents ?? const <EventSummary>[];
    final currentSeasonId = upcomingEvents.isNotEmpty
        ? upcomingEvents.first.seasonId
        : null;
    if (currentSeasonId != null) {
      return currentSeasonId;
    }

    final allEvents = _teamStats?.allEvents ?? const <EventSummary>[];
    if (allEvents.isNotEmpty) {
      return allEvents.last.seasonId;
    }
    return null;
  }

  void _primeSearchEvents(List<EventSummary> events) {
    if (events.isEmpty) {
      return;
    }

    final merged = <int, EventSummary>{
      for (final event in _preloadedSearchEvents) event.id: event,
      for (final event in events) event.id: event,
    };

    _preloadedSearchEvents = merged.values.toList(growable: false)
      ..sort((a, b) {
        final aStart = a.start ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bStart = b.start ?? DateTime.fromMillisecondsSinceEpoch(0);
        return aStart.compareTo(bStart);
      });
  }

  Future<void> updateProfile({required String fullName}) async {
    final account = _currentAccount;
    if (account == null) {
      return;
    }

    final normalizedName = fullName.trim();
    if (normalizedName.isEmpty) {
      throw const FormatException('Enter your full name.');
    }

    _currentAccount = account.copyWith(fullName: normalizedName);
    await _repository.saveAccount(_currentAccount!);
    notifyListeners();
  }

  Future<void> updateTeam({required String teamNumber}) async {
    final account = _currentAccount;
    if (account == null) {
      return;
    }

    final normalizedNumber = teamNumber.trim().toUpperCase();
    if (normalizedNumber.isEmpty) {
      throw const FormatException('Enter your team number.');
    }

    if (normalizedNumber == account.team.number.trim().toUpperCase()) {
      return;
    }

    final activeSeasonId = await _resolveActiveSeasonId();
    final validatedTeam = await _teamDirectory.validateTeamNumber(
      normalizedNumber,
      preferredSeasonId: activeSeasonId,
    );
    _currentAccount = account.copyWith(team: validatedTeam);
    _teamStats = _withLocalScrimmage(TeamStatsSnapshot(team: validatedTeam));
    _clearTeamDerivedCaches();
    await _repository.saveAccount(_currentAccount!);
    notifyListeners();
    await refreshTeamStats();
  }

  Future<void> updatePreferredSeason({
    required int? seasonId,
    bool refresh = true,
  }) async {
    if (_preferredSeasonId == seasonId) {
      return;
    }

    _preferredSeasonId = seasonId;
    _clearTeamDerivedCaches();
    if (_currentAccount != null) {
      _teamStats = _withLocalScrimmage(
        TeamStatsSnapshot(team: _currentAccount!.team),
      );
    }

    await _saveSettings(currentUserEmail: _currentAccount?.normalizedEmail);
    notifyListeners();

    if (refresh && _currentAccount != null) {
      await refreshTeamStats();
    }
  }

  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final account = _currentAccount;
    if (account == null) {
      return;
    }

    if (currentPassword != account.password) {
      throw const FormatException('Your current password does not match.');
    }

    if (newPassword.trim().isEmpty) {
      throw const FormatException('Enter a new password.');
    }

    if (newPassword != confirmPassword) {
      throw const FormatException('New passwords do not match.');
    }

    _currentAccount = account.copyWith(password: newPassword);
    await _repository.saveAccount(_currentAccount!);
    notifyListeners();
  }

  Future<int?> fetchEventTeamCount(int eventId) {
    final scrimmage = _scrimmagePackageForCurrentTeam();
    if (scrimmage != null && eventId == scrimmage.event.id) {
      return Future<int?>.value(scrimmage.teamCount);
    }

    return _eventTeamCountCache.putIfAbsent(eventId, () async {
      final api = _api;
      if (api == null || !api.config.hasRobotEventsApiKey) {
        return null;
      }

      try {
        final teams = await api.robotEvents.fetchEventTeams(eventId);
        return teams.length;
      } catch (_) {
        return null;
      }
    });
  }

  bool isCurrentTeamEvent(int eventId) {
    return (_teamStats?.allEvents ??
            _teamStats?.upcomingEvents ??
            const <EventSummary>[])
        .any((event) => event.id == eventId);
  }

  EventSummary? resolveKnownEvent(int eventId) {
    final scrimmage = _scrimmagePackageForCurrentTeam();
    if (scrimmage != null && eventId == scrimmage.event.id) {
      return scrimmage.event;
    }

    for (final event in _teamStats?.allEvents ?? const <EventSummary>[]) {
      if (event.id == eventId) {
        return event;
      }
    }

    for (final event in _teamStats?.upcomingEvents ?? const <EventSummary>[]) {
      if (event.id == eventId) {
        return event;
      }
    }

    for (final event in _preloadedSearchEvents) {
      if (event.id == eventId) {
        return event;
      }
    }

    return null;
  }

  DivisionSummary? currentTeamDivisionForEvent(int eventId) {
    final scrimmage = _scrimmagePackageForCurrentTeam();
    if (scrimmage != null && eventId == scrimmage.event.id) {
      return scrimmage.division;
    }

    final matchingRankings = (_teamStats?.rankings ?? const <RankingRecord>[])
        .where((ranking) => ranking.event.id == eventId)
        .toList(growable: false);
    if (matchingRankings.isEmpty) {
      return null;
    }
    return matchingRankings.first.division;
  }

  Future<List<RankingRecord>> fetchDivisionRankings({
    required int eventId,
    required int divisionId,
  }) {
    final scrimmage = _scrimmagePackageForCurrentTeam();
    if (scrimmage != null &&
        eventId == scrimmage.event.id &&
        divisionId == scrimmage.division.id) {
      return Future<List<RankingRecord>>.value(scrimmage.rankings);
    }

    final cacheKey = '$eventId:$divisionId';
    return _divisionRankingsCache.putIfAbsent(cacheKey, () async {
      final api = _api;
      if (api == null || !api.config.hasRobotEventsApiKey) {
        return const <RankingRecord>[];
      }

      try {
        final rankings = await api.robotEvents.fetchDivisionRankings(
          eventId: eventId,
          divisionId: divisionId,
        );
        rankings.sort((a, b) => a.rank.compareTo(b.rank));
        return rankings;
      } catch (_) {
        return const <RankingRecord>[];
      }
    });
  }

  Future<List<MatchSummary>> fetchDivisionMatches({
    required int eventId,
    required int divisionId,
  }) {
    final scrimmage = _scrimmagePackageForCurrentTeam();
    if (scrimmage != null &&
        eventId == scrimmage.event.id &&
        divisionId == scrimmage.division.id) {
      return Future<List<MatchSummary>>.value(scrimmage.matches);
    }

    final cacheKey = '$eventId:$divisionId';
    return _divisionMatchesCache.putIfAbsent(cacheKey, () async {
      final api = _api;
      if (api == null || !api.config.hasRobotEventsApiKey) {
        return const <MatchSummary>[];
      }

      try {
        final matches = await api.robotEvents.fetchDivisionMatches(
          eventId: eventId,
          divisionId: divisionId,
        );
        matches.sort((a, b) {
          final aDate =
              a.started ??
              a.scheduled ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bDate =
              b.started ??
              b.scheduled ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return aDate.compareTo(bDate);
        });
        return matches;
      } catch (_) {
        return const <MatchSummary>[];
      }
    });
  }

  Future<List<SkillAttempt>> fetchEventSkills(int eventId) {
    final scrimmage = _scrimmagePackageForCurrentTeam();
    if (scrimmage != null && eventId == scrimmage.event.id) {
      return Future<List<SkillAttempt>>.value(scrimmage.skills);
    }

    return _eventSkillsCache.putIfAbsent(eventId, () async {
      final api = _api;
      if (api == null || !api.config.hasRobotEventsApiKey) {
        return const <SkillAttempt>[];
      }

      try {
        final skills = await api.robotEvents.fetchEventSkills(eventId);
        skills.sort((a, b) {
          final aRank = a.rank <= 0 ? 999999 : a.rank;
          final bRank = b.rank <= 0 ? 999999 : b.rank;
          return aRank.compareTo(bRank);
        });
        return skills;
      } catch (_) {
        return const <SkillAttempt>[];
      }
    });
  }

  Future<List<AwardSummary>> fetchEventAwards(int eventId) {
    final scrimmage = _scrimmagePackageForCurrentTeam();
    if (scrimmage != null && eventId == scrimmage.event.id) {
      return Future<List<AwardSummary>>.value(const <AwardSummary>[]);
    }

    return _eventAwardsCache.putIfAbsent(eventId, () async {
      final api = _api;
      if (api == null || !api.config.hasRobotEventsApiKey) {
        return const <AwardSummary>[];
      }

      try {
        final awards = await api.robotEvents.fetchEventAwards(eventId);
        awards.sort((a, b) {
          if (a.order != b.order) {
            return a.order.compareTo(b.order);
          }
          return a.title.compareTo(b.title);
        });
        return awards;
      } catch (_) {
        return const <AwardSummary>[];
      }
    });
  }

  Future<List<MatchSummary>> fetchTeamScheduleForEvent(int eventId) {
    final account = _currentAccount;
    if (account == null) {
      return Future<List<MatchSummary>>.value(const <MatchSummary>[]);
    }

    final scrimmage = _scrimmagePackageForCurrentTeam();
    if (scrimmage != null && eventId == scrimmage.event.id) {
      final teamNumber = account.team.number.trim().toUpperCase();
      final matches = scrimmage.matches
          .where((match) {
            for (final alliance in match.alliances) {
              for (final team in alliance.teams) {
                if (team.number.trim().toUpperCase() == teamNumber) {
                  return true;
                }
              }
            }
            return false;
          })
          .toList(growable: false);
      return Future<List<MatchSummary>>.value(matches);
    }

    final cacheKey = '${account.team.id}:$eventId';
    return _teamScheduleCache.putIfAbsent(cacheKey, () async {
      final api = _api;
      if (api == null || !api.config.hasRobotEventsApiKey) {
        return const <MatchSummary>[];
      }

      try {
        final matches = await api.robotEvents.fetchTeamMatches(
          account.team.id,
          eventId: eventId,
        );
        matches.sort((a, b) {
          final aDate =
              a.started ??
              a.scheduled ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bDate =
              b.started ??
              b.scheduled ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return aDate.compareTo(bDate);
        });
        return matches;
      } catch (_) {
        return const <MatchSummary>[];
      }
    });
  }

  Future<List<MatchSummary>> fetchTeamMatchesForReference(
    TeamReference team, {
    int? season,
    int? eventId,
    bool force = false,
  }) {
    if (team.id <= 0) {
      return Future<List<MatchSummary>>.value(const <MatchSummary>[]);
    }

    final cacheKey = '${team.id}:${season ?? 0}:${eventId ?? 0}';
    if (force) {
      _teamMatchHistoryCache.remove(cacheKey);
    }

    return _teamMatchHistoryCache.putIfAbsent(cacheKey, () async {
      final api = _api;
      if (api == null || !api.config.hasRobotEventsApiKey) {
        return const <MatchSummary>[];
      }

      try {
        final matches = await api.robotEvents.fetchTeamMatches(
          team.id,
          season: season,
          eventId: eventId,
        );
        matches.sort((a, b) {
          final aDate =
              a.started ??
              a.scheduled ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bDate =
              b.started ??
              b.scheduled ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return aDate.compareTo(bDate);
        });
        return matches;
      } catch (_) {
        return const <MatchSummary>[];
      }
    });
  }

  Future<SolarQuickviewSnapshot?> fetchQuickviewSnapshot() async {
    if (_quickviewSnapshotFuture != null) {
      return _quickviewSnapshotFuture!;
    }

    final future = _loadQuickviewSnapshot();
    _quickviewSnapshotFuture = future;
    return future;
  }

  Future<SolarQuickviewSnapshot?> _loadQuickviewSnapshot() async {
    if (_preloadedWorldSkillsRankings.isEmpty &&
        _currentAccount != null &&
        !_isPreloadingSearchTeams) {
      await preloadSearchTeams();
    }

    final teamStats = _teamStats;
    if (teamStats == null) {
      return null;
    }

    final futureEvents = teamStats.futureEvents;
    if (futureEvents.isEmpty) {
      return null;
    }

    for (final event in futureEvents) {
      final schedule = await fetchTeamScheduleForEvent(event.id);
      final qualificationMatches = schedule
          .where((match) {
            return match.round == MatchRound.qualification;
          })
          .toList(growable: false);
      final futureMatches = qualificationMatches
          .where((match) {
            return _isFuturePendingMatch(match);
          })
          .toList(growable: false);

      if (futureMatches.isNotEmpty) {
        return SolarQuickviewSnapshot(
          event: event,
          nextQualifyingMatch: futureMatches.first,
          futureMatches: futureMatches,
        );
      }
    }

    final fallbackEvent = futureEvents.first;
    final fallbackSchedule = await fetchTeamScheduleForEvent(fallbackEvent.id);
    final fallbackMatches = fallbackSchedule
        .where((match) {
          return _isFuturePendingMatch(match);
        })
        .toList(growable: false);

    return SolarQuickviewSnapshot(
      event: fallbackEvent,
      nextQualifyingMatch: fallbackMatches.isEmpty
          ? null
          : fallbackMatches.first,
      futureMatches: fallbackMatches,
    );
  }

  Future<SolarMatchPrediction?> predictMatch({
    required MatchSummary match,
    EventSummary? event,
    bool force = false,
  }) {
    final knownEvent = event ?? resolveKnownEvent(match.event.id);
    final cacheKey = '${match.id}:${knownEvent?.seasonId ?? 0}';
    if (force) {
      _matchPredictionCache.remove(cacheKey);
    }

    return _matchPredictionCache.putIfAbsent(cacheKey, () async {
      final api = _api;
      if (api == null || !api.config.hasRobotEventsApiKey) {
        return null;
      }

      if (_preloadedSearchTeams.isEmpty &&
          _currentAccount != null &&
          !_isPreloadingSearchTeams) {
        await preloadSearchTeams();
      }

      final divisionMatches = await fetchDivisionMatches(
        eventId: match.event.id,
        divisionId: match.division.id,
      );
      final seasonId = knownEvent?.seasonId;
      final eventSkills = await fetchEventSkills(match.event.id);
      final allTeams = <TeamReference>[
        for (final alliance in match.alliances) ...alliance.teams,
      ];
      final uniqueTeams = <int, TeamReference>{};
      for (final team in allTeams) {
        if (team.id > 0) {
          uniqueTeams[team.id] = team;
        }
      }

      final seasonMatchEntries =
          await Future.wait<MapEntry<int, List<MatchSummary>>>(
            uniqueTeams.values.map((team) async {
              final matches = await fetchTeamMatchesForReference(
                team,
                season: seasonId,
              );
              return MapEntry<int, List<MatchSummary>>(team.id, matches);
            }),
          );

      final seasonMatchesByTeam = <int, List<MatchSummary>>{
        for (final entry in seasonMatchEntries) entry.key: entry.value,
      };
      final worldSkillsByTeam = <String, WorldSkillsEntry>{
        for (final entry in _preloadedWorldSkillsRankings)
          entry.teamNumber.trim().toUpperCase(): entry,
      };

      return _matchPredictionService.predictMatch(
        match: match,
        event: knownEvent,
        divisionMatches: divisionMatches,
        seasonMatchesByTeamId: seasonMatchesByTeam,
        openSkillByTeam: _preloadedOpenSkillEntriesByTeam,
        worldSkillsByTeam: worldSkillsByTeam,
        eventSkills: eventSkills,
      );
    });
  }

  TeamSummary resolveKnownTeamSummary({
    required String teamNumber,
    int? teamId,
    String teamName = '',
    String organization = '',
    String robotName = '',
    String? grade,
  }) {
    final normalizedNumber = teamNumber.trim().toUpperCase();
    final currentTeam = _currentAccount?.team;

    if (currentTeam != null &&
        (currentTeam.number.trim().toUpperCase() == normalizedNumber ||
            (teamId != null && currentTeam.id == teamId))) {
      return currentTeam;
    }

    for (final team in _preloadedSearchTeams) {
      if (team.number.trim().toUpperCase() == normalizedNumber ||
          (teamId != null && team.id == teamId)) {
        return team;
      }
    }

    for (final entry in _preloadedWorldSkillsRankings) {
      if (entry.teamNumber.trim().toUpperCase() == normalizedNumber ||
          (teamId != null && entry.teamId == teamId)) {
        return _teamFromWorldSkills(
          entry,
          grade ?? currentTeam?.grade ?? 'High School',
        );
      }
    }

    final openSkillEntry = _preloadedOpenSkillEntriesByTeam[normalizedNumber];
    if (openSkillEntry != null) {
      return _teamFromOpenSkill(
        openSkillEntry,
        grade ?? currentTeam?.grade ?? 'High School',
      );
    }

    return TeamSummary(
      id: teamId ?? 0,
      number: normalizedNumber,
      teamName: teamName,
      organization: organization,
      robotName: robotName,
      location: const LocationSummary(
        venue: '',
        address1: '',
        city: '',
        region: '',
        postcode: '',
        country: '',
      ),
      grade: grade ?? currentTeam?.grade ?? 'High School',
      registered: true,
    );
  }

  TeamStatsSnapshot _withLocalScrimmage(TeamStatsSnapshot snapshot) {
    final scrimmage = _scrimmagePackageForTeam(snapshot.team);
    if (scrimmage == null) {
      return snapshot;
    }

    final allEvents = _mergeEventLists(snapshot.allEvents, <EventSummary>[
      scrimmage.event,
    ]);
    final upcomingEvents = _mergeEventLists(
      snapshot.upcomingEvents,
      <EventSummary>[scrimmage.event],
    );

    return TeamStatsSnapshot(
      team: snapshot.team,
      allEvents: allEvents,
      upcomingEvents: upcomingEvents,
      rankings: snapshot.rankings,
      openSkillEntry: snapshot.openSkillEntry,
      worldSkillsEntry: snapshot.worldSkillsEntry,
      lastUpdated: snapshot.lastUpdated,
      errorMessage: snapshot.errorMessage,
    );
  }

  SolarScrimmagePackage? _scrimmagePackageForCurrentTeam() {
    final team = _currentAccount?.team ?? _teamStats?.team;
    if (team == null) {
      return null;
    }
    return _scrimmagePackageForTeam(team);
  }

  SolarScrimmagePackage? _scrimmagePackageForTeam(TeamSummary team) {
    final normalizedTeamKey = team.number.trim().toUpperCase();
    final existing = _scrimmagePackage;
    if (existing != null && _scrimmageTeamKey == normalizedTeamKey) {
      return existing;
    }

    _scrimmagePackage = _scrimmageService.build(
      currentTeam: team,
      worldSkills: _preloadedWorldSkillsRankings,
      openSkillByTeam: _preloadedOpenSkillEntriesByTeam,
    );
    _scrimmageTeamKey = normalizedTeamKey;
    return _scrimmagePackage;
  }

  List<EventSummary> _mergeEventLists(
    List<EventSummary> base,
    List<EventSummary> overlay,
  ) {
    final merged = <int, EventSummary>{
      for (final event in base) event.id: event,
      for (final event in overlay) event.id: event,
    };

    return merged.values.toList(growable: false)..sort((a, b) {
      final aStart = a.start ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bStart = b.start ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aStart.compareTo(bStart);
    });
  }

  bool _matchesTeamQuery(TeamSummary team, String query) {
    final haystack = <String>[
      team.number,
      team.teamName,
      team.organization,
      team.location.city,
      team.location.region,
    ].join(' ').toLowerCase();
    return haystack.contains(query);
  }

  int _eventRelevance(EventSummary event, String query) {
    final name = event.name.toLowerCase();
    final sku = event.sku.toLowerCase();
    final city = event.location.city.toLowerCase();
    if (name.startsWith(query) || sku == query) {
      return 3;
    }
    if (name.contains(query) || city.startsWith(query)) {
      return 2;
    }
    return 1;
  }

  int _teamRelevance(TeamSummary team, String query) {
    final number = team.number.toLowerCase();
    final name = team.teamName.toLowerCase();
    if (number == query || name == query) {
      return 3;
    }
    if (number.startsWith(query) || name.startsWith(query)) {
      return 2;
    }
    return 1;
  }

  bool _isFuturePendingMatch(MatchSummary match) {
    final now = DateTime.now();
    final anchor = match.scheduled ?? match.started;
    final hasOfficialScores =
        match.alliances.length >= 2 &&
        match.alliances.every((alliance) => alliance.score >= 0);
    return !hasOfficialScores && (anchor == null || !anchor.isBefore(now));
  }

  void _clearTeamDerivedCaches() {
    _preloadedSearchEvents = const <EventSummary>[];
    _preloadedSearchSeasonId = null;
    _preloadedSearchTeams = const <TeamSummary>[];
    _preloadedSearchTeamsSeasonId = null;
    _preloadedSearchTeamsGradeLevel = null;
    _preloadedWorldSkillsRankings = const <WorldSkillsEntry>[];
    _preloadedOpenSkillEntriesByTeam = const <String, OpenSkillCacheEntry>{};
    _openSkillRankingsCache.clear();
    _eventTeamCountCache.clear();
    _divisionRankingsCache.clear();
    _divisionMatchesCache.clear();
    _eventSkillsCache.clear();
    _eventAwardsCache.clear();
    _teamScheduleCache.clear();
    _teamMatchHistoryCache.clear();
    _matchPredictionCache.clear();
    _teamStatsCache.clear();
    _quickviewSnapshotFuture = null;
    _scrimmagePackage = null;
    _scrimmageTeamKey = null;
  }

  TeamSummary _teamFromWorldSkills(WorldSkillsEntry entry, String gradeLevel) {
    return TeamSummary(
      id: entry.teamId,
      number: entry.teamNumber,
      teamName: entry.teamName,
      organization: entry.organization,
      robotName: '',
      location: LocationSummary(
        venue: '',
        address1: '',
        city: entry.city,
        region: entry.region,
        postcode: '',
        country: entry.country,
      ),
      grade: gradeLevel,
      registered: true,
    );
  }

  TeamSummary _teamFromOpenSkill(OpenSkillCacheEntry entry, String grade) {
    return TeamSummary(
      id: entry.id,
      number: entry.teamNumber,
      teamName: '',
      organization: '',
      robotName: '',
      location: LocationSummary(
        venue: '',
        address1: '',
        city: '',
        region: entry.region,
        postcode: '',
        country: entry.country,
      ),
      grade: grade,
      registered: true,
    );
  }

  String _worldSkillsGradeLevel(String grade) {
    final normalized = grade.trim().toLowerCase();
    if (normalized.contains('middle')) {
      return 'Middle School';
    }
    if (normalized.contains('college')) {
      return 'College';
    }
    return 'High School';
  }

  bool _matchesSeasonProgramFilter(SeasonSummary season, String programFilter) {
    final normalizedFilter = programFilter.trim().toLowerCase();
    if (normalizedFilter.isEmpty) {
      return true;
    }

    final haystack = '${season.name} ${season.programName}'
        .trim()
        .toLowerCase();
    if (normalizedFilter == 'v5rc') {
      return haystack.contains('v5') ||
          haystack.contains('vrc') ||
          haystack.contains('robotics competition');
    }
    return haystack.contains(normalizedFilter);
  }

  Future<void> _saveSettings({
    String? currentUserEmail,
    bool clearCurrentUserEmail = false,
  }) {
    return _repository.saveSettings(
      AppSettings(
        hasCompletedOnboarding: _hasCompletedOnboarding,
        currentUserEmail: clearCurrentUserEmail ? null : currentUserEmail,
        preferredSeasonId: _preferredSeasonId,
      ),
    );
  }

  String _validateEmail(String email) {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) {
      throw const FormatException('Enter a valid email address.');
    }
    return normalizedEmail;
  }

  @override
  void dispose() {
    unawaited(_repository.close());
    _api?.close();
    super.dispose();
  }
}
