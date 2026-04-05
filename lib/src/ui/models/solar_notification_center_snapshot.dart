import '../../models/robot_events_models.dart';

class SolarNotificationCenterSnapshot {
  const SolarNotificationCenterSnapshot({
    this.upcomingEvent,
    this.upcomingMatch,
    this.recentResults = const <SolarRecentMatchResult>[],
  });

  final EventSummary? upcomingEvent;
  final MatchSummary? upcomingMatch;
  final List<SolarRecentMatchResult> recentResults;

  bool get hasItems => upcomingMatch != null || recentResults.isNotEmpty;

  int get itemCount => (upcomingMatch == null ? 0 : 1) + recentResults.length;
}

class SolarRecentMatchResult {
  const SolarRecentMatchResult({
    required this.event,
    required this.match,
    required this.allianceColor,
    required this.allianceScore,
    required this.opponentScore,
  });

  final EventSummary? event;
  final MatchSummary match;
  final String allianceColor;
  final int allianceScore;
  final int opponentScore;

  bool get won => allianceScore > opponentScore;

  bool get tied => allianceScore == opponentScore;

  DateTime? get completedAt => match.started ?? match.scheduled;
}
