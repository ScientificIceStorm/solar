import 'package:flutter/services.dart';

import '../models/robot_events_models.dart';
import '../ui/models/solar_notification_center_snapshot.dart';
import '../ui/models/team_stats_snapshot.dart';

class SolarIosCompanionService {
  const SolarIosCompanionService();

  static const MethodChannel _channel = MethodChannel('solar/ios_companion');

  Future<void> sync({
    required String teamNumber,
    required SolarNotificationCenterSnapshot snapshot,
    TeamStatsSnapshot? teamStats,
  }) async {
    try {
      await _channel.invokeMethod<void>('syncCompanion', <String, Object?>{
        'teamNumber': teamNumber,
        'teamName': teamStats?.team.teamName,
        'recordLabel': teamStats?.recordLabel,
        'worldRankLabel': teamStats?.skillsRankLabel,
        'solarizeRankLabel': teamStats?.openSkillEntry == null
            ? null
            : '#${teamStats!.openSkillEntry!.ranking}',
        'predictedScoreLine': _predictedScoreLine(snapshot),
        'upcoming': _upcomingPayload(snapshot),
        'recentResults': snapshot.recentResults
            .map<Map<String, Object?>>(_resultPayload)
            .toList(growable: false),
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
    } on MissingPluginException {
      // iOS-only bridge.
    } on PlatformException {
      // Keep the app responsive even if native sync is unavailable.
    }
  }

  Future<void> clear() async {
    try {
      await _channel.invokeMethod<void>('clearCompanion');
    } on MissingPluginException {
      // iOS-only bridge.
    } on PlatformException {
      // Ignore bridge errors.
    }
  }

  Map<String, Object?>? _upcomingPayload(
    SolarNotificationCenterSnapshot snapshot,
  ) {
    final match = snapshot.upcomingMatch;
    if (match == null) {
      return null;
    }

    return <String, Object?>{
      'id': match.id,
      'eventName': snapshot.upcomingEvent?.name ?? match.event.name,
      'divisionName': match.division.name,
      'matchName': match.name,
      'matchLabel': _matchLabel(match),
      'fieldName': match.field,
      'scheduledAt': _estimatedScheduledAt(snapshot)?.millisecondsSinceEpoch,
      'redAlliance': _allianceLabel(match, 'red'),
      'blueAlliance': _allianceLabel(match, 'blue'),
    };
  }

  Map<String, Object?> _resultPayload(SolarRecentMatchResult result) {
    return <String, Object?>{
      'id': result.match.id,
      'eventName': result.event?.name ?? result.match.event.name,
      'divisionName': result.match.division.name,
      'matchName': result.match.name,
      'matchLabel': _matchLabel(result.match),
      'fieldName': result.match.field,
      'completedAt': result.completedAt?.millisecondsSinceEpoch,
      'allianceColor': result.allianceColor,
      'allianceScore': result.allianceScore,
      'opponentScore': result.opponentScore,
      'redAlliance': _allianceLabel(result.match, 'red'),
      'blueAlliance': _allianceLabel(result.match, 'blue'),
    };
  }

  String? _predictedScoreLine(SolarNotificationCenterSnapshot snapshot) {
    final prediction = snapshot.upcomingPrediction;
    if (prediction == null) {
      return null;
    }
    return '${prediction.predictedRedScore}-${prediction.predictedBlueScore}';
  }

  String _allianceLabel(MatchSummary match, String color) {
    for (final alliance in match.alliances) {
      if (alliance.color.trim().toLowerCase() == color) {
        return alliance.teams
            .map<String>((team) => team.number)
            .where((value) => value.trim().isNotEmpty)
            .join(' • ');
      }
    }
    return '';
  }

  DateTime? _estimatedScheduledAt(SolarNotificationCenterSnapshot snapshot) {
    final upcoming = snapshot.upcomingMatch;
    if (upcoming == null) {
      return null;
    }

    final base = upcoming.scheduled ?? upcoming.started;
    if (base == null) {
      return null;
    }

    Duration delay = Duration.zero;
    for (final result in snapshot.recentResults) {
      if (result.match.event.id != upcoming.event.id) {
        continue;
      }
      final scheduled = result.match.scheduled;
      final started = result.match.started;
      if (scheduled == null || started == null) {
        continue;
      }
      final candidate = started.difference(scheduled);
      if (candidate.inMinutes <= 0) {
        continue;
      }
      if (candidate.inMinutes > 45) {
        continue;
      }
      delay = candidate;
      break;
    }
    return base.add(delay);
  }

  String _matchLabel(MatchSummary match) {
    switch (match.round) {
      case MatchRound.qualification:
        final number = match.matchNumber > 0 ? match.matchNumber : match.instance;
        return number > 0 ? 'Q$number' : 'Q';
      case MatchRound.quarterfinals:
        return _eliminationLabel('QF', match);
      case MatchRound.semifinals:
        return _eliminationLabel('SF', match);
      case MatchRound.finals:
        return _eliminationLabel('F', match);
      case MatchRound.round16:
        return _eliminationLabel('R16', match);
      case MatchRound.round32:
        return _eliminationLabel('R32', match);
      case MatchRound.round64:
        return _eliminationLabel('R64', match);
      case MatchRound.round128:
        return _eliminationLabel('R128', match);
      case MatchRound.practice:
        final number = match.matchNumber > 0 ? match.matchNumber : match.instance;
        return number > 0 ? 'P$number' : 'P';
      default:
        return match.name.trim().isEmpty ? 'Match' : match.name.trim();
    }
  }

  String _eliminationLabel(String prefix, MatchSummary match) {
    final series = match.instance > 0 ? '${match.instance}' : '';
    final game = match.matchNumber > 0 ? '${match.matchNumber}' : '';
    if (series.isNotEmpty && game.isNotEmpty) {
      return '$prefix$series-$game';
    }
    if (series.isNotEmpty) {
      return '$prefix$series';
    }
    if (game.isNotEmpty) {
      return '$prefix$game';
    }
    return prefix;
  }
}
