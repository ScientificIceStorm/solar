import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config/solar_config.dart';
import '../core/solar_competition_scope.dart';
import '../models/open_skill_models.dart';
import '../models/robot_events_models.dart';
import '../models/world_skills_models.dart';
import '../solar_api.dart';
import 'app_solar_config_loader.dart';
import 'solar_ios_companion_service.dart';
import '../ui/models/app_account.dart';
import '../ui/models/solar_match_prediction.dart';
import '../ui/models/solar_notification_center_snapshot.dart';
import '../ui/models/team_stats_snapshot.dart';
import '../ui/models/worlds_schedule_models.dart';
import '../ui/services/account_repository.dart';
import '../ui/services/in_memory_account_repository.dart';
import '../ui/services/local_account_repository.dart';
import '../ui/services/solar_auth_service.dart';
import '../ui/services/solar_disk_cache_store.dart';
import '../ui/services/solar_match_prediction_service.dart';
import '../ui/services/solar_scrimmage_service.dart';
import '../ui/services/solarize_history_service.dart';
import '../ui/services/team_directory_service.dart';

class AppSessionController extends ChangeNotifier {
  AppSessionController({
    required AccountRepository repository,
    required TeamDirectoryService teamDirectory,
    SolarApi? api,
    SolarAuthService? authService,
  }) : _repository = repository,
       _teamDirectory = teamDirectory,
       _api = api,
       _authService =
           authService ?? LocalSolarAuthService(repository: repository);

  final AccountRepository _repository;
  final TeamDirectoryService _teamDirectory;
  final SolarApi? _api;
  final SolarAuthService _authService;
  static const _matchPredictionService = SolarMatchPredictionService();
  static const _scrimmageService = SolarScrimmageService();
  static const _solarizeHistoryService = SolarizeHistoryService();
  static const _iosCompanionService = SolarIosCompanionService();
  static final _diskCacheStore = SolarDiskCacheStore.instance;
  static const _solarizeHistoryTeamLimit = 768;
  static const _solarizeHistoryBatchSize = 12;
  static const _solarizeMatchHistoryTeamLimit = 512;
  static const _solarizeMatchHistoryBatchSize = 8;
  static const _worldsScheduleAnnouncementKey = worldsScheduleAnnouncementId;
  static const _localAccountDomain = 'solar.local';
  static const _teamScheduleCacheNamespace = 'team_schedule_v1';

  AppAccount? _currentAccount;
  TeamStatsSnapshot? _teamStats;
  bool _hasCompletedOnboarding = false;
  bool _isPasswordRecoveryActive = false;
  int? _preferredSeasonId;
  AppThemeModePreference _themeModePreference = AppThemeModePreference.system;
  AppCompetitionPreference _competitionPreference =
      AppCompetitionPreference.vexV5;
  AppFollowMode _followMode = AppFollowMode.single;
  AppChromeAccentPreference _chromeAccentPreference =
      AppChromeAccentPreference.midnight;
  int? _customChromeAccentValue;
  String? _dismissedWorldsScheduleAnnouncementId;
  int? _notificationCenterSeenAtMillis;
  List<String> _favoriteTeamNumbers = const <String>[];
  List<int> _bookmarkedEventIds = const <int>[];
  bool _developerScrimmageEnabled = false;
  int? _developerScrimmageStartAtMillis;
  Map<String, int> _teamRatings = const <String, int>{};
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
  final Map<String, Future<List<RankingRecord>>> _teamRankingsCache =
      <String, Future<List<RankingRecord>>>{};
  final Map<int, Future<int?>> _eventTeamCountCache = <int, Future<int?>>{};
  final Map<int, Future<List<TeamSummary>>> _eventTeamsCache =
      <int, Future<List<TeamSummary>>>{};
  final Map<String, Future<List<RankingRecord>>> _divisionRankingsCache =
      <String, Future<List<RankingRecord>>>{};
  final Map<String, Future<List<MatchSummary>>> _divisionMatchesCache =
      <String, Future<List<MatchSummary>>>{};
  final Map<int, Future<List<SkillAttempt>>> _eventSkillsCache =
      <int, Future<List<SkillAttempt>>>{};
  final Map<int, Future<List<AwardSummary>>> _eventAwardsCache =
      <int, Future<List<AwardSummary>>>{};
  final Map<String, Future<int>> _teamAwardsCountCache =
      <String, Future<int>>{};
  final Map<String, Future<List<MatchSummary>>> _teamScheduleCache =
      <String, Future<List<MatchSummary>>>{};
  final Map<String, Future<List<MatchSummary>>> _teamMatchHistoryCache =
      <String, Future<List<MatchSummary>>>{};
  final Map<String, Future<List<TeamSummary>>> _liveSearchTeamRequestCache =
      <String, Future<List<TeamSummary>>>{};
  final Map<String, List<TeamSummary>> _liveSearchTeamsByQuery =
      <String, List<TeamSummary>>{};
  final Set<String> _solarizeCoverageInflight = <String>{};
  final Map<String, Future<SolarMatchPrediction?>> _matchPredictionCache =
      <String, Future<SolarMatchPrediction?>>{};
  final Map<String, Future<TeamStatsSnapshot>> _teamStatsCache =
      <String, Future<TeamStatsSnapshot>>{};
  Future<SolarQuickviewSnapshot?>? _quickviewSnapshotFuture;
  Future<SolarNotificationCenterSnapshot>? _notificationCenterSnapshotFuture;
  SolarScrimmagePackage? _scrimmagePackage;
  String? _scrimmageTeamKey;
  StreamSubscription<SolarAuthStateChange>? _authStateSubscription;

  AppAccount? get currentAccount => _currentAccount;

  TeamStatsSnapshot? get teamStats => _teamStats;

  bool get hasCompletedOnboarding => _hasCompletedOnboarding;

  bool get isPasswordRecoveryActive => _isPasswordRecoveryActive;

  int? get preferredSeasonId => _preferredSeasonId;

  AppThemeModePreference get themeModePreference => _themeModePreference;

  AppCompetitionPreference get competitionPreference => _competitionPreference;

  AppFollowMode get followMode => _followMode;

  AppChromeAccentPreference get chromeAccentPreference =>
      _chromeAccentPreference;

  int? get customChromeAccentValue => _customChromeAccentValue;

  int? get notificationCenterSeenAtMillis => _notificationCenterSeenAtMillis;

  List<String> get favoriteTeamNumbers => _favoriteTeamNumbers;

  List<int> get bookmarkedEventIds => _bookmarkedEventIds;

  bool get developerScrimmageEnabled => _developerScrimmageEnabled;

  DateTime? get developerScrimmageStartAt =>
      _developerScrimmageStartAtMillis == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(_developerScrimmageStartAtMillis!);

  bool isFavoriteTeam(String teamNumber) {
    final normalized = teamNumber.trim().toUpperCase();
    return _favoriteTeamNumbers.contains(normalized);
  }

  int teamRatingFor(String teamNumber) {
    return _teamRatings[teamNumber.trim().toUpperCase()] ?? 0;
  }

  bool isBookmarkedEvent(int eventId) {
    return _bookmarkedEventIds.contains(eventId);
  }

  List<TeamSummary> get favoriteTeams {
    return _favoriteTeamNumbers
        .map(
          (teamNumber) => resolveKnownTeamSummary(
            teamNumber: teamNumber,
            grade: _currentAccount?.team.grade ?? 'High School',
          ),
        )
        .toList(growable: false);
  }

  List<TeamSummary> get followedTeams {
    final account = _currentAccount;
    if (account == null) {
      return const <TeamSummary>[];
    }

    final teamsByNumber = <String, TeamSummary>{
      account.team.number.trim().toUpperCase(): account.team,
    };

    if (_followMode == AppFollowMode.multi) {
      for (final team in favoriteTeams) {
        final normalized = team.number.trim().toUpperCase();
        if (normalized.isEmpty) {
          continue;
        }
        teamsByNumber[normalized] = team;
      }
    }

    return teamsByNumber.values.toList(growable: false);
  }

  bool get showWorldsScheduleReleaseBanner {
    return _dismissedWorldsScheduleAnnouncementId !=
        _worldsScheduleAnnouncementKey;
  }

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
    final config = await _loadConfig();
    final api = SolarApi(config: config);
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

  static Future<SolarConfig> _loadConfig() async {
    try {
      return await AppSolarConfigLoader.load();
    } catch (error, stackTrace) {
      debugPrint(
        'Solar startup warning: local config unavailable. Using default config.\n$error',
      );
      debugPrintStack(stackTrace: stackTrace);
      return SolarConfig.defaults;
    }
  }

  Future<void> _handleAuthStateChange(SolarAuthStateChange change) async {
    switch (change.event) {
      case SolarAuthEvent.passwordRecovery:
        if (_isPasswordRecoveryActive) {
          return;
        }
        _isPasswordRecoveryActive = true;
        notifyListeners();
        return;
      case SolarAuthEvent.signedOut:
        await _clearSignedInState();
        return;
      case SolarAuthEvent.signedIn:
      case SolarAuthEvent.userUpdated:
        final restoredAccount =
            change.account ??
            await _authService.restoreCurrentAccount(
              cachedEmail: _currentAccount?.normalizedEmail,
              cachedAccount: _currentAccount,
            );
        if (restoredAccount == null) {
          return;
        }
        await _setSignedInAccount(restoredAccount);
        if (change.event == SolarAuthEvent.signedIn) {
          unawaited(refreshTeamStats());
        }
        return;
    }
  }

  Future<void> initialize() async {
    final settings = await _repository.loadSettings();
    _hasCompletedOnboarding = settings.hasCompletedOnboarding;
    _preferredSeasonId = settings.preferredSeasonId;
    _themeModePreference = settings.themeModePreference;
    _competitionPreference = settings.competitionPreference;
    _followMode = settings.followMode;
    _chromeAccentPreference = settings.chromeAccentPreference;
    _customChromeAccentValue = settings.customChromeAccentValue;
    _dismissedWorldsScheduleAnnouncementId =
        settings.dismissedWorldsScheduleAnnouncementId;
    _notificationCenterSeenAtMillis = settings.notificationCenterSeenAtMillis;
    _favoriteTeamNumbers = settings.favoriteTeamNumbers;
    _bookmarkedEventIds = settings.bookmarkedEventIds;
    _developerScrimmageEnabled = settings.developerScrimmageEnabled;
    _developerScrimmageStartAtMillis = settings.developerScrimmageStartAtMillis;
    _teamRatings = settings.teamRatings;

    // Never auto-enable test scrimmage data in production launches.
    if (kReleaseMode && _developerScrimmageEnabled) {
      _developerScrimmageEnabled = false;
      await _saveSettings(currentUserEmail: settings.currentUserEmail);
    }

    if (_developerScrimmageEnabled &&
        _developerScrimmageStartAtMillis == null) {
      final defaultStartAt = _defaultDeveloperScrimmageStartAt();
      _developerScrimmageStartAtMillis = defaultStartAt.millisecondsSinceEpoch;
      await _saveSettings(currentUserEmail: settings.currentUserEmail);
    }
    _authStateSubscription = _authService.authStateChanges.listen((change) {
      unawaited(_handleAuthStateChange(change));
    });

    final currentUserEmail = settings.currentUserEmail;
    final cachedAccount = currentUserEmail == null
        ? null
        : await _repository.findByEmail(currentUserEmail);
    _currentAccount = await _authService.restoreCurrentAccount(
      cachedEmail: currentUserEmail,
      cachedAccount: cachedAccount,
    );
    if (_currentAccount != null) {
      await _setSignedInAccount(_currentAccount!, notify: false);
      unawaited(refreshTeamStats());
      unawaited(syncIosCompanion());
    }
  }

  Future<void> completeOnboarding({
    AppThemeModePreference? themeModePreference,
    AppCompetitionPreference? competitionPreference,
  }) async {
    _hasCompletedOnboarding = true;
    if (themeModePreference != null) {
      _themeModePreference = themeModePreference;
    }
    if (competitionPreference != null) {
      _competitionPreference = competitionPreference;
    }
    await _saveSettings(currentUserEmail: _currentAccount?.normalizedEmail);
    notifyListeners();
  }

  Future<void> createLocalAccount({
    required String teamNumber,
    String? fullName,
    AppCompetitionPreference? competitionPreference,
  }) async {
    final normalizedTeamNumber = teamNumber.trim().toUpperCase();
    final normalizedName = fullName?.trim() ?? '';
    if (competitionPreference != null) {
      _competitionPreference = competitionPreference;
    }

    if (normalizedTeamNumber.isEmpty) {
      final existingAccount = _currentAccount;
      final guestTeam = _guestTeamSummary(
        grade:
            existingAccount?.team.grade ??
            _defaultGradeForCompetition(_competitionPreference),
      );
      final account = AppAccount(
        fullName: normalizedName.isNotEmpty ? normalizedName : 'Solar Guest',
        email:
            existingAccount?.normalizedEmail ??
            _localAccountEmailForTeam(guestTeam.number),
        password: '',
        team: guestTeam,
        createdAt: existingAccount?.createdAt ?? DateTime.now(),
      );
      await _setSignedInAccount(account);
      return;
    }

    final activeSeasonId = await _resolveActiveSeasonId();
    final validatedTeam = await _teamDirectory.validateTeamNumber(
      normalizedTeamNumber,
      preferredSeasonId: activeSeasonId,
      programIds: _searchProgramIdsForCurrentCompetition(),
    );
    final displayName = normalizedName.isNotEmpty
        ? normalizedName
        : (validatedTeam.teamName.trim().isNotEmpty
              ? validatedTeam.teamName.trim()
              : 'Team ${validatedTeam.number}');
    final existingAccount = _currentAccount;
    final account = AppAccount(
      fullName: displayName,
      email:
          existingAccount?.normalizedEmail ??
          _localAccountEmailForTeam(validatedTeam.number),
      password: '',
      team: validatedTeam,
      createdAt: existingAccount?.createdAt ?? DateTime.now(),
    );

    await _setSignedInAccount(account);
    await refreshTeamStats();
  }

  Future<void> setThemeModePreference(AppThemeModePreference value) async {
    if (_themeModePreference == value) {
      return;
    }
    _themeModePreference = value;
    await _saveSettings(currentUserEmail: _currentAccount?.normalizedEmail);
    notifyListeners();
  }

  Future<void> setCompetitionPreference(AppCompetitionPreference value) async {
    if (_competitionPreference == value) {
      return;
    }
    _competitionPreference = value;
    _preferredSeasonId = null;
    _worldSkillsSeasonsCache.clear();
    _worldSkillsRankingsCache.clear();
    _clearTeamDerivedCaches();
    await _saveSettings(currentUserEmail: _currentAccount?.normalizedEmail);
    unawaited(refreshTeamStats());
    unawaited(preloadSearchEvents(force: true));
    unawaited(preloadSearchTeams(force: true));
    notifyListeners();
  }

  Future<void> setFollowMode(AppFollowMode value) async {
    if (_followMode == value) {
      return;
    }
    _followMode = value;
    await _saveSettings(currentUserEmail: _currentAccount?.normalizedEmail);
    notifyListeners();
  }

  Future<void> setFavoriteTeamNumbers(List<String> teamNumbers) async {
    final accountTeamNumber =
        _currentAccount?.team.number.trim().toUpperCase() ?? '';
    final normalized = <String>{
      for (final value in teamNumbers)
        value.trim().toUpperCase(),
    }
      ..removeWhere((value) => value.isEmpty || value == accountTeamNumber);
    final nextFavorites = normalized.toList(growable: false)..sort();

    if (listEquals(nextFavorites, _favoriteTeamNumbers)) {
      return;
    }

    _favoriteTeamNumbers = nextFavorites;
    await _saveSettings(currentUserEmail: _currentAccount?.normalizedEmail);
    notifyListeners();
  }

  Future<void> setDeveloperScrimmageEnabled(bool value) async {
    if (_developerScrimmageEnabled == value) {
      return;
    }
    _developerScrimmageEnabled = value;
    _developerScrimmageStartAtMillis ??=
        _defaultDeveloperScrimmageStartAt().millisecondsSinceEpoch;
    _clearTeamDerivedCaches();
    await _saveSettings(currentUserEmail: _currentAccount?.normalizedEmail);
    notifyListeners();
  }

  Future<void> setChromeAccentPreference(
    AppChromeAccentPreference value,
  ) async {
    if (_chromeAccentPreference == value) {
      return;
    }
    _chromeAccentPreference = value;
    await _saveSettings(currentUserEmail: _currentAccount?.normalizedEmail);
    notifyListeners();
  }

  Future<void> setCustomChromeAccentValue(int? value) async {
    final normalized = value == null || value == 0 ? null : value;
    if (_customChromeAccentValue == normalized) {
      return;
    }
    _customChromeAccentValue = normalized;
    await _saveSettings(currentUserEmail: _currentAccount?.normalizedEmail);
    notifyListeners();
  }

  Future<void> setDeveloperScrimmageStartAt(DateTime value) async {
    _developerScrimmageStartAtMillis = value.millisecondsSinceEpoch;
    _clearTeamDerivedCaches();
    await _saveSettings(currentUserEmail: _currentAccount?.normalizedEmail);
    notifyListeners();
  }

  Future<void> setTeamRating(String teamNumber, int rating) async {
    final normalized = teamNumber.trim().toUpperCase();
    if (normalized.isEmpty) {
      return;
    }

    final nextRatings = <String, int>{..._teamRatings};
    final clampedRating = rating.clamp(0, 5);
    if (clampedRating <= 0) {
      nextRatings.remove(normalized);
    } else {
      nextRatings[normalized] = clampedRating;
    }

    _teamRatings = Map<String, int>.unmodifiable(nextRatings);
    await _saveSettings(currentUserEmail: _currentAccount?.normalizedEmail);
    notifyListeners();
  }

  Future<void> toggleFavoriteTeam(TeamSummary team) async {
    final normalized = team.number.trim().toUpperCase();
    if (normalized.isEmpty) {
      return;
    }

    final nextFavorites = _favoriteTeamNumbers.toList(growable: true);
    if (nextFavorites.contains(normalized)) {
      nextFavorites.remove(normalized);
    } else {
      nextFavorites.add(normalized);
      nextFavorites.sort();
      if (_followMode == AppFollowMode.single) {
        _followMode = AppFollowMode.multi;
      }
    }

    _favoriteTeamNumbers = nextFavorites.toList(growable: false);
    await _saveSettings(currentUserEmail: _currentAccount?.normalizedEmail);
    notifyListeners();
  }

  Future<void> toggleBookmarkedEvent(EventSummary event) async {
    final eventId = event.id;
    if (eventId <= 0) {
      return;
    }

    final nextBookmarks = _bookmarkedEventIds.toList(growable: true);
    if (nextBookmarks.contains(eventId)) {
      nextBookmarks.remove(eventId);
    } else {
      nextBookmarks.add(eventId);
      nextBookmarks.sort();
    }

    _bookmarkedEventIds = nextBookmarks.toList(growable: false);
    await _saveSettings(currentUserEmail: _currentAccount?.normalizedEmail);
    notifyListeners();
  }

  Future<void> signIn({required String email, required String password}) async {
    final normalizedEmail = _validateEmail(email);
    if (password.trim().isEmpty) {
      throw const FormatException('Enter your password.');
    }

    final cachedAccount = await _repository.findByEmail(normalizedEmail);
    final account = await _authService.signIn(
      email: normalizedEmail,
      password: password,
      cachedAccount: cachedAccount,
    );
    await _setSignedInAccount(account);
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

    final team = await _teamDirectory.validateTeamNumber(
      teamNumber,
      preferredSeasonId: await _resolveActiveSeasonId(),
      programIds: _searchProgramIdsForCurrentCompetition(),
    );
    await _authService.signUp(
      fullName: normalizedName,
      email: normalizedEmail,
      password: password,
      team: team,
    );
  }

  Future<void> sendResetPassword({required String email}) async {
    final normalizedEmail = _validateEmail(email);
    await _authService.sendResetPassword(email: normalizedEmail);
  }

  Future<void> signOut() async {
    await _authService.signOut();
    await _clearSignedInState();
  }

  Future<void> refreshTeamStats() async {
    final account = _currentAccount;
    if (account == null || _isRefreshingTeamStats) {
      return;
    }

    _isRefreshingTeamStats = true;
    notifyListeners();

    try {
      final activeSeasonId = await _resolveActiveSeasonId();
      final normalizedTeamNumber = account.team.number.trim().toUpperCase();
      final seedWorldSkillsEntry = _seedWorldSkillsEntryForTeam(
        teamNumber: normalizedTeamNumber,
        teamId: account.team.id,
      );
      final seedOpenSkillEntry = _seedOpenSkillEntryForTeam(
        teamNumber: normalizedTeamNumber,
        teamId: account.team.id,
      );
      var snapshot = await _teamDirectory.loadTeamStats(
        account.team,
        preferredSeasonId: activeSeasonId,
        seedWorldSkillsEntry: seedWorldSkillsEntry,
        seedOpenSkillEntry: seedOpenSkillEntry,
      );
      var scheduleHydratedSnapshot = await _withOfflineScheduleFallback(
        account.team,
        snapshot,
      );

      if (!_hasRobotEventsCoverage(scheduleHydratedSnapshot) &&
          (scheduleHydratedSnapshot.errorMessage?.trim().isNotEmpty ??
              false)) {
        snapshot = await _teamDirectory.loadTeamStats(
          account.team,
          preferredSeasonId: activeSeasonId,
          seedWorldSkillsEntry: seedWorldSkillsEntry,
          seedOpenSkillEntry: seedOpenSkillEntry,
        );
        scheduleHydratedSnapshot = await _withOfflineScheduleFallback(
          account.team,
          snapshot,
        );
      }

      if (_currentAccount?.normalizedEmail != account.normalizedEmail) {
        return;
      }

      final hydratedSnapshot = _applyKnownSignalsToTeamStats(
        scheduleHydratedSnapshot,
      );
      _teamStats = _withLocalScrimmage(hydratedSnapshot);
      _quickviewSnapshotFuture = null;
      _notificationCenterSnapshotFuture = null;
      _primeSearchEvents(
        hydratedSnapshot.allEvents.isEmpty
            ? hydratedSnapshot.upcomingEvents
            : hydratedSnapshot.allEvents,
      );
      _currentAccount = account.copyWith(team: hydratedSnapshot.team);
      await _repository.saveAccount(_currentAccount!);
      unawaited(preloadSearchEvents());
      unawaited(preloadSearchTeams(force: true));
      unawaited(fetchQuickviewSnapshot());
      unawaited(fetchNotificationCenterSnapshot());
      unawaited(syncIosCompanion());
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

    final cacheKey = '$seasonId';
    try {
      final sortedEvents = await _loadCachedList<EventSummary>(
        namespace: 'season_events',
        cacheKey: cacheKey,
        force: force,
        ttl: _dailyCacheTtl(),
        fromJson: EventSummary.fromJson,
        toJson: (item) => item.toJson(),
        loader: () async {
          final events = await api.robotEvents.fetchEvents(season: seasonId);
          final uniqueEvents = <int, EventSummary>{};
          for (final event in events) {
            uniqueEvents[event.id] = event;
          }
          return uniqueEvents.values.toList(growable: false)..sort((a, b) {
            final aStart = a.start ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bStart = b.start ?? DateTime.fromMillisecondsSinceEpoch(0);
            return aStart.compareTo(bStart);
          });
        },
      );

      if (sortedEvents.isNotEmpty) {
        _preloadedSearchSeasonId = seasonId;
        _preloadedSearchEvents = sortedEvents;
      }
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

    final gradeLevels = _searchGradeLevelsForCurrentCompetition(account.team);
    final cacheGradeKey = gradeLevels.join('|').toLowerCase();
    if (!force &&
        _preloadedSearchTeamsSeasonId == seasonId &&
        _preloadedSearchTeamsGradeLevel == cacheGradeKey &&
        _preloadedSearchTeams.isNotEmpty) {
      return;
    }

    _isPreloadingSearchTeams = true;
    notifyListeners();

    try {
      final results = await Future.wait<Object>(
        gradeLevels
            .expand<Future<Object>>((gradeLevel) {
              return <Future<Object>>[
                api.worldSkills
                    .fetchRankings(seasonId: seasonId, gradeLevel: gradeLevel)
                    .then<Object>((value) => value)
                    .catchError((_) => const <WorldSkillsEntry>[]),
                fetchOpenSkillRankings(
                      seasonId: seasonId,
                      gradeLevel: gradeLevel,
                    )
                    .then<Object>((value) => value)
                    .catchError((_) => const <OpenSkillCacheEntry>[]),
              ];
            })
            .toList(growable: false),
      );

      final worldSkillsEntries = <String, WorldSkillsEntry>{};
      final openSkillEntries = <String, OpenSkillCacheEntry>{};
      for (var index = 0; index < gradeLevels.length; index++) {
        final worldEntries = _filterPreferredProgramWorldSkills(
          results[index * 2] as List<WorldSkillsEntry>,
        );
        for (final entry in worldEntries) {
          final key = entry.teamNumber.trim().toUpperCase();
          worldSkillsEntries[key] = entry;
        }

        final gradeOpenSkillEntries =
            results[(index * 2) + 1] as List<OpenSkillCacheEntry>;
        for (final entry in gradeOpenSkillEntries) {
          final key = entry.teamNumber.trim().toUpperCase();
          openSkillEntries[key] = entry;
        }
      }

      final mergedTeams = <String, TeamSummary>{};
      for (final entry in worldSkillsEntries.values) {
        final team = _teamFromWorldSkills(entry, _resolvedGradeLabel(entry));
        mergedTeams[team.number.trim().toUpperCase()] = team;
      }

      for (final entry in openSkillEntries.values) {
        final key = entry.teamNumber.trim().toUpperCase();
        mergedTeams.putIfAbsent(
          key,
          () => _teamFromOpenSkill(entry, _resolvedOpenSkillGrade(entry)),
        );
      }

      mergedTeams[account.team.number.trim().toUpperCase()] = account.team;

      final teams = mergedTeams.values.toList(growable: false)
        ..sort((a, b) => a.number.compareTo(b.number));
      final openSkillByTeam = <String, OpenSkillCacheEntry>{
        for (final entry in openSkillEntries.values)
          entry.teamNumber.trim().toUpperCase(): entry,
      };
      final rankings = List<WorldSkillsEntry>.from(worldSkillsEntries.values)
        ..sort((a, b) {
          final aRank = a.rank <= 0 ? 999999 : a.rank;
          final bRank = b.rank <= 0 ? 999999 : b.rank;
          return aRank.compareTo(bRank);
        });

      _preloadedSearchTeamsSeasonId = seasonId;
      _preloadedSearchTeamsGradeLevel = cacheGradeKey;
      _preloadedSearchTeams = teams;
      _preloadedWorldSkillsRankings = rankings;
      _preloadedOpenSkillEntriesByTeam = openSkillByTeam;
      _scrimmagePackage = null;
      _scrimmageTeamKey = null;
      _quickviewSnapshotFuture = null;
      _notificationCenterSnapshotFuture = null;
      if (_teamStats != null) {
        _teamStats = _withLocalScrimmage(
          _applyKnownSignalsToTeamStats(_teamStats!),
        );
      }
    } catch (_) {
      // Keep the current team-only fallback if the wider preload fails.
    } finally {
      _isPreloadingSearchTeams = false;
      notifyListeners();
    }
  }

  Future<void> preloadLiveSearchTeams(
    String query, {
    bool force = false,
  }) async {
    final normalizedQuery = query.trim().toUpperCase();
    if (normalizedQuery.length < 2) {
      return;
    }

    final api = _api;
    if (api == null || !api.config.hasRobotEventsApiKey) {
      return;
    }

    final requestKey = '${_competitionPreference.name}|$normalizedQuery';
    if (force) {
      _liveSearchTeamRequestCache.remove(requestKey);
      _liveSearchTeamsByQuery.remove(normalizedQuery);
    } else if (_liveSearchTeamsByQuery.containsKey(normalizedQuery)) {
      return;
    }

    final request = _liveSearchTeamRequestCache.putIfAbsent(
      requestKey,
      () async {
        try {
          final searchedTeams = await api.robotEvents.searchTeams(
            number: normalizedQuery,
            programIds: _searchProgramIdsForCurrentCompetition(),
          );
          final mergedTeams = <String, TeamSummary>{};
          for (final team in searchedTeams) {
            final teamKey = team.number.trim().toUpperCase();
            if (teamKey.isEmpty) {
              continue;
            }
            final existing = mergedTeams[teamKey];
            mergedTeams[teamKey] = existing == null
                ? team
                : _preferSearchTeamCandidate(existing, team);
          }

          final ordered = mergedTeams.values.toList(growable: false)
            ..sort((a, b) {
              final aScore = _teamRelevance(a, normalizedQuery.toLowerCase());
              final bScore = _teamRelevance(b, normalizedQuery.toLowerCase());
              if (aScore != bScore) {
                return bScore.compareTo(aScore);
              }
              return a.number.compareTo(b.number);
            });
          return ordered;
        } catch (_) {
          return const <TeamSummary>[];
        }
      },
    );

    final results = await request;
    _liveSearchTeamsByQuery[normalizedQuery] = results;
    notifyListeners();
  }

  OpenSkillCacheEntry? openSkillEntryForTeam(String teamNumber) {
    return _preloadedOpenSkillEntriesByTeam[teamNumber.trim().toUpperCase()];
  }

  Future<void> ensureSolarizeCoverageForTeams({
    required Iterable<TeamSummary> teams,
    bool force = false,
  }) async {
    final teamMap = <String, TeamSummary>{};
    for (final team in teams) {
      final key = team.number.trim().toUpperCase();
      if (key.isNotEmpty) {
        teamMap[key] = team;
      }
    }
    if (teamMap.isEmpty) {
      return;
    }

    final seasonId = await _resolveActiveSeasonId();
    if (seasonId == null) {
      return;
    }

    if (_preloadedWorldSkillsRankings.isEmpty &&
        _currentAccount != null &&
        !_isPreloadingSearchTeams) {
      await preloadSearchTeams();
    }

    final selectedEntries = <WorldSkillsEntry>[];
    final inflightKeys = <String>{};
    for (final team in teamMap.values) {
      final key = team.number.trim().toUpperCase();
      if (!force && _preloadedOpenSkillEntriesByTeam.containsKey(key)) {
        continue;
      }
      final worldSkillsEntry = _seedWorldSkillsEntryForTeam(
        teamNumber: key,
        teamId: team.id,
      );
      if (worldSkillsEntry == null) {
        continue;
      }
      final inflightKey = '$seasonId|$key';
      if (!force && !_solarizeCoverageInflight.add(inflightKey)) {
        continue;
      }
      inflightKeys.add(inflightKey);
      selectedEntries.add(worldSkillsEntry);
    }

    if (selectedEntries.isEmpty) {
      return;
    }

    try {
      final results = await Future.wait<Object>(<Future<Object>>[
        _loadSolarizeTeamRankings(
          selectedEntries,
          seasonId: seasonId,
          force: force,
          limit: selectedEntries.length,
        ).then<Object>((value) => value),
        _loadSolarizeTeamMatches(
          selectedEntries,
          seasonId: seasonId,
          force: force,
          limit: selectedEntries.length,
        ).then<Object>((value) => value),
      ]);
      final rankingsByTeam = results[0] as Map<String, List<RankingRecord>>;
      final matchesByTeam = results[1] as Map<String, List<MatchSummary>>;
      final hydratedEntries = _solarizeHistoryService.build(
        worldSkills: selectedEntries,
        rankingsByTeam: rankingsByTeam,
        matchesByTeam: matchesByTeam,
      );
      final mergedEntries = <String, OpenSkillCacheEntry>{
        ..._preloadedOpenSkillEntriesByTeam,
      };
      for (final entry in hydratedEntries) {
        mergedEntries[entry.teamNumber.trim().toUpperCase()] = entry;
      }

      final mergedWorldSkills = <String, WorldSkillsEntry>{
        for (final entry in _preloadedWorldSkillsRankings)
          entry.teamNumber.trim().toUpperCase(): entry,
      };
      for (final entry in selectedEntries) {
        mergedWorldSkills[entry.teamNumber.trim().toUpperCase()] = entry;
      }

      _preloadedOpenSkillEntriesByTeam = mergedEntries;
      _preloadedWorldSkillsRankings =
          mergedWorldSkills.values.toList(growable: false)..sort((a, b) {
            final aRank = a.rank <= 0 ? 999999 : a.rank;
            final bRank = b.rank <= 0 ? 999999 : b.rank;
            return aRank.compareTo(bRank);
          });
      notifyListeners();
    } finally {
      for (final key in inflightKeys) {
        _solarizeCoverageInflight.remove(key);
      }
    }
  }

  Future<int?> resolveDefaultWorldSkillsSeasonId() {
    return _resolveActiveSeasonId();
  }

  Future<List<SeasonSummary>> fetchWorldSkillsSeasons({
    String programFilter = solarPrimaryProgramFilter,
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
        final normalizedFilter = programFilter.trim().toLowerCase();
        final seasons = await api.robotEvents.fetchSeasons(
          programId: normalizedFilter == solarPrimaryProgramFilter.toLowerCase()
              ? solarPrimaryProgramId
              : null,
        );
        seasons.sort(_compareSeasonSummaries);
        return seasons
            .where((season) {
              return _matchesSeasonProgramFilter(season, programFilter) &&
                  _isPublishedSeason(season);
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

      final entries = await _loadCachedList<WorldSkillsEntry>(
        namespace: 'world_skills_rankings',
        cacheKey: cacheKey,
        force: force,
        ttl: _dailyCacheTtl(),
        fromJson: WorldSkillsEntry.fromJson,
        toJson: (item) => item.toJson(),
        isUsable: _hasUsableWorldSkillsRankings,
        loader: () async {
          final fetched = _filterPreferredProgramWorldSkills(
            await api.worldSkills.fetchRankings(
              seasonId: seasonId,
              gradeLevel: gradeLevel,
            ),
          );
          fetched.sort((a, b) {
            final aRank = a.rank <= 0 ? 999999 : a.rank;
            final bRank = b.rank <= 0 ? 999999 : b.rank;
            return aRank.compareTo(bRank);
          });
          return fetched;
        },
      );
      if (entries.isEmpty) {
        _worldSkillsRankingsCache.remove(cacheKey);
      }
      return entries;
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
      if (api == null || !api.config.hasRobotEventsApiKey) {
        return const <OpenSkillCacheEntry>[];
      }

      final entries = await _loadCachedList<OpenSkillCacheEntry>(
        namespace: 'solarize_rankings_v4',
        cacheKey: cacheKey,
        force: force,
        ttl: _dailyCacheTtl(),
        fromJson: OpenSkillCacheEntry.fromJson,
        toJson: (item) => item.toJson(),
        isUsable: _hasUsableOpenSkillRankings,
        loader: () async {
          final worldSkills = await fetchWorldSkillsRankings(
            seasonId: seasonId,
            gradeLevel: gradeLevel,
            force: force,
          );
          if (worldSkills.isEmpty) {
            return const <OpenSkillCacheEntry>[];
          }

          final results = await Future.wait<Object>(<Future<Object>>[
            _loadSolarizeTeamRankings(
              worldSkills,
              seasonId: seasonId,
              force: force,
            ).then<Object>((value) => value),
            _loadSolarizeTeamMatches(
              worldSkills,
              seasonId: seasonId,
              force: force,
            ).then<Object>((value) => value),
          ]);
          final rankingsByTeam = results[0] as Map<String, List<RankingRecord>>;
          final matchesByTeam = results[1] as Map<String, List<MatchSummary>>;
          return _solarizeHistoryService.build(
            worldSkills: worldSkills,
            rankingsByTeam: rankingsByTeam,
            matchesByTeam: matchesByTeam,
          );
        },
      );
      if (entries.isEmpty) {
        _openSkillRankingsCache.remove(cacheKey);
      }
      return entries;
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
    final normalizedKey = query.trim().toUpperCase();
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

    final liveResults =
        _liveSearchTeamsByQuery[normalizedKey] ?? const <TeamSummary>[];
    for (final team in liveResults) {
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

  TeamStatsSnapshot previewTeamStatsSnapshot(TeamSummary team) {
    final normalizedKey = team.number.trim().toUpperCase();
    final currentTeam = _currentAccount?.team;
    if (currentTeam != null &&
        currentTeam.number.trim().toUpperCase() == normalizedKey &&
        _teamStats != null) {
      return _teamStats!;
    }

    final worldSkillsEntry = _seedWorldSkillsEntryForTeam(
      teamNumber: normalizedKey,
      teamId: team.id,
    );
    final openSkillEntry = _seedOpenSkillEntryForTeam(
      teamNumber: normalizedKey,
      teamId: team.id,
    );
    return _applyKnownSignalsToTeamStats(
      TeamStatsSnapshot(
        team: _bestKnownTeamSummary(
          team,
          worldSkillsEntry: worldSkillsEntry,
          openSkillEntry: openSkillEntry,
        ),
        openSkillEntry: openSkillEntry,
        worldSkillsEntry: worldSkillsEntry,
        lastUpdated:
            currentTeam != null &&
                currentTeam.number.trim().toUpperCase() == normalizedKey
            ? _teamStats?.lastUpdated
            : null,
      ),
    );
  }

  Future<TeamStatsSnapshot> fetchTeamStatsSnapshot(
    TeamSummary team, {
    bool force = false,
  }) async {
    final activeSeasonId = await _resolveActiveSeasonId();
    final normalizedKey = team.number.trim().toUpperCase();
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

    return _teamStatsCache
        .putIfAbsent(cacheKey, () async {
          final resolvedTeam = await _resolveTeamForStats(
            team,
            preferredSeasonId: activeSeasonId,
          );
          var snapshot = await _loadResolvedTeamStats(
            resolvedTeam,
            normalizedTeamNumber: normalizedKey,
            activeSeasonId: activeSeasonId,
          );

          if (_hasRobotEventsCoverage(snapshot)) {
            return _applyKnownSignalsToTeamStats(snapshot);
          }

          final recoveredTeam = await _recoverTeamStatsIdentity(
            originalTeam: team,
            currentTeam: resolvedTeam,
            preferredSeasonId: activeSeasonId,
          );
          if (recoveredTeam == null) {
            return snapshot;
          }

          final recoveredSnapshot = await _loadResolvedTeamStats(
            recoveredTeam,
            normalizedTeamNumber: normalizedKey,
            activeSeasonId: activeSeasonId,
          );
          if (_hasRobotEventsCoverage(recoveredSnapshot)) {
            snapshot = recoveredSnapshot;
          }
          return _applyKnownSignalsToTeamStats(snapshot);
        })
        .then((snapshot) {
          if (!_shouldCacheTeamStatsSnapshot(snapshot)) {
            _teamStatsCache.remove(cacheKey);
          }
          return snapshot;
        });
  }

  Future<TeamSummary> _resolveTeamForStats(
    TeamSummary team, {
    required int? preferredSeasonId,
  }) async {
    if (team.id > 0) {
      return team;
    }
    final validated = await _validateTeamNumberForCurrentCompetition(
      team.number,
      preferredSeasonId: preferredSeasonId,
    );
    return validated ?? team;
  }

  Future<TeamStatsSnapshot> _loadResolvedTeamStats(
    TeamSummary resolvedTeam, {
    required String normalizedTeamNumber,
    required int? activeSeasonId,
  }) async {
    final seedWorldSkillsEntry = _seedWorldSkillsEntryForTeam(
      teamNumber: normalizedTeamNumber,
      teamId: resolvedTeam.id,
    );
    final seedOpenSkillEntry = _seedOpenSkillEntryForTeam(
      teamNumber: normalizedTeamNumber,
      teamId: resolvedTeam.id,
    );
    final snapshot = await _teamDirectory.loadTeamStats(
      resolvedTeam,
      preferredSeasonId: activeSeasonId,
      seedWorldSkillsEntry: seedWorldSkillsEntry,
      seedOpenSkillEntry: seedOpenSkillEntry,
    );
    final bestKnownTeam = _bestKnownTeamSummary(
      snapshot.team,
      worldSkillsEntry: snapshot.worldSkillsEntry ?? seedWorldSkillsEntry,
      openSkillEntry: snapshot.openSkillEntry ?? seedOpenSkillEntry,
    );
    if (_sameTeamSummary(snapshot.team, bestKnownTeam)) {
      return snapshot;
    }
    return TeamStatsSnapshot(
      team: bestKnownTeam,
      allEvents: snapshot.allEvents,
      upcomingEvents: snapshot.upcomingEvents,
      rankings: snapshot.rankings,
      matchHistory: snapshot.matchHistory,
      openSkillEntry: snapshot.openSkillEntry,
      worldSkillsEntry: snapshot.worldSkillsEntry,
      lastUpdated: snapshot.lastUpdated,
      errorMessage: snapshot.errorMessage,
    );
  }

  Future<TeamSummary?> _recoverTeamStatsIdentity({
    required TeamSummary originalTeam,
    required TeamSummary currentTeam,
    required int? preferredSeasonId,
  }) async {
    final normalizedNumber = originalTeam.number.trim().toUpperCase();
    if (normalizedNumber.isEmpty) {
      return null;
    }

    final validated = await _validateTeamNumberForCurrentCompetition(
      normalizedNumber,
      preferredSeasonId: preferredSeasonId,
    );
    if (validated == null) {
      return null;
    }

    final recovered = _mergeTeamSummary(validated, originalTeam);
    if (_sameTeamSummary(recovered, currentTeam)) {
      return null;
    }
    return recovered;
  }

  bool _hasRobotEventsCoverage(TeamStatsSnapshot snapshot) {
    return snapshot.allEvents.isNotEmpty ||
        snapshot.rankings.isNotEmpty ||
        snapshot.matchHistory.isNotEmpty ||
        snapshot.worldSkillsEntry != null ||
        snapshot.openSkillEntry != null;
  }

  bool _shouldCacheTeamStatsSnapshot(TeamStatsSnapshot snapshot) {
    return _hasRobotEventsCoverage(snapshot) &&
        !(snapshot.errorMessage?.trim().isNotEmpty ?? false);
  }

  bool _sameTeamSummary(TeamSummary left, TeamSummary right) {
    return left.id == right.id &&
        left.number.trim().toUpperCase() == right.number.trim().toUpperCase() &&
        left.teamName.trim() == right.teamName.trim() &&
        left.organization.trim() == right.organization.trim() &&
        left.robotName.trim() == right.robotName.trim() &&
        left.grade.trim() == right.grade.trim() &&
        left.location.city.trim() == right.location.city.trim() &&
        left.location.region.trim() == right.location.region.trim() &&
        left.location.country.trim() == right.location.country.trim();
  }

  Future<void> dismissWorldsScheduleReleaseBanner() async {
    if (!showWorldsScheduleReleaseBanner) {
      return;
    }
    _dismissedWorldsScheduleAnnouncementId = _worldsScheduleAnnouncementKey;
    await _saveSettings(currentUserEmail: _currentAccount?.normalizedEmail);
    notifyListeners();
  }

  Future<int?> _resolveSearchSeasonId() async {
    return _resolveActiveSeasonId();
  }

  Future<int?> _resolveActiveSeasonId() async {
    if (_preferredSeasonId != null) {
      return _preferredSeasonId;
    }

    final seasons = await fetchWorldSkillsSeasons(
      programFilter: _worldSkillsProgramFilterForCurrentCompetition(),
    );
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

  Future<List<T>> _loadCachedList<T>({
    required String namespace,
    required String cacheKey,
    required Future<List<T>> Function() loader,
    required T Function(Map<String, dynamic> json) fromJson,
    required Map<String, dynamic> Function(T item) toJson,
    required Duration ttl,
    bool force = false,
    bool cacheEmptyResults = false,
    List<T> fallback = const [],
    bool Function(List<T> items)? isUsable,
  }) async {
    if (!force) {
      final cached = await _diskCacheStore.readList<T>(
        namespace: namespace,
        key: cacheKey,
        fromJson: fromJson,
      );
      if (cached != null) {
        final isCacheable = cached.isNotEmpty || cacheEmptyResults;
        final usable = !isCacheable || isUsable == null || isUsable(cached);
        if (isCacheable && usable) {
          return cached;
        }
        if (isCacheable && !usable) {
          await _diskCacheStore.clear(namespace, cacheKey);
        }
      }
    }

    try {
      final loaded = await loader();
      if (loaded.isNotEmpty || cacheEmptyResults) {
        await _diskCacheStore.writeList<T>(
          namespace: namespace,
          key: cacheKey,
          items: loaded,
          toJson: toJson,
          ttl: ttl,
        );
      }
      return loaded;
    } catch (_) {
      final cached = await _diskCacheStore.readList<T>(
        namespace: namespace,
        key: cacheKey,
        fromJson: fromJson,
        allowExpired: true,
      );
      final usable =
          cached == null ||
          isUsable == null ||
          !(cached.isNotEmpty || cacheEmptyResults) ||
          isUsable(cached);
      if (cached != null &&
          usable &&
          (cached.isNotEmpty || cacheEmptyResults)) {
        return cached;
      }
      return fallback;
    }
  }

  Future<TeamStatsSnapshot> _withOfflineScheduleFallback(
    TeamSummary team,
    TeamStatsSnapshot snapshot,
  ) async {
    final cacheKey = _teamScheduleCacheKey(team);
    final hasLiveSchedule = snapshot.allEvents.isNotEmpty;

    if (hasLiveSchedule) {
      await _diskCacheStore.writeList<EventSummary>(
        namespace: _teamScheduleCacheNamespace,
        key: cacheKey,
        items: snapshot.allEvents,
        toJson: (item) => item.toJson(),
        ttl: const Duration(days: 30),
      );
      return snapshot;
    }

    final cachedEvents = await _diskCacheStore.readList<EventSummary>(
      namespace: _teamScheduleCacheNamespace,
      key: cacheKey,
      fromJson: EventSummary.fromJson,
      allowExpired: true,
    );
    if (cachedEvents == null || cachedEvents.isEmpty) {
      return snapshot;
    }

    final mergedMessage = snapshot.errorMessage == null
        ? 'Offline mode: showing saved match schedule from this device.'
        : '${snapshot.errorMessage} Showing saved match schedule from this device.';

    return TeamStatsSnapshot(
      team: snapshot.team,
      allEvents: cachedEvents,
      upcomingEvents: _upcomingEventsFromSchedule(cachedEvents),
      rankings: snapshot.rankings,
      matchHistory: snapshot.matchHistory,
      openSkillEntry: snapshot.openSkillEntry,
      worldSkillsEntry: snapshot.worldSkillsEntry,
      lastUpdated: snapshot.lastUpdated,
      errorMessage: mergedMessage,
    );
  }

  String _teamScheduleCacheKey(TeamSummary team) {
    final normalizedNumber = team.number.trim().toUpperCase();
    final safeNumber = normalizedNumber.isEmpty
        ? 'team_unknown'
        : normalizedNumber;
    return '${team.id}_$safeNumber';
  }

  List<EventSummary> _upcomingEventsFromSchedule(List<EventSummary> allEvents) {
    final now = DateTime.now();
    final upcoming = allEvents
        .where((event) {
          final anchor = event.end ?? event.start;
          return anchor == null || !anchor.isBefore(now);
        })
        .toList(growable: false);
    return upcoming.take(6).toList(growable: false);
  }

  Duration _dailyCacheTtl() {
    final now = DateTime.now();
    final nextDay = DateTime(now.year, now.month, now.day + 1);
    return nextDay.difference(now);
  }

  Duration _eventCacheTtl(EventSummary? event) {
    return _isPastEvent(event)
        ? const Duration(days: 180)
        : const Duration(hours: 2);
  }

  bool _isPastEvent(EventSummary? event) {
    if (event == null) {
      return false;
    }
    final anchor = event.end ?? event.start;
    return anchor != null && anchor.isBefore(DateTime.now());
  }

  Future<Map<String, List<RankingRecord>>> _loadSolarizeTeamRankings(
    List<WorldSkillsEntry> worldSkills, {
    required int seasonId,
    required bool force,
    int? limit,
  }) async {
    final prioritized = _prioritizedSolarizeTeams(
      worldSkills,
      limit: limit ?? _solarizeHistoryTeamLimit,
    );
    final results = <String, List<RankingRecord>>{};

    for (
      var index = 0;
      index < prioritized.length;
      index += _solarizeHistoryBatchSize
    ) {
      final batch = prioritized
          .skip(index)
          .take(_solarizeHistoryBatchSize)
          .toList(growable: false);
      final batchResults =
          await Future.wait<MapEntry<String, List<RankingRecord>>>(
            batch.map((entry) async {
              final rankings = await _fetchTeamRankingsForSolarize(
                teamId: entry.teamId,
                seasonId: seasonId,
                force: force,
              );
              return MapEntry<String, List<RankingRecord>>(
                entry.teamNumber.trim().toUpperCase(),
                rankings,
              );
            }),
          );

      for (final result in batchResults) {
        results[result.key] = result.value;
      }
    }

    return results;
  }

  Future<Map<String, List<MatchSummary>>> _loadSolarizeTeamMatches(
    List<WorldSkillsEntry> worldSkills, {
    required int seasonId,
    required bool force,
    int? limit,
  }) async {
    final prioritized = _prioritizedSolarizeTeams(
      worldSkills,
      limit: limit ?? _solarizeMatchHistoryTeamLimit,
    );
    final results = <String, List<MatchSummary>>{};

    for (
      var index = 0;
      index < prioritized.length;
      index += _solarizeMatchHistoryBatchSize
    ) {
      final batch = prioritized
          .skip(index)
          .take(_solarizeMatchHistoryBatchSize)
          .toList(growable: false);
      final batchResults =
          await Future.wait<MapEntry<String, List<MatchSummary>>>(
            batch.map((entry) async {
              final matches = await fetchTeamMatchesForReference(
                TeamReference(
                  id: entry.teamId,
                  number: entry.teamNumber,
                  name: entry.teamName,
                ),
                season: seasonId,
                force: force,
              );
              return MapEntry<String, List<MatchSummary>>(
                entry.teamNumber.trim().toUpperCase(),
                matches,
              );
            }),
          );

      for (final result in batchResults) {
        results[result.key] = result.value;
      }
    }

    return results;
  }

  List<WorldSkillsEntry> _prioritizedSolarizeTeams(
    List<WorldSkillsEntry> worldSkills, {
    int limit = _solarizeHistoryTeamLimit,
  }) {
    final ordered = List<WorldSkillsEntry>.from(worldSkills)
      ..sort((a, b) {
        final aRank = a.rank <= 0 ? 999999 : a.rank;
        final bRank = b.rank <= 0 ? 999999 : b.rank;
        final rankCompare = aRank.compareTo(bRank);
        if (rankCompare != 0) {
          return rankCompare;
        }
        return b.combinedScore.compareTo(a.combinedScore);
      });

    final selected = <WorldSkillsEntry>[];
    final seen = <String>{};
    void addEntry(WorldSkillsEntry entry) {
      final key = entry.teamNumber.trim().toUpperCase();
      if (seen.add(key)) {
        selected.add(entry);
      }
    }

    for (final entry in ordered.take(limit)) {
      addEntry(entry);
    }

    final currentTeamNumber = _currentAccount?.team.number.trim().toUpperCase();
    if (currentTeamNumber != null) {
      for (final entry in ordered) {
        if (entry.teamNumber.trim().toUpperCase() == currentTeamNumber) {
          addEntry(entry);
          break;
        }
      }
    }

    return selected;
  }

  Future<List<RankingRecord>> _fetchTeamRankingsForSolarize({
    required int teamId,
    required int seasonId,
    required bool force,
  }) {
    if (teamId <= 0) {
      return Future<List<RankingRecord>>.value(const <RankingRecord>[]);
    }

    final cacheKey = '$teamId:$seasonId';
    if (force) {
      _teamRankingsCache.remove(cacheKey);
    }

    return _teamRankingsCache.putIfAbsent(cacheKey, () async {
      final api = _api;
      if (api == null || !api.config.hasRobotEventsApiKey) {
        return const <RankingRecord>[];
      }

      try {
        final rankings = await api.robotEvents.fetchTeamRankings(
          teamId,
          season: seasonId,
        );
        rankings.sort((a, b) {
          final aRank = a.rank <= 0 ? 999999 : a.rank;
          final bRank = b.rank <= 0 ? 999999 : b.rank;
          return aRank.compareTo(bRank);
        });
        return rankings;
      } catch (_) {
        return const <RankingRecord>[];
      }
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

    _currentAccount = await _authService.saveAccount(
      account.copyWith(fullName: normalizedName),
    );
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
      programIds: _searchProgramIdsForCurrentCompetition(),
    );
    _currentAccount = await _authService.saveAccount(
      account.copyWith(team: validatedTeam),
    );
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

    await _authService.updatePassword(
      account: account,
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
    final storedPassword = _authService is LocalSolarAuthService
        ? newPassword
        : '';
    _currentAccount = account.copyWith(password: storedPassword);
    await _repository.saveAccount(_currentAccount!);
    notifyListeners();
  }

  Future<void> updateRecoveryPassword({
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (newPassword.trim().isEmpty) {
      throw const FormatException('Enter a new password.');
    }

    if (newPassword != confirmPassword) {
      throw const FormatException('New passwords do not match.');
    }

    await _authService.updateRecoveryPassword(newPassword: newPassword);
    _isPasswordRecoveryActive = false;
    await signOut();
  }

  Future<int?> fetchEventTeamCount(int eventId) {
    final scrimmage = _scrimmagePackageForCurrentTeam();
    if (scrimmage != null && eventId == scrimmage.event.id) {
      return Future<int?>.value(scrimmage.teamCount);
    }

    return _eventTeamCountCache.putIfAbsent(eventId, () async {
      final teams = await fetchEventTeams(eventId);
      return teams.isEmpty ? null : teams.length;
    });
  }

  Future<List<TeamSummary>> fetchEventTeams(int eventId) {
    final scrimmage = _scrimmagePackageForCurrentTeam();
    if (scrimmage != null && eventId == scrimmage.event.id) {
      return Future<List<TeamSummary>>.value(
        scrimmage.teams
            .map(
              (team) => TeamSummary(
                id: team.id,
                number: team.number,
                teamName: team.name,
                organization: '',
                robotName: '',
                location: scrimmage.event.location,
                grade: _currentAccount?.team.grade ?? 'High School',
                registered: true,
              ),
            )
            .toList(growable: false),
      );
    }

    return _eventTeamsCache.putIfAbsent(eventId, () async {
      final api = _api;
      if (api == null || !api.config.hasRobotEventsApiKey) {
        return const <TeamSummary>[];
      }

      final event = resolveKnownEvent(eventId);
      final teams = await _loadCachedList<TeamSummary>(
        namespace: 'event_teams',
        cacheKey: '$eventId',
        ttl: _eventCacheTtl(event),
        cacheEmptyResults: _isPastEvent(event),
        fromJson: TeamSummary.fromJson,
        toJson: (item) => item.toJson(),
        loader: () => api.robotEvents.fetchEventTeams(eventId),
      );
      if (teams.isEmpty && !_isPastEvent(event)) {
        _eventTeamsCache.remove(eventId);
      }
      return teams;
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

      final event = resolveKnownEvent(eventId);
      final rankings = await _loadCachedList<RankingRecord>(
        namespace: 'division_rankings',
        cacheKey: cacheKey,
        ttl: _eventCacheTtl(event),
        cacheEmptyResults: _isPastEvent(event),
        fromJson: RankingRecord.fromJson,
        toJson: (item) => item.toJson(),
        loader: () async {
          final fetched = await api.robotEvents.fetchDivisionRankings(
            eventId: eventId,
            divisionId: divisionId,
          );
          fetched.sort((a, b) => a.rank.compareTo(b.rank));
          return fetched;
        },
      );
      if (rankings.isEmpty && !_isPastEvent(event)) {
        _divisionRankingsCache.remove(cacheKey);
      }
      return rankings;
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

      final event = resolveKnownEvent(eventId);
      final matches = await _loadCachedList<MatchSummary>(
        namespace: 'division_matches',
        cacheKey: cacheKey,
        ttl: _eventCacheTtl(event),
        cacheEmptyResults: _isPastEvent(event),
        fromJson: MatchSummary.fromJson,
        toJson: (item) => item.toJson(),
        loader: () async {
          final fetched = await api.robotEvents.fetchDivisionMatches(
            eventId: eventId,
            divisionId: divisionId,
          );
          fetched.sort((a, b) {
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
          return fetched;
        },
      );
      if (matches.isEmpty && !_isPastEvent(event)) {
        _divisionMatchesCache.remove(cacheKey);
      }
      return matches;
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

      final event = resolveKnownEvent(eventId);
      final skills = await _loadCachedList<SkillAttempt>(
        namespace: 'event_skills',
        cacheKey: '$eventId',
        ttl: _eventCacheTtl(event),
        cacheEmptyResults: _isPastEvent(event),
        fromJson: SkillAttempt.fromJson,
        toJson: (item) => item.toJson(),
        loader: () async {
          final fetched = await api.robotEvents.fetchEventSkills(eventId);
          fetched.sort((a, b) {
            final aRank = a.rank <= 0 ? 999999 : a.rank;
            final bRank = b.rank <= 0 ? 999999 : b.rank;
            return aRank.compareTo(bRank);
          });
          return fetched;
        },
      );
      if (skills.isEmpty && !_isPastEvent(event)) {
        _eventSkillsCache.remove(eventId);
      }
      return skills;
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

      final event = resolveKnownEvent(eventId);
      final awards = await _loadCachedList<AwardSummary>(
        namespace: 'event_awards',
        cacheKey: '$eventId',
        ttl: _eventCacheTtl(event),
        cacheEmptyResults: _isPastEvent(event),
        fromJson: AwardSummary.fromJson,
        toJson: (item) => item.toJson(),
        loader: () async {
          final fetched = await api.robotEvents.fetchEventAwards(eventId);
          fetched.sort((a, b) {
            if (a.order != b.order) {
              return a.order.compareTo(b.order);
            }
            return a.title.compareTo(b.title);
          });
          return fetched;
        },
      );
      if (awards.isEmpty && !_isPastEvent(event)) {
        _eventAwardsCache.remove(eventId);
      }
      return awards;
    });
  }

  Future<int> fetchTeamAwardsCount(
    TeamSummary team, {
    bool force = false,
    int maxEvents = 24,
  }) {
    final normalizedTeamNumber = team.number.trim().toUpperCase();
    final cacheKey = '${team.id}:$normalizedTeamNumber:$maxEvents';
    if (force) {
      _teamAwardsCountCache.remove(cacheKey);
    }

    return _teamAwardsCountCache.putIfAbsent(cacheKey, () async {
      try {
        final snapshot = await fetchTeamStatsSnapshot(team, force: force);
        if (snapshot.pastEvents.isEmpty) {
          return 0;
        }

        final trackedEvents = snapshot.pastEvents.toList(growable: false)
          ..sort((a, b) {
            final aDate =
                (a.end ?? a.start) ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate =
                (b.end ?? b.start) ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });

        var totalAwards = 0;
        for (final event in trackedEvents.take(maxEvents)) {
          List<AwardSummary> awards;
          try {
            awards = await fetchEventAwards(event.id);
          } catch (_) {
            continue;
          }

          for (final award in awards) {
            if (_awardMentionsTeamNumber(award, normalizedTeamNumber)) {
              totalAwards += 1;
            }
          }
        }
        return totalAwards;
      } catch (_) {
        return 0;
      }
    });
  }

  bool _awardMentionsTeamNumber(AwardSummary award, String teamNumber) {
    final normalized = teamNumber.trim().toUpperCase();
    if (normalized.isEmpty) {
      return false;
    }
    final boundaryPattern = RegExp(
      '(^|[^A-Z0-9])${RegExp.escape(normalized)}(\$|[^A-Z0-9])',
    );
    return award.recipients.any((recipient) {
      final recipientLabel = recipient.trim().toUpperCase();
      if (recipientLabel.isEmpty) {
        return false;
      }
      if (boundaryPattern.hasMatch(recipientLabel)) {
        return true;
      }

      final compressed = recipientLabel.replaceAll(RegExp(r'[^A-Z0-9]'), '');
      return compressed == normalized;
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

      final event = resolveKnownEvent(eventId);
      final matches = await _loadCachedList<MatchSummary>(
        namespace: 'team_event_schedule',
        cacheKey: cacheKey,
        ttl: _eventCacheTtl(event),
        cacheEmptyResults: _isPastEvent(event),
        fromJson: MatchSummary.fromJson,
        toJson: (item) => item.toJson(),
        loader: () async {
          final fetched = await api.robotEvents.fetchTeamMatches(
            account.team.id,
            eventId: eventId,
          );
          fetched.sort((a, b) {
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
          return fetched;
        },
      );
      if (matches.isEmpty && !_isPastEvent(event)) {
        _teamScheduleCache.remove(cacheKey);
      }
      return matches;
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

      final event = eventId == null ? null : resolveKnownEvent(eventId);
      final matches = await _loadCachedList<MatchSummary>(
        namespace: 'team_match_history',
        cacheKey: cacheKey,
        force: force,
        ttl: event == null ? _dailyCacheTtl() : _eventCacheTtl(event),
        cacheEmptyResults: event != null && _isPastEvent(event),
        fromJson: MatchSummary.fromJson,
        toJson: (item) => item.toJson(),
        loader: () async {
          final fetched = await api.robotEvents.fetchTeamMatches(
            team.id,
            season: season,
            eventId: eventId,
          );
          fetched.sort((a, b) {
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
          return fetched;
        },
      );
      if (matches.isEmpty && eventId == null) {
        _teamMatchHistoryCache.remove(cacheKey);
      }
      return matches;
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

  Future<SolarNotificationCenterSnapshot> fetchNotificationCenterSnapshot() {
    if (_notificationCenterSnapshotFuture != null) {
      return _notificationCenterSnapshotFuture!;
    }

    final future = _loadNotificationCenterSnapshot();
    _notificationCenterSnapshotFuture = future;
    return future;
  }

  Future<void> syncIosCompanion() async {
    final account = _currentAccount;
    if (account == null) {
      await _iosCompanionService.clear();
      return;
    }

    final snapshot = await fetchNotificationCenterSnapshot();
    await _iosCompanionService.sync(
      teamNumber: account.team.number,
      snapshot: snapshot,
      teamStats: _teamStats,
    );
  }

  Future<void> clearIosCompanion() {
    return _iosCompanionService.clear();
  }

  Future<void> markNotificationCenterSeen({
    SolarNotificationCenterSnapshot? snapshot,
  }) async {
    final resolvedSnapshot =
        snapshot ?? await fetchNotificationCenterSnapshot();
    final anchors = <int>[
      DateTime.now().millisecondsSinceEpoch,
      if (resolvedSnapshot.upcomingMatch != null)
        ((resolvedSnapshot.upcomingMatch!.scheduled ??
                        resolvedSnapshot.upcomingMatch!.started)
                    ?.millisecondsSinceEpoch ??
                0) +
            1,
      for (final result in resolvedSnapshot.recentResults)
        (result.completedAt?.millisecondsSinceEpoch ?? 0) + 1,
    ];
    final now = anchors.reduce(
      (current, value) => value > current ? value : current,
    );
    if (_notificationCenterSeenAtMillis != null &&
        _notificationCenterSeenAtMillis! >= now) {
      return;
    }

    _notificationCenterSeenAtMillis = now;
    await _saveSettings(currentUserEmail: _currentAccount?.normalizedEmail);
    notifyListeners();

    if (_currentAccount != null) {
      await _iosCompanionService.sync(
        teamNumber: _currentAccount!.team.number,
        snapshot: resolvedSnapshot,
        teamStats: _teamStats,
      );
    }
  }

  Future<SolarQuickviewSnapshot?> _loadQuickviewSnapshot() async {
    final teamStats = _teamStats;
    if (teamStats == null) {
      return null;
    }

    final futureEvents = teamStats.futureEvents;
    if (futureEvents.isEmpty) {
      return null;
    }

    final trackedEvents = futureEvents.take(4).toList(growable: false);
    final schedules =
        await Future.wait<MapEntry<EventSummary, List<MatchSummary>>>(
          trackedEvents.map((event) async {
            final schedule = await fetchTeamScheduleForEvent(event.id);
            return MapEntry<EventSummary, List<MatchSummary>>(event, schedule);
          }),
        );

    for (final entry in schedules) {
      final event = entry.key;
      final schedule = entry.value;
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

    final fallbackEntry = schedules.isEmpty ? null : schedules.first;
    final fallbackEvent = fallbackEntry?.key ?? futureEvents.first;
    final fallbackSchedule =
        fallbackEntry?.value ??
        await fetchTeamScheduleForEvent(fallbackEvent.id);
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

  Future<SolarNotificationCenterSnapshot>
  _loadNotificationCenterSnapshot() async {
    final quickview = await fetchQuickviewSnapshot();
    final recentResults = await _loadRecentMatchResults(limit: 4);

    var upcomingEvent = quickview?.event;
    var upcomingMatch =
        quickview?.nextQualifyingMatch ??
        (quickview?.futureMatches.isEmpty ?? true
            ? null
            : quickview!.futureMatches.first);

    if (upcomingMatch == null && _developerScrimmageEnabled) {
      final scrimmage = _scrimmagePackageForCurrentTeam();
      if (scrimmage != null) {
        final pendingMatches =
            scrimmage.matches
                .where((match) {
                  final hasOfficialScores =
                      match.alliances.length >= 2 &&
                      match.alliances.every((alliance) => alliance.score >= 0);
                  return !hasOfficialScores;
                })
                .toList(growable: false)
              ..sort((a, b) {
                final aTime =
                    a.scheduled ??
                    a.started ??
                    DateTime.fromMillisecondsSinceEpoch(0);
                final bTime =
                    b.scheduled ??
                    b.started ??
                    DateTime.fromMillisecondsSinceEpoch(0);
                return aTime.compareTo(bTime);
              });

        MatchSummary? scrimmageUpcoming;
        for (final match in pendingMatches) {
          if (_isFuturePendingMatch(match)) {
            scrimmageUpcoming = match;
            break;
          }
        }
        scrimmageUpcoming ??= pendingMatches.isEmpty
            ? null
            : pendingMatches.first;

        if (scrimmageUpcoming != null) {
          upcomingEvent = scrimmage.event;
          upcomingMatch = scrimmageUpcoming;
        }
      }
    }

    SolarMatchPrediction? upcomingPrediction;
    if (upcomingMatch != null) {
      try {
        upcomingPrediction = await predictMatch(
          match: upcomingMatch,
          event: upcomingEvent,
        );
      } catch (_) {
        upcomingPrediction = null;
      }
    }

    final rankingSummary = await _loadNotificationFocusRankingSummary(
      upcomingEvent: upcomingEvent,
      upcomingMatch: upcomingMatch,
      recentResults: recentResults,
    );

    return SolarNotificationCenterSnapshot(
      upcomingEvent: upcomingEvent,
      upcomingMatch: upcomingMatch,
      upcomingPrediction: upcomingPrediction,
      focusRankingSummary: rankingSummary,
      recentResults: recentResults,
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
    if (!_developerScrimmageEnabled) {
      return snapshot;
    }

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

    final baseTime =
        developerScrimmageStartAt ?? _defaultDeveloperScrimmageStartAt();
    _scrimmagePackage = _scrimmageService.build(
      currentTeam: team,
      worldSkills: _preloadedWorldSkillsRankings,
      openSkillByTeam: _preloadedOpenSkillEntriesByTeam,
      baseTime: baseTime,
      seasonId: _resolvedScrimmageSeasonId(),
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

  List<int> _searchProgramIdsForCurrentCompetition() {
    switch (_competitionPreference) {
      case AppCompetitionPreference.vexV5:
        return solarPrimaryProgramIds;
      case AppCompetitionPreference.vexIQ:
      case AppCompetitionPreference.vexU:
      case AppCompetitionPreference.vexAI:
        return const <int>[];
    }
  }

  Future<TeamSummary?> _validateTeamNumberForCurrentCompetition(
    String teamNumber, {
    required int? preferredSeasonId,
  }) async {
    final scopedProgramIds = _searchProgramIdsForCurrentCompetition();
    try {
      return await _teamDirectory.validateTeamNumber(
        teamNumber,
        preferredSeasonId: preferredSeasonId,
        programIds: scopedProgramIds,
      );
    } catch (_) {
      if (scopedProgramIds.isEmpty) {
        return null;
      }
    }

    try {
      return await _teamDirectory.validateTeamNumber(
        teamNumber,
        preferredSeasonId: preferredSeasonId,
        programIds: const <int>[],
      );
    } catch (_) {
      return null;
    }
  }

  TeamSummary _preferSearchTeamCandidate(
    TeamSummary existing,
    TeamSummary candidate,
  ) {
    if (existing.registered != candidate.registered) {
      return existing.registered ? existing : candidate;
    }

    final existingHasId = existing.id > 0;
    final candidateHasId = candidate.id > 0;
    if (existingHasId != candidateHasId) {
      return candidateHasId ? candidate : existing;
    }

    final existingHasName = existing.teamName.trim().isNotEmpty;
    final candidateHasName = candidate.teamName.trim().isNotEmpty;
    if (existingHasName != candidateHasName) {
      return candidateHasName ? candidate : existing;
    }

    final existingHasOrg = existing.organization.trim().isNotEmpty;
    final candidateHasOrg = candidate.organization.trim().isNotEmpty;
    if (existingHasOrg != candidateHasOrg) {
      return candidateHasOrg ? candidate : existing;
    }

    return existing;
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

  Future<List<SolarRecentMatchResult>> _loadRecentMatchResults({
    required int limit,
  }) async {
    final account = _currentAccount;
    final teamStats = _teamStats;
    if (account == null || teamStats == null) {
      return const <SolarRecentMatchResult>[];
    }

    final events =
        (teamStats.allEvents.isEmpty
                ? teamStats.upcomingEvents
                : teamStats.allEvents)
            .toList(growable: false)
          ..sort((a, b) {
            final aDate =
                a.end ?? a.start ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate =
                b.end ?? b.start ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });

    final results = <SolarRecentMatchResult>[];
    for (final event in events.take(4)) {
      final matches = await fetchTeamScheduleForEvent(event.id);
      for (final match in matches.reversed) {
        final recentResult = _recentResultForMatch(
          match,
          teamNumber: account.team.number,
          event: event,
        );
        if (recentResult != null) {
          results.add(recentResult);
        }
      }
      if (results.length >= limit) {
        break;
      }
    }

    results.sort((a, b) {
      final aDate = a.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return results.take(limit).toList(growable: false);
  }

  SolarRecentMatchResult? _recentResultForMatch(
    MatchSummary match, {
    required String teamNumber,
    required EventSummary event,
  }) {
    if (_isFuturePendingMatch(match)) {
      return null;
    }

    MatchAlliance? yourAlliance;
    MatchAlliance? opponentAlliance;
    for (final alliance in match.alliances) {
      final containsTeam = alliance.teams.any((team) {
        return team.number.trim().toUpperCase() ==
            teamNumber.trim().toUpperCase();
      });
      if (containsTeam) {
        yourAlliance = alliance;
      } else {
        opponentAlliance = alliance;
      }
    }

    if (yourAlliance == null ||
        opponentAlliance == null ||
        yourAlliance.score < 0 ||
        opponentAlliance.score < 0) {
      return null;
    }

    return SolarRecentMatchResult(
      event: event,
      match: match,
      allianceColor: yourAlliance.color,
      allianceScore: yourAlliance.score,
      opponentScore: opponentAlliance.score,
    );
  }

  bool _isFuturePendingMatch(MatchSummary match) {
    final now = DateTime.now();
    final anchor = match.scheduled ?? match.started;
    final hasOfficialScores =
        match.alliances.length >= 2 &&
        match.alliances.every((alliance) => alliance.score >= 0);
    return !hasOfficialScores && (anchor == null || !anchor.isBefore(now));
  }

  Future<String?> _loadNotificationFocusRankingSummary({
    required EventSummary? upcomingEvent,
    required MatchSummary? upcomingMatch,
    required List<SolarRecentMatchResult> recentResults,
  }) async {
    final account = _currentAccount;
    if (account == null) {
      return null;
    }

    final recentFocus = recentResults.isEmpty ? null : recentResults.first;
    final focusEvent = upcomingEvent ?? recentFocus?.event;
    final focusMatch = upcomingMatch ?? recentFocus?.match;
    if (focusEvent == null || focusMatch == null) {
      return null;
    }

    try {
      final rankings = await fetchDivisionRankings(
        eventId: focusEvent.id,
        divisionId: focusMatch.division.id,
      );
      for (final ranking in rankings) {
        if (ranking.team.number.trim().toUpperCase() ==
            account.team.number.trim().toUpperCase()) {
          final rankLabel = ranking.rank > 0 ? '#${ranking.rank}' : '--';
          return '$rankLabel | WP ${_livePointsLabel(ranking.wp)} | AP ${_livePointsLabel(ranking.ap)} | SP ${_livePointsLabel(ranking.sp)}';
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  String _livePointsLabel(int value) {
    return value >= 0 ? '$value' : '--';
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
    _eventTeamsCache.clear();
    _divisionRankingsCache.clear();
    _divisionMatchesCache.clear();
    _eventSkillsCache.clear();
    _eventAwardsCache.clear();
    _teamAwardsCountCache.clear();
    _teamScheduleCache.clear();
    _teamMatchHistoryCache.clear();
    _liveSearchTeamRequestCache.clear();
    _liveSearchTeamsByQuery.clear();
    _matchPredictionCache.clear();
    _teamStatsCache.clear();
    _quickviewSnapshotFuture = null;
    _notificationCenterSnapshotFuture = null;
    _scrimmagePackage = null;
    _scrimmageTeamKey = null;
  }

  WorldSkillsEntry? _seedWorldSkillsEntryForTeam({
    required String teamNumber,
    int? teamId,
  }) {
    final currentEntry = _teamStats?.worldSkillsEntry;
    if (_matchesSeedTeam(
      teamNumber: teamNumber,
      teamId: teamId,
      candidateTeamNumber: currentEntry?.teamNumber,
      candidateTeamId: currentEntry?.teamId,
    )) {
      return currentEntry;
    }

    for (final entry in _preloadedWorldSkillsRankings) {
      if (_matchesSeedTeam(
        teamNumber: teamNumber,
        teamId: teamId,
        candidateTeamNumber: entry.teamNumber,
        candidateTeamId: entry.teamId,
      )) {
        return entry;
      }
    }
    return null;
  }

  OpenSkillCacheEntry? _seedOpenSkillEntryForTeam({
    required String teamNumber,
    int? teamId,
  }) {
    final normalizedTeamNumber = teamNumber.trim().toUpperCase();
    final currentEntry = _teamStats?.openSkillEntry;
    if (_matchesSeedTeam(
      teamNumber: normalizedTeamNumber,
      teamId: teamId,
      candidateTeamNumber: currentEntry?.teamNumber,
      candidateTeamId: currentEntry?.id,
    )) {
      return currentEntry;
    }

    final seeded = _preloadedOpenSkillEntriesByTeam[normalizedTeamNumber];
    if (_matchesSeedTeam(
      teamNumber: normalizedTeamNumber,
      teamId: teamId,
      candidateTeamNumber: seeded?.teamNumber,
      candidateTeamId: seeded?.id,
    )) {
      return seeded;
    }
    return null;
  }

  bool _matchesSeedTeam({
    required String teamNumber,
    required int? teamId,
    required String? candidateTeamNumber,
    required int? candidateTeamId,
  }) {
    if (candidateTeamNumber != null &&
        candidateTeamNumber.trim().toUpperCase() == teamNumber) {
      return true;
    }
    return teamId != null && teamId > 0 && candidateTeamId == teamId;
  }

  TeamSummary _bestKnownTeamSummary(
    TeamSummary team, {
    WorldSkillsEntry? worldSkillsEntry,
    OpenSkillCacheEntry? openSkillEntry,
  }) {
    final normalizedKey = team.number.trim().toUpperCase();
    final currentTeam = _currentAccount?.team;
    if (currentTeam != null &&
        (currentTeam.number.trim().toUpperCase() == normalizedKey ||
            (team.id > 0 && currentTeam.id == team.id))) {
      return _mergeTeamSummary(team, currentTeam);
    }

    for (final candidate in _preloadedSearchTeams) {
      if (candidate.number.trim().toUpperCase() == normalizedKey ||
          (team.id > 0 && candidate.id == team.id)) {
        return _mergeTeamSummary(team, candidate);
      }
    }

    if (worldSkillsEntry != null) {
      return _mergeTeamSummary(
        team,
        _teamFromWorldSkills(worldSkillsEntry, _resolvedGradeFor(team.grade)),
      );
    }

    if (openSkillEntry != null) {
      return _mergeTeamSummary(
        team,
        _teamFromOpenSkill(openSkillEntry, _resolvedGradeFor(team.grade)),
      );
    }

    return team;
  }

  TeamSummary _mergeTeamSummary(TeamSummary primary, TeamSummary overlay) {
    return TeamSummary(
      id: primary.id > 0 ? primary.id : overlay.id,
      number: primary.number.trim().isNotEmpty
          ? primary.number
          : overlay.number,
      teamName: primary.teamName.trim().isNotEmpty
          ? primary.teamName
          : overlay.teamName,
      organization: primary.organization.trim().isNotEmpty
          ? primary.organization
          : overlay.organization,
      robotName: primary.robotName.trim().isNotEmpty
          ? primary.robotName
          : overlay.robotName,
      location: _mergeLocationSummary(primary.location, overlay.location),
      grade: primary.grade.trim().isNotEmpty ? primary.grade : overlay.grade,
      registered: primary.registered || overlay.registered,
    );
  }

  LocationSummary _mergeLocationSummary(
    LocationSummary primary,
    LocationSummary overlay,
  ) {
    return LocationSummary(
      venue: primary.venue.trim().isNotEmpty ? primary.venue : overlay.venue,
      address1: primary.address1.trim().isNotEmpty
          ? primary.address1
          : overlay.address1,
      city: primary.city.trim().isNotEmpty ? primary.city : overlay.city,
      region: primary.region.trim().isNotEmpty
          ? primary.region
          : overlay.region,
      postcode: primary.postcode.trim().isNotEmpty
          ? primary.postcode
          : overlay.postcode,
      country: primary.country.trim().isNotEmpty
          ? primary.country
          : overlay.country,
    );
  }

  TeamStatsSnapshot _applyKnownSignalsToTeamStats(TeamStatsSnapshot snapshot) {
    final normalizedTeamNumber = snapshot.team.number.trim().toUpperCase();
    final seededWorldSkillsEntry =
        snapshot.worldSkillsEntry ??
        _seedWorldSkillsEntryForTeam(
          teamNumber: normalizedTeamNumber,
          teamId: snapshot.team.id,
        );
    final seededOpenSkillEntry =
        snapshot.openSkillEntry ??
        _seedOpenSkillEntryForTeam(
          teamNumber: normalizedTeamNumber,
          teamId: snapshot.team.id,
        );
    final mergedTeam = _bestKnownTeamSummary(
      snapshot.team,
      worldSkillsEntry: seededWorldSkillsEntry,
      openSkillEntry: seededOpenSkillEntry,
    );

    if (_sameTeamSummary(snapshot.team, mergedTeam) &&
        identical(snapshot.worldSkillsEntry, seededWorldSkillsEntry) &&
        identical(snapshot.openSkillEntry, seededOpenSkillEntry)) {
      return snapshot;
    }

    return TeamStatsSnapshot(
      team: mergedTeam,
      allEvents: snapshot.allEvents,
      upcomingEvents: snapshot.upcomingEvents,
      rankings: snapshot.rankings,
      matchHistory: snapshot.matchHistory,
      openSkillEntry: seededOpenSkillEntry,
      worldSkillsEntry: seededWorldSkillsEntry,
      lastUpdated: snapshot.lastUpdated,
      errorMessage: snapshot.errorMessage,
    );
  }

  String _resolvedGradeFor(String grade) {
    if (grade.trim().isNotEmpty) {
      return grade;
    }
    return _currentAccount?.team.grade ?? 'High School';
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
    return 'High School';
  }

  List<String> _searchGradeLevelsForCurrentCompetition(
    TeamSummary accountTeam,
  ) {
    switch (_competitionPreference) {
      case AppCompetitionPreference.vexIQ:
        return const <String>['Elementary School', 'Middle School'];
      case AppCompetitionPreference.vexU:
      case AppCompetitionPreference.vexAI:
      case AppCompetitionPreference.vexV5:
        return const <String>['High School', 'Middle School'];
    }
  }

  String _resolvedGradeLabel(WorldSkillsEntry entry) {
    final lowered = entry.program.toLowerCase();
    if (lowered.contains('elementary')) {
      return 'Elementary School';
    }
    if (lowered.contains('middle')) {
      return 'Middle School';
    }
    return 'High School';
  }

  String _resolvedOpenSkillGrade(OpenSkillCacheEntry entry) {
    final normalized = entry.gradeLevel.trim().toLowerCase();
    if (normalized.contains('elementary')) {
      return 'Elementary School';
    }
    if (normalized.contains('middle')) {
      return 'Middle School';
    }
    return 'High School';
  }

  bool _matchesSeasonProgramFilter(SeasonSummary season, String programFilter) {
    final normalizedFilter = programFilter.trim().toLowerCase();
    if (normalizedFilter.isEmpty) {
      return true;
    }

    if (normalizedFilter == solarPrimaryProgramFilter.toLowerCase()) {
      return isSolarPrimaryProgramText('${season.name} ${season.programName}');
    }

    final haystack = '${season.name} ${season.programName}'
        .trim()
        .toLowerCase();
    return haystack.contains(normalizedFilter);
  }

  bool _isPublishedSeason(SeasonSummary season) {
    final match = RegExp(r'(20\d{2})\s*-\s*(20\d{2})').firstMatch(season.name);
    if (match == null) {
      return true;
    }

    final startYear = int.tryParse(match.group(1) ?? '');
    if (startYear == null) {
      return true;
    }

    final now = DateTime.now();
    if (startYear > now.year) {
      return false;
    }
    if (startYear == now.year && now.month < 5) {
      return false;
    }
    return true;
  }

  int _compareSeasonSummaries(SeasonSummary left, SeasonSummary right) {
    return compareSolarSeasonPriority(
      leftName: left.name,
      leftId: left.id,
      rightName: right.name,
      rightId: right.id,
    );
  }

  List<WorldSkillsEntry> _filterPreferredProgramWorldSkills(
    List<WorldSkillsEntry> entries,
  ) {
    final programFilter = _worldSkillsProgramFilterForCurrentCompetition();
    return entries
        .where((entry) {
          return _matchesProgramFilterText(entry.program, programFilter);
        })
        .toList(growable: false);
  }

  String _worldSkillsProgramFilterForCurrentCompetition() {
    switch (_competitionPreference) {
      case AppCompetitionPreference.vexIQ:
        return 'vex iq';
      case AppCompetitionPreference.vexU:
        return 'vex u';
      case AppCompetitionPreference.vexAI:
        return 'vex ai';
      case AppCompetitionPreference.vexV5:
        return solarPrimaryProgramFilter;
    }
  }

  bool _matchesProgramFilterText(String value, String programFilter) {
    final normalizedFilter = programFilter.trim().toLowerCase();
    if (normalizedFilter.isEmpty) {
      return true;
    }

    if (normalizedFilter == solarPrimaryProgramFilter.toLowerCase()) {
      return isSolarPrimaryProgramText(value);
    }

    final haystack = value.trim().toLowerCase();
    return haystack.contains(normalizedFilter);
  }

  bool _hasUsableWorldSkillsRankings(List<WorldSkillsEntry> entries) {
    if (entries.isEmpty) {
      return true;
    }

    final sample = entries.take(12).toList(growable: false);
    final validCount = sample.where((entry) {
      return entry.rank > 0 &&
          entry.teamId > 0 &&
          entry.teamNumber.trim().isNotEmpty &&
          (entry.combinedScore > 0 ||
              entry.programmingScore > 0 ||
              entry.driverScore > 0);
    }).length;

    return validCount >= (sample.length / 2).ceil();
  }

  bool _hasUsableOpenSkillRankings(List<OpenSkillCacheEntry> entries) {
    if (entries.isEmpty) {
      return true;
    }

    final sample = <OpenSkillCacheEntry>[
      ...entries.take(8),
      if (entries.length > 16) ...entries.skip(entries.length - 8),
    ];
    final validCount = sample.where((entry) {
      return entry.ranking > 0 &&
          entry.id > 0 &&
          entry.teamNumber.trim().isNotEmpty;
    }).length;
    final distinctOrdinals = sample
        .map((entry) => entry.openSkillOrdinal.toStringAsFixed(2))
        .toSet()
        .length;
    final distinctApValues = sample
        .map((entry) => entry.apPerMatch.toStringAsFixed(2))
        .toSet()
        .length;
    final distinctWpValues = sample
        .map((entry) => entry.wpPerMatch.toStringAsFixed(2))
        .toSet()
        .length;

    if (validCount < (sample.length / 2).ceil()) {
      return false;
    }
    if (sample.length >= 10 && distinctOrdinals < 4) {
      return false;
    }
    if (sample.length >= 10 && distinctApValues < 3 && distinctWpValues < 3) {
      return false;
    }
    return true;
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
        themeModePreference: _themeModePreference,
        competitionPreference: _competitionPreference,
        followMode: _followMode,
        chromeAccentPreference: _chromeAccentPreference,
        customChromeAccentValue: _customChromeAccentValue,
        dismissedWorldsScheduleAnnouncementId:
            _dismissedWorldsScheduleAnnouncementId,
        notificationCenterSeenAtMillis: _notificationCenterSeenAtMillis,
        favoriteTeamNumbers: _favoriteTeamNumbers,
        bookmarkedEventIds: _bookmarkedEventIds,
        developerScrimmageEnabled: _developerScrimmageEnabled,
        developerScrimmageStartAtMillis: _developerScrimmageStartAtMillis,
        teamRatings: _teamRatings,
      ),
    );
  }

  DateTime _defaultDeveloperScrimmageStartAt() {
    final now = DateTime.now();
    final roundedMinutes = ((now.minute + 14) ~/ 15) * 15;
    final anchored = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      0,
    ).add(Duration(minutes: roundedMinutes));
    return anchored.add(const Duration(minutes: 30));
  }

  int _resolvedScrimmageSeasonId() {
    if (_preferredSeasonId != null && _preferredSeasonId! > 0) {
      return _preferredSeasonId!;
    }
    if (_preloadedSearchTeamsSeasonId != null &&
        _preloadedSearchTeamsSeasonId! > 0) {
      return _preloadedSearchTeamsSeasonId!;
    }
    if (_preloadedSearchSeasonId != null && _preloadedSearchSeasonId! > 0) {
      return _preloadedSearchSeasonId!;
    }
    final currentTeamStats = _teamStats;
    if (currentTeamStats != null) {
      for (final event in currentTeamStats.futureEvents) {
        if (event.seasonId > 0) {
          return event.seasonId;
        }
      }
      for (final event in currentTeamStats.allEvents.reversed) {
        if (event.seasonId > 0) {
          return event.seasonId;
        }
      }
    }
    return DateTime.now().year;
  }

  String _validateEmail(String email) {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) {
      throw const FormatException('Enter a valid email address.');
    }
    return normalizedEmail;
  }

  TeamSummary _guestTeamSummary({required String grade}) {
    return TeamSummary(
      id: 0,
      number: 'GUEST',
      teamName: 'Guest Account',
      organization: '',
      robotName: '',
      location: const LocationSummary(
        venue: '',
        address1: '',
        city: '',
        region: '',
        postcode: '',
        country: '',
      ),
      grade: grade,
      registered: false,
    );
  }

  String _defaultGradeForCompetition(AppCompetitionPreference preference) {
    switch (preference) {
      case AppCompetitionPreference.vexIQ:
        return 'Middle School';
      case AppCompetitionPreference.vexU:
        return 'College';
      case AppCompetitionPreference.vexAI:
      case AppCompetitionPreference.vexV5:
        return 'High School';
    }
  }

  String _localAccountEmailForTeam(String teamNumber) {
    final sanitized = teamNumber
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final localPart = sanitized.isEmpty ? 'device-user' : 'team-$sanitized';
    return '$localPart@$_localAccountDomain';
  }

  Future<void> _setSignedInAccount(
    AppAccount account, {
    bool notify = true,
  }) async {
    final currentUserKey = _currentAccount?.normalizedEmail;
    final nextUserKey = account.normalizedEmail;
    final currentTeamKey = _currentAccount?.team.number.trim().toUpperCase();
    final nextTeamKey = account.team.number.trim().toUpperCase();
    final didUserChange =
        currentUserKey != nextUserKey || currentTeamKey != nextTeamKey;

    _currentAccount = account;
    _isPasswordRecoveryActive = false;
    if (didUserChange) {
      _clearTeamDerivedCaches();
    }
    _teamStats = _withLocalScrimmage(TeamStatsSnapshot(team: account.team));
    await _repository.saveAccount(account);
    await _saveSettings(currentUserEmail: account.normalizedEmail);
    if (notify) {
      notifyListeners();
    }
  }

  Future<void> _clearSignedInState() async {
    _currentAccount = null;
    _teamStats = null;
    _isPasswordRecoveryActive = false;
    _clearTeamDerivedCaches();
    await _iosCompanionService.clear();
    await _saveSettings(clearCurrentUserEmail: true);
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_authStateSubscription?.cancel() ?? Future<void>.value());
    unawaited(_authService.dispose());
    unawaited(_repository.close());
    _api?.close();
    super.dispose();
  }
}
