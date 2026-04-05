import 'package:flutter/services.dart';

import '../models/robot_events_models.dart';
import '../ui/models/solar_notification_center_snapshot.dart';

class SolarIosCompanionService {
  const SolarIosCompanionService();

  static const MethodChannel _channel = MethodChannel('solar/ios_companion');

  Future<void> sync({
    required String teamNumber,
    required SolarNotificationCenterSnapshot snapshot,
  }) async {
    try {
      await _channel.invokeMethod<void>('syncCompanion', <String, Object?>{
        'teamNumber': teamNumber,
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
      'fieldName': match.field,
      'scheduledAt': (match.scheduled ?? match.started)?.millisecondsSinceEpoch,
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
      'fieldName': result.match.field,
      'completedAt': result.completedAt?.millisecondsSinceEpoch,
      'allianceColor': result.allianceColor,
      'allianceScore': result.allianceScore,
      'opponentScore': result.opponentScore,
      'redAlliance': _allianceLabel(result.match, 'red'),
      'blueAlliance': _allianceLabel(result.match, 'blue'),
    };
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
}
