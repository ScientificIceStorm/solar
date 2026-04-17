import '../../models/robot_events_models.dart';
import 'solar_match_prediction.dart';

class SolarNotificationCenterSnapshot {
  const SolarNotificationCenterSnapshot({
    this.upcomingEvent,
    this.upcomingMatch,
    this.upcomingPrediction,
    this.recentResults = const <SolarRecentMatchResult>[],
  });

  final EventSummary? upcomingEvent;
  final MatchSummary? upcomingMatch;
  final SolarMatchPrediction? upcomingPrediction;
  final List<SolarRecentMatchResult> recentResults;

  bool get hasItems => upcomingMatch != null || recentResults.isNotEmpty;

  int get itemCount => (upcomingMatch == null ? 0 : 1) + recentResults.length;

  int unreadCount(int? seenAtMillis) {
    if (seenAtMillis == null) {
      return itemCount;
    }

    final seenAt = DateTime.fromMillisecondsSinceEpoch(seenAtMillis);
    var unread = 0;
    final upcomingAnchor = upcomingMatch?.scheduled ?? upcomingMatch?.started;
    if (upcomingAnchor != null && upcomingAnchor.isAfter(seenAt)) {
      unread += 1;
    }

    for (final result in recentResults) {
      final completedAt = result.completedAt;
      if (completedAt != null && completedAt.isAfter(seenAt)) {
        unread += 1;
      }
    }
    return unread;
  }
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
