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
  });

  static const empty = AppSettings(hasCompletedOnboarding: false);

  final bool hasCompletedOnboarding;
  final String? currentUserEmail;
  final int? preferredSeasonId;
  final AppThemeModePreference themeModePreference;
  final AppCompetitionPreference competitionPreference;

  AppSettings copyWith({
    bool? hasCompletedOnboarding,
    String? currentUserEmail,
    int? preferredSeasonId,
    AppThemeModePreference? themeModePreference,
    AppCompetitionPreference? competitionPreference,
    bool clearCurrentUserEmail = false,
    bool clearPreferredSeasonId = false,
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
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'hasCompletedOnboarding': hasCompletedOnboarding,
      'currentUserEmail': currentUserEmail,
      'preferredSeasonId': preferredSeasonId,
      'themeModePreference': themeModePreference.name,
      'competitionPreference': competitionPreference.name,
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
