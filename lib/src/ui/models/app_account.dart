import '../../models/robot_events_models.dart';

enum AppThemeModePreference { system, light, dark }

enum AppCompetitionPreference { vexV5, vexIQ, vexU, vexAI }

class AppAccount {
  const AppAccount({
    required this.fullName,
    required this.email,
    required this.password,
    required this.team,
    required this.createdAt,
  });

  final String fullName;
  final String email;
  final String password;
  final TeamSummary team;
  final DateTime createdAt;

  String get normalizedEmail => email.trim().toLowerCase();

  AppAccount copyWith({
    String? fullName,
    String? email,
    String? password,
    TeamSummary? team,
    DateTime? createdAt,
  }) {
    return AppAccount(
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      password: password ?? this.password,
      team: team ?? this.team,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory AppAccount.fromJson(Map<String, dynamic> json) {
    return AppAccount(
      fullName: (json['fullName'] as String?) ?? '',
      email: (json['email'] as String?) ?? '',
      password: (json['password'] as String?) ?? '',
      team: TeamSummary.fromJson(
        Map<String, dynamic>.from(
          (json['team'] as Map<Object?, Object?>?) ??
              const <Object?, Object?>{},
        ),
      ),
      createdAt:
          DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'fullName': fullName,
      'email': normalizedEmail,
      'password': password,
      'team': team.toJson(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

class AppSettings {
  const AppSettings({
    required this.hasCompletedOnboarding,
    this.currentUserEmail,
    this.preferredSeasonId,
    this.themeModePreference = AppThemeModePreference.system,
    this.competitionPreference = AppCompetitionPreference.vexV5,
    this.dismissedWorldsScheduleAnnouncementId,
    this.notificationCenterSeenAtMillis,
    this.favoriteTeamNumbers = const <String>[],
    this.bookmarkedEventIds = const <int>[],
    this.developerScrimmageEnabled = false,
    this.developerScrimmageStartAtMillis,
    this.teamRatings = const <String, int>{},
  });

  static const empty = AppSettings(hasCompletedOnboarding: false);

  final bool hasCompletedOnboarding;
  final String? currentUserEmail;
  final int? preferredSeasonId;
  final AppThemeModePreference themeModePreference;
  final AppCompetitionPreference competitionPreference;
  final String? dismissedWorldsScheduleAnnouncementId;
  final int? notificationCenterSeenAtMillis;
  final List<String> favoriteTeamNumbers;
  final List<int> bookmarkedEventIds;
  final bool developerScrimmageEnabled;
  final int? developerScrimmageStartAtMillis;
  final Map<String, int> teamRatings;

  AppSettings copyWith({
    bool? hasCompletedOnboarding,
    String? currentUserEmail,
    int? preferredSeasonId,
    AppThemeModePreference? themeModePreference,
    AppCompetitionPreference? competitionPreference,
    String? dismissedWorldsScheduleAnnouncementId,
    int? notificationCenterSeenAtMillis,
    List<String>? favoriteTeamNumbers,
    List<int>? bookmarkedEventIds,
    bool? developerScrimmageEnabled,
    int? developerScrimmageStartAtMillis,
    Map<String, int>? teamRatings,
    bool clearCurrentUserEmail = false,
    bool clearPreferredSeasonId = false,
    bool clearDismissedWorldsScheduleAnnouncementId = false,
    bool clearNotificationCenterSeenAtMillis = false,
    bool clearDeveloperScrimmageStartAtMillis = false,
  }) {
    return AppSettings(
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      currentUserEmail: clearCurrentUserEmail
          ? null
          : currentUserEmail ?? this.currentUserEmail,
      preferredSeasonId: clearPreferredSeasonId
          ? null
          : preferredSeasonId ?? this.preferredSeasonId,
      themeModePreference: themeModePreference ?? this.themeModePreference,
      competitionPreference:
          competitionPreference ?? this.competitionPreference,
      dismissedWorldsScheduleAnnouncementId:
          clearDismissedWorldsScheduleAnnouncementId
          ? null
          : dismissedWorldsScheduleAnnouncementId ??
                this.dismissedWorldsScheduleAnnouncementId,
      notificationCenterSeenAtMillis: clearNotificationCenterSeenAtMillis
          ? null
          : notificationCenterSeenAtMillis ??
                this.notificationCenterSeenAtMillis,
      favoriteTeamNumbers: favoriteTeamNumbers ?? this.favoriteTeamNumbers,
      bookmarkedEventIds: bookmarkedEventIds ?? this.bookmarkedEventIds,
      developerScrimmageEnabled:
          developerScrimmageEnabled ?? this.developerScrimmageEnabled,
      developerScrimmageStartAtMillis: clearDeveloperScrimmageStartAtMillis
          ? null
          : developerScrimmageStartAtMillis ??
                this.developerScrimmageStartAtMillis,
      teamRatings: teamRatings ?? this.teamRatings,
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      hasCompletedOnboarding:
          (json['hasCompletedOnboarding'] as bool?) ?? false,
      currentUserEmail:
          (json['currentUserEmail'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['currentUserEmail'] as String).trim().toLowerCase(),
      preferredSeasonId: json['preferredSeasonId'] is num
          ? (json['preferredSeasonId'] as num).toInt()
          : null,
      themeModePreference: _themeModeFromJson(json['themeModePreference']),
      competitionPreference: _competitionFromJson(
        json['competitionPreference'],
      ),
      dismissedWorldsScheduleAnnouncementId:
          (json['dismissedWorldsScheduleAnnouncementId'] as String?)
                  ?.trim()
                  .isEmpty ??
              true
          ? null
          : (json['dismissedWorldsScheduleAnnouncementId'] as String).trim(),
      notificationCenterSeenAtMillis:
          json['notificationCenterSeenAtMillis'] is num
          ? (json['notificationCenterSeenAtMillis'] as num).toInt()
          : null,
      favoriteTeamNumbers:
          ((json['favoriteTeamNumbers'] as List<Object?>?) ?? const <Object?>[])
              .whereType<String>()
              .map((value) => value.trim().toUpperCase())
              .where((value) => value.isNotEmpty)
              .toList(growable: false),
      bookmarkedEventIds:
          ((json['bookmarkedEventIds'] as List<Object?>?) ?? const <Object?>[])
              .whereType<num>()
              .map((value) => value.toInt())
              .where((value) => value > 0)
              .toList(growable: false),
      developerScrimmageEnabled:
          (json['developerScrimmageEnabled'] as bool?) ?? false,
      developerScrimmageStartAtMillis:
          json['developerScrimmageStartAtMillis'] is num
          ? (json['developerScrimmageStartAtMillis'] as num).toInt()
          : null,
      teamRatings:
          ((json['teamRatings'] as Map<Object?, Object?>?) ??
                  const <Object?, Object?>{})
              .map((key, value) {
                final normalizedKey =
                    (key as String?)?.trim().toUpperCase() ?? '';
                final rating = value is num ? value.toInt() : 0;
                return MapEntry(normalizedKey, rating.clamp(1, 5));
              })
            ..removeWhere((key, value) => key.isEmpty),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'hasCompletedOnboarding': hasCompletedOnboarding,
      'currentUserEmail': currentUserEmail,
      'preferredSeasonId': preferredSeasonId,
      'themeModePreference': themeModePreference.name,
      'competitionPreference': competitionPreference.name,
      'dismissedWorldsScheduleAnnouncementId':
          dismissedWorldsScheduleAnnouncementId,
      'notificationCenterSeenAtMillis': notificationCenterSeenAtMillis,
      'favoriteTeamNumbers': favoriteTeamNumbers,
      'bookmarkedEventIds': bookmarkedEventIds,
      'developerScrimmageEnabled': developerScrimmageEnabled,
      'developerScrimmageStartAtMillis': developerScrimmageStartAtMillis,
      'teamRatings': teamRatings,
    };
  }
}

AppThemeModePreference _themeModeFromJson(Object? value) {
  final raw = (value as String?)?.trim();
  for (final mode in AppThemeModePreference.values) {
    if (mode.name == raw) {
      return mode;
    }
  }
  return AppThemeModePreference.system;
}

AppCompetitionPreference _competitionFromJson(Object? value) {
  final raw = (value as String?)?.trim();
  for (final competition in AppCompetitionPreference.values) {
    if (competition.name == raw) {
      return competition;
    }
  }
  return AppCompetitionPreference.vexV5;
}
